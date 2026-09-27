/**
 * OHLCV bar shape — INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 §16, §18.
 *
 * The one row shape every in-process engine (generic_rule_engine.ts) and
 * every dataset source (synthetic fixture or user-provided) must produce
 * before it can be backtested. Kept minimal and dependency-free.
 */
export interface OhlcvBar {
  readonly timestamp: string; // ISO 8601, UTC
  readonly open: number;
  readonly high: number;
  readonly low: number;
  readonly close: number;
  readonly volume: number;
}

/** §18: schema/timestamp/numeric-integrity validation for a user- or
 * fixture-provided bar series before any engine ever sees it. */
export function validateOhlcvBars(bars: readonly unknown[]): string | null {
  if (!Array.isArray(bars) || bars.length === 0) return 'bars must be a non-empty array';
  if (bars.length > 200_000) return 'bars exceed the maximum supported size';
  let prevTs = -Infinity;
  for (let i = 0; i < bars.length; i++) {
    const b = bars[i] as Partial<OhlcvBar>;
    if (!b || typeof b !== 'object') return `bar ${i} is not an object`;
    const ts = typeof b.timestamp === 'string' ? Date.parse(b.timestamp) : NaN;
    if (!Number.isFinite(ts)) return `bar ${i} has an invalid timestamp`;
    if (ts <= prevTs) return `bar ${i} is not strictly after the previous bar (no duplicates, no reordering)`;
    prevTs = ts;
    for (const field of ['open', 'high', 'low', 'close', 'volume'] as const) {
      const v = b[field];
      if (typeof v !== 'number' || !Number.isFinite(v)) return `bar ${i}.${field} must be a finite number`;
    }
    if (b.high! < b.low!) return `bar ${i} has high < low`;
    if (b.open! < b.low! || b.open! > b.high! || b.close! < b.low! || b.close! > b.high!) {
      return `bar ${i} has open/close outside the high/low range`;
    }
    if (b.volume! < 0) return `bar ${i} has negative volume`;
  }
  return null;
}
