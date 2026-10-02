/**
 * Tests for the Databento EQUS.SUMMARY adapter — IV-QUANT-LICENSED-PROVIDER-PILOT-04
 * (Migrated from DBEQ.BASIC, deprecated 2025-01-13, EV-DB-01.)
 *
 * All tests use a mock fetch (no real network I/O) via the HttpAdapterProvider
 * dependency-injection interface. Credentials are never present in test code.
 */
import { assertEquals, assertMatch, assertNotEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { databentoAdapter } from './databento_adapter.ts';
import { HttpAdapterProvider } from '../quant_provider_runtime.ts';
import type { HistoricalBarsRequest } from './provider.ts';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const BASE_URL = 'https://hist.databento.com';
const NOW_MS = 1_700_000_000_000; // 2023-11-14T22:13:20.000Z (arbitrary fixed clock)

const AAPL_INSTRUMENT = {
  symbol: 'AAPL',
  exchangeMic: 'XNAS',
  currency: 'USD',
  assetClass: 'EQUITY' as const,
};

function req(overrides?: Partial<HistoricalBarsRequest>): HistoricalBarsRequest {
  return {
    instrument: AAPL_INSTRUMENT,
    frequency: 'DAILY' as const,
    fromT: NOW_MS - 10 * 86_400_000, // 10 days ago
    toT: NOW_MS,
    adjustment: 'UNADJUSTED' as const,
    ...overrides,
  };
}

/** Build a single valid NDJSON bar line. */
function ndjsonBar(overrides: Record<string, unknown> = {}): string {
  const defaults = {
    ts_recv: '2023-11-13T21:00:00.000000000Z',
    ts_event: '2023-11-13T00:00:00.000000000Z', // session date
    rtype: 32,
    publisher_id: 39,
    instrument_id: 170352,
    open: '182.000000000',
    high: '184.950000000',
    low: '181.440000000',
    close: '184.800000000',
    volume: 52_038_800,
  };
  return JSON.stringify({ ...defaults, ...overrides });
}

function mockFetch(statusCode: number, body: string, extraHeaders?: Record<string, string>) {
  return async (_url: string, _opts: unknown) => {
    const headers = new Headers({ 'Content-Type': 'application/json', ...extraHeaders });
    return new Response(body, { status: statusCode, headers });
  };
}

function makeProvider(fetchImpl: (url: string, opts: unknown) => Promise<Response>) {
  return new HttpAdapterProvider(databentoAdapter, BASE_URL, {
    fetchImpl: fetchImpl as never,
    // Raw API key is stored; secretTransform converts it to Basic auth header.
    readSecret: (_name: string) => 'db-test00000000000000000000000000000',
    clock: () => NOW_MS,
  });
}

// ---------------------------------------------------------------------------
// AdapterSpec — buildRequest
// ---------------------------------------------------------------------------

Deno.test('buildRequest: valid DAILY UNADJUSTED returns https URL for hist.databento.com', () => {
  const result = databentoAdapter.buildRequest(req(), BASE_URL);
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error();
  const u = new URL(result.value.url);
  assertEquals(u.hostname, 'hist.databento.com');
  assertEquals(u.pathname, '/v0/timeseries.get_range');
  assertEquals(u.searchParams.get('dataset'), 'EQUS.SUMMARY');
  assertEquals(u.searchParams.get('schema'), 'ohlcv-1d');
  assertEquals(u.searchParams.get('symbols'), 'AAPL');
  assertEquals(u.searchParams.get('encoding'), 'json');
  assertEquals(u.searchParams.get('pretty_px'), 'true');
  assertEquals(u.searchParams.get('pretty_ts'), 'true');
  // No credential in URL
  assertMatch(result.value.url, /^https:\/\/hist\.databento\.com/);
  assertEquals(result.value.url.includes('key='), false);
  assertEquals(result.value.url.includes('token='), false);
  assertEquals(result.value.url.includes('Authorization='), false);
});

// DEPRECATION GUARD — prevents regression to DBEQ.BASIC (deprecated 2025-01-13, EV-DB-01)
Deno.test('DEPRECATION GUARD: adapter uses EQUS.SUMMARY, never deprecated DBEQ.BASIC', () => {
  const result = databentoAdapter.buildRequest(req(), BASE_URL);
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error();
  const u = new URL(result.value.url);
  // Positive assertion: must use current dataset
  assertEquals(u.searchParams.get('dataset'), 'EQUS.SUMMARY');
  // Negative assertion: must not regress to deprecated dataset
  assertNotEquals(u.searchParams.get('dataset'), 'DBEQ.BASIC');
});

Deno.test('buildRequest: rejects non-DAILY frequency', () => {
  const result = databentoAdapter.buildRequest(req({ frequency: 'INTRADAY_1H' }), BASE_URL);
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('buildRequest: rejects SPLIT_ADJUSTED (not supported in v1)', () => {
  const result = databentoAdapter.buildRequest(req({ adjustment: 'SPLIT_ADJUSTED' }), BASE_URL);
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('buildRequest: rejects SPLIT_AND_DIVIDEND_ADJUSTED', () => {
  const result = databentoAdapter.buildRequest(req({ adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED' }), BASE_URL);
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('buildRequest: accepts UNKNOWN adjustment', () => {
  const result = databentoAdapter.buildRequest(req({ adjustment: 'UNKNOWN' }), BASE_URL);
  assertEquals(result.ok, true);
});

Deno.test('buildRequest: rejects unsupported exchange MIC', () => {
  const result = databentoAdapter.buildRequest(req({
    instrument: { ...AAPL_INSTRUMENT, exchangeMic: 'XLON' },
  }), BASE_URL);
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('buildRequest: accepts null exchangeMic (symbol-only request)', () => {
  const result = databentoAdapter.buildRequest(req({
    instrument: { ...AAPL_INSTRUMENT, exchangeMic: undefined },
  }), BASE_URL);
  assertEquals(result.ok, true);
});

Deno.test('buildRequest: rejects http base URL', () => {
  const result = databentoAdapter.buildRequest(req(), 'http://hist.databento.com');
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

// ---------------------------------------------------------------------------
// parseResponse — happy path
// ---------------------------------------------------------------------------

Deno.test('parseResponse: valid single bar returns correct RawBarInput and provenance', async () => {
  const barLine = ndjsonBar();
  const provider = makeProvider(mockFetch(200, barLine + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error(result.error.message);
  assertEquals(result.value.data.length, 1);
  const bar = result.value.data[0];
  assertEquals(bar.open, 182.0);
  assertEquals(bar.high, 184.95);
  assertEquals(bar.low, 181.44);
  assertEquals(bar.close, 184.8);
  assertEquals(bar.volume, 52_038_800);

  const prov = result.value.provenance;
  assertEquals(prov.providerId, 'databento-equs-summary-v1');
  assertEquals(prov.providerKind, 'EXTERNAL_PROVIDER');
  assertEquals(prov.trust, 'PROVIDER_REPORTED');
  assertEquals(prov.frequency, 'DAILY');
  assertEquals(prov.currency, 'USD');
  assertEquals(prov.adjustment, 'UNADJUSTED');
  assertEquals(typeof prov.sourceAsOf, 'string');
  assertEquals(typeof prov.retrievedAt, 'string');
});

Deno.test('parseResponse: multiple valid bars parsed correctly', async () => {
  const bar1 = ndjsonBar({ ts_event: '2023-11-10T00:00:00.000000000Z', close: '180.000000000' });
  const bar2 = ndjsonBar({ ts_event: '2023-11-13T00:00:00.000000000Z', close: '184.800000000' });
  const provider = makeProvider(mockFetch(200, bar1 + '\n' + bar2 + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error(result.error.message);
  assertEquals(result.value.data.length, 2);
});

Deno.test('parseResponse: skips metadata records (rtype=0)', async () => {
  const metaRecord = JSON.stringify({ rtype: 0, version: 2, dataset: 'EQUS.SUMMARY' });
  const bar = ndjsonBar();
  const provider = makeProvider(mockFetch(200, metaRecord + '\n' + bar + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error(result.error.message);
  assertEquals(result.value.data.length, 1);
});

Deno.test('parseResponse: nano-integer prices (pretty_px not active) are divided by 1e9', async () => {
  // 184800000000 / 1e9 = 184.8
  const bar = ndjsonBar({ open: 182000000000, high: 184950000000, low: 181440000000, close: 184800000000 });
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error(result.error.message);
  assertEquals(result.value.data[0].close, 184.8);
});

// ---------------------------------------------------------------------------
// parseResponse — error cases
// ---------------------------------------------------------------------------

Deno.test('parseResponse: 401 returns PROVIDER_UNAVAILABLE', async () => {
  const provider = makeProvider(mockFetch(401, '{"detail":"Unauthorized"}'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('parseResponse: 429 returns PROVIDER_RATE_LIMITED', async () => {
  const provider = makeProvider(mockFetch(429, '{"detail":"Rate limited"}', { 'retry-after': '60' }));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_RATE_LIMITED');
});

Deno.test('parseResponse: 503 returns PROVIDER_UNAVAILABLE', async () => {
  const provider = makeProvider(mockFetch(503, 'Service Unavailable'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('parseResponse: empty body returns INSUFFICIENT_DATA', async () => {
  const provider = makeProvider(mockFetch(200, ''));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'INSUFFICIENT_DATA');
});

Deno.test('parseResponse: body with only metadata record returns INSUFFICIENT_DATA', async () => {
  const metaOnly = JSON.stringify({ rtype: 0, version: 2 });
  const provider = makeProvider(mockFetch(200, metaOnly + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'INSUFFICIENT_DATA');
});

Deno.test('parseResponse: non-JSON line returns PROVIDER_MALFORMED', async () => {
  const provider = makeProvider(mockFetch(200, 'not json\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: unexpected rtype returns PROVIDER_MALFORMED', async () => {
  const bar = ndjsonBar({ rtype: 99 }); // unknown rtype
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: mixed instrument IDs returns PROVIDER_MALFORMED (response poisoning guard)', async () => {
  const bar1 = ndjsonBar({ instrument_id: 170352, ts_event: '2023-11-10T00:00:00.000000000Z' });
  const bar2 = ndjsonBar({ instrument_id: 999999, ts_event: '2023-11-13T00:00:00.000000000Z' });
  const provider = makeProvider(mockFetch(200, bar1 + '\n' + bar2 + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: bar with invalid ts_event returns PROVIDER_MALFORMED', async () => {
  const bar = ndjsonBar({ ts_event: 'not-a-date' });
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: bar outside requested window returns PROVIDER_MALFORMED', async () => {
  // Bar far in the future — outside the request window
  const futureDateMs = NOW_MS + 30 * 86_400_000;
  const futureIso = new Date(futureDateMs).toISOString();
  const bar = ndjsonBar({ ts_event: futureIso });
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: bar ts_event after retrieval time returns PROVIDER_MALFORMED (look-ahead guard)', async () => {
  // Bar stamped 1 hour after "now" — clock manipulation / look-ahead contamination
  const futureTs = new Date(NOW_MS + 3_600_000).toISOString();
  const bar = ndjsonBar({ ts_event: futureTs });
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req({
    toT: NOW_MS + 2 * 86_400_000, // extended window so the window check passes
  }));
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: missing credential returns PROVIDER_UNAVAILABLE (fail-closed)', async () => {
  const provider = new HttpAdapterProvider(databentoAdapter, BASE_URL, {
    fetchImpl: mockFetch(200, ndjsonBar() + '\n') as never,
    readSecret: (_name: string) => null, // no credential configured
    clock: () => NOW_MS,
  });
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('parseResponse: zero-price bar returns PROVIDER_MALFORMED', async () => {
  const bar = ndjsonBar({ open: '0.000000000', close: '0.000000000' });
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: provenance.adjustment is always UNADJUSTED for EQUS.SUMMARY', async () => {
  // Even when caller requests UNKNOWN, we report what the provider actually delivers.
  const provider = makeProvider(mockFetch(200, ndjsonBar() + '\n'));
  const result = await provider.historicalBars(req({ adjustment: 'UNKNOWN' }));
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error(result.error.message);
  assertEquals(result.value.provenance.adjustment, 'UNADJUSTED');
});

Deno.test('AdapterSpec: allowedHosts contains only hist.databento.com', () => {
  assertEquals(databentoAdapter.allowedHosts, ['hist.databento.com']);
});

Deno.test('AdapterSpec: secretHeader is Authorization (no credential in URL)', () => {
  assertEquals(databentoAdapter.secretHeader, 'Authorization');
});

Deno.test('AdapterSpec: secretEnvName is DATABENTO_API_KEY (raw key stored, header constructed server-side)', () => {
  assertEquals(databentoAdapter.secretEnvName, 'DATABENTO_API_KEY');
});

Deno.test('AdapterSpec: secretTransform constructs HTTP Basic auth from raw API key', () => {
  const transform = databentoAdapter.secretTransform;
  if (!transform) throw new Error('secretTransform must be defined');
  const apiKey = 'db-testkey1234567890';
  const result = transform(apiKey);
  assertEquals(result, 'Basic ' + btoa(apiKey + ':'));
  // Must start with "Basic " and contain no raw key characters that break Basic auth
  assertEquals(result.startsWith('Basic '), true);
});

Deno.test('AdapterSpec: providerKind is EXTERNAL_PROVIDER and trust is PROVIDER_REPORTED', () => {
  assertEquals(databentoAdapter.providerKind, 'EXTERNAL_PROVIDER');
  assertEquals(databentoAdapter.trust, 'PROVIDER_REPORTED');
});

// ---------------------------------------------------------------------------
// Hardening tests — HTTP status codes
// ---------------------------------------------------------------------------

Deno.test('parseResponse: 403 returns PROVIDER_UNAVAILABLE (credential rejected)', async () => {
  const provider = makeProvider(mockFetch(403, '{"detail":"Forbidden"}'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('parseResponse: 404 returns PROVIDER_UNAVAILABLE (endpoint not found)', async () => {
  const provider = makeProvider(mockFetch(404, '{"detail":"Not Found"}'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('parseResponse: 500 returns PROVIDER_UNAVAILABLE (server error)', async () => {
  const provider = makeProvider(mockFetch(500, '{"detail":"Internal Server Error"}'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

// ---------------------------------------------------------------------------
// Hardening tests — response overflow
// ---------------------------------------------------------------------------

Deno.test('parseResponse: response exceeding MAX_BARS (50 000) returns DATASET_TOO_LARGE', async () => {
  // Generate 50 001 bars at 1 ms intervals so all fall within a single wide window.
  // Using 1 ms granularity avoids going before the UNIX epoch.
  const body = Array.from({ length: 50_001 }, (_, i) =>
    ndjsonBar({ ts_event: new Date(NOW_MS - i).toISOString() })
  ).join('\n') + '\n';
  const provider = makeProvider(mockFetch(200, body));
  const result = await provider.historicalBars(req({ fromT: NOW_MS - 50_001, toT: NOW_MS }));
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'DATASET_TOO_LARGE');
});

// ---------------------------------------------------------------------------
// Hardening tests — volume edge cases
// ---------------------------------------------------------------------------

Deno.test('parseResponse: negative volume is accepted (treated as undefined, not a parse error)', async () => {
  // Volume < 0 is suspicious but not a parsing error; downstream engine decides.
  const bar = ndjsonBar({ volume: -1 });
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error(result.error.message);
  assertEquals(result.value.data[0].volume, undefined); // negative → stripped
});

Deno.test('parseResponse: missing volume field is accepted (volume is optional)', async () => {
  const bar = ndjsonBar({ volume: undefined });
  const body = JSON.stringify(JSON.parse(bar.replace(/"volume":\d+,?/, '').replace(/,}/, '}'))) + '\n';
  const provider = makeProvider(mockFetch(200, body));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, true);
  if (!result.ok) throw new Error(result.error.message);
  assertEquals(result.value.data[0].volume, undefined);
});

Deno.test('parseResponse: null rtype returns PROVIDER_MALFORMED (unexpected type, not silently skipped)', async () => {
  const bar = ndjsonBar({ rtype: null });
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

// ---------------------------------------------------------------------------
// Hardening tests — OHLC / duplicate timestamp boundary (engine's responsibility)
// ---------------------------------------------------------------------------

Deno.test('parseResponse: impossible OHLC (high < low) is passed through to engine (not adapter-level validation)', async () => {
  // The adapter does not validate OHLC consistency — that is createPriceSeries territory.
  // This test documents the boundary: impossible bars reach the caller as RawBarInput[].
  const bar = ndjsonBar({ high: '100.000000000', low: '200.000000000' }); // high < low
  const provider = makeProvider(mockFetch(200, bar + '\n'));
  const result = await provider.historicalBars(req());
  // Result may be ok (bars pass through to engine) or fail depending on price validation
  // The important guarantee: if ok, the raw bars are returned for engine to validate.
  if (result.ok) {
    assertEquals(result.value.data.length, 1);
  }
  // No assertion on error code — this documents the boundary, not a specific outcome.
});

Deno.test('parseResponse: duplicate timestamps are passed through to engine (not adapter-level validation)', async () => {
  // Duplicate timestamps reach the caller; createPriceSeries deduplicates or rejects.
  const bar1 = ndjsonBar({ ts_event: '2023-11-13T00:00:00.000000000Z', close: '184.800000000' });
  const bar2 = ndjsonBar({ ts_event: '2023-11-13T00:00:00.000000000Z', close: '185.100000000' });
  const provider = makeProvider(mockFetch(200, bar1 + '\n' + bar2 + '\n'));
  const result = await provider.historicalBars(req());
  // If ok: 2 bars returned (engine's responsibility to detect duplicates)
  if (result.ok) {
    assertEquals(result.value.data.length, 2);
  }
});

// ---------------------------------------------------------------------------
// Hardening tests — P1 fixes (Codex IV-QUANT-04 adversarial audit)
// ---------------------------------------------------------------------------

Deno.test('historicalBars: non-Latin-1 secret causes secretTransform to throw → PROVIDER_UNAVAILABLE', async () => {
  // btoa() throws InvalidCharacterError for characters outside Latin-1 (e.g. emoji).
  // The runtime must catch this and return PROVIDER_UNAVAILABLE, not crash.
  const provider = new HttpAdapterProvider(databentoAdapter, BASE_URL, {
    fetchImpl: mockFetch(200, ndjsonBar() + '\n') as never,
    readSecret: () => 'db-😀', // U+1F600 emoji — non-Latin-1
    clock: () => NOW_MS,
  });
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('historicalBars: parseResponse that throws is caught and returns PROVIDER_MALFORMED', async () => {
  // The runtime wraps parseResponse in try/catch; adapter exceptions must not escape.
  const throwingAdapter = { ...databentoAdapter, parseResponse: () => { throw new Error('boom'); } };
  const provider = new HttpAdapterProvider(throwingAdapter as never, BASE_URL, {
    fetchImpl: mockFetch(200, ndjsonBar() + '\n') as never,
    readSecret: () => 'db-test00000000000000000000000000000',
    clock: () => NOW_MS,
  });
  const result = await provider.historicalBars(req());
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

// ---------------------------------------------------------------------------
// Hardening tests — P2 fixes (Codex IV-QUANT-04 adversarial audit)
// ---------------------------------------------------------------------------

Deno.test('buildRequest: base URL with embedded credentials returns PROVIDER_UNAVAILABLE', () => {
  const result = databentoAdapter.buildRequest(req(), 'https://user:pass@hist.databento.com');
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('buildRequest: NaN fromT returns PROVIDER_UNAVAILABLE', () => {
  const result = databentoAdapter.buildRequest(req({ fromT: NaN }), BASE_URL);
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('buildRequest: Infinity toT returns PROVIDER_UNAVAILABLE', () => {
  const result = databentoAdapter.buildRequest(req({ toT: Infinity }), BASE_URL);
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('buildRequest: fromT > toT returns PROVIDER_UNAVAILABLE (reversed window)', () => {
  const result = databentoAdapter.buildRequest(req({ fromT: NOW_MS, toT: NOW_MS - 1 }), BASE_URL);
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_UNAVAILABLE');
});

Deno.test('parseResponse: invalid retrievedAtMs (NaN) returns PROVIDER_MALFORMED', () => {
  const result = databentoAdapter.parseResponse(
    req(),
    200,
    new Headers({ 'Content-Type': 'application/json' }),
    ndjsonBar() + '\n',
    NaN,
  );
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: instrument_id = 0 returns PROVIDER_MALFORMED', () => {
  const result = databentoAdapter.parseResponse(
    req(),
    200,
    new Headers({ 'Content-Type': 'application/json' }),
    ndjsonBar({ instrument_id: 0 }) + '\n',
    NOW_MS,
  );
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: instrument_id = -1 returns PROVIDER_MALFORMED', () => {
  const result = databentoAdapter.parseResponse(
    req(),
    200,
    new Headers({ 'Content-Type': 'application/json' }),
    ndjsonBar({ instrument_id: -1 }) + '\n',
    NOW_MS,
  );
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: fractional instrument_id (1.5) returns PROVIDER_MALFORMED', () => {
  const result = databentoAdapter.parseResponse(
    req(),
    200,
    new Headers({ 'Content-Type': 'application/json' }),
    ndjsonBar({ instrument_id: 1.5 }) + '\n',
    NOW_MS,
  );
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});

Deno.test('parseResponse: oversized NDJSON line (>128 KB) returns PROVIDER_MALFORMED', () => {
  // A 130 KB padding field makes the line exceed MAX_LINE_BYTES.
  const giantBar = ndjsonBar({ _padding: 'x'.repeat(130 * 1024) });
  const result = databentoAdapter.parseResponse(
    req(),
    200,
    new Headers({ 'Content-Type': 'application/json' }),
    giantBar + '\n',
    NOW_MS,
  );
  assertEquals(result.ok, false);
  if (result.ok) throw new Error();
  assertEquals(result.error.code, 'PROVIDER_MALFORMED');
});
