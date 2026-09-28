import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { MAX_BOUNDED_VARIANTS, proposeBoundedStopVariants } from './bounded_exploration.ts';
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
