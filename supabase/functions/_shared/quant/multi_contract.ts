/**
 * Multi-series + watchlist analysis contracts — IV-QUANT-REAL-DATA-READINESS-03
 * (docs/quant/QUANT_API_CONTRACT.md §7–§8). New explicit versions; the
 * existing quant.analyze.v1 is untouched.
 *
 *   quant.analyze.multi.v1      — up to MAX_SERIES_PER_ANALYSIS user CSV series
 *   quant.analyze.watchlist.v1  — the caller's OWN watchlist, instruments taken
 *                                 from the database (never from the client),
 *                                 data from a server-side provider
 * Strict schema (unknown fields rejected); provenance set by the server.
 */
import { parseInstrument } from './api_contract.ts';
import { parseOhlcvCsv } from './csv.ts';
import { fail, ok, type QuantResult, type QuantWarning } from './errors.ts';
import type { InstrumentIdentity } from './instrument.ts';
import { instrumentKey } from './instrument.ts';
import { analyzeMultiSeries, MAX_SERIES_PER_ANALYSIS, type MultiSeriesOptions, type MultiSeriesResult } from './multi_series.ts';
import { ALL_FREQUENCIES, type AdjustmentPolicy, type DataProvenance, type Frequency } from './provenance.ts';
import { createPriceSeries, type PriceSeries } from './timeseries.ts';
import type { MarketDataProvider } from './provider.ts';
import { barsRequest } from './provider_adapter.ts';
import type { CachedProviderResponse } from './market_cache.ts';

export const MULTI_CONTRACT_VERSION = 'quant.analyze.multi.v1' as const;
export const WATCHLIST_ANALYSIS_CONTRACT_VERSION = 'quant.analyze.watchlist.v1' as const;
/**
 * Total rows across all series in one multi request. Measured bound
 * (QUANT_RESOURCE_BUDGET.md): 100 000 rows took ~1.2 s CPU locally — too
 * close to the Edge 2 s CPU budget — while 50 000 takes ~0.42 s with a
 * ~55 MB heap peak. Same ceiling as one quant.analyze.v1 series.
 */
export const MAX_TOTAL_ROWS = 50_000;
export const MAX_LOOKBACK_DAYS = 1_100; // ≈ 3 years of daily sessions per instrument

type Obj = Record<string, unknown>;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const ADJUSTMENTS: readonly AdjustmentPolicy[] = ['UNADJUSTED', 'SPLIT_ADJUSTED', 'SPLIT_AND_DIVIDEND_ADJUSTED', 'UNKNOWN'];
const isObj = (v: unknown): v is Obj => typeof v === 'object' && v !== null && !Array.isArray(v);
function onlyKeys(o: Obj, allowed: readonly string[], where: string): QuantResult<Obj> {
  for (const k of Object.keys(o)) if (!allowed.includes(k)) return fail('INVALID_PARAMETER', 'unknown field', { field: `${where}${k}` });
  return ok(o);
}

interface ParsedCommonOptions {
  periodsPerYear: number | null;
  priceBasis?: 'close' | 'adjustedClose';
  /** Weights by position (series index or watchlist item order), resolved to instrument keys later. */
  weightsByIndex?: { index: number; weight: number }[];
}

