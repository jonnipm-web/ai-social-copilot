import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { analyzeStrategyMarketFit } from './strategy_market_fit.ts';
import { computeMarketStatistics } from './market_statistics.ts';
import { buildGenericReferenceSpecification } from './generic_reference_strategy.ts';
import { syntheticFixtureBars } from './generic_engine_fixtures.ts';
import type { OhlcvBar } from './ohlcv.ts';

function specAndStats() {
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) throw new Error('unreachable');
  const bars = syntheticFixtureBars();
  const statsResult = computeMarketStatistics(bars, '5min');
  assert(statsResult.ok);
  if (!statsResult.ok) throw new Error('unreachable');
  return { spec: specResult.value, stats: statsResult.value, bars };
}

Deno.test('MF-01 always returns exactly the dimensions computable without a cost model, plus COST_VS_MOVEMENT when the profile has one', () => {
  const { spec, stats, bars } = specAndStats();
  const evidence = analyzeStrategyMarketFit(spec, stats, bars);
  const dims = evidence.items.map((i) => i.dimension);
  assertEquals(dims, ['STOP_VS_MOVEMENT', 'TARGET_VS_MOVEMENT', 'SESSION_VS_DATA_COVERAGE', 'SIGNAL_TIMEFRAME_MATCH']);
});

Deno.test('MF-02 STOP_VS_MOVEMENT and TARGET_VS_MOVEMENT are real ratios computed from spec+stats, not placeholders', () => {
  const { spec, stats, bars } = specAndStats();
  const evidence = analyzeStrategyMarketFit(spec, stats, bars);
  const stop = evidence.items.find((i) => i.dimension === 'STOP_VS_MOVEMENT')!;
  const target = evidence.items.find((i) => i.dimension === 'TARGET_VS_MOVEMENT')!;
  assertEquals(stop.value, spec.stop.distance / stats.rangePoints.median);
  assertEquals(target.value, spec.target.distance / stats.absMovePoints.p90);
});

Deno.test('MF-03 SIGNAL_TIMEFRAME_MATCH is flagged when the spec and stats timeframes disagree', () => {
  const { spec, stats, bars } = specAndStats();
  const mismatched = { ...stats, timeframe: '1min' };
  const evidence = analyzeStrategyMarketFit(spec, mismatched, bars);
  const item = evidence.items.find((i) => i.dimension === 'SIGNAL_TIMEFRAME_MATCH')!;
  assertEquals(item.value, 0);
  assertEquals(item.flagged, true);
});

Deno.test('MF-04 SESSION_VS_DATA_COVERAGE measures the real fraction of bars inside the configured session window', () => {
  const { spec, stats, bars } = specAndStats();
  const evidence = analyzeStrategyMarketFit(spec, stats, bars);
  const item = evidence.items.find((i) => i.dimension === 'SESSION_VS_DATA_COVERAGE')!;
  // The synthetic fixture's own bars are documented (generic_engine_fixtures.ts)
  // to sit within the 13:00-14:00 UTC session window used by the reference spec.
  assertEquals(item.value, 1);
  assertEquals(item.flagged, false);
});

Deno.test('MF-05 COST_VS_MOVEMENT is included, honestly, only when the market profile actually carries cost assumptions', () => {
  const { spec, stats, bars } = specAndStats();
  const withCost = {
    ...spec,
    marketProfile: {
      ...spec.marketProfile,
      defaultCostAssumptions: { brokeragePerContract: 0.75, exchangeFeePerContract: 0.1, slippageTicks: 1, source: 'test' },
    },
  };
  const evidence = analyzeStrategyMarketFit(withCost, stats, bars);
  const item = evidence.items.find((i) => i.dimension === 'COST_VS_MOVEMENT');
  assert(item !== undefined);
  assert(Number.isFinite(item!.value));
});

Deno.test('MF-06 sufficientData mirrors the stats it was computed from, never independently guessed', () => {
  const { spec, stats, bars } = specAndStats();
  const evidence = analyzeStrategyMarketFit(spec, stats, bars);
  assertEquals(evidence.sufficientData, stats.sufficientForStatistics);
});

Deno.test('MF-07 an invalid IANA timezone on the profile never throws -- session coverage degrades to 0/flagged, not a crash', () => {
  const { spec, stats, bars } = specAndStats();
  const bad = { ...spec, marketProfile: { ...spec.marketProfile, timezone: 'Not/AZone' } };
  const evidence = analyzeStrategyMarketFit(bad, stats, bars);
  const item = evidence.items.find((i) => i.dimension === 'SESSION_VS_DATA_COVERAGE')!;
  assertEquals(item.value, 0);
});

Deno.test('MF-08 explicit bar-arithmetic sanity check on STOP_VS_MOVEMENT with hand-picked bars', () => {
  const { spec } = specAndStats();
  const bars: OhlcvBar[] = [
    { timestamp: '2026-01-05T13:00:00Z', open: 100, high: 110, low: 90, close: 105, volume: 10 }, // range 20
    { timestamp: '2026-01-05T13:05:00Z', open: 105, high: 108, low: 100, close: 102, volume: 10 }, // range 8
  ];
  const statsResult = computeMarketStatistics(bars, '5min');
  assert(statsResult.ok);
  if (!statsResult.ok) return;
  const evidence = analyzeStrategyMarketFit(spec, statsResult.value, bars);
  const stop = evidence.items.find((i) => i.dimension === 'STOP_VS_MOVEMENT')!;
  // median range of [20, 8] -- percentile(sorted=[8,20], 0.5) = 8 + (20-8)*0.5 = 14
  assertEquals(stop.value, spec.stop.distance / 14);
});
