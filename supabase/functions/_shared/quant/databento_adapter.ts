/**
 * Databento EQUS.SUMMARY market-data adapter — IV-QUANT-LICENSED-PROVIDER-PILOT-04
 * (docs/quant/BOOTSTRAP_PROVIDER_DECISION.md, docs/quant/PROVIDER_EVIDENCE_REGISTER.md).
 *
 * MIGRATION NOTE: This adapter was previously pointed at DBEQ.BASIC, which was
 * deprecated by Databento on January 13, 2025 (EV-DB-01). The dataset has been
 * updated to EQUS.SUMMARY, the current replacement product. API endpoint, auth,
 * schema (ohlcv-1d), and encoding are unchanged. See BOOTSTRAP_PROVIDER_DECISION.md.
 *
 * RIGHTS CLASSIFICATION: GREEN
 * Databento US Equities Summary (EQUS.SUMMARY) carries zero exchange license fees
 * and explicitly permits redistribution, display, and non-display commercial
 * applications. Databento markets EQUS.SUMMARY as "the only provider with zero
 * license fees AND free redistribution rights."
 * Evidence: EV-DB-02, EV-DB-03, EV-DB-04 (PROVIDER_EVIDENCE_REGISTER.md)
 *
 * CREDENTIALS:
 * Secret name : DATABENTO_API_KEY
 * Header      : Authorization (constructed server-side via secretTransform)
 * Value stored: the raw Databento API key (db-xxxxxxxx…), nothing else
 * Never store : base64, "Basic …", or any derived value — the adapter
 *               constructs the Authorization header server-side via btoa().
 * Never        : put the key in the URL, expose to Flutter, or log it.
 *
 * DATASET: EQUS.SUMMARY (replaces deprecated DBEQ.BASIC)
 * Coverage    : All 15 US NMS exchanges + 30 ATSs — consolidated EOD OHLCV
 * Adjustment  : UNADJUSTED (raw trade aggregates; no corporate action adjustment)
 * Frequency   : DAILY only in this adapter version
 * History     : Full history available via pay-as-you-go (billed per byte)
 * Pricing     : ~$0/month PAYG historical; $199/month subscription for live data
 *
 * IDENTITY LIMITATION (documented, not a defect):
 * Databento OHLCV-1d bar records do not echo back the requested symbol.
 * The adapter validates instrument_id consistency across bars (all bars must
 * share one instrument_id, preventing mixed responses) and that all bars
 * are within the requested time window. Symbol-level identity is trusted
 * from the request, not confirmed from response fields. A PROVENANCE_WEAK
 * warning is NOT raised here — the adapter trusts the Databento API routing
 * (server-side, credentialed call to a specific symbol). This is documented
 * as a known limitation vs. the full identity-echo requirement.
 *
 * The deterministic engine (createPriceSeries) is never bypassed: raw bars
 * are returned as RawBarInput[] and the engine applies its own validation.
 */
import { fail, ok, type QuantResult } from './errors.ts';
import type { AdjustmentPolicy, DataProvenance } from './provenance.ts';
import type { HistoricalBarsRequest, ProviderResponse } from './provider.ts';
import type { AdapterHttpRequest, AdapterSpec } from './provider_adapter.ts';
import { normalizeVendorStatus } from './provider_adapter.ts';
import type { RawBarInput } from './timeseries.ts';

const OHLCV_1D_RTYPE = 32;
const METADATA_RTYPE = 0; // rtype=0 is the DBN metadata record, skip it
const MAX_BARS = 50_000;
const DAY_MS = 86_400_000;
const MAX_LINE_BYTES = 128 * 1024; // reject a single NDJSON line larger than 128 KB

// EQUS.SUMMARY covers all 15 NMS exchanges + 30 ATSs. This includes the major venues;
// add others as needed (all standard US NMS MICs are supported by the dataset).
const SUPPORTED_MICS = new Set([
  'XNYS', // NYSE
  'XNAS', // Nasdaq Global Select / Nasdaq
  'ARCX', // NYSE Arca
  'XASE', // NYSE American (AMEX)
  'XCHI', // NYSE Chicago
  'BATS', // CBOE BZX (formerly BATS)
  'EDGX', // CBOE EDGX
  'BATY', // CBOE BYX
  'EDGA', // CBOE EDGA
  'XBOS', // Nasdaq BX
  'XPHL', // Nasdaq PSX
  'IEXG', // IEX Exchange
  'MEMX', // Members Exchange (MEMX)
]);

/**
 * Parse a price value from Databento JSON.
 * With pretty_px=true the API returns decimal strings ("185.790000000").
 * Without pretty_px the API returns nano-integers (185790000000).
 * This adapter requests pretty_px=true; the string path is primary.
 */