function parseCommonOptions(v: unknown, maxIndex: number): QuantResult<ParsedCommonOptions> {
  if (!isObj(v)) return fail('INVALID_PARAMETER', 'options must be an object', { field: 'options' });
  const k = onlyKeys(v, ['periods_per_year', 'price_basis', 'weights'], 'options.');
  if (!k.ok) return k;
  if (!('periods_per_year' in v) || (v.periods_per_year !== null && typeof v.periods_per_year !== 'number')) {
    return fail('INVALID_PARAMETER', 'periods_per_year must be stated explicitly (number or null)', { field: 'options.periods_per_year' });
  }
  const out: ParsedCommonOptions = { periodsPerYear: v.periods_per_year as number | null };
  if (v.price_basis !== undefined) {
    if (v.price_basis !== 'close' && v.price_basis !== 'adjusted_close') return fail('INVALID_PARAMETER', 'invalid price_basis', { field: 'options.price_basis' });
    out.priceBasis = v.price_basis === 'close' ? 'close' : 'adjustedClose';
  }
  if (v.weights !== undefined) {
    if (!Array.isArray(v.weights) || v.weights.length === 0 || v.weights.length > MAX_SERIES_PER_ANALYSIS) {
      return fail('INVALID_PARAMETER', 'weights must be a non-empty array of at most 10 entries', { field: 'options.weights' });
    }
    out.weightsByIndex = [];
    for (const w of v.weights) {
      if (!isObj(w)) return fail('INVALID_PARAMETER', 'invalid weight entry', { field: 'options.weights' });
      const wk = onlyKeys(w, ['index', 'weight'], 'options.weights.');
      if (!wk.ok) return wk;
      if (!Number.isSafeInteger(w.index) || (w.index as number) < 0 || (w.index as number) > maxIndex || typeof w.weight !== 'number') {
        return fail('INVALID_PARAMETER', 'weight entries need a valid index and a numeric weight', { field: 'options.weights' });
      }
      out.weightsByIndex.push({ index: w.index as number, weight: w.weight });
    }
  }
  return ok(out);
}

// ---------------------------------------------------------------- quant.analyze.multi.v1

export interface MultiRequest {
  readonly series: ReadonlyArray<{ instrument: InstrumentIdentity; frequency: Frequency; adjustment: AdjustmentPolicy; csv: string }>;
  readonly options: ParsedCommonOptions;
  readonly projectId?: string;
}

export function parseMultiRequest(body: unknown): QuantResult<MultiRequest> {
  if (!isObj(body)) return fail('INVALID_PARAMETER', 'body must be a JSON object');
  const k = onlyKeys(body, ['contract_version', 'series', 'options', 'project_id'], '');
  if (!k.ok) return k;
  if (!Array.isArray(body.series) || body.series.length < 1 || body.series.length > MAX_SERIES_PER_ANALYSIS) {
    return fail('INVALID_PARAMETER', `series must list 1..${MAX_SERIES_PER_ANALYSIS} datasets`, { field: 'series', max: MAX_SERIES_PER_ANALYSIS });
  }
  const series: MultiRequest['series'][number][] = [];
  for (let i = 0; i < body.series.length; i++) {
    const s = body.series[i];
    if (!isObj(s)) return fail('INVALID_PARAMETER', 'series entry must be an object', { field: `series.${i}` });
    const sk = onlyKeys(s, ['instrument', 'dataset'], `series.${i}.`);
    if (!sk.ok) return sk;
    const inst = parseInstrument(s.instrument);
    if (!inst.ok) return fail(inst.error.code, inst.error.message, { ...(inst.error.details ?? {}), series: i });
    if (!isObj(s.dataset)) return fail('INVALID_DATASET', 'dataset must be an object', { field: `series.${i}.dataset` });
    const dk = onlyKeys(s.dataset, ['format', 'frequency', 'adjustment', 'csv'], `series.${i}.dataset.`);
    if (!dk.ok) return dk;
    const d = s.dataset;
    if (d.format !== 'csv' || !ALL_FREQUENCIES.includes(d.frequency as Frequency) || !ADJUSTMENTS.includes(d.adjustment as AdjustmentPolicy) || typeof d.csv !== 'string' || d.csv.length === 0) {
      return fail('INVALID_DATASET', 'dataset needs format csv, a frequency, an adjustment and csv text', { field: `series.${i}.dataset` });
    }
    series.push({ instrument: inst.value, frequency: d.frequency as Frequency, adjustment: d.adjustment as AdjustmentPolicy, csv: d.csv });
  }
  const opts = parseCommonOptions(body.options, series.length - 1);
  if (!opts.ok) return opts;
  if (body.project_id !== undefined && (typeof body.project_id !== 'string' || !UUID_RE.test(body.project_id))) {
    return fail('INVALID_PARAMETER', 'project_id must be a UUID', { field: 'project_id' });
  }
  return ok({ series, options: opts.value, ...(body.project_id ? { projectId: body.project_id as string } : {}) });
}

