/**
 * Multi-series analytics + multi/watchlist contracts — IV-QUANT-REAL-DATA-READINESS-03
 * (docs/quant/QUANT_MULTI_SERIES.md). Expected values derived by hand inline.
 *
 * Execução:
 *   deno test supabase/functions/_shared/quant/multi_series_test.ts
 */
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { QuantResult } from './errors.ts';
import type { InstrumentIdentity } from './instrument.ts';
import { instrumentKey } from './instrument.ts';
import { analyzeMultiSeries, MAX_SERIES_PER_ANALYSIS, MIN_ALIGNED_BARS } from './multi_series.ts';
import {
  MAX_TOTAL_ROWS,
  parseMultiRequest,
  parseWatchlistAnalysisRequest,
  runMulti,
  runWatchlistAnalysis,
} from './multi_contract.ts';
import type { DataProvenance } from './provenance.ts';
import { createPriceSeries, type PriceSeries } from './timeseries.ts';
import { close, dailyBars, G_START_T, INSTR_A, INSTR_B, INSTR_C } from './fixtures/golden.ts';
import { SyntheticInProcessProvider } from './synthetic_market.ts';
import { CachingProvider, InMemoryMarketCache } from './market_cache.ts';

function val<T>(r: QuantResult<T>): T {
  if (!r.ok) throw new Error(`expected ok, got ${r.error.code}: ${r.error.message}`);
  return r.value;
}
function code<T>(r: QuantResult<T>): string {
  assert(!r.ok, 'expected failure');
  return (r as { ok: false; error: { code: string } }).error.code;
}

const DAY = 86_400_000;
/** Thu 2026-01-15 12:00Z — 8 weekday bars from Mon 2026-01-05 end Wed 2026-01-14. */
const NOW = Date.UTC(2026, 0, 15, 12);
const clock = () => NOW;

