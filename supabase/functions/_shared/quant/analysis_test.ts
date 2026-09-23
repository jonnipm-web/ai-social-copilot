/**
 * Risk, portfolio, signals, provider, analysis result, IVE/LLM boundary
 * and observability tests — IV-QUANT-FOUNDATION-01.
 *
 * Execução:
 *   deno test supabase/functions/_shared/quant/analysis_test.ts
 */
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { analyzeSeries, FORMULAS, type QuantAnalysisResult } from './analysis.ts';
import { buildExplanationRequest, checkNarrativeGrounding, renderNarrative } from './ive_boundary.ts';
import { instrumentKey } from './instrument.ts';
import { quantLogEvent } from './observability.ts';
import { buyAndHoldReturn, type ManualPortfolio, type PricePoint, valuePortfolio } from './portfolio.ts';
import { FixtureProvider } from './provider.ts';
import { concentration, RISK_NOT_IMPLEMENTED, returnCorrelationMatrix, seriesRiskOverview, validateWeights } from './risk.ts';
import { movingAverageCrossovers } from './signals.ts';
import { createPriceSeries, type PriceSeries } from './timeseries.ts';
import { formatNumber, formatRatioAsPercent } from './display.ts';
import { normalizeWatchlist } from './domain_future.ts';
import {
  close,
  dailyBars,
  G1,
  G1_CLOSES,
  G4,
  G4_CLOSES,
  goldenFixtureDatasets,
  INSTR_A,
  INSTR_B,
  INSTR_BRL,
  INSTR_C,
  PORTFOLIO,
} from './fixtures/golden.ts';
import type { QuantResult } from './errors.ts';

function val<T>(r: QuantResult<T>): T {
  if (!r.ok) throw new Error(`expected ok, got ${r.error.code}: ${r.error.message}`);
  return r.value;
}
function code<T>(r: QuantResult<T>): string {
  assert(!r.ok, 'expected failure');
  return (r as { ok: false; error: { code: string } }).error.code;
}

const DAY = 86_400_000;
/** "Now" = Monday 2026-01-12 12:00Z: the G1 fixture's last bar (Fri 2026-01-09) is 3.5 days old → FRESH for DAILY. */
const NOW = Date.UTC(2026, 0, 12, 12);
const clock = () => NOW;

