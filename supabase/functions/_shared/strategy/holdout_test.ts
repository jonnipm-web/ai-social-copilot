import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { splitBarsForHoldout } from './holdout.ts';
import { syntheticFixtureBars } from './generic_engine_fixtures.ts';

Deno.test('HO-01 rejects fewer than 2 bars', () => {
  const r = splitBarsForHoldout([], 0.3);
  assert(!r.ok);
});

Deno.test('HO-02 rejects a fraction outside (0,1)', () => {
  const bars = syntheticFixtureBars();
  assert(!splitBarsForHoldout(bars, 0).ok);
  assert(!splitBarsForHoldout(bars, 1).ok);
  assert(!splitBarsForHoldout(bars, -0.1).ok);
  assert(!splitBarsForHoldout(bars, 1.5).ok);
});

Deno.test('HO-03 splits the 9-bar synthetic fixture exactly at its session boundary with a 4/9 holdout fraction', () => {
  const bars = syntheticFixtureBars();
  const r = splitBarsForHoldout(bars, 4 / 9);
  assert(r.ok);
  if (!r.ok) return;
  assertEquals(r.value.research.length, 5);
  assertEquals(r.value.holdout.length, 4);
  assertEquals(r.value.research[0].timestamp, '2026-01-05T13:00:00Z');
  assertEquals(r.value.research[r.value.research.length - 1].timestamp, '2026-01-05T13:55:00Z');
  assertEquals(r.value.holdout[0].timestamp, '2026-01-06T13:00:00Z');
});

Deno.test('HO-04 the split is chronological -- research bars are all strictly earlier than every holdout bar', () => {
  const bars = syntheticFixtureBars();
  const r = splitBarsForHoldout(bars, 4 / 9);
  assert(r.ok);
  if (!r.ok) return;
  const lastResearchTs = Date.parse(r.value.research[r.value.research.length - 1].timestamp);
  const firstHoldoutTs = Date.parse(r.value.holdout[0].timestamp);
  assert(lastResearchTs < firstHoldoutTs);
});

Deno.test('HO-05 refuses a fraction that would leave one side empty for a small series', () => {
  const bars = syntheticFixtureBars().slice(0, 2);
  const r = splitBarsForHoldout(bars, 0.01); // floor(2*0.99)=1 -- fine, not empty
  assert(r.ok);
  const r2 = splitBarsForHoldout(bars.slice(0, 1).concat(bars.slice(0, 1)), 0.99); // degenerate, still 2 bars: floor(2*0.01)=0 -- empty research
  assert(!r2.ok);
});
