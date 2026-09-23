/**
 * Time-series core + normalization — IV-QUANT-FOUNDATION-01
 * (QUANT_DATA_MODEL.md §5–§6).
 *
 * RAW provider/CSV rows → validate → normalize → canonical PriceSeries.
 * Calculations only ever see a PriceSeries, never a provider's JSON.
 *
 * Normalization rules (all tested):
 *  - timestamps are epoch milliseconds UTC (integers); invalid → reject
 *  - prices must be finite and > 0; volume finite and >= 0
 *  - OHLC consistency: low <= min(open, close), high >= max(open, close)
 *  - out-of-order rows are sorted (ROWS_REORDERED warning)
 *  - exact duplicate rows are collapsed (EXACT_DUPLICATES_COLLAPSED warning)
 *  - two DIFFERENT rows with the same timestamp → DATA_QUALITY_ERROR (the
 *    engine never silently picks one)
 *  - missing values are never filled; a row missing a required field is
 *    rejected, and gaps between bars are only reported, never interpolated
 *  - adjustedClose must be present on every bar or on none
 *  - timestamps must fall in [1800-01-01, 2300-01-01) UTC
 *
 * A PriceSeries is deeply frozen: bars, instrument, provenance and warnings
 * cannot be mutated after validation (Codex Gate 1 CX1-06).
 */
import { fail, ok, type QuantResult, type QuantWarning } from './errors.ts';
import { createInstrument, type InstrumentIdentity, requireFoundationSupported } from './instrument.ts';
import { type DataProvenance, type Frequency, parseIsoUtc, validateProvenance } from './provenance.ts';

export interface PriceBar {
  /** Bar timestamp, epoch ms UTC. For DAILY bars from date-only sources this
   * is 00:00Z of the session date (a label, not an exchange-local instant). */
  readonly t: number;
  readonly open: number;
  readonly high: number;
  readonly low: number;
  readonly close: number;
  readonly volume?: number;
  readonly adjustedClose?: number;
}

export interface RawBarInput {
  readonly t: unknown;
  readonly open: unknown;
  readonly high: unknown;
  readonly low: unknown;
  readonly close: unknown;
  readonly volume?: unknown;
  readonly adjustedClose?: unknown;
}

export interface PriceSeries {
  readonly instrument: InstrumentIdentity;
  readonly frequency: Frequency;
  readonly provenance: DataProvenance;
  /** Strictly increasing by t. */
  readonly bars: readonly PriceBar[];
  readonly normalizationWarnings: readonly QuantWarning[];
}

/** Upper bound on bars accepted in one series (≈ 200 years of daily bars;
 * ≈ 35 trading days of 1-minute bars). Protects server memory/CPU. */
export const MAX_BARS_PER_SERIES = 50_000;

const DAY = 86_400_000;
/** Plausible bar-time range. Also keeps every timestamp inside the ECMAScript
 * Date range, so toISOString() can never throw (Claude finding CL-01). */
export const MIN_BAR_T = Date.UTC(1800, 0, 1);
export const MAX_BAR_T = Date.UTC(2300, 0, 1);

/** Nominal span of one bar: provenance.sourceAsOf must fall within
 * [newest bar t, newest bar t + span] (Codex Gate 1 CX1-01). */
export const BAR_SPAN_MS: Readonly<Record<Frequency, number>> = {
  INTRADAY_1M: 60_000,
  INTRADAY_5M: 300_000,
  INTRADAY_1H: 3_600_000,
  DAILY: DAY,
  WEEKLY: 7 * DAY,
  MONTHLY: 31 * DAY,
};

/** Calendar-naive gap thresholds (a larger spacing is reported, never filled). */
const GAP_THRESHOLD_MS: Partial<Record<Frequency, number>> = {
  DAILY: 4 * DAY,
  WEEKLY: 10 * DAY,
  MONTHLY: 35 * DAY,
};

function isFinitePositive(v: unknown): v is number {
  return typeof v === 'number' && Number.isFinite(v) && v > 0;
}

function sameBar(a: PriceBar, b: PriceBar): boolean {
  return a.t === b.t && a.open === b.open && a.high === b.high && a.low === b.low && a.close === b.close &&
    a.volume === b.volume && a.adjustedClose === b.adjustedClose;
}

