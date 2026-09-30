/**
 * Regression tests for Codex Final findings (CXF-01..CXF-06) —
 * IV-QUANT-FOUNDATION-01.
 *
 * Execução:
 *   deno test supabase/functions/_shared/quant/regression_final_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { analyzeSeries } from './analysis.ts';
import { buildExplanationRequest, checkNarrativeGrounding, type QuantExplanationRequest, renderNarrative } from './ive_boundary.ts';
import { simpleMovingAverage } from './metrics.ts';
import { fsum } from './numeric.ts';
import { quantLogEvent } from './observability.ts';
import type { DataProvenance } from './provenance.ts';
import { FixtureProvider } from './provider.ts';
import { createPriceSeries } from './timeseries.ts';
import { dailyBars, G1_CLOSES, goldenFixtureDatasets, INSTR_A } from './fixtures/golden.ts';
import type { QuantResult } from './errors.ts';

function val<T>(r: QuantResult<T>): T {
  if (!r.ok) throw new Error(`expected ok, got ${r.error.code}: ${r.error.message}`);
  return r.value;
}
function err<T>(r: QuantResult<T>): { code: string; reason?: unknown } {
  assert(!r.ok, 'expected failure');
  const e = (r as { ok: false; error: { code: string; details?: Record<string, unknown> } }).error;
  return { code: e.code, reason: e.details?.reason };
}

const NOW = Date.UTC(2026, 0, 12, 12);
const PROV: DataProvenance = {
  providerId: 'user-csv',
  providerKind: 'USER_UPLOAD',
  trust: 'USER_SUPPLIED',
  retrievedAt: '2026-01-12T10:00:00.000Z',
  frequency: 'DAILY',
  currency: 'USD',
  adjustment: 'UNKNOWN',
};

async function request(): Promise<QuantExplanationRequest> {
  const s = val(createPriceSeries(INSTR_A, PROV, dailyBars(G1_CLOSES)));
  return buildExplanationRequest(val(await analyzeSeries(s, { periodsPerYear: 252 }, () => NOW)));
}

Deno.test('CXF-01 renderNarrative refuses forged fact displays (placeholder syntax, control chars, non-engine source, oversize)', async () => {
  const req = await request();
  const forge = (patch: Record<string, unknown>) => ({ ...req, facts: [{ ...req.facts[0], ...patch }, ...req.facts.slice(1)] });
  const id = req.facts[0].id;
  for (const bad of [{ display: '{{EVIL}} 999' }, { display: 'ok​x' }, { source: 'LLM' }, { display: 'x'.repeat(65) }]) {
    assertEquals(err(renderNarrative({ template: `Value {{${id}}}` }, forge(bad) as QuantExplanationRequest)).reason, 'FORGED_FACT', JSON.stringify(bad));
  }
  assert(renderNarrative({ template: `Value {{${id}}}` }, req).ok);
});

Deno.test('CXF-02 zero-width / bidi / control characters and ordinal words are rejected', async () => {
  const req = await request();
  for (const template of ['gained t​wo', 'up ‮five', 'rank second', 'o terceiro maior', 'bell\u0007']) {
    assertEquals(checkNarrativeGrounding({ template }, req).grounded, false, JSON.stringify(template));
  }
  // Ordinary prose, newlines and tabs remain fine.
  assertEquals(checkNarrativeGrounding({ template: 'Return:\t{{CUMULATIVE_RETURN}}\nPeriod ends {{PERIOD_END}}.' }, req).grounded, true);
});

Deno.test('CXF-03 periodsPerYear is validated even when volatility is skipped', async () => {
  const two = val(createPriceSeries(INSTR_A, PROV, dailyBars([100, 101])));
  for (const p of [NaN, Infinity, 0, -252]) {
    assertEquals(err(await analyzeSeries(two, { periodsPerYear: p }, () => NOW)).code, 'INVALID_PARAMETER', String(p));
  }
  assert((await analyzeSeries(two, { periodsPerYear: null }, () => NOW)).ok);
});

Deno.test('CXF-04 FixtureProvider state cannot be mutated through inputs or outputs', async () => {
  const datasets = goldenFixtureDatasets();
  const p = new FixtureProvider(datasets, () => NOW);
  (datasets[0].bars[0] as { close: number }).close = 1; // caller mutates its own input afterwards
  const req = { instrument: INSTR_A, frequency: 'DAILY' as const, fromT: 0, toT: 8.64e15, adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED' as const };
  const first = val(await p.historicalBars(req));
  assertEquals(first.data[0].close, 100);
  (first.data[0] as { close: number }).close = 2; // consumer mutates a response
  (val(await p.lookupInstrument('TSTA'))[0] as { symbol: string }).symbol = 'HACK';
  assertEquals(val(await p.historicalBars(req)).data[0].close, 100);
  assertEquals(val(await p.lookupInstrument('TSTA')).length, 1);
});

Deno.test('CXF-05 log event drops runtime-forged enum values', () => {
  // deno-lint-ignore no-explicit-any
  const ev = quantLogEvent({ instrumentCount: 1, datasetSize: 1, latencyMs: 1, errorCode: 'secret-value' as any, freshness: 'sk-live' as any });
  assertEquals([ev.error_code, ev.freshness], [null, null]);
  assertEquals(quantLogEvent({ instrumentCount: 1, datasetSize: 1, latencyMs: 1, errorCode: 'STALE_DATA', freshness: 'STALE' }).error_code, 'STALE_DATA');
});

Deno.test('CXF-06 SMA survives catastrophic cancellation when a spike leaves the window (was 0 instead of 1)', () => {
  const spike = [1e17, 1, 1, 1, 1, 1, 1];
  for (const w of [2, 3]) {
    const got = val(simpleMovingAverage(spike, w));
    for (let t = w; t < spike.length; t++) assertEquals(got[t], 1, `w=${w} t=${t}`);
  }
  // Repeated spikes, every window compared with an exact sum.
  const values = Array.from({ length: 2_000 }, (_, i) => (i % 97 === 0 ? 1e15 : 1 + (i % 5) * 0.25));
  for (const w of [2, 5, 50]) {
    const got = val(simpleMovingAverage(values, w));
    for (let t = w - 1; t < values.length; t++) {
      const exact = fsum(values.slice(t - w + 1, t + 1)) / w;
      assert(Math.abs((got[t] as number) - exact) <= 1e-9 * exact, `w=${w} t=${t} ${got[t]} vs ${exact}`);
    }
  }
});
