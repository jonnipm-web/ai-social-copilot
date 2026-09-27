/**
 * Provider adapter contract + cache tests — IV-QUANT-REAL-DATA-READINESS-03.
 * A fake outbound fetch serves SYNTHETIC vendor payloads (synthetic_market.ts);
 * no network, no real vendor, no key.
 *
 * Execução:
 *   deno test --allow-read --allow-net=deno.land,esm.sh supabase/functions/_shared/quant_provider_contract_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { HttpAdapterProvider, type OutboundFetch } from './quant_provider_runtime.ts';
import { barsRequest, syntheticVendorAdapter, type AdapterSpec } from './quant/provider_adapter.ts';
import { SyntheticInProcessProvider, syntheticVendorPayload } from './quant/synthetic_market.ts';
import { CachingProvider, InMemoryMarketCache, marketCacheKey } from './quant/market_cache.ts';
import { createPriceSeries } from './quant/timeseries.ts';
import { analyzeSeries } from './quant/analysis.ts';
import type { InstrumentIdentity } from './quant/instrument.ts';
import type { QuantResult } from './quant/errors.ts';
import type { MarketDataProvider } from './quant/provider.ts';
import { UnsafeUrlError } from './safe_fetch.ts';

const NOW = Date.UTC(2026, 0, 14, 23, 30); // Wed after NYSE close + grace
const AAPLX: InstrumentIdentity = { assetClass: 'EQUITY', symbol: 'SYNA', exchangeMic: 'XNAS', currency: 'USD' };
const LON: InstrumentIdentity = { assetClass: 'EQUITY', symbol: 'SYNL', exchangeMic: 'XLON', currency: 'GBP' };
const BASE = 'https://synthetic.invalid';
const req = barsRequest(AAPLX, NOW, 120, 'SPLIT_AND_DIVIDEND_ADJUSTED');

function err<T>(r: QuantResult<T>): string {
  assert(!r.ok, 'expected failure');
  return (r as { ok: false; error: { code: string } }).error.code;
}
function val<T>(r: QuantResult<T>): T {
  if (!r.ok) throw new Error(`${r.error.code}: ${r.error.message}`);
  return r.value;
}
const payload = (mutate?: (p: ReturnType<typeof syntheticVendorPayload>) => void, instrument = AAPLX) => {
  const p = syntheticVendorPayload(instrument, NOW, { sessions: 60 });
  mutate?.(p);
  return JSON.stringify(p);
};
function serving(body: string, status = 200, headers: Record<string, string> = {}): { fetchImpl: OutboundFetch; calls: { url: string; headers: Record<string, string> }[] } {
  const calls: { url: string; headers: Record<string, string> }[] = [];
  return {
    calls,
    fetchImpl: (url, opts) => {
      calls.push({ url, headers: { ...(opts.headers ?? {}) } });
      return Promise.resolve(new Response(body, { status, headers }));
    },
  };
}
const provider = (fetchImpl: OutboundFetch, spec: AdapterSpec = syntheticVendorAdapter, readSecret?: (n: string) => string | null) =>
  new HttpAdapterProvider(spec, BASE, { fetchImpl, clock: () => NOW, readSecret });

// ---------------------------------------------------------------- adapter contract

Deno.test('PC-01 success: vendor payload → canonical series → analysis, provenance from the provider (never the client)', async () => {
  const f = serving(payload());
  const res = val(await provider(f.fetchImpl).historicalBars(req));
  assertEquals(res.provenance.providerId, 'synthetic-vendor');
  assertEquals([res.provenance.providerKind, res.provenance.trust], ['FIXTURE', 'SYNTHETIC_FIXTURE']);
  assertEquals(res.provenance.retrievedAt, new Date(NOW).toISOString());
  assertEquals(res.provenance.sourceAsOf, '2026-01-14T00:00:00.000Z');
  const series = val(createPriceSeries(AAPLX, res.provenance, res.data));
  assertEquals(series.bars.length, 60);
  const a = val(await analyzeSeries(series, { periodsPerYear: 252 }, () => NOW));
  assertEquals([a.dataSnapshot.freshness.state, a.dataSnapshot.calendar.calendar], ['FRESH', 'XNAS']);
  assertEquals(a.dataSnapshot.evidenceStrength, 'WEAK'); // synthetic is never strong evidence
  assert(new URL(f.calls[0].url).hostname === 'synthetic.invalid');
});

Deno.test('PC-02 transport failures are normalized: timeout, 429 (+retry), 5xx, 401, unreachable, redirect off-allowlist', async () => {
  const timeout: OutboundFetch = () => Promise.reject(new DOMException('aborted', 'AbortError'));
  assertEquals(err(await provider(timeout).historicalBars(req)), 'PROVIDER_TIMEOUT');
  const r429 = await provider(serving('{}', 429, { 'retry-after': '17' }).fetchImpl).historicalBars(req);
  assert(!r429.ok && r429.error.code === 'PROVIDER_RATE_LIMITED' && r429.error.details?.retryAfterSeconds === 17);
  assertEquals(err(await provider(serving('oops', 503).fetchImpl).historicalBars(req)), 'PROVIDER_UNAVAILABLE');
  assertEquals(err(await provider(serving('{}', 401).fetchImpl).historicalBars(req)), 'PROVIDER_UNAVAILABLE');
  assertEquals(err(await provider(() => Promise.reject(new TypeError('dns'))).historicalBars(req)), 'PROVIDER_UNAVAILABLE');
  assertEquals(err(await provider(() => Promise.reject(new UnsafeUrlError('redirect'))).historicalBars(req)), 'PROVIDER_UNAVAILABLE');
});

Deno.test('PC-03 malformed payloads are rejected, never an empty success', async () => {
  const bad = [
    'not json',
    '[]',
    JSON.stringify({ status: 'error' }),
    payload((p) => { (p as { values: unknown }).values = 'x'; }),
    payload((p) => { p.values[0].close = 'NaN'; }),
    payload((p) => { p.values[0].datetime = '01/02/2026'; }),
    payload((p) => { (p.meta as { as_of: string }).as_of = 'yesterday'; }),
  ];
  for (const b of bad) assertEquals(err(await provider(serving(b).fetchImpl).historicalBars(req)), 'PROVIDER_MALFORMED', b.slice(0, 40));
  assertEquals(err(await provider(serving(payload((p) => { p.values = []; })).fetchImpl).historicalBars(req)), 'INSUFFICIENT_DATA');
});

Deno.test('PC-04 provider spoofing / poisoning: wrong symbol, exchange, currency, interval or adjustment is rejected', async () => {
  const cases: [string, (p: ReturnType<typeof syntheticVendorPayload>) => void][] = [
    ['symbol', (p) => { p.meta.symbol = 'OTHER'; }],
    ['exchange', (p) => { p.meta.exchange = 'XNYS'; }],
    ['currency', (p) => { p.meta.currency = 'EUR'; }],
    ['interval', (p) => { (p.meta as { interval: string }).interval = '1min'; }],
    ['adjustment', (p) => { p.meta.adjustment = 'UNADJUSTED'; }],
  ];
  for (const [field, m] of cases) {
    const r = await provider(serving(payload(m)).fetchImpl).historicalBars(req);
    assert(!r.ok && r.error.code === 'PROVIDER_MALFORMED' && r.error.details?.field === field, field);
  }
});

Deno.test('PC-05 data quality downstream: missing bars reported, duplicates collapsed or rejected, out-of-order sorted, stale timestamp detected', async () => {
  // Missing bars: drop 3 sessions in the middle → MISSING_SESSIONS warning, never filled.
  const holes = val(await provider(serving(payload((p) => { p.values.splice(10, 3); })).fetchImpl).historicalBars(req));
  const s1 = val(createPriceSeries(AAPLX, holes.provenance, holes.data));
  const a1 = val(await analyzeSeries(s1, { periodsPerYear: 252 }, () => NOW));
  assertEquals(a1.dataSnapshot.calendar.missingSessions, 3);
  // Exact duplicate collapsed; conflicting duplicate rejected.
  const dup = val(await provider(serving(payload((p) => { p.values.push({ ...p.values[5] }); })).fetchImpl).historicalBars(req));
  assert(val(createPriceSeries(AAPLX, dup.provenance, dup.data)).normalizationWarnings.some((w) => w.code === 'EXACT_DUPLICATES_COLLAPSED'));
  const conflict = val(await provider(serving(payload((p) => { p.values.push({ ...p.values[5], close: '1.0000', low: '0.5000' }); })).fetchImpl).historicalBars(req));
  assertEquals(err(createPriceSeries(AAPLX, conflict.provenance, conflict.data)), 'DATA_QUALITY_ERROR');
  // Newest-first vendor order is sorted into canonical order.
  const ord = val(await provider(serving(payload()).fetchImpl).historicalBars(req));
  const s2 = val(createPriceSeries(AAPLX, ord.provenance, ord.data));
  assert(s2.bars[0].t < s2.bars[s2.bars.length - 1].t);
  // as_of that disagrees with the newest bar is rejected; an old but consistent series reads STALE.
  const lying = val(await provider(serving(payload((p) => { p.meta.as_of = '2025-06-01T00:00:00.000Z'; })).fetchImpl).historicalBars(req));
  assertEquals(err(createPriceSeries(AAPLX, lying.provenance, lying.data)), 'DATA_QUALITY_ERROR');
  const old = syntheticVendorPayload(AAPLX, Date.UTC(2025, 10, 3, 23), { sessions: 40 });
  // (window wide enough to contain the old series: the range check of PC-08 is not what this case tests)
  const oldRes = val(await provider(serving(JSON.stringify(old)).fetchImpl).historicalBars(barsRequest(AAPLX, NOW, 200, 'SPLIT_AND_DIVIDEND_ADJUSTED')));
  const a3 = val(await analyzeSeries(val(createPriceSeries(AAPLX, oldRes.provenance, oldRes.data)), { periodsPerYear: 252 }, () => NOW));
  assertEquals(a3.dataSnapshot.freshness.state, 'STALE');
});

Deno.test('PC-06 credentials: only from server secrets, only as a header, never in the URL; missing secret fails closed', async () => {
  const keyed: AdapterSpec = { ...syntheticVendorAdapter, id: 'keyed-synthetic', secretEnvName: 'QUANT_PROVIDER_TEST_KEY', secretHeader: 'X-Api-Key' };
  const f = serving(payload((p) => { p.meta.symbol = AAPLX.symbol; }));
  // Adapter id differs from the payload's provider → provenance providerId is the adapter id.
  const res = await provider(f.fetchImpl, { ...keyed, parseResponse: syntheticVendorAdapter.parseResponse }, (n) => (n === 'QUANT_PROVIDER_TEST_KEY' ? 'sk-test-123' : null)).historicalBars(req);
  assert(res.ok);
  assertEquals(f.calls[0].headers['X-Api-Key'], 'sk-test-123');
  assert(!f.calls[0].url.includes('sk-test-123'));
  assertEquals(err(await provider(f.fetchImpl, keyed, () => null).historicalBars(req)), 'PROVIDER_UNAVAILABLE');
  // An adapter that tries to put a key in the query string is refused before any request.
  const leaky: AdapterSpec = { ...syntheticVendorAdapter, buildRequest: () => ({ ok: true, value: { url: `${BASE}/v1/x?apikey=abc`, headers: {} } }) };
  const f2 = serving(payload());
  assertEquals(err(await provider(f2.fetchImpl, leaky).historicalBars(req)), 'PROVIDER_UNAVAILABLE');
  assertEquals(f2.calls.length, 0);
  // A host outside the adapter allowlist is refused before any request.
  const f3 = serving(payload());
  assertEquals(err(await new HttpAdapterProvider(syntheticVendorAdapter, 'https://evil.example.org', { fetchImpl: f3.fetchImpl }).historicalBars(req)), 'PROVIDER_UNAVAILABLE');
  assertEquals(f3.calls.length, 0);
  // The runtime passes the allowlist down to safeFetch for redirect re-checks.
  let seen: readonly string[] | undefined;
  await provider((_u, o) => { seen = o.allowedHosts; return Promise.resolve(new Response(payload(), { status: 200 })); }).historicalBars(req);
  assertEquals(seen, ['synthetic.invalid']);
});

// ---------------------------------------------------------------- cache

class CountingProvider implements MarketDataProvider {
  calls = 0;
  failing = false;
  readonly id = 'synthetic-vendor';
  readonly capabilities = new Set(['HISTORICAL_BARS'] as const);
  constructor(private readonly inner: MarketDataProvider) {}
  lookupInstrument() { return this.inner.lookupInstrument(''); }
  latestQuote(i: InstrumentIdentity) { return this.inner.latestQuote(i); }
  historicalBars(r: Parameters<MarketDataProvider['historicalBars']>[0]) {
    this.calls++;
    return this.failing ? Promise.resolve({ ok: false as const, error: { code: 'PROVIDER_UNAVAILABLE' as const, message: 'down' } }) : this.inner.historicalBars(r);
  }
}

Deno.test('CA-01 cache hit preserves the provider provenance exactly; cache metadata is separate', async () => {
  let now = NOW;
  const inner = new CountingProvider(new SyntheticInProcessProvider(() => NOW));
  const cp = new CachingProvider(inner, new InMemoryMarketCache(), () => now);
  const miss = val(await cp.historicalBars(req));
  now += 2 * 3_600_000;
  const hit = val(await cp.historicalBars(req));
  assertEquals(inner.calls, 1);
  assertEquals([miss.cache.status, hit.cache.status, hit.cache.state], ['MISS', 'HIT', 'FRESH_CACHE']);
  assertEquals(hit.provenance, miss.provenance); // sourceAsOf, retrievedAt, providerId, adjustment untouched
  assertEquals(hit.cache.providerRetrievedAt, miss.provenance.retrievedAt);
  assertEquals(hit.cache.cacheServedAt, new Date(now).toISOString());
  assertEquals(hit.cache.ageMs, 2 * 3_600_000);
  // Mutating a served copy cannot poison the cache.
  (hit.data[0] as { close: number }).close = 1;
  assert((val(await cp.historicalBars(req)).data[0].close as number) !== 1);
});

Deno.test('CA-02 staleness: expired → provider refetch; provider down → STALE_FALLBACK within staleServe only; never fresh', async () => {
  let now = NOW;
  const inner = new CountingProvider(new SyntheticInProcessProvider(() => NOW));
  const cp = new CachingProvider(inner, new InMemoryMarketCache(), () => now);
  await cp.historicalBars(req);
  now += 7 * 3_600_000; // beyond freshTtl (6h)
  await cp.historicalBars(req);
  assertEquals(inner.calls, 2); // refetched, not served stale
  inner.failing = true;
  now += 24 * 3_600_000;
  const stale = val(await cp.historicalBars(req));
  assertEquals([stale.cache.status, stale.cache.state], ['STALE_FALLBACK', 'STALE_CACHE']);
  now += 4 * 24 * 3_600_000; // beyond staleServe (3 days)
  assertEquals(err(await cp.historicalBars(req)), 'PROVIDER_UNAVAILABLE');
});

Deno.test('CA-03 cache security: user uploads never cached, provider-bound entries, collision-free keys', () => {
  const cache = new InMemoryMarketCache();
  const upload = { data: [], provenance: { providerId: 'user-csv', providerKind: 'USER_UPLOAD' as const, trust: 'USER_SUPPLIED' as const, retrievedAt: '2026-01-14T00:00:00.000Z', frequency: 'DAILY' as const, currency: 'USD', adjustment: 'UNKNOWN' as const } };
  assertEquals(err(cache.put('k', 'user-csv', upload, NOW)), 'INVALID_PARAMETER');
  const spoof = { ...upload, provenance: { ...upload.provenance, providerId: 'other-vendor', providerKind: 'EXTERNAL_PROVIDER' as const, trust: 'PROVIDER_REPORTED' as const } };
  assertEquals(err(cache.put('k', 'synthetic-vendor', spoof, NOW)), 'PROVIDER_MALFORMED');
  // Every dimension changes the key; separators cannot be injected.
  const k = (over: Partial<typeof req>, inst: Partial<InstrumentIdentity> = {}) => marketCacheKey('p', '1', { ...req, ...over, instrument: { ...AAPLX, ...inst } });
  const base = k({});
  for (const other of [k({ adjustment: 'UNADJUSTED' }), k({ frequency: 'WEEKLY' }), k({}, { currency: 'GBP' }), k({}, { exchangeMic: 'XNYS' }), k({}, { symbol: 'SYNA:XNAS' }), marketCacheKey('p', '2', req), marketCacheKey('q', '1', req), k({ fromT: req.fromT - 86_400_000 })]) {
    assert(other !== base);
  }
  // Same calendar day → same key (requests a few minutes apart share an entry).
  assertEquals(k({ toT: req.toT + 60_000 }), base);
});

Deno.test('CA-04 LRU bound: the cache never grows past its entry limit', async () => {
  const cache = new InMemoryMarketCache(3);
  const cp = new CachingProvider(new SyntheticInProcessProvider(() => NOW), cache, () => NOW);
  for (const sym of ['SYNA', 'SYNB', 'SYNC', 'SYND', 'SYNE']) await cp.historicalBars({ ...req, instrument: { ...AAPLX, symbol: sym } });
  assertEquals(cache.size(), 3);
});

Deno.test('PC-07 London synthetic series respects the LSE calendar (bank holidays are not bars)', async () => {
  const lonReq = barsRequest(LON, Date.UTC(2025, 7, 27, 20), 30, 'SPLIT_AND_DIVIDEND_ADJUSTED');
  const r = val(await new SyntheticInProcessProvider(() => Date.UTC(2025, 7, 27, 20)).historicalBars(lonReq));
  const s = val(createPriceSeries(LON, r.provenance, r.data));
  assert(!s.bars.some((b) => new Date(b.t).toISOString().startsWith('2025-08-25'))); // Summer bank holiday
  const a = val(await analyzeSeries(s, { periodsPerYear: 252 }, () => Date.UTC(2025, 7, 27, 20)));
  assertEquals([a.dataSnapshot.calendar.nonSessionBars, a.dataSnapshot.calendar.missingSessions], [0, 0]);
});

Deno.test('PC-08 provider range integrity (Codex Gate 2 P1): no bar after toT (look-ahead), none before fromT beyond one day of date granularity, as_of never after retrieval', async () => {
  const DAY = 86_400_000;
  const inside = payload();
  assert((await provider(serving(inside).fetchImpl).historicalBars(req)).ok);
  // A bar dated after the request end (look-ahead) is rejected.
  const future = payload((p) => { p.values.unshift({ ...p.values[0], datetime: '2026-01-15' }); });
  const rf = await provider(serving(future).fetchImpl).historicalBars(req);
  assert(!rf.ok && rf.error.code === 'PROVIDER_MALFORMED' && rf.error.message.includes('outside the requested range'));
  // A bar well before the window start is rejected…
  const early = payload((p) => { p.values.push({ ...p.values[p.values.length - 1], datetime: new Date(req.fromT - 3 * DAY).toISOString().slice(0, 10) }); });
  assertEquals(err(await provider(serving(early).fetchImpl).historicalBars(req)), 'PROVIDER_MALFORMED');
  // …but the start day itself (00:00 UTC < fromT) is date granularity, not contamination.
  const startDay = new Date(req.fromT).toISOString().slice(0, 10);
  const edge = payload((p) => {
    p.values = p.values.slice(0, 5);
    p.values.push({ ...p.values[4], datetime: startDay });
  });
  assert((await provider(serving(edge).fetchImpl).historicalBars(req)).ok, 'start-day bar must be accepted');
  // as_of claiming a time after we received the data is rejected.
  const asOfFuture = payload((p) => { (p.meta as { as_of: string }).as_of = new Date(NOW + 60_000).toISOString(); });
  assertEquals(err(await provider(serving(asOfFuture).fetchImpl).historicalBars(req)), 'PROVIDER_MALFORMED');
});
