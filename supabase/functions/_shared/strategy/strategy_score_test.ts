import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { computeStrategyScore } from './strategy_score.ts';
import { buildCanonicalBacktestResult, type CanonicalBacktestResultInput } from './backtest_result.ts';
import { STRATEGY_OBJECTIVES } from './user_objective.ts';

function baseInput(overrides: Partial<CanonicalBacktestResultInput> = {}): CanonicalBacktestResultInput {
  return {
    strategyId: 's1', strategyVersion: 1, strategySpecHash: 'h1', datasetId: 'd1', datasetHash: 'dh1',
    instrumentSymbol: 'SYNTH1', periodStart: '2026-01-01T00:00:00Z', periodEnd: '2026-01-31T00:00:00Z',
    timeframes: ['5min'], tradeCount: 40, longCount: 25, shortCount: 15, wins: 22, losses: 18,
    grossPnl: 50, grossProfit: 300, grossLoss: 250, totalCost: 0, netPnl: 50, maxDrawdown: -40,
    targetTouches: 22, stopTouches: 18, executionAmbiguityCount: 0, methodologyStatus: 'ZERO_COST_RESEARCH',
    costAssumptions: null, limitations: [], provenance: 'test', ...overrides,
  };
}

Deno.test('SS-01 every weight set (default + every objective) sums to exactly 1', async () => {
  const built = await buildCanonicalBacktestResult(baseInput());
  assert(built.ok);
  if (!built.ok) return;
  for (const objective of [null, ...STRATEGY_OBJECTIVES]) {
    const score = computeStrategyScore(built.value, objective);
    const weightSum = score.components.reduce((s, c) => s + c.weight, 0);
    assertEquals(Math.round(weightSum * 1000) / 1000, 1, `objective=${objective}`);
  }
});

Deno.test('SS-02 overall is a real weighted sum of the exposed components, never a hidden number', async () => {
  const built = await buildCanonicalBacktestResult(baseInput());
  assert(built.ok);
  if (!built.ok) return;
  const score = computeStrategyScore(built.value, null);
  const expected = Math.round(100 * score.components.reduce((s, c) => s + c.value * c.weight, 0));
  assertEquals(score.overall, expected);
});

Deno.test('SS-03 language is drawn only from the closed, non-guarantee vocabulary', async () => {
  const built = await buildCanonicalBacktestResult(baseInput());
  assert(built.ok);
  if (!built.ok) return;
  const score = computeStrategyScore(built.value, null);
  assert(['MORE_ROBUST_UNDER_TESTED_ASSUMPTIONS', 'REQUIRES_MORE_EVIDENCE'].includes(score.language));
});

Deno.test('SS-04 a small, ambiguous sample scores low and reads REQUIRES_MORE_EVIDENCE', async () => {
  const built = await buildCanonicalBacktestResult(baseInput({
    tradeCount: 3, longCount: 3, shortCount: 0, wins: 1, losses: 2, grossProfit: 10, grossLoss: 30,
    grossPnl: -20, netPnl: -20, executionAmbiguityCount: 3, targetTouches: 1, stopTouches: 2, maxDrawdown: -25,
  }));
  assert(built.ok);
  if (!built.ok) return;
  const score = computeStrategyScore(built.value, null);
  assertEquals(score.language, 'REQUIRES_MORE_EVIDENCE');
});

Deno.test('SS-05 CAPITAL_PRESERVATION weighs drawdown control far more heavily than the default weights', async () => {
  const built = await buildCanonicalBacktestResult(baseInput());
  assert(built.ok);
  if (!built.ok) return;
  const capitalPreservation = computeStrategyScore(built.value, 'CAPITAL_PRESERVATION');
  const balanced = computeStrategyScore(built.value, 'BALANCED'); // falls through to DEFAULT_WEIGHTS
  const drawdownWeight = (s: typeof balanced) => s.components.find((c) => c.name === 'DRAWDOWN_CONTROL')!.weight;
  assert(drawdownWeight(capitalPreservation) > drawdownWeight(balanced));
});

Deno.test('SS-06 undefined profit factor scores that component at 0 with an honest rationale, never a guessed number', async () => {
  const built = await buildCanonicalBacktestResult(baseInput({ grossLoss: 0, losses: 0, wins: 40, tradeCount: 40, longCount: 40, shortCount: 0 }));
  assert(built.ok);
  if (!built.ok) return;
  const score = computeStrategyScore(built.value, null);
  const profitability = score.components.find((c) => c.name === 'PROFITABILITY')!;
  assertEquals(profitability.value, 0);
  assert(profitability.rationale.includes('undefined'));
});

Deno.test('SS-07 unmeasured maxDrawdown gets a neutral 0.5, explicitly labeled as not measured -- not fabricated as good or bad', async () => {
  const built = await buildCanonicalBacktestResult(baseInput({ maxDrawdown: null }));
  assert(built.ok);
  if (!built.ok) return;
  const score = computeStrategyScore(built.value, null);
  const drawdown = score.components.find((c) => c.name === 'DRAWDOWN_CONTROL')!;
  assertEquals(drawdown.value, 0.5);
  assert(drawdown.rationale.includes('not measured'));
});
