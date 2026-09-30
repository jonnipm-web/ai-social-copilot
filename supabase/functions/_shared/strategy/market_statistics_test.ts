import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { computeMarketStatistics, MIN_BARS_FOR_STATISTICS, MIN_DISTINCT_DAYS_FOR_HOUR_OF_DAY } from './market_statistics.ts';
import type { OhlcvBar } from './ohlcv.ts';

function bar(ts: string, open: number, high: number, low: number, close: number, volume = 100): OhlcvBar {
  return { timestamp: ts, open, high, low, close, volume };
}

Deno.test('MS-01 rejects an empty bar series and a missing timeframe', () => {
  const r1 = computeMarketStatistics([], '5min');
  assert(!r1.ok);
  const r2 = computeMarketStatistics([bar('2026-01-01T00:00:00Z', 1, 2, 0, 1)], '');
  assert(!r2.ok);
});

Deno.test('MS-02 computes range/move distributions and up/down fractions from real bar arithmetic, not guesses', () => {
  const bars = [
    bar('2026-01-01T13:00:00Z', 100, 110, 95, 105), // range 15, move +5, up
    bar('2026-01-01T13:05:00Z', 105, 108, 100, 102), // range 8, move -3, down
    bar('2026-01-01T13:10:00Z', 102, 103, 101, 102), // range 2, move 0, flat
  ];
  const r = computeMarketStatistics(bars, '5min');
  assert(r.ok);
  if (!r.ok) return;
  assertEquals(r.value.barCount, 3);
  assertEquals(r.value.rangePoints.max, 15);
  assertEquals(r.value.rangePoints.mean, (15 + 8 + 2) / 3);
  assertEquals(r.value.absMovePoints.max, 5);
  assertEquals(r.value.upBarFraction, 1 / 3);
  assertEquals(r.value.downBarFraction, 1 / 3);
  assertEquals(r.value.averageVolume, 100);
  assertEquals(r.value.sufficientForStatistics, false); // only 3 bars, below MIN_BARS_FOR_STATISTICS
});

Deno.test('MS-03 sufficientForStatistics flips true only at MIN_BARS_FOR_STATISTICS', () => {
  const bars: OhlcvBar[] = [];
  for (let i = 0; i < MIN_BARS_FOR_STATISTICS; i++) {
    bars.push(bar(new Date(Date.UTC(2026, 0, 1, 13, i * 5)).toISOString(), 100, 101, 99, 100));
  }
  const r = computeMarketStatistics(bars, '5min');
  assert(r.ok);
  if (!r.ok) return;
  assertEquals(r.value.sufficientForStatistics, true);
});

Deno.test('MS-04 gapFrequency counts real timestamp gaps larger than 1.5x the modal spacing, never a fabricated rate', () => {
  const bars = [
    bar('2026-01-01T13:00:00Z', 100, 101, 99, 100),
    bar('2026-01-01T13:05:00Z', 100, 101, 99, 100), // 5min gap (modal)
    bar('2026-01-01T13:10:00Z', 100, 101, 99, 100), // 5min gap (modal)
    bar('2026-01-01T14:00:00Z', 100, 101, 99, 100), // 50min gap -- a real break
  ];
  const r = computeMarketStatistics(bars, '5min');
  assert(r.ok);
  if (!r.ok) return;
  // 3 deltas total, 1 of them is the outsized gap.
  assertEquals(r.value.gapFrequency, 1 / 3);
});

Deno.test('MS-05 hourOfDayUtcRangePoints stays null without enough distinct days -- no fabricated time-of-day breakdown', () => {
  const bars = [
    bar('2026-01-01T13:00:00Z', 100, 110, 90, 100),
    bar('2026-01-01T14:00:00Z', 100, 105, 95, 100),
  ];
  const r = computeMarketStatistics(bars, '5min');
  assert(r.ok);
  if (!r.ok) return;
  assertEquals(r.value.hourOfDayUtcRangePoints, null);
});

Deno.test('MS-06 hourOfDayUtcRangePoints appears once enough distinct UTC days are present, bucketed correctly', () => {
  const bars: OhlcvBar[] = [];
  for (let day = 1; day <= MIN_DISTINCT_DAYS_FOR_HOUR_OF_DAY; day++) {
    bars.push(bar(`2026-01-${String(day).padStart(2, '0')}T13:00:00Z`, 100, 100 + day, 100 - day, 100)); // range = 2*day, hour 13
    bars.push(bar(`2026-01-${String(day).padStart(2, '0')}T14:00:00Z`, 100, 100 + 1, 100 - 1, 100)); // range = 2, hour 14
  }
  const r = computeMarketStatistics(bars, '5min');
  assert(r.ok);
  if (!r.ok) return;
  assert(r.value.hourOfDayUtcRangePoints !== null);
  const buckets = r.value.hourOfDayUtcRangePoints!;
  const hour13 = buckets.find((b) => b.hourUtc === 13);
  const hour14 = buckets.find((b) => b.hourUtc === 14);
  assert(hour13 && hour14);
  assertEquals(hour13!.sampleCount, MIN_DISTINCT_DAYS_FOR_HOUR_OF_DAY);
  assertEquals(hour14!.sampleCount, MIN_DISTINCT_DAYS_FOR_HOUR_OF_DAY);
  assertEquals(hour14!.meanRangePoints, 2);
});
