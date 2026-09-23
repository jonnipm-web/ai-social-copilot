/**
 * quant-analyze API contract — IV-QUANT-DATA-PLANE-AND-API-02
 * (docs/quant/QUANT_API_CONTRACT.md).
 *
 * Pure: request validation, the data-plane pipeline and error→HTTP
 * mapping. The Edge Function (supabase/functions/quant-analyze) only adds
 * transport, authentication, entitlement and project ownership. Every
 * number comes from the existing deterministic engine — nothing here
 * computes a metric.
 *
 *   INPUT → VALIDATE (this file) → CSV parse (csv.ts) → NORMALIZE + PROVENANCE
 *   (createPriceSeries) → FRESHNESS/CALENDAR + ANALYZE (analyzeSeries) → RESULT
 *
 * Strict schema: unknown fields are REJECTED at every level, so a client
 * cannot smuggle `user_id`, `plan`, `role`, a provider claim or a metric.
 * The server — not the client — sets provenance: providerKind USER_UPLOAD,
 * trust USER_SUPPLIED, retrievedAt = server receipt time, no sourceAsOf.
 */
import { analyzeSeries, type QuantAnalysisResult, type SeriesAnalysisOptions } from './analysis.ts';
import { parseOhlcvCsv } from './csv.ts';
import { fail, ok, type QuantErrorCode, type QuantResult } from './errors.ts';
import type { AssetClass, InstrumentIdentity } from './instrument.ts';
import { ALL_FREQUENCIES, type AdjustmentPolicy, type DataProvenance, type FreshnessState, type Frequency } from './provenance.ts';
import { createPriceSeries, type PriceBasis } from './timeseries.ts';

export const ANALYZE_CONTRACT_VERSION = 'quant.analyze.v1' as const;
/** 5 MiB CSV (csv.ts limit) + JSON escaping/envelope headroom. */
export const MAX_ANALYZE_BODY_BYTES = 6 * 1024 * 1024;

export interface AnalyzeRequest {
  readonly instrument: InstrumentIdentity;
  readonly frequency: Frequency;
  readonly adjustment: AdjustmentPolicy;
  readonly csv: string;
  readonly sourceLabel?: string;
  readonly options: SeriesAnalysisOptions;
  readonly projectId?: string;
}

type Obj = Record<string, unknown>;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const ADJUSTMENTS: readonly AdjustmentPolicy[] = ['UNADJUSTED', 'SPLIT_ADJUSTED', 'SPLIT_AND_DIVIDEND_ADJUSTED', 'UNKNOWN'];
const FRESHNESS: readonly FreshnessState[] = ['FRESH', 'DELAYED', 'STALE', 'UNKNOWN'];

