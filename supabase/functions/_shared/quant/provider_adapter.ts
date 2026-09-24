/**
 * Market-data provider adapters — IV-QUANT-REAL-DATA-READINESS-03
 * (docs/quant/QUANT_REAL_DATA_READINESS.md §3).
 *
 * The ADAPTER owns everything vendor-specific: request construction,
 * response parsing, error normalization, provider provenance, rate-limit
 * metadata, source timestamps and adjustment semantics. The deterministic
 * engine never sees vendor JSON — it receives RawBarInput + DataProvenance
 * and still goes through createPriceSeries (validation, sourceAsOf
 * consistency, canonical identity).
 *
 * Pure (no I/O): the runtime (_shared/quant_provider_runtime.ts) performs the
 * outbound call through safeFetch with the adapter's host allowlist and
 * injects any credential from server secrets. No real vendor is implemented
 * here; `syntheticVendorAdapter` parses the generic envelope produced by
 * synthetic_market.ts and is the contract-test reference.
 */
import { fail, ok, type QuantResult } from './errors.ts';
import type { InstrumentIdentity } from './instrument.ts';
import type { AdjustmentPolicy, DataProvenance, ProviderKind, TrustLevel } from './provenance.ts';
import { parseIsoUtc } from './provenance.ts';
import type { HistoricalBarsRequest, ProviderResponse } from './provider.ts';
import type { RawBarInput } from './timeseries.ts';

export interface AdapterHttpRequest {
  readonly url: string;
  /** Non-secret headers only. Credentials are added by the runtime from secrets. */
  readonly headers: Readonly<Record<string, string>>;
}

export interface AdapterSpec {
  readonly id: string;
  readonly providerKind: ProviderKind;
  readonly trust: TrustLevel;
  /** Exact hostnames the runtime may contact (re-checked on every redirect). */
  readonly allowedHosts: readonly string[];
  /** Server secret name (never a value). null = no credential. */
  readonly secretEnvName: string | null;
  /** How the credential is attached; header name, never a URL query parameter. */
  readonly secretHeader: string | null;
  readonly maxResponseBytes: number;
  readonly timeoutMs: number;
  buildRequest(req: HistoricalBarsRequest, baseUrl: string): QuantResult<AdapterHttpRequest>;
  parseResponse(
    req: HistoricalBarsRequest,
    status: number,
    headers: Headers,
    body: string,
    retrievedAtMs: number,
  ): QuantResult<ProviderResponse<RawBarInput[]>>;
}

/** Normalizes transport-level vendor failures into Quant error codes. */
export function normalizeVendorStatus(status: number, headers: Headers): QuantResult<null> {
  if (status >= 200 && status < 300) return ok(null);
  if (status === 429) {
    const ra = Number(headers.get('retry-after') ?? '');
    return fail('PROVIDER_RATE_LIMITED', 'provider rate limit reached', Number.isFinite(ra) && ra > 0 ? { retryAfterSeconds: Math.ceil(ra) } : undefined);
  }
  if (status === 401 || status === 403) return fail('PROVIDER_UNAVAILABLE', 'provider rejected the credential', { status });
  if (status >= 500) return fail('PROVIDER_UNAVAILABLE', 'provider error', { status });
  return fail('PROVIDER_UNAVAILABLE', 'provider refused the request', { status });
}

const NUM_RE = /^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$/;
function num(v: unknown): number | null {
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v !== 'string' || !NUM_RE.test(v.trim())) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

const MAX_VENDOR_BARS = 50_000;

/**
 * Reference adapter for the generic synthetic envelope. Every identity field
 * echoed by the provider must match the request — a provider answering for a
 * different symbol, venue, currency, interval or adjustment is rejected
 * (provider spoofing / response poisoning defence).
 */
