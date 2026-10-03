/**
 * Databento EQUS.SUMMARY market-data adapter — IV-QUANT-LICENSED-PROVIDER-PILOT-04
 * (docs/quant/BOOTSTRAP_PROVIDER_DECISION.md, docs/quant/PROVIDER_EVIDENCE_REGISTER.md).
 *
 * MIGRATION NOTE: This adapter was previously pointed at DBEQ.BASIC, which was
 * deprecated by Databento on January 13, 2025 (EV-DB-01). The dataset has been
 * updated to EQUS.SUMMARY, the current replacement product. API endpoint, auth,
 * schema (ohlcv-1d), and encoding are unchanged. See BOOTSTRAP_PROVIDER_DECISION.md.
 *
 * RIGHTS CLASSIFICATION: YELLOW — NOT_VERIFIED (Codex VND-01, 2026-10-03)
 * EV-DB-03 (the source of the "free redistribution rights" claim) is a third-party
 * PRNewswire article, not a Databento contractual document. EV-DB-04 describes
 * EQUS.MINI (live data), not EQUS.SUMMARY historical. Rights for SaaS display,
 * caching, derived analytics, AI processing, and raw retention require written
 * confirmation from Databento before commercial production launch.
 * Action required: Owner sends DATABENTO_RIGHTS_CONFIRMATION_REQUEST.md and
 * receives written reply. Until then, classification is YELLOW/NOT_VERIFIED.
 * Evidence reviewed: EV-DB-02, EV-DB-03, EV-DB-04 (PROVIDER_EVIDENCE_REGISTER.md)
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

// Databento DBN rtype values (per official DBN spec):
//   0x00 ( 0) = MBP-0 / trades (NOT metadata — do not skip on rtype=0)
//   0x20 (32) = ohlcv-1h  (hourly)
//   0x21 (33) = ohlcv-1m  (minute)
//   0x22 (34) = ohlcv-1s  (second)
//   0x23 (35) = ohlcv-1d  (daily) ← this adapter
// CONTRACT GUARD: any other rtype in a response to an ohlcv-1d request is rejected as PROVIDER_MALFORMED.
// Databento metadata lines (DBN header serialized as JSON) have NO 'hd' field — they are skipped
// by the 'typeof r.hd !== object' check, not by rtype value.
const OHLCV_1D_RTYPE = 35;
const MAX_BARS = 50_000;
const DAY_MS = 86_400_000;
const MAX_LINE_BYTES = 128 * 1024; // reject a single NDJSON line larger than 128 KB
// JavaScript Date representable range: ±8,640,000,000,000,000 ms
const MAX_EPOCH_MS = 8_640_000_000_000_000;
// Databento instrument_id is a uint32 per the DBN spec (Codex SEC-04)
const MAX_INSTRUMENT_ID = 0xffffffff;

/**
 * Parse a price value from Databento JSON.
 * With pretty_px=true the API returns decimal strings ("185.790000000").
 * Without pretty_px the API returns nano-integers (185790000000, always integers).
 * This adapter requests pretty_px=true; the string path is primary.
 * Numeric path is only accepted for integer values (nanoint encoding).
 * A non-integer numeric price (e.g. 185.79) is rejected as PROVIDER_MALFORMED
 * to prevent silent 1e-9 scaling of unexpected decimal responses (Codex SEC-03).
 */