export function normalizeBars(
  raw: readonly RawBarInput[],
  frequency: Frequency,
  maxBars: number = MAX_BARS_PER_SERIES,
): QuantResult<{ bars: PriceBar[]; warnings: QuantWarning[] }> {
  if (!Array.isArray(raw)) return fail('INVALID_DATASET', 'bars must be an array');
  if (raw.length > maxBars) {
    return fail('DATASET_TOO_LARGE', 'too many bars', { rows: raw.length, max: maxBars });
  }
  const bars: PriceBar[] = [];
  let withAdj = 0;
  for (let i = 0; i < raw.length; i++) {
    const r = raw[i];
    if (!r || typeof r !== 'object') return fail('INVALID_DATASET', 'bar must be an object', { row: i });
    if (typeof r.t !== 'number' || !Number.isSafeInteger(r.t) || r.t < MIN_BAR_T || r.t >= MAX_BAR_T) {
      return fail('INVALID_DATASET', 'invalid or out-of-range timestamp', { row: i, field: 't' });
    }
    for (const f of ['open', 'high', 'low', 'close'] as const) {
      if (!isFinitePositive(r[f])) return fail('INVALID_DATASET', 'price must be a finite number > 0', { row: i, field: f });
    }
    const open = r.open as number, high = r.high as number, low = r.low as number, close = r.close as number;
    if (low > Math.min(open, close) || high < Math.max(open, close) || low > high) {
      return fail('DATA_QUALITY_ERROR', 'OHLC inconsistent (low/high do not bound open/close)', { row: i });
    }
    let volume: number | undefined;
    if (r.volume !== undefined && r.volume !== null) {
      if (typeof r.volume !== 'number' || !Number.isFinite(r.volume) || r.volume < 0) {
        return fail('INVALID_DATASET', 'volume must be a finite number >= 0', { row: i, field: 'volume' });
      }
      volume = r.volume;
    }
    let adjustedClose: number | undefined;
    if (r.adjustedClose !== undefined && r.adjustedClose !== null) {
      if (!isFinitePositive(r.adjustedClose)) {
        return fail('INVALID_DATASET', 'adjustedClose must be a finite number > 0', { row: i, field: 'adjustedClose' });
      }
      adjustedClose = r.adjustedClose;
      withAdj++;
    }
    bars.push({
      t: r.t,
      open,
      high,
      low,
      close,
      ...(volume !== undefined ? { volume } : {}),
      ...(adjustedClose !== undefined ? { adjustedClose } : {}),
    });
  }
  if (withAdj !== 0 && withAdj !== bars.length) {
    return fail('DATA_QUALITY_ERROR', 'adjustedClose present on some bars but not all', { withAdjusted: withAdj, rows: bars.length });
  }

  const warnings: QuantWarning[] = [];
  let ordered = true;
  for (let i = 1; i < bars.length; i++) if (bars[i].t < bars[i - 1].t) ordered = false;
  if (!ordered) {
    // Stable sort by t; equal timestamps keep input order (resolved below).
    bars.sort((a, b) => a.t - b.t);
    warnings.push({ code: 'ROWS_REORDERED', message: 'rows were not in chronological order and were sorted' });
  }

  const unique: PriceBar[] = [];
  let collapsed = 0;
  for (const b of bars) {
    const prev = unique[unique.length - 1];
    if (prev && prev.t === b.t) {
      if (sameBar(prev, b)) {
        collapsed++;
        continue;
      }
      return fail('DATA_QUALITY_ERROR', 'conflicting rows share a timestamp', { t: new Date(b.t).toISOString() });
    }
    unique.push(b);
  }
  if (collapsed > 0) {
    warnings.push({ code: 'EXACT_DUPLICATES_COLLAPSED', message: 'identical duplicate rows were collapsed', details: { collapsed } });
  }

  const gapMs = GAP_THRESHOLD_MS[frequency];
  if (gapMs !== undefined) {
    let gaps = 0;
    let largest = 0;
    for (let i = 1; i < unique.length; i++) {
      const d = unique[i].t - unique[i - 1].t;
      if (d > gapMs) {
        gaps++;
        largest = Math.max(largest, d);
      }
    }
    if (gaps > 0) {
      warnings.push({
        code: 'TIME_GAPS_DETECTED',
        message: 'spacing larger than the calendar-naive threshold; values were NOT interpolated',
        details: { gaps, largestGapDays: Math.round((largest / DAY) * 100) / 100 },
      });
    }
  }
  return ok({ bars: unique, warnings });
}