function parsePrice(v: unknown): number | null {
  if (typeof v === 'number') {
    // nano-int path (fallback if pretty_px is ignored)
    if (!Number.isFinite(v) || v <= 0) return null;
    return v / 1e9;
  }
  if (typeof v === 'string') {
    const n = Number(v);
    return Number.isFinite(n) && n > 0 ? n : null;
  }
  return null;
}

export const databentoAdapter: AdapterSpec = {
  id: 'databento-equs-summary-v1',
  providerKind: 'EXTERNAL_PROVIDER',
  trust: 'PROVIDER_REPORTED',
  allowedHosts: ['hist.databento.com'],
  secretEnvName: 'DATABENTO_API_KEY',
  secretHeader: 'Authorization',
  // Databento uses HTTP Basic auth: username = apiKey, password = empty string.
  // The raw key (db-xxx) is stored; the Authorization header is constructed here.
  secretTransform: (apiKey: string) => 'Basic ' + btoa(apiKey + ':'),
  maxResponseBytes: 16 * 1024 * 1024, // 16 MB — generous for multi-year daily history
  timeoutMs: 30_000, // historical streaming can be slow for large date ranges

  buildRequest(req: HistoricalBarsRequest, baseUrl: string): QuantResult<AdapterHttpRequest> {
    if (req.frequency !== 'DAILY') {
      return fail('PROVIDER_UNAVAILABLE', 'databento-equs-summary-v1 supports DAILY frequency only');
    }
    // Only UNADJUSTED supported; EQUS.SUMMARY provides raw trade aggregates.
    if (req.adjustment !== 'UNADJUSTED' && req.adjustment !== 'UNKNOWN') {
      return fail(
        'PROVIDER_UNAVAILABLE',
        'databento-equs-summary-v1 provides UNADJUSTED prices; SPLIT_ADJUSTED / SPLIT_AND_DIVIDEND_ADJUSTED not available in this adapter version',
        { requested: req.adjustment },
      );
    }

    const mic = req.instrument.exchangeMic?.toUpperCase();
    if (mic && !SUPPORTED_MICS.has(mic)) {
      return fail('PROVIDER_UNAVAILABLE', `exchange ${mic} not in EQUS.SUMMARY coverage`, { mic });
    }

    let baseU: URL;
    try {
      baseU = new URL(baseUrl);
    } catch {
      return fail('PROVIDER_UNAVAILABLE', 'invalid provider base URL');
    }
    if (baseU.protocol !== 'https:') {
      return fail('PROVIDER_UNAVAILABLE', 'provider base URL must use https');
    }
    if (baseU.username || baseU.password) {
      return fail('PROVIDER_UNAVAILABLE', 'provider base URL must not contain embedded credentials');
    }
    if (!Number.isFinite(req.fromT) || !Number.isFinite(req.toT) || req.fromT > req.toT) {
      return fail('PROVIDER_UNAVAILABLE', 'databento-equs-summary-v1: invalid or inconsistent time range');
    }

    const u = new URL('/v0/timeseries.get_range', baseUrl);
    u.searchParams.set('dataset', 'EQUS.SUMMARY');
    u.searchParams.set('schema', 'ohlcv-1d');
    u.searchParams.set('symbols', req.instrument.symbol);
    // Databento uses nanosecond-precision ISO timestamps; we provide millisecond UTC.
    u.searchParams.set('start', isoMs(req.fromT));
    u.searchParams.set('end', isoMs(req.toT));
    u.searchParams.set('encoding', 'json');
    u.searchParams.set('pretty_px', 'true');
    u.searchParams.set('pretty_ts', 'true');

    return ok({
      url: u.toString(),
      headers: { Accept: 'application/json' },
    });
  },

  parseResponse(
    req: HistoricalBarsRequest,
    status: number,
    headers: Headers,
    body: string,
    retrievedAtMs: number,
  ): QuantResult<ProviderResponse<RawBarInput[]>> {
    if (!Number.isFinite(retrievedAtMs)) {
      return fail('PROVIDER_MALFORMED', 'databento-equs-summary-v1: invalid retrieval timestamp');
    }

    const transport = normalizeVendorStatus(status, headers);
    if (!transport.ok) return transport;

    // Databento returns NDJSON: one JSON object per line.
    const lines = body.split('\n').filter((l) => l.trim().length > 0);
    if (lines.length === 0) {
      return fail('INSUFFICIENT_DATA', 'databento returned empty body');
    }

    const rows: RawBarInput[] = [];
    let firstInstrumentId: number | null = null;
    let latestEventMs = 0;

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].length > MAX_LINE_BYTES) {
        return fail('PROVIDER_MALFORMED', 'databento NDJSON line exceeds maximum line length', { row: i });
      }
      let rec: unknown;
      try {
        rec = JSON.parse(lines[i]);
      } catch {
        return fail('PROVIDER_MALFORMED', 'databento NDJSON line is not valid JSON', { row: i });
      }
      if (typeof rec !== 'object' || rec === null) {
        return fail('PROVIDER_MALFORMED', 'databento NDJSON line is not an object', { row: i });
      }
      const r = rec as Record<string, unknown>;

      // Skip DBN metadata records (rtype=0) — these appear first in some responses.
      if (r.rtype === METADATA_RTYPE || r.rtype === undefined) continue;

      if (r.rtype !== OHLCV_1D_RTYPE) {
        // Unexpected record type — reject rather than silently skip unknown data.
        return fail('PROVIDER_MALFORMED', 'databento response contains unexpected record type', {
          row: i, rtype: typeof r.rtype === 'number' ? r.rtype : -1,
        });
      }

      // Instrument-ID consistency check: all bars in a single-symbol request
      // must share the same instrument_id. Multiple IDs would indicate the
      // provider responded for more than one instrument (response poisoning defence).
      // instrument_id must be a positive finite integer (> 0, no floats, no NaN).
      if (
        typeof r.instrument_id !== 'number' ||
        !Number.isFinite(r.instrument_id) ||
        r.instrument_id <= 0 ||
        !Number.isInteger(r.instrument_id)
      ) {
        return fail('PROVIDER_MALFORMED', 'databento bar has invalid instrument_id', { row: i });
      }
      if (firstInstrumentId === null) {
        firstInstrumentId = r.instrument_id;
      } else if (r.instrument_id !== firstInstrumentId) {
        return fail(
          'PROVIDER_MALFORMED',
          'databento response contains multiple instrument IDs for a single-symbol request',
          { row: i, first: firstInstrumentId, got: r.instrument_id },
        );
      }

      // Timestamp: pretty_ts=true yields ISO 8601 strings.
      // For ohlcv-1d, ts_event is the start of the session (00:00:00 UTC for the date).
      if (typeof r.ts_event !== 'string') {
        return fail('PROVIDER_MALFORMED', 'databento bar missing ts_event', { row: i });
      }
      const t = Date.parse(r.ts_event);
      if (!Number.isFinite(t)) {
        return fail('PROVIDER_MALFORMED', 'databento bar ts_event is not a parseable date', { row: i });
      }

      // Window bounds validation (Codex Gate 2 precedent from mission 03).
      // One DAY_MS grace on fromT because daily bars are stamped at 00:00 UTC.
      if (t > req.toT || t < req.fromT - DAY_MS) {
        return fail('PROVIDER_MALFORMED', 'databento bar outside the requested time window', { row: i });
      }

      const open = parsePrice(r.open);
      const high = parsePrice(r.high);
      const low = parsePrice(r.low);
      const close = parsePrice(r.close);
      if (open === null || high === null || low === null || close === null) {
        return fail('PROVIDER_MALFORMED', 'databento bar has invalid or non-positive prices', { row: i });
      }

      const vol = typeof r.volume === 'number' && r.volume >= 0 ? r.volume : undefined;
      rows.push({ t, open, high, low, close, ...(vol !== undefined ? { volume: vol } : {}) });
      if (t > latestEventMs) latestEventMs = t;
    }

    if (rows.length > MAX_BARS) {
      return fail('DATASET_TOO_LARGE', 'databento response exceeds maximum bar count', { max: MAX_BARS });
    }
    if (rows.length === 0) {
      return fail('INSUFFICIENT_DATA', 'databento response contained no OHLCV-1d bars');
    }

    // sourceAsOf sanity: the most recent bar's session time must not be after
    // the moment we received the response (look-ahead contamination guard).
    if (latestEventMs > retrievedAtMs) {
      return fail('PROVIDER_MALFORMED', 'databento bar ts_event is after retrieval time (look-ahead contamination)');
    }

    // Adjustment policy: EQUS.SUMMARY provides raw trade aggregates (unadjusted).
    // If the caller requested UNKNOWN we report UNADJUSTED as delivered.
    const reportedAdjustment: AdjustmentPolicy = 'UNADJUSTED';

    const provenance: DataProvenance = {
      providerId: this.id,
      providerKind: 'EXTERNAL_PROVIDER',
      trust: 'PROVIDER_REPORTED',
      sourceAsOf: new Date(latestEventMs).toISOString(),
      retrievedAt: new Date(retrievedAtMs).toISOString(),
      frequency: 'DAILY',
      currency: req.instrument.currency,
      adjustment: reportedAdjustment,
      sourceLabel: 'Databento EQUS.SUMMARY ohlcv-1d',
    };

    return ok({ data: rows, provenance });
  },
};

/** Format epoch ms as an ISO UTC string suitable for Databento API params. */
function isoMs(ms: number): string {
  return new Date(ms).toISOString();
}
