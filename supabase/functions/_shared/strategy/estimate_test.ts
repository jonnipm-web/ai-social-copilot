import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildEpistemicClaim, type EstimateProvenance } from './estimate.ts';

const PROVENANCE: EstimateProvenance = Object.freeze({
  sourcePeriodStart: '2026-03-30T00:00:00Z',
  sourcePeriodEnd: '2026-08-11T00:00:00Z',
  sampleSize: 75,
  dataSource: 'WIN1! TradingView 5-minute dataset',
  assumptions: Object.freeze(['no slippage beyond the stated model']),
  costModelDescription: 'QT-01C.3 Run B',
  confidenceNote: 'single-period sample; no out-of-sample split performed',
  limitations: Object.freeze(['5-minute-only data']),
});

Deno.test('EC-01 MEASURED never requires provenance', () => {
  const result = buildEpistemicClaim('MEASURED', -57.0, 'Net P&L on the certified WIN1! dataset.', null);
  assert(result.ok);
});

Deno.test('EC-02 ESTIMATE without provenance is refused (never a bare confident number)', () => {
  const result = buildEpistemicClaim('ESTIMATE', -300, 'If costs rose 20%...', null);
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'INVALID_STRATEGY_SPEC');
});

Deno.test('EC-03 ESTIMATE/INFERENCE/HYPOTHESIS with provenance succeed', () => {
  for (const status of ['ESTIMATE', 'INFERENCE', 'HYPOTHESIS'] as const) {
    const result = buildEpistemicClaim(status, 1, 'x', PROVENANCE);
    assert(result.ok, status);
  }
});

Deno.test('EC-04 RECOMMENDATION and UNKNOWN never require provenance', () => {
  const rec = buildEpistemicClaim('RECOMMENDATION', null, 'Consider a larger sample before drawing conclusions.', null);
  assert(rec.ok);
  const unk = buildEpistemicClaim('UNKNOWN', null, 'Insufficient evidence to judge robustness.', null);
  assert(unk.ok);
});
