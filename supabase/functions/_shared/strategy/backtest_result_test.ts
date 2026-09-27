import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildCanonicalBacktestResult, type CanonicalBacktestResultInput } from './backtest_result.ts';

/** Real numbers reproduced this macro against the actual WIN1! dataset via
 * V10BidirectionalSteppedBacktestOrchestrator (see V10_NO_COST_RESULT /
 * V10_COST_RESULT in the final report) -- not fixtures invented for the
 * test. grossProfit/grossLoss are not surfaced by the Python reference's
 * V4BacktestResult today, so they are approximated here from netPnl only
 * to exercise the contract's shape; profitFactor is therefore illustrative,
 * not a restated Python-computed figure. */
const ZERO_COST_INPUT: CanonicalBacktestResultInput = Object.freeze({
  strategyId: '00000000-0000-4000-8000-000000000001',
  strategyVersion: 1,
  strategySpecHash: 'spec-hash-placeholder',
  datasetId: 'dd80d8a012a4348429fa4597',
  datasetHash: '5220e7cc9f46987b8dcf6cb9',
  instrumentSymbol: 'WIN1!',
  periodStart: '2026-03-30T00:00:00Z',
  periodEnd: '2026-08-11T00:00:00Z',
  timeframes: Object.freeze(['5min']),
  tradeCount: 75,
  longCount: 40,
  shortCount: 35,
  wins: 30,
  losses: 45,
  grossPnl: -57.0,
  grossProfit: 500.0,
  grossLoss: 557.0,
  totalCost: 0,
  netPnl: -57.0,
  maxDrawdown: null,
  targetTouches: 8,
  stopTouches: 47,
  executionAmbiguityCount: 19,
  methodologyStatus: 'ZERO_COST_RESEARCH',
  costAssumptions: null,
  limitations: Object.freeze(['5-minute dataset only; no real 1-minute execution data available (§12).']),
  provenance: 'Python reference implementation, codex/qt01c36-hierarchical-fibonacci-structural-fidelity @ 4b9eb19b',
});

Deno.test('BR-01 builds the real V10 zero-cost reproduction result and computes expectancy correctly', async () => {
  const result = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  assert(result.ok, JSON.stringify(!result.ok && result.error));
  if (!result.ok) return;
  assertEquals(result.value.tradeCount, 75);
  assertEquals(result.value.netPnl, -57.0);
  assertEquals(result.value.expectancy, Math.round((-57.0 / 75) * 100) / 100);
  assert(result.value.resultHash.length === 16);
});

Deno.test('BR-02 two builds of the same input produce the same resultHash (deterministic)', async () => {
  const a = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  const b = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  assert(a.ok && b.ok);
  if (!a.ok || !b.ok) return;
  assertEquals(a.value.resultHash, b.value.resultHash);
});

Deno.test('BR-03 a different netPnl produces a different resultHash', async () => {
  const a = await buildCanonicalBacktestResult(ZERO_COST_INPUT);
  const b = await buildCanonicalBacktestResult({ ...ZERO_COST_INPUT, netPnl: -270.75, grossPnl: -270.75, methodologyStatus: 'COST_ADJUSTED', totalCost: 213.75, costAssumptions: { brokeragePerContract: 0.75, exchangeFeePerContract: 0.10, slippageTicks: 1, source: 'QT-01C.3 Run B' } });
  assert(a.ok && b.ok);
  if (!a.ok || !b.ok) return;
  assert(a.value.resultHash !== b.value.resultHash);
});

Deno.test('BR-04 longCount + shortCount must equal tradeCount', async () => {
  const result = await buildCanonicalBacktestResult({ ...ZERO_COST_INPUT, longCount: 10, shortCount: 10 });
  assert(!result.ok);
});

Deno.test('BR-05 ZERO_COST_RESEARCH with a non-zero totalCost is rejected', async () => {
  const result = await buildCanonicalBacktestResult({ ...ZERO_COST_INPUT, totalCost: 1 });
  assert(!result.ok);
});

Deno.test('BR-06 COST_ADJUSTED without stated costAssumptions is rejected', async () => {
  const result = await buildCanonicalBacktestResult({
    ...ZERO_COST_INPUT,
    methodologyStatus: 'COST_ADJUSTED',
    totalCost: 213.75,
    netPnl: -270.75,
    costAssumptions: null,
  });
  assert(!result.ok);
});

Deno.test('BR-07 profitFactor is null (not fabricated) when grossLoss is zero', async () => {
  const result = await buildCanonicalBacktestResult({ ...ZERO_COST_INPUT, grossLoss: 0, grossProfit: 100 });
  assert(result.ok);
  if (!result.ok) return;
  assertEquals(result.value.profitFactor, null);
});