function resolveWeights(opts: ParsedCommonOptions, list: readonly PriceSeries[]): MultiSeriesOptions['weights'] {
  return opts.weightsByIndex?.map((w) => ({ instrumentKey: list[w.index] ? instrumentKey(list[w.index].instrument) : `#${w.index}`, weight: w.weight }));
}

export async function runMulti(req: MultiRequest, nowMs: number): Promise<QuantResult<MultiSeriesResult>> {
  if (!Number.isFinite(nowMs) || Math.abs(nowMs) > 8.64e15) return fail('INVALID_PARAMETER', 'server clock returned an unusable time');
  let totalRows = 0;
  const list: PriceSeries[] = [];
  for (let i = 0; i < req.series.length; i++) {
    const s = req.series[i];
    const parsed = parseOhlcvCsv(s.csv);
    if (!parsed.ok) return fail(parsed.error.code, parsed.error.message, { ...(parsed.error.details ?? {}), series: i });
    totalRows += parsed.value.rows.length;
    if (totalRows > MAX_TOTAL_ROWS) return fail('DATASET_TOO_LARGE', 'too many rows across all series', { max: MAX_TOTAL_ROWS });
    const provenance: DataProvenance = {
      providerId: 'user-csv',
      providerKind: 'USER_UPLOAD',
      trust: 'USER_SUPPLIED',
      retrievedAt: new Date(nowMs).toISOString(),
      frequency: s.frequency,
      currency: typeof s.instrument.currency === 'string' ? s.instrument.currency.trim().toUpperCase() : '',
      adjustment: s.adjustment,
    };
    const series = createPriceSeries(s.instrument, provenance, parsed.value.rows);
    if (!series.ok) return fail(series.error.code, series.error.message, { ...(series.error.details ?? {}), series: i });
    list.push(series.value);
  }
  return analyzeMultiSeries(list, {
    periodsPerYear: req.options.periodsPerYear,
    ...(req.options.priceBasis ? { priceBasis: req.options.priceBasis } : {}),
    ...(req.options.weightsByIndex ? { weights: resolveWeights(req.options, list) } : {}),
    ...(req.projectId ? { projectId: req.projectId } : {}),
  }, () => nowMs);
}

// ---------------------------------------------------------------- quant.analyze.watchlist.v1

export type WatchlistDataSource = 'SYNTHETIC_PROVIDER';

export interface WatchlistAnalysisResult extends MultiSeriesResult {
  readonly dataSource: {
    readonly kind: WatchlistDataSource;
    readonly providerId: string;
    /** Per-call cache outcome counts (HIT/MISS/STALE_FALLBACK; uncached = provider without cache). */
    readonly cache: { readonly hits: number; readonly misses: number; readonly staleFallbacks: number; readonly uncached: number };
  };
}

export interface WatchlistAnalysisRequest {
  readonly watchlistId: string;
  /** Optional subset of item ids (required when the watchlist has more than 10 items). */
  readonly itemIds?: readonly string[];
  readonly dataSource: WatchlistDataSource;
  readonly lookbackDays: number;
  readonly options: ParsedCommonOptions;
}

