import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { validateOhlcvBars } from './ohlcv.ts';
import { syntheticFixtureBars } from './generic_engine_fixtures.ts';

Deno.test('OH-01 the real synthetic fixture passes validation', () => {
  assertEquals(validateOhlcvBars(syntheticFixtureBars()), null);
});

Deno.test('OH-02 an empty array is rejected', () => {
  assertEquals(validateOhlcvBars([]) !== null, true);
});

Deno.test('OH-03 out-of-order/duplicate timestamps are rejected', () => {
  const bars = [
    { timestamp: '2026-01-05T13:05:00Z', open: 100, high: 101, low: 99, close: 100, volume: 1 },
    { timestamp: '2026-01-05T13:00:00Z', open: 100, high: 101, low: 99, close: 100, volume: 1 },
  ];
  assertEquals(validateOhlcvBars(bars) !== null, true);
});

Deno.test('OH-04 high < low, and open/close outside the high/low range, are rejected', () => {
  const badRange = [{ timestamp: '2026-01-05T13:00:00Z', open: 100, high: 99, low: 101, close: 100, volume: 1 }];
  assertEquals(validateOhlcvBars(badRange) !== null, true);
  const openOutside = [{ timestamp: '2026-01-05T13:00:00Z', open: 105, high: 101, low: 99, close: 100, volume: 1 }];
  assertEquals(validateOhlcvBars(openOutside) !== null, true);
});

Deno.test('OH-05 non-finite numeric fields (Infinity/NaN) are rejected', () => {
  const withInfinity = [{ timestamp: '2026-01-05T13:00:00Z', open: 100, high: Infinity, low: 99, close: 100, volume: 1 }];
  assertEquals(validateOhlcvBars(withInfinity) !== null, true);
});

Deno.test('OH-06 negative volume is rejected', () => {
  const badVolume = [{ timestamp: '2026-01-05T13:00:00Z', open: 100, high: 101, low: 99, close: 100, volume: -1 }];
  assertEquals(validateOhlcvBars(badVolume) !== null, true);
});

Deno.test('OH-07 more than 200,000 bars is rejected (resource limit)', () => {
  const huge = Array.from({ length: 200_001 }, (_, i) => ({
    timestamp: new Date(Date.UTC(2026, 0, 1) + i * 60_000).toISOString(),
    open: 100, high: 101, low: 99, close: 100, volume: 1,
  }));
  assertEquals(validateOhlcvBars(huge) !== null, true);
});
