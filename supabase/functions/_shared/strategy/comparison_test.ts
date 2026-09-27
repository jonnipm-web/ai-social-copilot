import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildCanonicalBacktestResult, type CanonicalBacktestResultInput } from './backtest_result.ts';
import { compareBacktestResults } from './comparison.ts';

const BASE: CanonicalBacktestResultInput = Object.freeze({
  strategyId: 's1',
  strategyVersion: 1,
  strategySpecHash: 'h1',
  datasetId: 'dataset-a',
  datasetHash: 'hash-a',
  instrumentSymbol: 'WIN1!',
  periodStart: '2026-01-01T00:00:00Z',
  periodEnd: '2026-02-01T00:00:00Z',
  timeframes: Object.freeze(['5min']),
  tradeCount: 10,
  longCount: 5,
  shortCount: 5,
  wins: 4,
  losses: 6,
  grossPnl: -100,
  grossProfit: 200,
  grossLoss: 300,
  totalCost: 0,
  netPnl: -100,
  maxDrawdown: -150,
  targetTouches: 2,
  stopTouches: 6,
  executionAmbiguityCount: 1,
  methodologyStatus: 'ZERO_COST_RESEARCH',
  costAssumptions: null,
  limitations: Object.freeze([]),
  provenance: 'test fixture',
});

Deno.test('CE-01 same dataset/period/cost basis is comparable and computes deltas', async () => {
  const a = await buildCanonicalBacktestResult(BASE);
  const b = await buildCanonicalBacktestResult({ ...BASE, netPnl: -50, tradeCount: 12, longCount: 6, shortCount: 6 });
  assert(a.ok && b.ok);
  if (!a.ok || !b.ok) return;
  const cmp = compareBacktestResults(a.value, b.value);
  assert(cmp.ok);
  if (!cmp.ok) return;
  assertEquals(cmp.value.comparable, true);
  assertEquals(cmp.value.deltas?.netPnlDelta, 50);
  assertEquals(cmp.value.deltas?.tradeCountDelta, 2);
});

Deno.test('CE-02 a different dataset is flagged NOT comparable with a stated reason, never silently compared', async () => {
  const a = await buildCanonicalBacktestResult(BASE);
  const b = await buildCanonicalBacktestResult({ ...BASE, datasetId: 'dataset-b', datasetHash: 'hash-b' });
  assert(a.ok && b.ok);
  if (!a.ok || !b.ok) return;
  const cmp = compareBacktestResults(a.value, b.value);
  assert(cmp.ok);
  if (!cmp.ok) return;
  assertEquals(cmp.value.comparable, false);
  assert(cmp.value.incomparabilityReasons.some((r) => r.includes('dataset')));
  assertEquals(cmp.value.deltas, null);
});

Deno.test('CE-03 different cost assumptions are flagged even when everything else matches', async () => {
  const a = await buildCanonicalBacktestResult(BASE);
  const b = await buildCanonicalBacktestResult({
    ...BASE,
    methodologyStatus: 'COST_ADJUSTED',
    totalCost: 10,
    netPnl: -110,
    costAssumptions: { brokeragePerContract: 0.75, exchangeFeePerContract: 0.1, slippageTicks: 1, source: 'x' },
  });
  assert(a.ok && b.ok);
  if (!a.ok || !b.ok) return;
  const cmp = compareBacktestResults(a.value, b.value);
  assert(cmp.ok);
  if (!cmp.ok) return;
  assertEquals(cmp.value.comparable, false);
});
