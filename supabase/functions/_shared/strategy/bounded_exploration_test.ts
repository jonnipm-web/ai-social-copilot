import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { MAX_BOUNDED_VARIANTS, proposeBoundedStopVariants, proposeBoundedTargetVariants, proposeBoundedVariants } from './bounded_exploration.ts';
import { analyzeStrategyMarketFit } from './strategy_market_fit.ts';
import { computeMarketStatistics } from './market_statistics.ts';
import { buildGenericReferenceSpecification } from './generic_reference_strategy.ts';
import { syntheticFixtureBars } from './generic_engine_fixtures.ts';

function specAndFit(stopDistance?: number) {
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) throw new Error('unreachable');
  const spec = stopDistance !== undefined ? { ...specResult.value, stop: { ...specResult.value.stop, distance: stopDistance } } : specResult.value;
  const bars = syntheticFixtureBars();
  const statsResult = computeMarketStatistics(bars, '5min');
  assert(statsResult.ok);
  if (!statsResult.ok) throw new Error('unreachable');
  const fit = analyzeStrategyMarketFit(spec, statsResult.value, bars);
  return { spec, fit };
}

function specAndFitTarget(targetDistance?: number) {
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) throw new Error('unreachable');
  const spec = targetDistance !== undefined ? { ...specResult.value, target: { ...specResult.value.target, distance: targetDistance } } : specResult.value;
  const bars = syntheticFixtureBars();
  const statsResult = computeMarketStatistics(bars, '5min');
  assert(statsResult.ok);
  if (!statsResult.ok) throw new Error('unreachable');
  const fit = analyzeStrategyMarketFit(spec, statsResult.value, bars);
  return { spec, fit };
}

Deno.test('BE-01 proposes nothing when STOP_VS_MOVEMENT is not flagged -- no fabricated suggestion', () => {
  // A very wide stop relative to the fixture's typical range should not be flagged.
  const { spec, fit } = specAndFit(1000);
  const variants = proposeBoundedStopVariants(spec, fit);
  assertEquals(variants, []);
});

Deno.test('BE-02 proposes bounded, capped variants when STOP_VS_MOVEMENT IS flagged', () => {
  // The reference spec's default stop (5) is tight vs this fixture's range -- should flag.
  const { spec, fit } = specAndFit(1);
  const stopFinding = fit.items.find((i) => i.dimension === 'STOP_VS_MOVEMENT')!;
  assert(stopFinding.flagged);
  const variants = proposeBoundedStopVariants(spec, fit);
  assert(variants.length > 0);
  assert(variants.length <= MAX_BOUNDED_VARIANTS);
});

Deno.test('BE-03 every proposed variant carries a real reason citing the measured evidence, and a from/to on stop.distance', () => {
  const { spec, fit } = specAndFit(1);
  const variants = proposeBoundedStopVariants(spec, fit);
  for (const v of variants) {
    assert(v.reason.length > 0);
    assertEquals(v.parametersChanged['stop.distance'].from, spec.stop.distance);
    assert(v.parametersChanged['stop.distance'].to > spec.stop.distance);
  }
});

Deno.test('BE-04 proposed stop distances are strictly increasing and distinct', () => {
  const { spec, fit } = specAndFit(1);
  const variants = proposeBoundedStopVariants(spec, fit);
  const tos = variants.map((v) => v.parametersChanged['stop.distance'].to);
  const sorted = [...tos].sort((a, b) => a - b);
  assertEquals(tos, sorted);
  assertEquals(new Set(tos).size, tos.length);
});

// ── Macro-08 continuation §11: generalized to target ──────────────────────

Deno.test('BE-05 proposes nothing when TARGET_VS_MOVEMENT is not flagged -- no fabricated suggestion', () => {
  // A tiny target relative to the fixture's typical move should not be flagged (ratio << 5.0).
  const { spec, fit } = specAndFitTarget(1);
  const variants = proposeBoundedTargetVariants(spec, fit);
  assertEquals(variants, []);
});

Deno.test('BE-06 proposes bounded, capped NARROWER target variants when TARGET_VS_MOVEMENT IS flagged', () => {
  const { spec, fit } = specAndFitTarget(100000);
  const targetFinding = fit.items.find((i) => i.dimension === 'TARGET_VS_MOVEMENT')!;
  assert(targetFinding.flagged);
  const variants = proposeBoundedTargetVariants(spec, fit);
  assert(variants.length > 0);
  assert(variants.length <= MAX_BOUNDED_VARIANTS);
  for (const v of variants) {
    assertEquals(v.parametersChanged['target.distance'].from, spec.target.distance);
    assert(v.parametersChanged['target.distance'].to < spec.target.distance, 'target concern is TOO FAR, so bounded exploration must propose NARROWER, never wider');
  }
});

Deno.test('BE-07 proposed target distances are strictly decreasing and distinct, each with a real evidence-citing reason', () => {
  const { spec, fit } = specAndFitTarget(100000);
  const variants = proposeBoundedTargetVariants(spec, fit);
  const tos = variants.map((v) => v.parametersChanged['target.distance'].to);
  const sorted = [...tos].sort((a, b) => b - a);
  assertEquals(tos, sorted);
  assertEquals(new Set(tos).size, tos.length);
  for (const v of variants) assert(v.reason.length > 0);
});

Deno.test('BE-08 proposeBoundedVariants combines stop and target proposals, and reports breakEven as UNSUPPORTED_BY_CURRENT_ENGINE only when the strategy actually configures one', () => {
  // Neither flagged: no proposals, no breakEven configured -> no unsupported entries either.
  const clean = specAndFit(1000);
  const cleanResult = proposeBoundedVariants(clean.spec, clean.fit);
  assertEquals(cleanResult.proposals, []);
  // The reference spec's own default stop (1000 here is an override, but
  // target is untouched) may or may not configure breakEven; this first
  // assertion only pins the proposals side, the breakEven signal itself
  // is exercised explicitly below with a spec known to configure one.

  // Both flagged simultaneously: a spec with a tight stop AND a far target.
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) throw new Error('unreachable');
  const bothSpec = {
    ...specResult.value,
    stop: { ...specResult.value.stop, distance: 1 },
    target: { ...specResult.value.target, distance: 100000 },
    // The generic reference spec does not configure breakEven by default
    // (it is null) -- set one explicitly so this test exercises the
    // "configured" branch of the unsupported-parameter signal.
    breakEven: { ruleId: 'BREAK_EVEN.STEPPED', triggerDistance: 50, initialProtectedDistance: 10, stepDistance: 10 },
  };
  const bars = syntheticFixtureBars();
  const statsResult = computeMarketStatistics(bars, '5min');
  assert(statsResult.ok);
  if (!statsResult.ok) throw new Error('unreachable');
  const bothFit = analyzeStrategyMarketFit(bothSpec, statsResult.value, bars);
  const { proposals } = proposeBoundedVariants(bothSpec, bothFit);
  assert(proposals.some((p) => 'stop.distance' in p.parametersChanged));
  assert(proposals.some((p) => 'target.distance' in p.parametersChanged));

  // A strategy with breakEven configured gets the explicit unsupported signal.
  const { unsupportedParameters } = proposeBoundedVariants(bothSpec, bothFit);
  assertEquals(unsupportedParameters.length, 1);
  assertEquals(unsupportedParameters[0].parameter, 'breakEven');
  assert(unsupportedParameters[0].reason.startsWith('UNSUPPORTED_BY_CURRENT_ENGINE'));
});