function parsePrice(v: unknown): number | null {
  if (typeof v === 'number') {
    // Only accept integers as nanosecond prices; reject non-integer numerics.
    if (!Number.isInteger(v) || !Number.isFinite(v) || v <= 0) return null;
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

    // MIC validation: EQUS.SUMMARY covers all US NMS exchanges and 30 ATSs.
    // No hard allowlist — Databento handles routing by symbol. Unsupported venue
    // returns empty data (INSUFFICIENT_DATA downstream). MIC is passed through
    // for informational purposes only. (Codex VND-02: prior 13-MIC allowlist was
    // not officially documented and rejected valid US instruments.)

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
    // Guard against finite epoch values outside the JavaScript Date representable range
    // which would cause isoMs() → new Date(ms).toISOString() to throw RangeError (Codex SEC-01).
    if (Math.abs(req.fromT) > MAX_EPOCH_MS || Math.abs(req.toT) > MAX_EPOCH_MS) {
      return fail('PROVIDER_UNAVAILABLE', 'databento-equs-summary-v1: time range exceeds JavaScript Date representable limit');
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
    // Validate retrievedAtMs: must be finite and within JS Date range (Codex SEC-01).
    if (!Number.isFinite(retrievedAtMs) || Math.abs(retrievedAtMs) > MAX_EPOCH_MS) {
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
      if (new TextEncoder().encode(lines[i]).length > MAX_LINE_BYTES) {
        return fail('PROVIDER_MALFORMED', 'databento NDJSON line exceeds maximum line length (bytes)', { row: i });
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

      // Databento JSON encoding: DBN header fields (rtype, instrument_id, ts_event,
      // publisher_id) are nested under 'hd'. Records without 'hd' are metadata lines
      // (DBN header blocks) that do not represent OHLCV bars — skip them silently.
      // Codex P0/P1: the previous adapter incorrectly read these fields at top-level,
      // causing every real Databento response to be rejected as INSUFFICIENT_DATA.
      if (typeof r.hd !== 'object' || r.hd === null) continue;
      const hd = r.hd as Record<string, unknown>;

      if (hd.rtype !== OHLCV_1D_RTYPE) {
        // Unexpected record type — reject rather than silently skip unknown data.
        // Note: rtype=0 is MBP-0 (trades), not metadata — rejected here if it arrives.
        return fail('PROVIDER_MALFORMED', 'databento response contains unexpected record type', {
          row: i, rtype: typeof hd.rtype === 'number' ? hd.rtype : -1,
        });
      }

      // instrument_id is in hd; Databento uint32 (DBN spec) — safe positive integer
      // within [1, 0xffffffff] with no fractional component (Codex SEC-04).
      // Instrument-ID consistency: all bars must share the same instrument_id to
      // prevent response poisoning (mixed instruments for a single-symbol request).
      if (
        typeof hd.instrument_id !== 'number' ||
        !Number.isSafeInteger(hd.instrument_id) ||
        hd.instrument_id <= 0 ||
        hd.instrument_id > MAX_INSTRUMENT_ID
      ) {
        return fail('PROVIDER_MALFORMED', 'databento bar has invalid instrument_id', { row: i });
      }
      if (firstInstrumentId === null) {
        firstInstrumentId = hd.instrument_id as number;
      } else if (hd.instrument_id !== firstInstrumentId) {
        return fail(
          'PROVIDER_MALFORMED',
          'databento response contains multiple instrument IDs for a single-symbol request',
          { row: i, first: firstInstrumentId, got: hd.instrument_id },
        );
      }

      // ts_event is in hd; with pretty_ts=true returns ISO 8601 string.
      // For ohlcv-1d, ts_event is the start of the session (00:00:00 UTC for the date).
      if (typeof hd.ts_event !== 'string') {
        return fail('PROVIDER_MALFORMED', 'databento bar missing ts_event', { row: i });
      }
      const t = Date.parse(hd.ts_event);
      if (!Number.isFinite(t)) {
        return fail('PROVIDER_MALFORMED', 'databento bar ts_event is not a parseable date', { row: i });
      }

      // Window bounds validation (Codex Gate 2 precedent from mission 03).
      // EQUS.SUMMARY ohlcv-1d bars are stamped at UTC midnight (session open 00:00:00Z).
      // Require midnight alignment to reject non-session timestamps (Codex SEC-02).
      if (t % DAY_MS !== 0) {
        return fail('PROVIDER_MALFORMED', 'databento ohlcv-1d bar ts_event is not UTC midnight (00:00:00Z)', { row: i });
      }
      // Use calendar-date comparison rather than unrestricted millisecond grace (Codex SEC-02).
      // Bar's UTC date must fall within [floor(fromT/DAY), floor(toT/DAY)].
      const barDay = Math.floor(t / DAY_MS);
      const fromDay = Math.floor(req.fromT / DAY_MS);
      const toDay = Math.floor(req.toT / DAY_MS);
      if (barDay < fromDay || barDay > toDay) {
        return fail('PROVIDER_MALFORMED', 'databento bar date outside the requested time window', { row: i });
      }

      const open = parsePrice(r.open);
      const high = parsePrice(r.high);
      const low = parsePrice(r.low);
      const close = parsePrice(r.close);
      if (open === null || high === null || low === null || close === null) {
        return fail('PROVIDER_MALFORMED', 'databento bar has invalid or non-positive prices', { row: i });
      }

      // Volume: DBN type is uint64_t; Databento JSON encoding returns it as a string.
      // Accept both string (canonical) and number (numeric fallback for non-pretty_px).
      // Values exceeding Number.MAX_SAFE_INTEGER (2^53-1) lose precision — stripped.
      // Infinity (e.g. 1e309 overflowed in JSON) is rejected (Codex SEC-05, P2).
      let vol: number | undefined = undefined;
      if (typeof r.volume === 'string') {
        const vn = Number(r.volume);
        if (Number.isFinite(vn) && vn >= 0 && vn <= Number.MAX_SAFE_INTEGER) vol = vn;
      } else if (typeof r.volume === 'number' && r.volume >= 0 && Number.isFinite(r.volume) && r.volume <= Number.MAX_SAFE_INTEGER) {
        vol = r.volume;
      }
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