function prov(currency: string): DataProvenance {
  return { providerId: 'fixture-multi', providerKind: 'FIXTURE', trust: 'SYNTHETIC_FIXTURE', retrievedAt: new Date(NOW).toISOString(), frequency: 'DAILY', currency, adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED' };
}
function series(instr: InstrumentIdentity, closes: readonly number[], startT = G_START_T): PriceSeries {
  return val(createPriceSeries(instr, prov(instr.currency), dailyBars(closes, startT)));
}
/** Closes from simple returns, starting at 100. */
function fromReturns(rs: readonly number[]): number[] {
  const out = [100];
  for (const r of rs) out.push(out[out.length - 1] * (1 + r));
  return out;
}
const opts = { periodsPerYear: 252 };

// Zero-mean, orthogonal return vectors → Pearson = 0 exactly.
//   a = ±0.01 alternating, b = +,+,−,− pattern; Σa·b = 0.01²·(1−1−1+1)·… = 0
const RA = [0.01, -0.01, 0.01, -0.01, 0.01, -0.01, 0.01];
const RB_NEG = RA.map((r) => -r);
const RU_A = [0.01, -0.01, 0.01, -0.01];
const RU_B = [0.01, 0.01, -0.01, -0.01];

Deno.test('MS-01 perfect positive correlation: B = 2·A prices → ρ = 1, identical aligned returns', async () => {
  const a = fromReturns(RA);
  const r = val(await analyzeMultiSeries([series(INSTR_A, a), series(INSTR_B, a.map((x) => 2 * x))], opts, clock));
  assertEquals(r.correlation.length, 1);
  assert(close(r.correlation[0].correlation!, 1));
  assertEquals(r.correlation[0].observations, RA.length);
  assert(close(r.series[0].alignedCumulativeReturn, r.series[1].alignedCumulativeReturn));
  assertEquals(r.alignment.policy, 'INTERSECTION_OF_TIMESTAMPS');
  assertEquals(r.alignment.commonBars, RA.length + 1);
  assertEquals(r.warnings.filter((w) => w.code === 'MISSING_FROM_ALIGNMENT').length, 0);
  assertEquals(r.computedBy, 'DETERMINISTIC_ENGINE');
  assert(r.multiAnalysisId.startsWith('qm_'));
});

Deno.test('MS-02 perfect negative correlation: mirrored returns → ρ = −1', async () => {
  const r = val(await analyzeMultiSeries([series(INSTR_A, fromReturns(RA)), series(INSTR_B, fromReturns(RB_NEG))], opts, clock));
  assert(close(r.correlation[0].correlation!, -1));
});

Deno.test('MS-03 uncorrelated (orthogonal zero-mean returns) → ρ = 0', async () => {
  const r = val(await analyzeMultiSeries([series(INSTR_A, fromReturns(RU_A)), series(INSTR_B, fromReturns(RU_B))], opts, clock));
  assert(close(r.correlation[0].correlation!, 0), `got ${r.correlation[0].correlation}`);
});

Deno.test('MS-04 constant series → correlation undefined (null + reason), never 0 or NaN', async () => {
  const r = val(await analyzeMultiSeries([series(INSTR_A, fromReturns(RA)), series(INSTR_B, [50, 50, 50, 50, 50, 50, 50, 50])], opts, clock));
  assertEquals(r.correlation[0].correlation, null);
  assert(typeof r.correlation[0].error === 'string' && r.correlation[0].error.length > 0);
});

Deno.test('MS-05 correlation matrix: 3 series → 3 unique pairs, symmetric order, ρ ∈ [−1, 1]', async () => {
  const r = val(await analyzeMultiSeries([
    series(INSTR_A, fromReturns(RA)),
    series(INSTR_B, fromReturns(RB_NEG)),
    series(INSTR_C, fromReturns([0.02, 0.0, -0.01, 0.03, -0.02, 0.01, 0.0])),
  ], opts, clock));
  assertEquals(r.correlation.length, 3); // n(n−1)/2
  const pairs = r.correlation.map((c) => `${c.a}|${c.b}`);
  assertEquals(new Set(pairs).size, 3);
  for (const c of r.correlation) assert(c.correlation === null || (c.correlation >= -1 - 1e-12 && c.correlation <= 1 + 1e-12));
  assert(close(r.correlation[0].correlation!, -1)); // A vs B
  // corr(A,C) = −corr(B,C) because B's returns are −A's.
  assert(close(r.correlation[1].correlation!, -r.correlation[2].correlation!));
});

Deno.test('MS-06 partial overlap: intersection only, dropped bars counted, never filled', async () => {
  // A: Mon 05 .. Wed 14 (8 bars). B starts Wed 07 → 6 common bars (07,08,09,12,13,14).
  const a = series(INSTR_A, [100, 101, 102, 103, 104, 105, 106, 107]);
  const b = series(INSTR_B, [50, 51, 52, 53, 54, 55], G_START_T + 2 * DAY);
  const r = val(await analyzeMultiSeries([a, b], opts, clock));
  assertEquals(r.alignment.commonBars, 6);
  assertEquals(r.series[0].droppedFromAlignment, 2);
  assertEquals(r.series[1].droppedFromAlignment, 0);
  assertEquals(r.alignment.start, new Date(G_START_T + 2 * DAY).toISOString());
  assert(r.warnings.some((w) => w.code === 'MISSING_FROM_ALIGNMENT'));
  // Aligned return of A = 107/102 − 1 (from the first common bar), not 107/100 − 1.
  assert(close(r.series[0].alignedCumulativeReturn, 107 / 102 - 1));
});

Deno.test('MS-07 insufficient overlap → INSUFFICIENT_OVERLAP (422), not a silent partial result', async () => {
  const a = series(INSTR_A, [100, 101, 102, 103, 104, 105, 106, 107]);
  // B starts Tue 13 → only 2 common bars (< MIN_ALIGNED_BARS).
  const b = series(INSTR_B, [50, 51, 52, 53, 54], G_START_T + 8 * DAY);
  assertEquals(code(await analyzeMultiSeries([a, b], opts, clock)), 'INSUFFICIENT_OVERLAP');
  assert(MIN_ALIGNED_BARS >= 4);
});

Deno.test('MS-08 mixed currency: returns allowed with MIXED_CURRENCY_RETURNS warning; portfolio refused', async () => {
  const eur: InstrumentIdentity = { ...INSTR_B, currency: 'EUR' };
  const list = [series(INSTR_A, fromReturns(RA)), series(eur, fromReturns(RB_NEG))];
  const r = val(await analyzeMultiSeries(list, opts, clock));
  assert(r.warnings.some((w) => w.code === 'MIXED_CURRENCY_RETURNS'));
  assert(r.assumptions.some((a) => a.code === 'RETURNS_IN_OWN_CURRENCY'));
  const w = [{ instrumentKey: instrumentKey(INSTR_A), weight: 0.5 }, { instrumentKey: instrumentKey(eur), weight: 0.5 }];
  assertEquals(code(await analyzeMultiSeries(list, { ...opts, weights: w }, clock)), 'CURRENCY_MISMATCH');
});

Deno.test('MS-09 portfolio: buy-and-hold on the aligned window, hand-derived', async () => {
  // A 100 → 110 (+10 %), B 50 → 45 (−10 %) over the same 5 bars; 0.6/0.4 → 0.6·0.1 + 0.4·(−0.1) = 0.02
  const a = series(INSTR_A, [100, 102, 104, 106, 110]);
  const b = series(INSTR_B, [50, 49, 48, 47, 45]);
  const w = [{ instrumentKey: instrumentKey(INSTR_A), weight: 0.6 }, { instrumentKey: instrumentKey(INSTR_B), weight: 0.4 }];
  const r = val(await analyzeMultiSeries([a, b], { ...opts, weights: w }, clock));
  assert(r.portfolio !== null);
  assert(close(r.portfolio!.buyAndHoldReturn, 0.02));
  assertEquals(r.portfolio!.currency, 'USD');
  assert(close(r.portfolio!.concentration.maxWeight, 0.6));
  assert(r.assumptions.some((x) => x.code === 'BUY_AND_HOLD_INITIAL_WEIGHTS'));
});

Deno.test('MS-10 portfolio validation policies (INVALID_PORTFOLIO): coverage, sum, bounds, duplicates, foreign key', async () => {
  const list = [series(INSTR_A, fromReturns(RA)), series(INSTR_B, fromReturns(RB_NEG))];
  const kA = instrumentKey(INSTR_A), kB = instrumentKey(INSTR_B);
  const bad: Array<Array<{ instrumentKey: string; weight: number }>> = [
    [{ instrumentKey: kA, weight: 1 }], // does not cover B
    [{ instrumentKey: kA, weight: 0.5 }, { instrumentKey: kB, weight: 0.4 }], // sum 0.9
    [{ instrumentKey: kA, weight: 1.2 }, { instrumentKey: kB, weight: -0.2 }], // short
    [{ instrumentKey: kA, weight: 0 }, { instrumentKey: kB, weight: 1 }], // zero weight
    [{ instrumentKey: kA, weight: 0.5 }, { instrumentKey: kA, weight: 0.5 }], // duplicate
    [{ instrumentKey: kA, weight: 0.5 }, { instrumentKey: 'EQUITY:ZZZ:XTST:USD', weight: 0.5 }], // not analyzed
    [{ instrumentKey: kA, weight: NaN }, { instrumentKey: kB, weight: 0.5 }],
  ];
  for (const w of bad) assertEquals(code(await analyzeMultiSeries(list, { ...opts, weights: w }, clock)), 'INVALID_PORTFOLIO', JSON.stringify(w));
  // Float-noise tolerance: 0.1 + 0.2 + 0.7 is accepted.
  const three = [...list, series(INSTR_C, fromReturns(RU_B.concat([0.01, 0, 0])))];
  const ok3 = await analyzeMultiSeries(three, { ...opts, weights: [{ instrumentKey: kA, weight: 0.1 }, { instrumentKey: kB, weight: 0.2 }, { instrumentKey: instrumentKey(INSTR_C), weight: 0.7 }] }, clock);
  assert(ok3.ok);
});

Deno.test('MS-11 input policies: 0 series, > MAX series, duplicate instrument, mixed frequency', async () => {
  assertEquals(code(await analyzeMultiSeries([], opts, clock)), 'INSUFFICIENT_DATA');
  const many = Array.from({ length: MAX_SERIES_PER_ANALYSIS + 1 }, (_, i) => series({ ...INSTR_A, symbol: `T${i}` }, fromReturns(RA)));
  assertEquals(code(await analyzeMultiSeries(many, opts, clock)), 'DATASET_TOO_LARGE');
  assertEquals(code(await analyzeMultiSeries([series(INSTR_A, fromReturns(RA)), series(INSTR_A, fromReturns(RB_NEG))], opts, clock)), 'INVALID_PARAMETER');
  const weekly = val(createPriceSeries(INSTR_B, { ...prov('USD'), frequency: 'WEEKLY' }, dailyBars([1, 2, 3, 4, 5]).map((b, i) => ({ ...b, t: G_START_T + i * 7 * DAY }))));
  assertEquals(code(await analyzeMultiSeries([series(INSTR_A, fromReturns(RA)), weekly], opts, clock)), 'INVALID_PARAMETER');
  // Exactly MAX is accepted.
  assert((await analyzeMultiSeries(many.slice(0, MAX_SERIES_PER_ANALYSIS), opts, clock)).ok);
});

Deno.test('MS-12 reproducibility: same input → identical result and id; different weights → different id', async () => {
  const mk = () => [series(INSTR_A, [100, 102, 104, 106, 110]), series(INSTR_B, [50, 49, 48, 47, 45])];
  const w1 = [{ instrumentKey: instrumentKey(INSTR_A), weight: 0.6 }, { instrumentKey: instrumentKey(INSTR_B), weight: 0.4 }];
  const w2 = [{ instrumentKey: instrumentKey(INSTR_A), weight: 0.5 }, { instrumentKey: instrumentKey(INSTR_B), weight: 0.5 }];
  const r1 = val(await analyzeMultiSeries(mk(), { ...opts, weights: w1 }, clock));
  const r2 = val(await analyzeMultiSeries(mk(), { ...opts, weights: w1 }, clock));
  const r3 = val(await analyzeMultiSeries(mk(), { ...opts, weights: w2 }, clock));
  assertEquals(JSON.stringify(r1), JSON.stringify(r2));
  assertNotEquals(r1.multiAnalysisId, r3.multiAnalysisId);
});

Deno.test('MS-13 single series is allowed (no pairs, no alignment loss)', async () => {
  const r = val(await analyzeMultiSeries([series(INSTR_A, fromReturns(RA))], opts, clock));
  assertEquals(r.correlation.length, 0);
  assertEquals(r.series[0].droppedFromAlignment, 0);
});

// ---------------------------------------------------------------- quant.analyze.multi.v1 contract

function csvOf(closes: readonly number[], startT = G_START_T): string {
  return 'date,open,high,low,close,volume\n' + dailyBars(closes, startT).map((b) => `${new Date(b.t as number).toISOString().slice(0, 10)},${b.open},${b.high},${b.low},${b.close},${b.volume}`).join('\n');
}
const inst = (s: string) => ({ asset_class: 'EQUITY', symbol: s, exchange_mic: 'XTST', currency: 'USD' });
function multiBody(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    contract_version: 'quant.analyze.multi.v1',
    series: [
      { instrument: inst('TSTA'), dataset: { format: 'csv', frequency: 'DAILY', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', csv: csvOf([100, 102, 104, 106, 110]) } },
      { instrument: inst('TSTB'), dataset: { format: 'csv', frequency: 'DAILY', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', csv: csvOf([50, 49, 48, 47, 45]) } },
    ],
    options: { periods_per_year: 252, weights: [{ index: 0, weight: 0.6 }, { index: 1, weight: 0.4 }] },
    ...extra,
  };
}

Deno.test('MC-01 multi.v1 happy path: CSV → USER_UPLOAD provenance → portfolio by series index', async () => {
  const req = val(parseMultiRequest(multiBody()));
  const r = val(await runMulti(req, NOW));
  assertEquals(r.series.length, 2);
  for (const s of r.series) assertEquals(s.analysis.dataSnapshot.provenance.providerKind, 'USER_UPLOAD');
  assert(close(r.portfolio!.buyAndHoldReturn, 0.02));
});

Deno.test('MC-02 multi.v1 strict schema: unknown fields, bad counts, bad weights, bad project id', () => {
  assertEquals(code(parseMultiRequest(multiBody({ extra: 1 }))), 'INVALID_PARAMETER');
  assertEquals(code(parseMultiRequest(multiBody({ series: [] }))), 'INVALID_PARAMETER');
  const s = (multiBody().series as unknown[])[0];
  assertEquals(code(parseMultiRequest(multiBody({ series: Array.from({ length: 11 }, () => s) }))), 'INVALID_PARAMETER');
  assertEquals(code(parseMultiRequest(multiBody({ options: { periods_per_year: 252, weights: [{ index: 2, weight: 1 }] } }))), 'INVALID_PARAMETER');
  assertEquals(code(parseMultiRequest(multiBody({ options: { periods_per_year: 252, weights: [{ index: 0, weight: 1, key: 'x' }] } }))), 'INVALID_PARAMETER');
  assertEquals(code(parseMultiRequest(multiBody({ options: {} }))), 'INVALID_PARAMETER'); // periods_per_year must be explicit
  assertEquals(code(parseMultiRequest(multiBody({ project_id: 'not-a-uuid' }))), 'INVALID_PARAMETER');
  const badDs = multiBody();
  (badDs.series as Array<Record<string, unknown>>)[0] = { instrument: inst('TSTA'), dataset: { format: 'xlsx', frequency: 'DAILY', adjustment: 'UNKNOWN', csv: 'x' } };
  assertEquals(code(parseMultiRequest(badDs)), 'INVALID_DATASET');
  // Provenance cannot be injected by the client.
  const inj = multiBody();
  (inj.series as Array<Record<string, unknown>>)[0] = { ...(inj.series as Array<Record<string, unknown>>)[0], provenance: { providerKind: 'LICENSED_VENDOR' } };
  assertEquals(code(parseMultiRequest(inj)), 'INVALID_PARAMETER');
});

Deno.test('MC-03 multi.v1: per-series errors carry the series index; total rows bounded', async () => {
  const b = multiBody();
  (b.series as Array<{ dataset: { csv: string } }>)[1].dataset.csv = 'date,open,high,low,close\n2026-01-05,1,1,1,abc';
  const r = await runMulti(val(parseMultiRequest(b)), NOW);
  assert(!r.ok);
  assertEquals(r.error.details?.series, 1);
  assertEquals(MAX_TOTAL_ROWS, 50_000);
});

Deno.test('MC-03b multi.v1: the total-row bound is enforced exactly (measured CPU budget)', async () => {
  const rows = (n: number, startT: number) => {
    const out = ['date,open,high,low,close'];
    for (let i = 0, t = startT; i < n; i++, t += DAY) out.push(`${new Date(t).toISOString().slice(0, 10)},1,1,1,1`);
    return out.join(String.fromCharCode(10));
  };
  const mk = (a: number, b: number) => {
    const body = multiBody();
    (body.series as Array<{ dataset: { csv: string } }>)[0].dataset.csv = rows(a, Date.UTC(1900, 0, 1));
    (body.series as Array<{ dataset: { csv: string } }>)[1].dataset.csv = rows(b, Date.UTC(1900, 0, 1));
    return val(parseMultiRequest(body));
  };
  const over = await runMulti(mk(25_001, 25_000), NOW);
  assert(!over.ok);
  assertEquals(over.error.code, 'DATASET_TOO_LARGE');
  assertEquals(over.error.details?.max, 50_000);
  const at = await runMulti(mk(25_000, 25_000), NOW);
  assert(at.ok || at.error.code !== 'DATASET_TOO_LARGE', 'exactly 50 000 rows is inside the bound');
});

// ---------------------------------------------------------------- quant.analyze.watchlist.v1 contract

const WL = '11111111-1111-4111-8111-111111111111';
Deno.test('MC-04 watchlist.v1 strict schema: data_source, item_ids bounds, lookback bounds', () => {
  const base = { contract_version: 'quant.analyze.watchlist.v1', watchlist_id: WL, data_source: 'SYNTHETIC_PROVIDER', options: { periods_per_year: 252 } };
  const ok1 = val(parseWatchlistAnalysisRequest(base));
  assertEquals(ok1.lookbackDays, 365);
  assertEquals(code(parseWatchlistAnalysisRequest({ ...base, data_source: 'LICENSED_VENDOR' })), 'INVALID_PARAMETER');
  assertEquals(code(parseWatchlistAnalysisRequest({ ...base, watchlist_id: 'x' })), 'INVALID_PARAMETER');
  assertEquals(code(parseWatchlistAnalysisRequest({ ...base, item_ids: [] })), 'INVALID_PARAMETER');
  assertEquals(code(parseWatchlistAnalysisRequest({ ...base, item_ids: [WL, WL] })), 'INVALID_PARAMETER');
  assertEquals(code(parseWatchlistAnalysisRequest({ ...base, item_ids: Array.from({ length: 11 }, (_, i) => `11111111-1111-4111-8111-${String(i).padStart(12, '0')}`) })), 'INVALID_PARAMETER');
  assertEquals(code(parseWatchlistAnalysisRequest({ ...base, lookback_days: 5 })), 'INVALID_PARAMETER');
  assertEquals(code(parseWatchlistAnalysisRequest({ ...base, lookback_days: 5000 })), 'INVALID_PARAMETER');
  // Instruments can never come from the client.
  assertEquals(code(parseWatchlistAnalysisRequest({ ...base, instruments: [inst('TSTA')] })), 'INVALID_PARAMETER');
});

const US: InstrumentIdentity = { assetClass: 'EQUITY', symbol: 'SYNA', exchangeMic: 'XNYS', currency: 'USD' };
const US2: InstrumentIdentity = { assetClass: 'EQUITY', symbol: 'SYNB', exchangeMic: 'XNAS', currency: 'USD' };
const UK: InstrumentIdentity = { assetClass: 'EQUITY', symbol: 'SYNL', exchangeMic: 'XLON', currency: 'GBP' };
/** Wed 2026-09-23 22:00Z: after the NYSE close. */
const WNOW = Date.UTC(2026, 8, 23, 22);

Deno.test('MC-05 watchlist.v1 over the synthetic provider: FIXTURE provenance, US+UK calendars differ, mixed currency', async () => {
  const req = val(parseWatchlistAnalysisRequest({ contract_version: 'quant.analyze.watchlist.v1', watchlist_id: WL, data_source: 'SYNTHETIC_PROVIDER', lookback_days: 365, options: { periods_per_year: 252 } }));
  const r = val(await runWatchlistAnalysis([US, US2, UK], req, new SyntheticInProcessProvider(() => WNOW), WNOW));
  assertEquals(r.series.length, 3);
  for (const s of r.series) {
    assertEquals(s.analysis.dataSnapshot.provenance.providerKind, 'FIXTURE');
    assertEquals(s.analysis.dataSnapshot.provenance.trust, 'SYNTHETIC_FIXTURE');
  }
  assert(r.warnings.some((w) => w.code === 'CALENDARS_DIFFER'));
  assert(r.warnings.some((w) => w.code === 'MIXED_CURRENCY_RETURNS'));
  // UK and US holidays differ (e.g. 2026-05-25 Memorial Day vs 2026-05-04 Early May bank holiday).
  assert(r.warnings.some((w) => w.code === 'MISSING_FROM_ALIGNMENT'));
  assertEquals(r.correlation.length, 3);
});

Deno.test('MC-06 watchlist.v1: > 10 instruments refused; provider through cache → second call is a HIT with identical result', async () => {
  const req = val(parseWatchlistAnalysisRequest({ contract_version: 'quant.analyze.watchlist.v1', watchlist_id: WL, data_source: 'SYNTHETIC_PROVIDER', options: { periods_per_year: 252 } }));
  const many = Array.from({ length: 11 }, (_, i) => ({ ...US, symbol: `S${i}` }));
  assertEquals(code(await runWatchlistAnalysis(many, req, new SyntheticInProcessProvider(() => WNOW), WNOW)), 'DATASET_TOO_LARGE');
  assertEquals(code(await runWatchlistAnalysis([], req, new SyntheticInProcessProvider(() => WNOW), WNOW)), 'INSUFFICIENT_DATA');
  const cache = new InMemoryMarketCache(64);
  const cp = new CachingProvider(new SyntheticInProcessProvider(() => WNOW), cache, () => WNOW);
  const a = val(await runWatchlistAnalysis([US, US2], req, cp, WNOW));
  const b = val(await runWatchlistAnalysis([US, US2], req, cp, WNOW));
  assertEquals(a.multiAnalysisId, b.multiAnalysisId);
  assertEquals(a.dataSource.cache, { hits: 0, misses: 2, staleFallbacks: 0, uncached: 0 });
  assertEquals(b.dataSource.cache, { hits: 2, misses: 0, staleFallbacks: 0, uncached: 0 });
  assertEquals(a.dataSource.kind, 'SYNTHETIC_PROVIDER');
});

Deno.test('MS-14 multiAnalysisId is a CALCULATION-INPUT identity (same semantics as v1 analysisId, QA-02): clock-independent, input-sensitive', async () => {
  // Codex Gate 2: pinned, documented semantics — the id identifies the deterministic
  // calculation (engine, instruments, bar content, options), NOT the evaluation instant.
  const mk = () => [series(INSTR_A, [100, 102, 104, 106, 110]), series(INSTR_B, [50, 49, 48, 47, 45])];
  const early = val(await analyzeMultiSeries(mk(), opts, () => NOW));
  const late = val(await analyzeMultiSeries(mk(), opts, () => NOW + 30 * DAY));
  assertEquals(late.multiAnalysisId, early.multiAnalysisId);
  assertNotEquals(late.generatedAt, early.generatedAt);
  assertNotEquals(late.series[0].analysis.dataSnapshot.freshness.state, early.series[0].analysis.dataSnapshot.freshness.state);
  // Any change to what is calculated changes the id.
  const otherBars = val(await analyzeMultiSeries([series(INSTR_A, [100, 102, 104, 106, 111]), series(INSTR_B, [50, 49, 48, 47, 45])], opts, () => NOW));
  const otherPeriods = val(await analyzeMultiSeries(mk(), { periodsPerYear: 52 }, () => NOW));
  const w = [{ instrumentKey: instrumentKey(INSTR_A), weight: 0.5 }, { instrumentKey: instrumentKey(INSTR_B), weight: 0.5 }];
  const otherWeights = val(await analyzeMultiSeries(mk(), { ...opts, weights: w }, () => NOW)).multiAnalysisId;
  for (const id of [otherBars.multiAnalysisId, otherPeriods.multiAnalysisId, otherWeights]) assertNotEquals(id, early.multiAnalysisId);
});