export function parseWatchlistAnalysisRequest(body: unknown): QuantResult<WatchlistAnalysisRequest> {
  if (!isObj(body)) return fail('INVALID_PARAMETER', 'body must be a JSON object');
  const k = onlyKeys(body, ['contract_version', 'watchlist_id', 'item_ids', 'data_source', 'lookback_days', 'options'], '');
  if (!k.ok) return k;
  if (typeof body.watchlist_id !== 'string' || !UUID_RE.test(body.watchlist_id)) return fail('INVALID_PARAMETER', 'watchlist_id must be a UUID', { field: 'watchlist_id' });
  // Only the server-side synthetic provider exists; a licensed provider is a future, separately gated value.
  if (body.data_source !== 'SYNTHETIC_PROVIDER') return fail('INVALID_PARAMETER', 'data_source must be SYNTHETIC_PROVIDER', { field: 'data_source' });
  let itemIds: string[] | undefined;
  if (body.item_ids !== undefined) {
    if (!Array.isArray(body.item_ids) || body.item_ids.length < 1 || body.item_ids.length > MAX_SERIES_PER_ANALYSIS || body.item_ids.some((x) => typeof x !== 'string' || !UUID_RE.test(x)) || new Set(body.item_ids).size !== body.item_ids.length) {
      return fail('INVALID_PARAMETER', `item_ids must list 1..${MAX_SERIES_PER_ANALYSIS} distinct UUIDs`, { field: 'item_ids' });
    }
    itemIds = body.item_ids as string[];
  }
  const lookback = body.lookback_days ?? 365;
  if (!Number.isSafeInteger(lookback) || (lookback as number) < 30 || (lookback as number) > MAX_LOOKBACK_DAYS) {
    return fail('INVALID_PARAMETER', `lookback_days must be an integer in 30..${MAX_LOOKBACK_DAYS}`, { field: 'lookback_days' });
  }
  const opts = parseCommonOptions(body.options, MAX_SERIES_PER_ANALYSIS - 1);
  if (!opts.ok) return opts;
  return ok({ watchlistId: body.watchlist_id, ...(itemIds ? { itemIds } : {}), dataSource: 'SYNTHETIC_PROVIDER', lookbackDays: lookback as number, options: opts.value });
}

/**
 * Runs the analysis for instruments ALREADY resolved from the caller's own
 * watchlist (server-side). Provider data goes through createPriceSeries like
 * any other dataset; provider failures are reported per instrument.
 */
export async function runWatchlistAnalysis(
  instruments: readonly InstrumentIdentity[],
  req: WatchlistAnalysisRequest,
  provider: MarketDataProvider,
  nowMs: number,
): Promise<QuantResult<WatchlistAnalysisResult>> {
  if (!Number.isFinite(nowMs) || Math.abs(nowMs) > 8.64e15) return fail('INVALID_PARAMETER', 'server clock returned an unusable time');
  if (instruments.length < 1) return fail('INSUFFICIENT_DATA', 'the selected watchlist items are empty');
  if (instruments.length > MAX_SERIES_PER_ANALYSIS) {
    return fail('DATASET_TOO_LARGE', 'select at most 10 watchlist items per analysis (item_ids)', { max: MAX_SERIES_PER_ANALYSIS });
  }
  const list: PriceSeries[] = [];
  const cache = { hits: 0, misses: 0, staleFallbacks: 0, uncached: 0 };
  for (let i = 0; i < instruments.length; i++) {
    const res = await provider.historicalBars(barsRequest(instruments[i], nowMs, req.lookbackDays, 'SPLIT_AND_DIVIDEND_ADJUSTED'));
    if (!res.ok) return fail(res.error.code, res.error.message, { ...(res.error.details ?? {}), series: i });
    const status = (res.value as Partial<CachedProviderResponse>).cache?.status;
    if (status === 'HIT') cache.hits++;
    else if (status === 'MISS') cache.misses++;
    else if (status === 'STALE_FALLBACK') cache.staleFallbacks++;
    else cache.uncached++;
    const s = createPriceSeries(instruments[i], res.value.provenance, res.value.data);
    if (!s.ok) return fail(s.error.code, s.error.message, { ...(s.error.details ?? {}), series: i });
    list.push(s.value);
  }
  const r = await analyzeMultiSeries(list, {
    periodsPerYear: req.options.periodsPerYear,
    ...(req.options.priceBasis ? { priceBasis: req.options.priceBasis } : {}),
    ...(req.options.weightsByIndex ? { weights: resolveWeights(req.options, list) } : {}),
  }, () => nowMs);
  if (!r.ok) return r;
  const warnings: QuantWarning[] = [...r.value.warnings];
  if (cache.staleFallbacks > 0) {
    warnings.push({ code: 'CACHE_STALE', message: 'the provider failed; some series were served from an older cached copy', details: { series: cache.staleFallbacks } });
  }
  return ok({ ...r.value, warnings, dataSource: { kind: req.dataSource, providerId: provider.id, cache } });
}