function deepFreeze<T>(v: T): T {
  if (v && typeof v === 'object' && !Object.isFrozen(v)) {
    for (const k of Object.keys(v)) deepFreeze((v as Record<string, unknown>)[k]);
    Object.freeze(v);
  }
  return v;
}

/**
 * The only constructor of a PriceSeries. Validates and canonicalizes the
 * instrument (Codex Gate 1 CX1-05), validates provenance, requires at least
 * one bar (CX1-09), checks that provenance.sourceAsOf agrees with the newest
 * bar (CX1-01), and returns a deep-frozen copy (CX1-06).
 */
export function createPriceSeries(
  instrument: InstrumentIdentity,
  provenance: DataProvenance,
  raw: readonly RawBarInput[],
  maxBars: number = MAX_BARS_PER_SERIES,
): QuantResult<PriceSeries> {
  const inst = createInstrument(instrument);
  if (!inst.ok) return inst;
  const supported = requireFoundationSupported(inst.value);
  if (!supported.ok) return supported;
  const prov = validateProvenance(provenance);
  if (!prov.ok) return prov;
  if (provenance.currency !== inst.value.currency) {
    return fail('CURRENCY_MISMATCH', 'dataset currency differs from instrument currency', {
      instrumentCurrency: inst.value.currency,
      datasetCurrency: provenance.currency,
    });
  }
  const norm = normalizeBars(raw, provenance.frequency, maxBars);
  if (!norm.ok) return norm;
  const bars = norm.value.bars;
  if (bars.length === 0) return fail('INSUFFICIENT_DATA', 'dataset has no bars');
  if (provenance.sourceAsOf !== undefined) {
    const asOf = parseIsoUtc(provenance.sourceAsOf) as number;
    const newest = bars[bars.length - 1].t;
    if (asOf < newest || asOf > newest + BAR_SPAN_MS[provenance.frequency]) {
      return fail('DATA_QUALITY_ERROR', 'provenance sourceAsOf disagrees with the newest bar', {
        sourceAsOf: provenance.sourceAsOf,
        newestBar: new Date(newest).toISOString(),
      });
    }
  }
  return ok(deepFreeze({
    instrument: structuredClone(inst.value),
    frequency: provenance.frequency,
    provenance: structuredClone(provenance),
    bars: bars.map((b) => ({ ...b })),
    normalizationWarnings: structuredClone(norm.value.warnings),
  }));
}

/**
 * Which price the calculations use. There is NO inference from field
 * presence (Codex Gate 1 CX1-03): the default is always 'close', and
 * 'adjustedClose' must be requested explicitly. `provenance.adjustment`
 * describes the OHLC fields; the adjustedClose column is provider-defined.
 */
export type PriceBasis = 'close' | 'adjustedClose';

export function pricesOf(series: PriceSeries, basis: PriceBasis): QuantResult<number[]> {
  if (basis === 'adjustedClose') {
    if (!series.bars.every((b) => b.adjustedClose !== undefined)) {
      return fail('INVALID_PARAMETER', 'adjustedClose basis requested but not available on every bar');
    }
    return ok(series.bars.map((b) => b.adjustedClose as number));
  }
  return ok(series.bars.map((b) => b.close));
}

/**
 * Inner join of two series on identical timestamps. No forward-fill, no
 * interpolation: a timestamp missing on either side is dropped from both.
 */
export function alignOnTimestamps(
  a: readonly PriceBar[],
  b: readonly PriceBar[],
): { t: number[]; ai: number[]; bi: number[] } {
  const t: number[] = [], ai: number[] = [], bi: number[] = [];
  let i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i].t === b[j].t) {
      t.push(a[i].t);
      ai.push(i);
      bi.push(j);
      i++;
      j++;
    } else if (a[i].t < b[j].t) i++;
    else j++;
  }
  return { t, ai, bi };
}