export const syntheticVendorAdapter: AdapterSpec = {
  id: 'synthetic-vendor',
  providerKind: 'FIXTURE',
  trust: 'SYNTHETIC_FIXTURE',
  allowedHosts: ['synthetic.invalid'],
  secretEnvName: null,
  secretHeader: null,
  maxResponseBytes: 8 * 1024 * 1024,
  timeoutMs: 10_000,

  buildRequest(req, baseUrl) {
    let u: URL;
    try {
      u = new URL('/v1/time_series', baseUrl);
    } catch {
      return fail('PROVIDER_UNAVAILABLE', 'invalid provider base URL');
    }
    if (u.protocol !== 'https:') return fail('PROVIDER_UNAVAILABLE', 'provider base URL must be https');
    u.searchParams.set('symbol', req.instrument.symbol);
    if (req.instrument.exchangeMic) u.searchParams.set('mic', req.instrument.exchangeMic);
    u.searchParams.set('interval', '1day');
    u.searchParams.set('start', new Date(req.fromT).toISOString().slice(0, 10));
    u.searchParams.set('end', new Date(req.toT).toISOString().slice(0, 10));
    u.searchParams.set('adjustment', req.adjustment);
    return ok({ url: u.toString(), headers: { Accept: 'application/json' } });
  },

  parseResponse(req, status, headers, body, retrievedAtMs) {
    const st = normalizeVendorStatus(status, headers);
    if (!st.ok) return st;
    let json: unknown;
    try {
      json = JSON.parse(body);
    } catch {
      return fail('PROVIDER_MALFORMED', 'provider body is not JSON');
    }
    if (typeof json !== 'object' || json === null) return fail('PROVIDER_MALFORMED', 'provider body is not an object');
    const j = json as { meta?: Record<string, unknown>; values?: unknown; status?: unknown };
    if (j.status !== 'ok' || typeof j.meta !== 'object' || j.meta === null || !Array.isArray(j.values)) {
      return fail('PROVIDER_MALFORMED', 'provider envelope missing meta/values');
    }
    const m = j.meta;
    const expect = (field: string, got: unknown, want: unknown) =>
      got === want ? null : fail<never>('PROVIDER_MALFORMED', 'provider identity mismatch', { field });
    const mismatch = expect('symbol', m.symbol, req.instrument.symbol) ??
      expect('exchange', m.exchange ?? null, req.instrument.exchangeMic ?? null) ??
      expect('currency', m.currency, req.instrument.currency) ??
      expect('interval', m.interval, '1day') ??
      expect('adjustment', m.adjustment, req.adjustment);
    if (mismatch) return mismatch;
    if (req.frequency !== 'DAILY') return fail('PROVIDER_MALFORMED', 'adapter supports DAILY only');
    const asOf = parseIsoUtc(m.as_of);
    if (asOf === null) return fail('PROVIDER_MALFORMED', 'provider as_of missing or not ISO UTC');
    if (j.values.length === 0) return fail('INSUFFICIENT_DATA', 'provider returned no bars');
    if (j.values.length > MAX_VENDOR_BARS) return fail('DATASET_TOO_LARGE', 'provider returned too many bars', { max: MAX_VENDOR_BARS });
    const rows: RawBarInput[] = [];
    for (let i = 0; i < j.values.length; i++) {
      const v = j.values[i] as Record<string, unknown>;
      if (typeof v !== 'object' || v === null || typeof v.datetime !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v.datetime)) {
        return fail('PROVIDER_MALFORMED', 'provider bar has an invalid datetime', { row: i });
      }
      const t = Date.parse(`${v.datetime}T00:00:00Z`);
      const open = num(v.open), high = num(v.high), low = num(v.low), close = num(v.close), volume = v.volume === undefined ? undefined : num(v.volume);
      if (!Number.isFinite(t) || open === null || high === null || low === null || close === null || volume === null) {
        return fail('PROVIDER_MALFORMED', 'provider bar has invalid numbers', { row: i });
      }
      rows.push({ t, open, high, low, close, ...(volume !== undefined ? { volume } : {}) });
    }
    const provenance: DataProvenance = {
      providerId: this.id,
      providerKind: this.providerKind,
      trust: this.trust,
      sourceAsOf: new Date(asOf).toISOString(),
      retrievedAt: new Date(retrievedAtMs).toISOString(),
      frequency: 'DAILY',
      currency: req.instrument.currency,
      adjustment: m.adjustment as AdjustmentPolicy,
    };
    // Duplicates / out-of-order / OHLC / sourceAsOf-vs-newest-bar are validated
    // downstream by createPriceSeries — the single authority for data quality.
    return ok({ data: rows, provenance });
  },
};

/** The HistoricalBarsRequest for `instrument` over the last `days` calendar days. */
export function barsRequest(instrument: InstrumentIdentity, nowMs: number, days: number, adjustment: AdjustmentPolicy): HistoricalBarsRequest {
  return { instrument, frequency: 'DAILY', fromT: nowMs - days * 86_400_000, toT: nowMs, adjustment };
}
