import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildCanonicalBacktestResult, type CanonicalBacktestResultInput } from './backtest_result.ts';
import { compareBacktestResults } from './comparison.ts';
import { analyzeBacktestResult, analyzeComparison, analyzeCostSensitivity } from './ive_strategy_analyst.ts';

/** The real V10 zero-cost reproduction (Macro-05). */
const ZERO_COST_INPUT: CanonicalBacktestResultInput = Object.freeze({
  strategyId: 'sid', strategyVersion: 1, strategySpecHash: 'h',
  datasetId: 'win1-5min-qt01c3', datasetHash: 'dh', instrumentSymbol: 'WIN1!',
  periodStart: '2026-03-30T00:00:00Z', periodEnd: '2026-08-11T00:00:00Z', timeframes: ['5min'],
  tradeCount: 75, longCount: 35, shortCount: 40, wins: 29, losses: 45,
  grossPnl: -57.0, grossProfit: 769.0, grossLoss: 826.0, totalCost: 0, netPnl: -57.0,
  maxDrawdown: null, targetTouches: 8, stopTouches: 47, executionAmbiguityCount: 19,
  methodologyStatus: 'ZERO_COST_RESEARCH', costAssumptions: null,
  limitations: ['5-minute dataset only.'], provenance: 'test',
});

const COST_ADJUSTED_INPUT: CanonicalBacktestResultInput = {
  ...ZERO_COST_INPUT,
  netPnl: -270.75, totalCost: 213.75, methodologyStatus: 'COST_ADJUSTED',
  costAssumptions: { brokeragePerContract: 0.75, exchangeFeePerContract: 0.10, slippageTicks: 1, source: 'QT-01C.3 Run B' },
};

Deno.test('IA-01 a real result produces a MEASURED net-P&L claim traceable to its own numbers', async () => {
  const result = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  assert(result.ok);
  if (!result.ok) return;
  const claims = analyzeBacktestResult(result.value);
  const measured = claims.find((c) => c.status === 'MEASURED' && c.statement.includes('Net P&L'));
  assert(measured, JSON.stringify(claims));
  assertEquals(measured!.value, -57.0);
});

Deno.test('IA-02 an UNKNOWN claim about future profitability is ALWAYS present -- never a promise of future performance', async () => {
  const result = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  assert(result.ok);
  if (!result.ok) return;
  const claims = analyzeBacktestResult(result.value);
  assert(claims.some((c) => c.status === 'UNKNOWN' && c.statement.includes('Future profitability')));
});

Deno.test('IA-03 a small-sample result (< 30 trades) gets an INFERENCE caveat AND a RECOMMENDATION, with real provenance', async () => {
  const smallSample = await buildCanonicalBacktestResult({ ...ZERO_COST_INPUT, tradeCount: 10, longCount: 5, shortCount: 5, wins: 4, losses: 6 });
  assert(smallSample.ok);
  if (!smallSample.ok) return;
  const claims = analyzeBacktestResult(smallSample.value);
  const inference = claims.find((c) => c.status === 'INFERENCE' && c.statement.includes('too few'));
  assert(inference);
  assertEquals(inference!.provenance?.sampleSize, 10);
  assert(claims.some((c) => c.status === 'RECOMMENDATION'));
});

Deno.test('IA-04 a large-sample result (>= 30 trades) gets NEITHER the small-sample caveat nor the recommendation', async () => {
  const result = await buildCanonicalBacktestResult(ZERO_COST_INPUT); // 75 trades
  assert(result.ok);
  if (!result.ok) return;
  const claims = analyzeBacktestResult(result.value);
  assert(!claims.some((c) => c.statement.includes('too few')));
  assert(!claims.some((c) => c.status === 'RECOMMENDATION'));
});

Deno.test('IA-05 execution ambiguity (BAR_OPEN_GAP-style) is surfaced as an INFERENCE claim with the real count', async () => {
  const result = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  assert(result.ok);
  if (!result.ok) return;
  const claims = analyzeBacktestResult(result.value);
  assert(claims.some((c) => c.status === 'INFERENCE' && c.statement.includes('19 of 75')));
});

Deno.test('IA-06 cost sensitivity is flagged when the sign flips between zero-cost and cost-adjusted (same strategy/dataset)', async () => {
  const zeroCost = await buildCanonicalBacktestResult({ ...ZERO_COST_INPUT, netPnl: 10, grossPnl: 10 });
  const costAdjusted = await buildCanonicalBacktestResult(COST_ADJUSTED_INPUT);
  assert(zeroCost.ok && costAdjusted.ok);
  if (!zeroCost.ok || !costAdjusted.ok) return;
  const claim = analyzeCostSensitivity(zeroCost.value, costAdjusted.value);
  assert(claim !== null);
  assertEquals(claim!.status, 'INFERENCE');
});

Deno.test('IA-07 cost sensitivity is null (no claim fabricated) for a different strategy/dataset pair', async () => {
  const zeroCost = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  const costAdjusted = await buildCanonicalBacktestResult({ ...COST_ADJUSTED_INPUT, strategyId: 'different-strategy' });
  assert(zeroCost.ok && costAdjusted.ok);
  if (!zeroCost.ok || !costAdjusted.ok) return;
  assertEquals(analyzeCostSensitivity(zeroCost.value, costAdjusted.value), null);
});

Deno.test('IA-08 an incomparable comparison becomes an INFERENCE claim stating why, never a fabricated delta', async () => {
  const a = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  const b = await buildCanonicalBacktestResult({ ...ZERO_COST_INPUT, datasetId: 'different-dataset' });
  assert(a.ok && b.ok);
  if (!a.ok || !b.ok) return;
  const comparison = compareBacktestResults(a.value, b.value);
  assert(comparison.ok);
  if (!comparison.ok) return;
  const claim = analyzeComparison(comparison.value);
  assertEquals(claim.status, 'INFERENCE');
  assert(claim.statement.includes('not directly comparable'));
});

Deno.test('IA-09 a comparable comparison becomes a MEASURED delta claim', async () => {
  const a = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  const b = await buildCanonicalBacktestResult({ ...ZERO_COST_INPUT, netPnl: -50, grossPnl: -50 });
  assert(a.ok && b.ok);
  if (!a.ok || !b.ok) return;
  const comparison = compareBacktestResults(a.value, b.value);
  assert(comparison.ok);
  if (!comparison.ok) return;
  const claim = analyzeComparison(comparison.value);
  assertEquals(claim.status, 'MEASURED');
});