async function g1Series(): Promise<PriceSeries> {
  const p = new FixtureProvider(goldenFixtureDatasets(), clock);
  const res = val(await p.historicalBars({ instrument: INSTR_A, frequency: 'DAILY', fromT: 0, toT: 8.64e15, adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED' }));
  return val(createPriceSeries(INSTR_A, res.provenance, res.data));
}

// ------------------------------------------------------------ risk + portfolio

Deno.test('AN-01 series risk overview = golden σ and MDD, explicitly FOUNDATION_PARTIAL', () => {
  const r = val(seriesRiskOverview(G1_CLOSES, 252));
  assert(close(r.volatility.perPeriod, G1.volPerPeriod));
  assert(close(r.drawdown.maxDrawdown, G1.maxDrawdown));
  assertEquals(r.coverage, 'FOUNDATION_PARTIAL');
  for (const m of ['VAR', 'CVAR', 'BETA', 'FACTOR_EXPOSURE']) assert(r.notImplemented.includes(m));
  assertEquals([...RISK_NOT_IMPLEMENTED].length >= 4, true);
});
Deno.test('AN-02 weights validation: sum to 1 (documented tolerance), non-negative, unique', () => {
  assert(validateWeights([{ key: 'a', weight: 0.5 }, { key: 'b', weight: 0.5 }]).ok);
  assert(validateWeights([{ key: 'a', weight: 0.1 }, { key: 'b', weight: 0.2 }, { key: 'c', weight: 0.7 }]).ok); // 0.1+0.2 float noise tolerated
  assertEquals(code(validateWeights([{ key: 'a', weight: 0.5 }, { key: 'b', weight: 0.49 }])), 'INVALID_PORTFOLIO');
  assertEquals(code(validateWeights([{ key: 'a', weight: 1.5 }, { key: 'b', weight: -0.5 }])), 'INVALID_PORTFOLIO');
  assertEquals(code(validateWeights([{ key: 'a', weight: 0.5 }, { key: 'a', weight: 0.5 }])), 'INVALID_PORTFOLIO');
  assertEquals(code(validateWeights([{ key: 'a', weight: NaN }])), 'INVALID_PORTFOLIO');
  assertEquals(code(validateWeights([])), 'INVALID_PORTFOLIO');
});
Deno.test('AN-03 concentration: HHI / effective holdings / max weight — golden', () => {
  const c = val(concentration([{ key: 'A', weight: 0.25 }, { key: 'B', weight: 0.25 }, { key: 'C', weight: 0.5 }]));
  assert(close(c.hhi, PORTFOLIO.hhi) && close(c.effectiveHoldings, PORTFOLIO.effective));
  assertEquals([c.maxWeight, c.maxWeightKey, c.holdings], [0.5, 'C', 3]);
});

const px = (price: number, asOf = '2026-01-09T00:00:00.000Z', currency = 'USD'): PricePoint => ({ price, currency, asOf, frequency: 'DAILY' });
const DEMO: ManualPortfolio = {
  source: 'DEMO',
  baseCurrency: 'USD',
  positions: [
    { instrument: INSTR_A, quantity: 10, costBasisPerUnit: 40 },
    { instrument: INSTR_B, quantity: 5 },
    { instrument: INSTR_C, quantity: 20 },
  ],
};
const DEMO_PRICES = new Map([[instrumentKey(INSTR_A), px(50)], [instrumentKey(INSTR_B), px(100)], [instrumentKey(INSTR_C), px(50)]]);

Deno.test('AN-04 portfolio valuation — golden allocation, weights sum to 1, unrealized return from cost basis', () => {
  const v = val(valuePortfolio(DEMO, DEMO_PRICES, NOW));
  assertEquals(v.totalMarketValue, PORTFOLIO.total);
  assertEquals(v.holdings.map((h) => h.weight), PORTFOLIO.weights);
  assert(close(v.holdings.reduce((s, h) => s + h.weight, 0), 1));
  assert(close(v.concentration.hhi, PORTFOLIO.hhi));
  assert(close(v.holdings[0].unrealizedReturn as number, 0.25)); // 50/40 − 1
  assertEquals(v.holdings[1].unrealizedReturn, null);
  assertEquals(v.warnings, []);
});
Deno.test('AN-05 currency mismatch is a stated limitation, never a silent sum', () => {
  const mixed: ManualPortfolio = { ...DEMO, positions: [...DEMO.positions, { instrument: INSTR_BRL, quantity: 1 }] };
  assertEquals(code(valuePortfolio(mixed, DEMO_PRICES, NOW)), 'CURRENCY_MISMATCH');
  const wrongPriceCcy = new Map(DEMO_PRICES);
  wrongPriceCcy.set(instrumentKey(INSTR_B), px(100, undefined, 'EUR'));
  assertEquals(code(valuePortfolio(DEMO, wrongPriceCcy, NOW)), 'CURRENCY_MISMATCH');
});
Deno.test('AN-06 portfolio input validation: shorts, zero qty, duplicates, missing price, source', () => {
  const withPos = (positions: ManualPortfolio['positions']) => ({ ...DEMO, positions });
  assertEquals(code(valuePortfolio(withPos([{ instrument: INSTR_A, quantity: -1 }]), DEMO_PRICES, NOW)), 'INVALID_PORTFOLIO');
  assertEquals(code(valuePortfolio(withPos([{ instrument: INSTR_A, quantity: 0 }]), DEMO_PRICES, NOW)), 'INVALID_PORTFOLIO');
  assertEquals(code(valuePortfolio(withPos([{ instrument: INSTR_A, quantity: 1 }, { instrument: INSTR_A, quantity: 2 }]), DEMO_PRICES, NOW)), 'INVALID_PORTFOLIO');
  assertEquals(code(valuePortfolio(DEMO, new Map(), NOW)), 'INSUFFICIENT_DATA');
  // deno-lint-ignore no-explicit-any
  assertEquals(code(valuePortfolio({ ...DEMO, source: 'BROKER' as any }, DEMO_PRICES, NOW)), 'INVALID_PORTFOLIO');
});
Deno.test('AN-07 stale position prices surface as warnings with freshness per holding', () => {
  const stale = new Map(DEMO_PRICES);
  stale.set(instrumentKey(INSTR_C), px(50, '2025-11-01T00:00:00.000Z'));
  const v = val(valuePortfolio(DEMO, stale, NOW));
  assertEquals(v.holdings[2].priceFreshness.state, 'STALE');
  assert(v.warnings.some((w) => w.code === 'DATA_STALE'));
});
Deno.test('AN-08 buy-and-hold return over the common period — golden 0 (+10 % / −10 % at 50/50)', () => {
  const prov = { providerId: 'fixture-golden', providerKind: 'FIXTURE', retrievedAt: '2026-01-12T00:00:00.000Z', frequency: 'DAILY', currency: 'USD', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', trust: 'SYNTHETIC_FIXTURE' } as const;
  const a = val(createPriceSeries(INSTR_A, prov, dailyBars([100, 105, 110])));
  const b = val(createPriceSeries(INSTR_B, prov, dailyBars([50, 47, 45])));
  const r = val(buyAndHoldReturn([{ key: instrumentKey(INSTR_A), weight: 0.5 }, { key: instrumentKey(INSTR_B), weight: 0.5 }], [a, b], 'close', 'USD'));
  assert(close(r.value, 0));
  assertEquals(code(buyAndHoldReturn([{ key: instrumentKey(INSTR_A), weight: 1 }], [a], 'close', 'BRL')), 'CURRENCY_MISMATCH');
  assertEquals(code(buyAndHoldReturn([{ key: 'EQUITY:XTST:NOPE:USD', weight: 1 }], [a], 'close', 'USD')), 'INSUFFICIENT_DATA');
});
Deno.test('AN-09 return correlation matrix aligns on timestamps; undefined pairs reported, never 0', () => {
  const prov = { providerId: 'fixture-golden', providerKind: 'FIXTURE', retrievedAt: '2026-01-12T00:00:00.000Z', frequency: 'DAILY', currency: 'USD', adjustment: 'UNADJUSTED', trust: 'SYNTHETIC_FIXTURE' } as const;
  const a = val(createPriceSeries(INSTR_A, prov, dailyBars([100, 110, 99, 108.9, 98.01])));
  const b = val(createPriceSeries(INSTR_B, prov, dailyBars([200, 220, 198, 217.8, 196.02]))); // 2× a → identical returns
  const c = val(createPriceSeries(INSTR_C, prov, dailyBars([10, 10, 10, 10, 10]))); // constant
  const m = val(returnCorrelationMatrix([a, b, c], 'close'));
  assert(close(m[0].correlation as number, 1, 1e-9));
  assertEquals([m[1].correlation, m[1].error], [null, 'CALCULATION_ERROR']);
  assertEquals(code(returnCorrelationMatrix([a], 'close')), 'INSUFFICIENT_DATA');
});

// ------------------------------------------------------------ signals

Deno.test('AN-10 MA crossovers — golden G4; signals are descriptive, never recommendations', () => {
  const ts = G4_CLOSES.map((_, i) => i * DAY);
  const s = val(movingAverageCrossovers(G4_CLOSES, ts, 2, 3));
  assertEquals(s.map((x) => ({ index: x.index, direction: x.direction })), G4.crosses);
  for (const x of s) {
    assertEquals(x.nature, 'DESCRIPTIVE');
    assertEquals(x.isRecommendation, false);
    assert(/not a recommendation/.test(x.description));
    assert(!/\b(buy|sell|compra|venda)\b/i.test(x.description));
  }
  assertEquals(code(movingAverageCrossovers(G4_CLOSES, ts, 3, 2)), 'INVALID_PARAMETER');
  assertEquals(code(movingAverageCrossovers(G4_CLOSES, ts.slice(1), 2, 3)), 'INVALID_PARAMETER');
});

// ------------------------------------------------------------ provider

Deno.test('AN-20 fixture provider: provenance stamped, synthetic trust, no live-price pretence', async () => {
  const p = new FixtureProvider(goldenFixtureDatasets(), clock);
  const q = val(await p.latestQuote(INSTR_A));
  assertEquals(q.data.price, 98.01);
  assertEquals(q.data.marketTimestamp, '2026-01-09T00:00:00.000Z'); // last bar time, not "now"
  assertEquals(q.provenance.retrievedAt, new Date(NOW).toISOString());
  assertEquals([q.provenance.providerKind, q.provenance.trust], ['FIXTURE', 'SYNTHETIC_FIXTURE']);
  assertEquals(code(await p.latestQuote({ ...INSTR_A, symbol: 'NOPE' })), 'INVALID_INSTRUMENT');
  assertEquals(val(await p.lookupInstrument('tsta')).map(instrumentKey), [instrumentKey(INSTR_A)]);
  assertEquals(code(await p.historicalBars({ instrument: INSTR_A, frequency: 'INTRADAY_1M', fromT: 0, toT: 1, adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED' })), 'INVALID_PARAMETER');
  assertEquals(code(await p.historicalBars({ instrument: INSTR_A, frequency: 'DAILY', fromT: 5, toT: 1, adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED' })), 'INVALID_PARAMETER');
});

// ------------------------------------------------------------ analysis result

Deno.test('AN-30 end-to-end: provider → normalize → analyze reproduces the golden numbers with full provenance', async () => {
  const r = val(await analyzeSeries(await g1Series(), { periodsPerYear: 252, smaWindows: [2, 3] }, clock));
  const m = (id: string, w?: number) => r.metrics.find((x) => x.id === id && (w === undefined || x.parameters?.window === w))!.value as number;
  assert(close(m('CUMULATIVE_RETURN'), G1.cumulative));
  assert(close(m('MEAN_SIMPLE_RETURN'), 0));
  assert(close(m('VOLATILITY_PER_PERIOD'), G1.volPerPeriod));
  assert(close(m('VOLATILITY_ANNUALIZED'), G1.volAnnualized252));
  assert(close(m('MAX_DRAWDOWN'), G1.maxDrawdown));
  assert(close(m('SMA_LAST', 2), 103.455));
  assert(close(m('SMA_LAST', 3), 101.97));
  assertEquals(r.computedBy, 'DETERMINISTIC_ENGINE');
  assertEquals(r.period, { start: '2026-01-05T00:00:00.000Z', end: '2026-01-09T00:00:00.000Z', bars: 5, frequency: 'DAILY' });
  assertEquals(r.dataSnapshot.provenance.providerId, 'fixture-golden');
  assertEquals(r.dataSnapshot.freshness.state, 'FRESH');
  assertEquals(r.dataSnapshot.evidenceStrength, 'WEAK'); // synthetic fixture is never strong evidence
  assert(/^[0-9a-f]{64}$/.test(r.dataSnapshot.contentHash));
  assert(r.warnings.some((w) => w.code === 'PROVENANCE_WEAK'));
  assert(r.warnings.some((w) => w.code === 'CALENDAR_NAIVE'));
  assertEquals(r.assumptions.find((a) => a.code === 'PRICE_BASIS')?.value, 'close');
  assertEquals(r.assumptions.find((a) => a.code === 'ANNUALIZATION')?.value, 252);
  // Explainability: every metric names a formula that exists in the catalog.
  for (const x of r.metrics) assert(FORMULAS[x.formulaId]);
});
Deno.test('AN-31 reproducible: same data + options → same analysisId and numbers; row order irrelevant', async () => {
  const s1 = await g1Series();
  const shuffled = val(createPriceSeries(INSTR_A, s1.provenance, [...s1.bars].reverse()));
  const a = val(await analyzeSeries(s1, { periodsPerYear: 252 }, clock));
  const b = val(await analyzeSeries(shuffled, { periodsPerYear: 252 }, () => NOW + 1000));
  assertEquals(a.analysisId, b.analysisId);
  assertEquals(a.metrics, b.metrics);
  assertEquals(a.dataSnapshot.contentHash, b.dataSnapshot.contentHash);
  const c = val(await analyzeSeries(s1, { periodsPerYear: null }, clock));
  assertNotEquals(a.analysisId, c.analysisId);
});
Deno.test('AN-32 stale data: warned by default, refused with STALE_DATA when the caller requires freshness', async () => {
  const s = await g1Series();
  const later = () => NOW + 60 * DAY;
  const r = val(await analyzeSeries(s, { periodsPerYear: 252 }, later));
  assertEquals(r.dataSnapshot.freshness.state, 'STALE');
  assert(r.warnings.some((w) => w.code === 'DATA_STALE'));
  assertEquals(code(await analyzeSeries(s, { periodsPerYear: 252, acceptedFreshness: ['FRESH', 'DELAYED'] }, later)), 'STALE_DATA');
});
Deno.test('AN-33 annualization must be stated; bad options rejected', async () => {
  const s = await g1Series();
  // deno-lint-ignore no-explicit-any
  assertEquals(code(await analyzeSeries(s, {} as any, clock)), 'INVALID_PARAMETER');
  assertEquals(code(await analyzeSeries(s, { periodsPerYear: 252, projectId: "1' OR 1=1" }, clock)), 'INVALID_PARAMETER');
  assertEquals(code(await analyzeSeries(s, { periodsPerYear: 252, smaWindows: [2, 2] }, clock)), 'INVALID_PARAMETER');
  assertEquals(code(await analyzeSeries(s, { periodsPerYear: 252, smaWindows: [1, 2, 3, 4, 5, 6, 7, 8, 9] }, clock)), 'INVALID_PARAMETER');
  const r = val(await analyzeSeries(s, { periodsPerYear: 252, smaWindows: [10] }, clock));
  assert(r.warnings.some((w) => w.code === 'INSUFFICIENT_DATA_FOR_METRIC'));
});
Deno.test('AN-34 insufficient data: one bar → INSUFFICIENT_DATA; two bars → no volatility, warned', async () => {
  const s = await g1Series();
  // Slicing changes the newest bar, so the provider's sourceAsOf no longer applies (CX1-01).
  const { sourceAsOf: _asOf, ...prov } = s.provenance;
  const one = val(createPriceSeries(INSTR_A, prov, s.bars.slice(0, 1)));
  assertEquals(code(await analyzeSeries(one, { periodsPerYear: 252 }, clock)), 'INSUFFICIENT_DATA');
  const two = val(createPriceSeries(INSTR_A, prov, s.bars.slice(0, 2)));
  const r = val(await analyzeSeries(two, { periodsPerYear: 252 }, clock));
  assertEquals(r.risk, null);
  assert(!r.metrics.some((m) => m.id === 'VOLATILITY_PER_PERIOD'));
});
Deno.test('AN-35 unadjusted close basis is flagged (corporate actions can distort returns)', async () => {
  const s = await g1Series();
  const unadj = val(createPriceSeries(INSTR_A, { ...s.provenance, adjustment: 'UNADJUSTED' }, s.bars));
  const r = val(await analyzeSeries(unadj, { periodsPerYear: 252 }, clock));
  assert(r.warnings.some((w) => w.code === 'ADJUSTMENT_UNKNOWN'));
});
Deno.test('AN-36 project scope is a validated label only', async () => {
  const r = val(await analyzeSeries(await g1Series(), { periodsPerYear: 252, projectId: '3f1c2d4e-5a6b-4c7d-8e9f-0a1b2c3d4e5f' }, clock));
  assertEquals(r.subject.projectId, '3f1c2d4e-5a6b-4c7d-8e9f-0a1b2c3d4e5f');
});

// ------------------------------------------------------------ IVE / LLM boundary

async function g1Result(): Promise<QuantAnalysisResult> {
  return val(await analyzeSeries(await g1Series(), { periodsPerYear: 252, smaWindows: [3] }, clock));
}

Deno.test('AN-40 explanation request carries pre-computed facts, formulas, caveats and rules — no raw data', async () => {
  const req = buildExplanationRequest(await g1Result());
  assertEquals(req.contract, 'quant.explanation.v1');
  const f = Object.fromEntries(req.facts.map((x) => [x.id, x]));
  assertEquals(f.CUMULATIVE_RETURN.display, '-1.99%');
  assertEquals(f.MAX_DRAWDOWN.display, '-10.90%');
  assertEquals(f.SMA_LAST_3.display, '101.97 USD');
  for (const x of req.facts) assertEquals(x.source, 'DETERMINISTIC_ENGINE');
  assert(req.warningCodes.includes('PROVENANCE_WEAK'));
  assert(req.limitations.some((l) => /FOUNDATION_PARTIAL/.test(l)));
  assert(req.rules.some((r) => /not recommendations/i.test(r)));
  assert(!JSON.stringify(req).includes('"bars":[')); // no raw price rows handed to the narrator
});
Deno.test('AN-41 grounding: a placeholder template renders engine values; invented numbers and unknown facts are rejected', async () => {
  const req = buildExplanationRequest(await g1Result());
  const template = 'Between {{PERIOD_START}} and {{PERIOD_END}} ({{PERIOD_BARS}} bars) the cumulative return was {{CUMULATIVE_RETURN}} and the max drawdown {{MAX_DRAWDOWN}}. Data is synthetic, so evidence is weak.';
  const good = checkNarrativeGrounding({ template }, req);
  assertEquals(good.grounded, true);
  assertEquals(good.citedFactIds, ['PERIOD_START', 'PERIOD_END', 'PERIOD_BARS', 'CUMULATIVE_RETURN', 'MAX_DRAWDOWN']);
  assertEquals(
    val(renderNarrative({ template }, req)),
    'Between 2026-01-05 and 2026-01-09 (5 bars) the cumulative return was -1.99% and the max drawdown -10.90%. Data is synthetic, so evidence is weak.',
  );
  const invented = checkNarrativeGrounding({ template: 'Volatility is about 45% and the price will reach 130 per {{VOLATILITY_FORECAST}}.' }, req);
  assertEquals(invented.grounded, false);
  assertEquals(invented.ungroundedNumbers, ['45', '130', '%']);
  assertEquals(invented.unknownFactIds, ['VOLATILITY_FORECAST']);
  assertEquals(code(renderNarrative({ template: 'up 45%' }, req)), 'CALCULATION_ERROR');
});
Deno.test('AN-42 display precision is separate from computation precision', async () => {
  const r = await g1Result();
  const vol = r.metrics.find((m) => m.id === 'VOLATILITY_PER_PERIOD')!.value as number;
  // The result keeps the unrounded float64; only display strings are rounded.
  assert(close(vol, G1.volPerPeriod));
  assertNotEquals(vol, 0.1155);
  assertEquals(formatRatioAsPercent(vol), '11.55%');
  assertEquals(formatNumber(-0.00001, 2), '0.00');
  assertEquals(formatRatioAsPercent(NaN), 'n/a');
});

// ------------------------------------------------------------ observability + watchlist

Deno.test('AN-50 log event is an allowlist: no symbols, quantities, prices or free text leak', async () => {
  const r = await g1Result();
  const ev = quantLogEvent({
    analysisId: r.analysisId,
    providerId: r.dataSnapshot.provenance.providerId,
    instrumentCount: 1,
    datasetSize: r.period.bars,
    periodStart: r.period.start,
    periodEnd: r.period.end,
    calculations: r.metrics.map((m) => m.id),
    freshness: r.dataSnapshot.freshness.state,
    latencyMs: 3.7,
    errorCode: null,
  });
  // deno-lint-ignore no-explicit-any
  const evil = quantLogEvent({ instrumentCount: 1, datasetSize: 1, latencyMs: 1, providerId: 'x y <script>', symbol: 'TSTA', apiKey: 'sk-live-123' } as any);
  const text = JSON.stringify([ev, evil]);
  for (const forbidden of ['TSTA', 'sk-live', '98.01', 'quantity', 'script']) assert(!text.includes(forbidden), forbidden);
  assertEquals(Object.keys(ev).sort(), ['analysis_id', 'calculations', 'dataset_size', 'error_code', 'event', 'freshness', 'instrument_count', 'latency_ms', 'period_end', 'period_start', 'provider_id']);
  assertEquals(ev.latency_ms, 4);
  assertEquals(evil.provider_id, null);
});
Deno.test('AN-51 watchlist: dedup by canonical identity, bounded, named', () => {
  const w = val(normalizeWatchlist({ name: ' Core ', instruments: [INSTR_A, { ...INSTR_A }, INSTR_B] }));
  assertEquals([w.name, w.instruments.length], ['Core', 2]);
  assertEquals(code(normalizeWatchlist({ name: '', instruments: [] })), 'INVALID_PARAMETER');
  const many = Array.from({ length: 201 }, (_, i) => ({ ...INSTR_A, symbol: `T${i}` }));
  assertEquals(code(normalizeWatchlist({ name: 'x', instruments: many })), 'DATASET_TOO_LARGE');
});