function isObj(v: unknown): v is Obj {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** Rejects any key outside `allowed` — the anti-smuggling rule. */
function onlyKeys(o: Obj, allowed: readonly string[], where: string): QuantResult<Obj> {
  for (const k of Object.keys(o)) {
    if (!allowed.includes(k)) return fail('INVALID_PARAMETER', 'unknown field', { field: `${where}.${k}`.replace(/^\./, '') });
  }
  return ok(o);
}

function optString(o: Obj, k: string, max: number, where: string): QuantResult<string | undefined> {
  if (o[k] === undefined) return ok(undefined);
  if (typeof o[k] !== 'string' || (o[k] as string).length > max) return fail('INVALID_PARAMETER', 'must be a string', { field: `${where}.${k}` });
  return ok(o[k] as string);
}

function parseInstrument(v: unknown): QuantResult<InstrumentIdentity> {
  if (!isObj(v)) return fail('INVALID_INSTRUMENT', 'instrument must be an object');
  const keys = onlyKeys(v, ['asset_class', 'symbol', 'exchange_mic', 'currency', 'exchange_timezone', 'isin', 'figi'], 'instrument');
  if (!keys.ok) return keys;
  const out: Record<string, unknown> = {};
  for (const [src, dst] of [['symbol', 'symbol'], ['currency', 'currency'], ['exchange_mic', 'exchangeMic'], ['exchange_timezone', 'exchangeTimezone'], ['isin', 'isin'], ['figi', 'figi']] as const) {
    const s = optString(v, src, 64, 'instrument');
    if (!s.ok) return fail('INVALID_INSTRUMENT', 'invalid instrument field', { field: `instrument.${src}` });
    if (s.value !== undefined) out[dst] = s.value;
  }
  if (typeof v.asset_class !== 'string') return fail('INVALID_INSTRUMENT', 'asset_class required', { field: 'instrument.asset_class' });
  out.assetClass = v.asset_class as AssetClass;
  // Full identity validation (charset, ISO codes, check digits, supported class)
  // happens in createPriceSeries — the single authority for instrument identity.
  return ok(out as unknown as InstrumentIdentity);
}

function positiveInt(v: unknown, field: string, max: number): QuantResult<number> {
  return Number.isSafeInteger(v) && (v as number) >= 1 && (v as number) <= max
    ? ok(v as number)
    : fail('INVALID_PARAMETER', `must be an integer in 1..${max}`, { field });
}

function parseOptions(v: unknown): QuantResult<SeriesAnalysisOptions> {
  if (!isObj(v)) return fail('INVALID_PARAMETER', 'options must be an object', { field: 'options' });
  const keys = onlyKeys(v, ['periods_per_year', 'price_basis', 'sma_windows', 'crossover', 'sharpe', 'accepted_freshness'], 'options');
  if (!keys.ok) return keys;
  // periodsPerYear must be stated explicitly (number or null); analyzeSeries validates the value.
  if (!('periods_per_year' in v) || (v.periods_per_year !== null && typeof v.periods_per_year !== 'number')) {
    return fail('INVALID_PARAMETER', 'periods_per_year must be stated explicitly (number or null)', { field: 'options.periods_per_year' });
  }
  const out: { -readonly [K in keyof SeriesAnalysisOptions]: SeriesAnalysisOptions[K] } = { periodsPerYear: v.periods_per_year as number | null };
  if (v.price_basis !== undefined) {
    if (v.price_basis !== 'close' && v.price_basis !== 'adjusted_close') {
      return fail('INVALID_PARAMETER', 'price_basis must be close | adjusted_close', { field: 'options.price_basis' });
    }
    out.priceBasis = (v.price_basis === 'close' ? 'close' : 'adjustedClose') as PriceBasis;
  }
  if (v.sma_windows !== undefined) {
    if (!Array.isArray(v.sma_windows)) return fail('INVALID_PARAMETER', 'sma_windows must be an array', { field: 'options.sma_windows' });
    const ws: number[] = [];
    for (const w of v.sma_windows) {
      const r = positiveInt(w, 'options.sma_windows', 50_000);
      if (!r.ok) return r;
      ws.push(r.value);
    }
    out.smaWindows = ws;
  }
  if (v.crossover !== undefined) {
    if (!isObj(v.crossover)) return fail('INVALID_PARAMETER', 'crossover must be an object', { field: 'options.crossover' });
    const k = onlyKeys(v.crossover, ['fast', 'slow'], 'options.crossover');
    if (!k.ok) return k;
    const fast = positiveInt(v.crossover.fast, 'options.crossover.fast', 50_000);
    if (!fast.ok) return fast;
    const slow = positiveInt(v.crossover.slow, 'options.crossover.slow', 50_000);
    if (!slow.ok) return slow;
    out.crossover = { fast: fast.value, slow: slow.value };
  }
  if (v.sharpe !== undefined) {
    if (!isObj(v.sharpe)) return fail('INVALID_PARAMETER', 'sharpe must be an object', { field: 'options.sharpe' });
    const k = onlyKeys(v.sharpe, ['risk_free_rate_per_period', 'periods_per_year'], 'options.sharpe');
    if (!k.ok) return k;
    if (typeof v.sharpe.risk_free_rate_per_period !== 'number' || typeof v.sharpe.periods_per_year !== 'number') {
      return fail('INVALID_PARAMETER', 'sharpe requires risk_free_rate_per_period and periods_per_year', { field: 'options.sharpe' });
    }
    out.sharpe = { riskFreeRatePerPeriod: v.sharpe.risk_free_rate_per_period, periodsPerYear: v.sharpe.periods_per_year };
  }
  if (v.accepted_freshness !== undefined) {
    if (!Array.isArray(v.accepted_freshness) || v.accepted_freshness.length === 0 || v.accepted_freshness.some((s) => !FRESHNESS.includes(s as FreshnessState))) {
      return fail('INVALID_PARAMETER', 'accepted_freshness must list FRESH|DELAYED|STALE|UNKNOWN', { field: 'options.accepted_freshness' });
    }
    out.acceptedFreshness = v.accepted_freshness as FreshnessState[];
  }
  return ok(out);
}

/** Validates the parsed JSON body of a quant-analyze request. */
export function parseAnalyzeRequest(body: unknown): QuantResult<AnalyzeRequest> {
  if (!isObj(body)) return fail('INVALID_PARAMETER', 'body must be a JSON object');
  const keys = onlyKeys(body, ['contract_version', 'instrument', 'dataset', 'options', 'project_id'], '');
  if (!keys.ok) return keys;
  if (body.contract_version !== ANALYZE_CONTRACT_VERSION) {
    return fail('INVALID_PARAMETER', `contract_version must be ${ANALYZE_CONTRACT_VERSION}`, { field: 'contract_version' });
  }
  const instrument = parseInstrument(body.instrument);
  if (!instrument.ok) return instrument;
  if (!isObj(body.dataset)) return fail('INVALID_DATASET', 'dataset must be an object', { field: 'dataset' });
  const dk = onlyKeys(body.dataset, ['format', 'frequency', 'adjustment', 'csv', 'source_label'], 'dataset');
  if (!dk.ok) return dk;
  const ds = body.dataset;
  if (ds.format !== 'csv') return fail('INVALID_DATASET', 'dataset.format must be csv', { field: 'dataset.format' });
  if (!ALL_FREQUENCIES.includes(ds.frequency as Frequency)) return fail('INVALID_DATASET', 'invalid frequency', { field: 'dataset.frequency' });
  if (!ADJUSTMENTS.includes(ds.adjustment as AdjustmentPolicy)) return fail('INVALID_DATASET', 'invalid adjustment', { field: 'dataset.adjustment' });
  if (typeof ds.csv !== 'string' || ds.csv.length === 0) return fail('INVALID_DATASET', 'dataset.csv must be a non-empty string', { field: 'dataset.csv' });
  const label = optString(ds, 'source_label', 120, 'dataset');
  if (!label.ok) return label;
  const options = parseOptions(body.options);
  if (!options.ok) return options;
  if (body.project_id !== undefined && (typeof body.project_id !== 'string' || !UUID_RE.test(body.project_id))) {
    return fail('INVALID_PARAMETER', 'project_id must be a UUID', { field: 'project_id' });
  }
  return ok({
    instrument: instrument.value,
    frequency: ds.frequency as Frequency,
    adjustment: ds.adjustment as AdjustmentPolicy,
    csv: ds.csv,
    ...(label.value ? { sourceLabel: label.value } : {}),
    options: { ...options.value, ...(body.project_id ? { projectId: body.project_id as string } : {}) },
    ...(body.project_id ? { projectId: body.project_id as string } : {}),
  });
}

/**
 * The data-plane pipeline. `nowMs` is the server clock at request receipt;
 * it becomes provenance.retrievedAt and the freshness reference — never a
 * calculation input.
 */
export async function runAnalyze(req: AnalyzeRequest, nowMs: number): Promise<QuantResult<QuantAnalysisResult>> {
  const parsed = parseOhlcvCsv(req.csv);
  if (!parsed.ok) return parsed;
  const provenance: DataProvenance = {
    providerId: 'user-csv',
    providerKind: 'USER_UPLOAD',
    trust: 'USER_SUPPLIED',
    retrievedAt: new Date(nowMs).toISOString(),
    frequency: req.frequency,
    currency: typeof req.instrument.currency === 'string' ? req.instrument.currency.trim().toUpperCase() : '',
    adjustment: req.adjustment,
    ...(req.sourceLabel ? { sourceLabel: req.sourceLabel } : {}),
  };
  const series = createPriceSeries(req.instrument, provenance, parsed.value.rows);
  if (!series.ok) return series;
  const result = await analyzeSeries(series.value, req.options, () => nowMs);
  if (!result.ok) return result;
  // CSV-level caveats (e.g. ignored columns) belong in the result too.
  return ok({ ...result.value, warnings: [...parsed.value.warnings, ...result.value.warnings] });
}

/** Transport-level error codes (not calculation errors). */
export type TransportErrorCode = 'METHOD_NOT_ALLOWED' | 'UNSUPPORTED_MEDIA_TYPE' | 'INVALID_JSON' | 'INTERNAL_ERROR';

const STATUS: Readonly<Record<QuantErrorCode | TransportErrorCode, number>> = {
  INVALID_PARAMETER: 400,
  INVALID_INSTRUMENT: 400,
  INVALID_DATASET: 400,
  INVALID_JSON: 400,
  ENTITLEMENT_DENIED: 403,
  PROJECT_ACCESS_DENIED: 403,
  METHOD_NOT_ALLOWED: 405,
  DATASET_TOO_LARGE: 413,
  UNSUPPORTED_MEDIA_TYPE: 415,
  DATA_QUALITY_ERROR: 422,
  INSUFFICIENT_DATA: 422,
  CURRENCY_MISMATCH: 422,
  UNSUPPORTED_ASSET_CLASS: 422,
  STALE_DATA: 422,
  CALCULATION_ERROR: 422,
  INVALID_PORTFOLIO: 422,
  INTERNAL_ERROR: 500,
  PROVIDER_UNAVAILABLE: 503,
};

export function httpStatusFor(code: QuantErrorCode | TransportErrorCode): number {
  return STATUS[code] ?? 500;
}
