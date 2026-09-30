import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  checkRiskConstraintsAgainstResult, checkRiskConstraintsAgainstSpec, createUserObjectiveProfile,
} from './user_objective.ts';
import { buildGenericReferenceSpecification } from './generic_reference_strategy.ts';
import { buildCanonicalBacktestResult, type CanonicalBacktestResultInput } from './backtest_result.ts';

function baseResultInput(): CanonicalBacktestResultInput {
  return {
    strategyId: 's1', strategyVersion: 1, strategySpecHash: 'h1', datasetId: 'd1', datasetHash: 'dh1',
    instrumentSymbol: 'SYNTH1', periodStart: '2026-01-01T00:00:00Z', periodEnd: '2026-01-11T00:00:00Z',
    timeframes: ['5min'], tradeCount: 20, longCount: 20, shortCount: 0, wins: 10, losses: 10,
    grossPnl: 0, grossProfit: 100, grossLoss: 100, totalCost: 0, netPnl: 0, maxDrawdown: -50,
    targetTouches: 10, stopTouches: 10, executionAmbiguityCount: 0, methodologyStatus: 'ZERO_COST_RESEARCH',
    costAssumptions: null, limitations: [], provenance: 'test',
  };
}

Deno.test('UO-01 rejects an unknown objective', () => {
  const r = createUserObjectiveProfile({ objective: 'NOT_A_REAL_OBJECTIVE' as never });
  assert(!r.ok);
});

Deno.test('UO-02 rejects non-positive risk constraint values', () => {
  const r = createUserObjectiveProfile({ objective: 'BALANCED', riskConstraints: { maxPositionSize: -1 } });
  assert(!r.ok);
});

Deno.test('UO-03 rejects notes over the length cap', () => {
  const r = createUserObjectiveProfile({ objective: 'BALANCED', notes: 'x'.repeat(501) });
  assert(!r.ok);
});

Deno.test('UO-04 accepts a well-formed profile with all constraint fields', () => {
  const r = createUserObjectiveProfile({
    objective: 'LOW_DRAWDOWN',
    riskConstraints: { maxAcceptableDrawdown: 100, maxPositionSize: 2, maxTradeFrequencyPerDay: 5, allowedDirections: ['LONG'] },
    notes: 'test profile',
  });
  assert(r.ok);
});

Deno.test('UO-05 spec-level check: maxPositionSize compliance is measured against the real spec quantity', () => {
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  const compliant = checkRiskConstraintsAgainstSpec({ maxPositionSize: 5 }, specResult.value);
  assertEquals(compliant.checks[0].status, 'COMPLIANT');
  assertEquals(compliant.checks[0].measured, specResult.value.positionSize.quantity);
  const violated = checkRiskConstraintsAgainstSpec({ maxPositionSize: 0.5 }, specResult.value);
  assertEquals(violated.checks[0].status, 'VIOLATED');
  assertEquals(violated.anyViolated, true);
});

Deno.test('UO-06 spec-level check: allowedDirections VIOLATED when the spec permits a direction outside the constraint', () => {
  const specResult = buildGenericReferenceSpecification(); // allowedDirections: ['LONG']
  assert(specResult.ok);
  if (!specResult.ok) return;
  const r = checkRiskConstraintsAgainstSpec({ allowedDirections: ['SHORT'] }, specResult.value);
  assertEquals(r.checks[0].status, 'VIOLATED');
});

Deno.test('UO-07 result-level check: maxAcceptableDrawdown is measured from the real maxDrawdown field', async () => {
  const built = await buildCanonicalBacktestResult(baseResultInput());
  assert(built.ok);
  if (!built.ok) return;
  const compliant = checkRiskConstraintsAgainstResult({ maxAcceptableDrawdown: 100 }, built.value);
  assertEquals(compliant.checks[0], { constraint: 'MAX_ACCEPTABLE_DRAWDOWN', limit: 100, measured: -50, status: 'COMPLIANT' });
  const violated = checkRiskConstraintsAgainstResult({ maxAcceptableDrawdown: 10 }, built.value);
  assertEquals(violated.checks[0].status, 'VIOLATED');
});

Deno.test('UO-08 result-level check: maxAcceptableDrawdown is UNKNOWN, never fabricated, when maxDrawdown was not measured', async () => {
  const built = await buildCanonicalBacktestResult({ ...baseResultInput(), maxDrawdown: null });
  assert(built.ok);
  if (!built.ok) return;
  const r = checkRiskConstraintsAgainstResult({ maxAcceptableDrawdown: 100 }, built.value);
  assertEquals(r.checks[0].status, 'UNKNOWN');
  assertEquals(r.checks[0].measured, null);
  assert(typeof r.checks[0].unknownReason === 'string');
  assertEquals(r.anyUnknown, true);
  assertEquals(r.anyViolated, false);
});

Deno.test('UO-09 result-level check: maxTradeFrequencyPerDay is computed from the real period length and trade count', async () => {
  const built = await buildCanonicalBacktestResult(baseResultInput()); // 20 trades over 10 days = 2/day
  assert(built.ok);
  if (!built.ok) return;
  const r = checkRiskConstraintsAgainstResult({ maxTradeFrequencyPerDay: 3 }, built.value);
  assertEquals(r.checks[0].measured, 2);
  assertEquals(r.checks[0].status, 'COMPLIANT');
  const r2 = checkRiskConstraintsAgainstResult({ maxTradeFrequencyPerDay: 1 }, built.value);
  assertEquals(r2.checks[0].status, 'VIOLATED');
});

Deno.test('UO-10 result-level check: maxSimulatedDailyLoss is always UNKNOWN -- CanonicalBacktestResult has no per-day granularity', async () => {
  const built = await buildCanonicalBacktestResult(baseResultInput());
  assert(built.ok);
  if (!built.ok) return;
  const r = checkRiskConstraintsAgainstResult({ maxSimulatedDailyLoss: 100 }, built.value);
  assertEquals(r.checks[0].status, 'UNKNOWN');
  assertEquals(r.anyUnknown, true);
});

Deno.test('UO-11 every compliance report unconditionally states historical compliance does not guarantee future compliance', async () => {
  const built = await buildCanonicalBacktestResult(baseResultInput());
  assert(built.ok);
  if (!built.ok) return;
  const r1 = checkRiskConstraintsAgainstResult({}, built.value);
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  const r2 = checkRiskConstraintsAgainstSpec({}, specResult.value);
  assertEquals(r1.historicalComplianceDoesNotGuaranteeFuture, true);
  assertEquals(r2.historicalComplianceDoesNotGuaranteeFuture, true);
});
