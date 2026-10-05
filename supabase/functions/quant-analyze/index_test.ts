/**
 * quant-analyze API tests — IV-QUANT-DATA-PLANE-AND-API-02.
 * Real handler, fake auth/entitlement/ownership (no network, no database).
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env --allow-read --allow-net=deno.land,esm.sh supabase/functions/quant-analyze/index_test.ts
 */
import { assert, assertEquals, assertThrows } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { AuthClient } from '../_shared/auth.ts';
import { fakeSubjectSource } from '../_shared/entitlement_test_support.ts';
import { type AnalyzeDeps, handler } from './index.ts';
import { checkQuantCapability, InMemoryRateLimiter } from '../_shared/quant_server.ts';
import { resolveProviderMode } from '../_shared/quant_provider_mode.ts';
import type { WatchlistRow, WatchlistStore } from '../_shared/quant/watchlist_contract.ts';
import type { EntitlementSubjectSource } from '../_shared/entitlement.ts';

globalThis.fetch = () => Promise.reject(new Error('network is forbidden in quant-analyze tests'));

const USER_A = 'aaaaaaaa-0000-4000-8000-00000000000a';
const PROJECT_A = 'bbbbbbbb-0000-4000-8000-00000000000a';
const PROJECT_B = 'bbbbbbbb-0000-4000-8000-00000000000b';
const auth: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      return token === 'jwt-a' ? { data: { user: { id: USER_A } }, error: null } : { data: { user: null }, error: { message: 'invalid' } };
    },
  },
};
const admin = fakeSubjectSource('admin');
const logs: string[] = [];
const ownership = { calls: 0 };
const deps = (over: Partial<AnalyzeDeps> = {}): AnalyzeDeps => ({
  clock: () => Date.UTC(2026, 0, 12, 12), // Mon 12:00Z, before the NYSE open
  log: (l) => logs.push(l),
  rateLimiter: { hit: () => Promise.resolve({ allowed: true, limit: 30, remaining: 29, retryAfterSeconds: 60 }) },
  projectAccess: {
    // deno-lint-ignore require-await
    async ownsProject(userId, projectId) {
      ownership.calls++;
      return userId === USER_A && projectId === PROJECT_A;
    },
  },
  ...over,
});

const G1_CSV = 'date,open,high,low,close,volume\n2026-01-05,100,101,99,100,1000\n2026-01-06,110,111,109,110,1000\n2026-01-07,99,100,98,99,1000\n2026-01-08,108.9,109.9,107.9,108.9,1000\n2026-01-09,98.01,99.01,97.01,98.01,1000\n';

function body(over: Record<string, unknown> = {}, dsOver: Record<string, unknown> = {}) {
  return {
    contract_version: 'quant.analyze.v1',
    instrument: { asset_class: 'EQUITY', symbol: 'TSTA', exchange_mic: 'XNAS', currency: 'USD' },
    dataset: { format: 'csv', frequency: 'DAILY', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', csv: G1_CSV, ...dsOver },
    options: { periods_per_year: 252, sma_windows: [2, 3] },
    ...over,
  };
}
function post(b: unknown, token: string | null = 'jwt-a', headers: Record<string, string> = {}): Request {
  const h: Record<string, string> = { 'Content-Type': 'application/json', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  return new Request('http://localhost/', { method: 'POST', headers: h, body: typeof b === 'string' ? b : JSON.stringify(b) });
}
async function call(r: Request, d: AnalyzeDeps = deps(), source = admin) {
  const res = await handler(r, auth, undefined, source, d);
  return { status: res.status, json: await res.json() };
}

// ---------------------------------------------------------------- happy path + numerical regression

Deno.test('QA-01 valid CSV → 200 structured QuantAnalysisResult with goldens, provenance, snapshot and calendar', async () => {
  const { status, json } = await call(post(body()));
  assertEquals(status, 200);
  assertEquals(json.contract_version, 'quant.analyze.v1');
  const a = json.analysis;
  assertEquals(a.computedBy, 'DETERMINISTIC_ENGINE');
  const m = (id: string, w?: number) => a.metrics.find((x: { id: string; parameters?: { window?: number } }) => x.id === id && (w === undefined || x.parameters?.window === w)).value;
  // Same goldens as the Foundation (fixtures/golden.ts G1): the API adds no arithmetic.
  assert(Math.abs(m('CUMULATIVE_RETURN') - -0.0199) < 1e-12);
  assert(Math.abs(m('VOLATILITY_PER_PERIOD') - 0.11547005383792515) < 1e-12);
  assert(Math.abs(m('VOLATILITY_ANNUALIZED') - 1.833030277982336) < 1e-12);
  assert(Math.abs(m('MAX_DRAWDOWN') - -0.109) < 1e-12);
  assert(Math.abs(m('SMA_LAST', 3) - 101.97) < 1e-12);
  const snap = a.dataSnapshot;
  assertEquals(snap.provenance.providerKind, 'USER_UPLOAD');
  assertEquals(snap.provenance.trust, 'USER_SUPPLIED');
  assertEquals(snap.provenance.retrievedAt, '2026-01-12T12:00:00.000Z'); // server clock, not client
  assertEquals(snap.provenance.adjustment, 'SPLIT_AND_DIVIDEND_ADJUSTED');
  assertEquals(snap.evidenceStrength, 'WEAK');
  assert(/^[0-9a-f]{64}$/.test(snap.contentHash));
  assertEquals(snap.calendar.calendar, 'XNAS');
  assertEquals(snap.calendar.basis, 'MARKET_CALENDAR');
  assertEquals(snap.freshness.state, 'FRESH'); // Friday's bar on Monday before the open = 0 sessions behind
  assertEquals(a.engineVersion, 'quant-foundation-0.2.0');
  assertEquals(a.instruments[0].symbol, 'TSTA');
});

Deno.test('QA-02 reproducible: same dataset + options → same analysisId and numbers; generatedAt follows the server clock', async () => {
  const a = (await call(post(body()))).json.analysis;
  const b = (await call(post(body()), deps({ clock: () => Date.UTC(2026, 0, 12, 13) }))).json.analysis;
  assertEquals(a.analysisId, b.analysisId);
  assertEquals(a.metrics, b.metrics);
  assertEquals(a.dataSnapshot.contentHash, b.dataSnapshot.contentHash);
  assert(a.generatedAt !== b.generatedAt);
});

// ---------------------------------------------------------------- schema / anti-smuggling

Deno.test('QA-10 strict schema: forged user_id / plan / role / provider claims are rejected, not ignored', async () => {
  for (const extra of [{ user_id: 'x' }, { plan: 'premium' }, { role: 'admin' }, { module_access: true }]) {
    const { status, json } = await call(post(body(extra)));
    assertEquals([status, json.error], [400, 'INVALID_PARAMETER'], JSON.stringify(extra));
  }
  for (const ds of [{ trust: 'PROVIDER_REPORTED' }, { source_as_of: '2026-01-12T00:00:00Z' }, { url: 'http://169.254.169.254/' }]) {
    const { status, json } = await call(post(body({}, ds)));
    assertEquals([status, json.error], [400, 'INVALID_PARAMETER'], JSON.stringify(ds));
  }
  const inst = await call(post(body({ instrument: { asset_class: 'EQUITY', symbol: 'A', currency: 'USD', provider_ids: { x: 'y' } } })));
  assertEquals(inst.json.error, 'INVALID_PARAMETER');
});

Deno.test('QA-11 invalid schema values → 400 with the offending field', async () => {
  const cases: [Record<string, unknown>, string][] = [
    [{ contract_version: 'quant.analyze.v0' }, 'contract_version'],
    [{ options: { sma_windows: [2] } }, 'options.periods_per_year'],
    [{ options: { periods_per_year: 252, sma_windows: [0] } }, 'options.sma_windows'],
    [{ project_id: 'not-a-uuid' }, 'project_id'],
  ];
  for (const [over, field] of cases) {
    const { status, json } = await call(post(body(over)));
    assertEquals([status, json.details?.field], [400, field], JSON.stringify(over));
  }
  assertEquals((await call(post(body({}, { format: 'url' })))).json.error, 'INVALID_DATASET');
  assertEquals((await call(post(body({}, { frequency: 'HOURLY' })))).json.error, 'INVALID_DATASET');
  assertEquals((await call(post(body({ options: { periods_per_year: -1 } })))).json.error, 'INVALID_PARAMETER');
});

// ---------------------------------------------------------------- CSV / data quality through the API

Deno.test('QA-20 malformed, oversized, too many rows, NaN/Infinity, missing values', async () => {
  const cases: [string, number, string][] = [
    ['date,open,high,low,close\n2026-01-05,1,1,1\n', 400, 'INVALID_DATASET'],
    ['name,email\nana,a@x\n', 400, 'INVALID_DATASET'],
    ['date,open,high,low,close\n2026-01-05,NaN,1,1,1\n', 400, 'INVALID_DATASET'],
    ['date,open,high,low,close\n2026-01-05,Infinity,1,1,1\n', 400, 'INVALID_DATASET'],
    ['date,open,high,low,close\n2026-01-05,1,1,1,\n', 400, 'INVALID_DATASET'],
    ['date,open,high,low,close\n01/05/2026,1,1,1,1\n', 400, 'INVALID_DATASET'],
  ];
  for (const [csv, status, code] of cases) {
    const r = await call(post(body({}, { csv })));
    assertEquals([r.status, r.json.error], [status, code], csv);
  }
  const rows = ['date,open,high,low,close', ...Array.from({ length: 50_001 }, (_, i) => `${new Date(Date.UTC(1900, 0, 1) + i * 86_400_000).toISOString().slice(0, 10)},1,1,1,1`)].join('\n');
  const tooMany = await call(post(body({}, { csv: rows })));
  assertEquals([tooMany.status, tooMany.json.error], [413, 'DATASET_TOO_LARGE']);
});

Deno.test('QA-21 body cap: Content-Length and streamed size both enforced (413) before parsing', async () => {
  const big = 'x'.repeat(6 * 1024 * 1024 + 10);
  const r1 = await call(post(body({}, { csv: big })));
  assertEquals([r1.status, r1.json.error], [413, 'DATASET_TOO_LARGE']);
  const r2 = await call(post(JSON.stringify(body({}, { csv: big })), 'jwt-a', { 'Content-Length': '10' }));
  assertEquals(r2.status, 413);
  const r3 = await call(post('{not json', 'jwt-a'));
  assertEquals([r3.status, r3.json.error], [400, 'INVALID_JSON']);
  const r4 = await call(new Request('http://localhost/', { method: 'POST', headers: { Authorization: 'Bearer jwt-a', 'Content-Type': 'text/csv' }, body: G1_CSV }));
  assertEquals([r4.status, r4.json.error], [415, 'UNSUPPORTED_MEDIA_TYPE']);
  const r5 = await call(new Request('http://localhost/', { method: 'GET', headers: { Authorization: 'Bearer jwt-a' } }));
  assertEquals([r5.status, r5.json.error], [405, 'METHOD_NOT_ALLOWED']);
});

Deno.test('QA-22 duplicates (exact collapse / conflicting reject), out-of-order sorted, currency mismatch, unsupported asset', async () => {
  const lines = G1_CSV.trim().split('\n');
  const exactDup = await call(post(body({}, { csv: [...lines, lines[3]].join('\n') })));
  assertEquals(exactDup.status, 200);
  assert(exactDup.json.analysis.warnings.some((w: { code: string }) => w.code === 'EXACT_DUPLICATES_COLLAPSED'));
  const conflict = await call(post(body({}, { csv: [...lines, '2026-01-07,99,100,98,99.5,1000'].join('\n') })));
  assertEquals([conflict.status, conflict.json.error], [422, 'DATA_QUALITY_ERROR']);
  const shuffled = await call(post(body({}, { csv: [lines[0], lines[4], lines[1], lines[5], lines[2], lines[3]].join('\n') })));
  assertEquals(shuffled.status, 200);
  assertEquals(shuffled.json.analysis.analysisId, (await call(post(body()))).json.analysis.analysisId);
  const ohlc = await call(post(body({}, { csv: 'date,open,high,low,close\n2026-01-05,10,9,8,10\n2026-01-06,10,11,9,10\n' })));
  assertEquals([ohlc.status, ohlc.json.error], [422, 'DATA_QUALITY_ERROR']);
  const crypto = await call(post(body({ instrument: { asset_class: 'CRYPTO', symbol: 'BTC', currency: 'USD' } })));
  assertEquals([crypto.status, crypto.json.error], [422, 'UNSUPPORTED_ASSET_CLASS']);
  const badCcy = await call(post(body({ instrument: { asset_class: 'EQUITY', symbol: 'A', currency: 'usd$' } })));
  assertEquals([badCcy.status, badCcy.json.error], [400, 'INVALID_INSTRUMENT']);
  const one = await call(post(body({}, { csv: 'date,open,high,low,close\n2026-01-05,1,1,1,1\n' })));
  assertEquals([one.status, one.json.error], [422, 'INSUFFICIENT_DATA']);
});

// ---------------------------------------------------------------- freshness / calendar via the API

Deno.test('QA-30 calendar-aware freshness: weekend is not stale; holiday is not a missed session; unknown MIC is naive', async () => {
  // Friday bar evaluated Sunday: FRESH on XNAS; still 0 sessions behind.
  const sunday = await call(post(body()), deps({ clock: () => Date.UTC(2026, 0, 11, 18) }));
  assertEquals([sunday.json.analysis.dataSnapshot.freshness.state, sunday.json.analysis.dataSnapshot.calendar.sessionsBehind], ['FRESH', 0]);
  // Same data on Tuesday after the close: Monday + Tuesday sessions missed → STALE.
  const tuesday = await call(post(body()), deps({ clock: () => Date.UTC(2026, 0, 13, 23, 30) }));
  assertEquals([tuesday.json.analysis.dataSnapshot.freshness.state, tuesday.json.analysis.dataSnapshot.calendar.sessionsBehind], ['STALE', 2]);
  // Unknown venue: calendar-naive, explicitly flagged.
  const naive = await call(post(body({ instrument: { asset_class: 'EQUITY', symbol: 'TSTA', exchange_mic: 'XTST', currency: 'USD' } })));
  assertEquals(naive.json.analysis.dataSnapshot.calendar.calendarStatus, 'CALENDAR_UNKNOWN');
  assert(naive.json.analysis.warnings.some((w: { code: string }) => w.code === 'CALENDAR_NAIVE'));
  // accepted_freshness refusal → 422 STALE_DATA.
  const refused = await call(post(body({ options: { periods_per_year: 252, accepted_freshness: ['FRESH'] } })), deps({ clock: () => Date.UTC(2026, 0, 13, 23, 30) }));
  assertEquals([refused.status, refused.json.error], [422, 'STALE_DATA']);
});

// ---------------------------------------------------------------- auth / entitlement / ownership

Deno.test('QA-40 authentication and entitlement fail closed before any work', async () => {
  assertEquals((await call(post(body(), null))).status, 401);
  assertEquals((await call(post(body(), 'forged.jwt.token'))).status, 401);
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    const r = await call(post(body({ plan: 'premium', role: 'admin' })), deps(), fakeSubjectSource(role));
    assertEquals([r.status, r.json.error], [403, 'MODULE_NOT_AVAILABLE'], role);
  }
});

Deno.test('QA-41 project ownership is verified server-side: own project allowed, foreign project denied, lookup failure fails closed', async () => {
  ownership.calls = 0;
  const own = await call(post(body({ project_id: PROJECT_A })));
  assertEquals(own.status, 200);
  assertEquals(own.json.analysis.subject.projectId, PROJECT_A);
  const foreign = await call(post(body({ project_id: PROJECT_B })));
  assertEquals([foreign.status, foreign.json.error], [403, 'PROJECT_ACCESS_DENIED']);
  assertEquals(ownership.calls, 2);
  const down = await call(post(body({ project_id: PROJECT_A })), deps({
    // deno-lint-ignore require-await
    projectAccess: { async ownsProject() { throw new Error('db down'); } },
  }));
  assertEquals([down.status, down.json.error], [503, 'OWNERSHIP_UNAVAILABLE']);
  // No project_id → no ownership lookup at all.
  ownership.calls = 0;
  await call(post(body()));
  assertEquals(ownership.calls, 0);
});

// ---------------------------------------------------------------- observability + boundaries

Deno.test('QA-50 logs are allowlisted: no CSV, prices, symbol, JWT or project id', async () => {
  logs.length = 0;
  await call(post(body({ project_id: PROJECT_A })));
  await call(post(body({}, { csv: 'bad' })));
  const text = logs.join('\n');
  assertEquals(logs.length, 2);
  for (const forbidden of ['TSTA', '98.01', 'jwt-a', PROJECT_A, 'date,open', USER_A]) assert(!text.includes(forbidden), forbidden);
  const ev = JSON.parse(logs[0]);
  assertEquals([ev.event, ev.provider_id, ev.dataset_size, ev.freshness, ev.error_code], ['quant_analysis', 'user-csv', 5, 'FRESH', null]);
  assertEquals(JSON.parse(logs[1]).error_code, 'INVALID_DATASET');
});

Deno.test('QA-51 the API never fetches (no SSRF surface, no LLM, no provider call)', async () => {
  // fetch is replaced by a rejecting stub at module top: a 200 proves no network was used.
  assertEquals((await call(post(body()))).status, 200);
  const src = await Deno.readTextFile(new URL('./index.ts', import.meta.url));
  assert(!/\bfetch\s*\(/.test(src) && !/groq|openai|anthropic/i.test(src.replace(/\/\/.*$/gm, '')));
});

// ---------------------------------------------------------------- Codex numerical/API gate regressions

Deno.test('CXN-01 a client-declared adjustment can never suppress the corporate-action caveat', async () => {
  const split = 'date,open,high,low,close\n2026-01-05,100,100,100,100\n2026-01-06,10,10,10,10\n2026-01-07,10.5,10.5,10.5,10.5\n';
  for (const adjustment of ['UNADJUSTED', 'SPLIT_ADJUSTED', 'SPLIT_AND_DIVIDEND_ADJUSTED', 'UNKNOWN']) {
    for (const price_basis of ['close', undefined]) {
      const opts = price_basis ? { periods_per_year: 252, price_basis } : { periods_per_year: 252 };
      const r = await call(post(body({ options: opts }, { csv: split, adjustment })));
      assertEquals(r.status, 200, adjustment);
      const codes = r.json.analysis.warnings.map((w: { code: string }) => w.code);
      assert(codes.includes('ADJUSTMENT_UNVERIFIED') || codes.includes('ADJUSTMENT_UNKNOWN'), `${adjustment}: caveat suppressed`);
    }
  }
});

Deno.test('CXN-02 exact media type: charset allowed, look-alikes rejected with 415', async () => {
  assertEquals((await call(post(body(), 'jwt-a', { 'Content-Type': 'application/json; charset=utf-8' }))).status, 200);
  for (const ct of ['application/jsonx', 'application/json-patch+json', 'text/json', 'application/x-json']) {
    const r = await call(post(body(), 'jwt-a', { 'Content-Type': ct }));
    assertEquals([r.status, r.json.error], [415, 'UNSUPPORTED_MEDIA_TYPE'], ct);
  }
});

Deno.test('CXN-03 an out-of-range clock yields a structured 400, never an exception', async () => {
  for (const t of [8.7e15, -8.7e15, NaN, Infinity]) {
    const r = await call(post(body()), deps({ clock: () => t }));
    assertEquals([r.status, r.json.error], [400, 'INVALID_PARAMETER'], String(t));
  }
  const { marketClock, calendarForMic } = await import('../_shared/quant/calendar.ts');
  assertEquals(marketClock(calendarForMic('XNYS')!, 8.7e15), null);
});

Deno.test('CXN-04 oversized option arrays are rejected before iteration', async () => {
  const huge = Array.from({ length: 200_000 }, () => 2);
  const r = await call(post(body({ options: { periods_per_year: 252, sma_windows: huge } })));
  assertEquals([r.status, r.json.details?.field], [400, 'options.sma_windows']);
  const f = await call(post(body({ options: { periods_per_year: 252, accepted_freshness: ['FRESH', 'FRESH', 'FRESH', 'FRESH', 'FRESH'] } })));
  assertEquals(f.status, 400);
});

// ---------------------------------------------------------------- rate limiting (IV-QUANT-REAL-DATA-READINESS-03)

const USER_B = 'aaaaaaaa-0000-4000-8000-00000000000b';
const auth2: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      const id = token === 'jwt-a' ? USER_A : token === 'jwt-b' ? USER_B : null;
      return id ? { data: { user: { id } }, error: null } : { data: { user: null }, error: { message: 'invalid' } };
    },
  },
};
async function callRL(r: Request, limiter: InMemoryRateLimiter | { hit: () => Promise<never> }) {
  const res = await handler(r, auth2, undefined, admin, deps({ rateLimiter: limiter as never }));
  return { status: res.status, retryAfter: res.headers.get('Retry-After'), json: await res.json() };
}

Deno.test('RL-01 within / at / over the limit → 200 … 200, then 429 with Retry-After and structured body', async () => {
  let now = Date.UTC(2026, 0, 12, 12, 0, 10);
  const limiter = new InMemoryRateLimiter(() => now);
  for (let i = 1; i <= 30; i++) assertEquals((await callRL(post(body()), limiter)).status, 200, `hit ${i}`);
  const over = await callRL(post(body()), limiter);
  assertEquals([over.status, over.json.error, over.json.details.limit], [429, 'RATE_LIMITED', 30]);
  assertEquals(over.retryAfter, '50'); // window ends at 12:01:00
  assertEquals(over.json.details.retry_after_seconds, 50);
  assert(!JSON.stringify(over.json).match(/postgres|supabase|table|counter/i));
  // Next window: allowed again.
  now += 60_000;
  assertEquals((await callRL(post(body()), limiter)).status, 200);
});

Deno.test('RL-02 users have independent counters; a forged user_id in the body cannot move the count', async () => {
  const limiter = new InMemoryRateLimiter(() => Date.UTC(2026, 0, 12, 12));
  for (let i = 0; i < 30; i++) await callRL(post(body()), limiter);
  assertEquals((await callRL(post(body()), limiter)).status, 429);
  assertEquals((await callRL(post(body(), 'jwt-b'), limiter)).status, 200); // user B unaffected
  // A forged user_id is rejected by the schema, and in any case the limiter keys on the JWT user.
  const forged = await callRL(post(body({ user_id: USER_B })), limiter);
  assertEquals(forged.status, 429); // still user A's exhausted counter — checked BEFORE the body is read
});

Deno.test('RL-03 counter store failure fails CLOSED with 503 RATE_LIMIT_UNAVAILABLE', async () => {
  const r = await callRL(post(body()), { hit: () => Promise.reject(new Error('db down')) });
  assertEquals([r.status, r.json.error], [503, 'RATE_LIMIT_UNAVAILABLE']);
});

Deno.test('RL-04 concurrency: 45 simultaneous requests → exactly 30 allowed, 15 limited', async () => {
  const limiter = new InMemoryRateLimiter(() => Date.UTC(2026, 0, 12, 12));
  const results = await Promise.all(Array.from({ length: 45 }, () => callRL(post(body()), limiter)));
  assertEquals(results.filter((r) => r.status === 200).length, 30);
  assertEquals(results.filter((r) => r.status === 429).length, 15);
});

Deno.test('RL-05 unauthenticated and non-entitled callers never reach the limiter', async () => {
  let hits = 0;
  const counting = { hit: () => { hits++; return Promise.resolve({ allowed: true, limit: 30, remaining: 29, retryAfterSeconds: 60 }); } };
  await handler(post(body(), null), auth2, undefined, admin, deps({ rateLimiter: counting }));
  await handler(post(body()), auth2, undefined, fakeSubjectSource('free'), deps({ rateLimiter: counting }));
  assertEquals(hits, 0);
});

// ---------------------------------------------------------------- READINESS-03: multi.v1 + watchlist.v1

const WL_A = 'cccccccc-0000-4000-8000-00000000000a';
const WL_B = 'cccccccc-0000-4000-8000-00000000000b';
const itemId = (n: number) => `dddddddd-0000-4000-8000-${String(n).padStart(12, '0')}`;
function wlRow(id: string, symbols: Array<[string, string, string]>): WatchlistRow {
  return {
    id, name: 'wl', project_id: null, created_at: 't', updated_at: 't',
    items: symbols.map(([s, mic, ccy], i) => ({ id: itemId(i + 1), instrument_key: `EQUITY:${s}:${mic}:${ccy}`, asset_class: 'EQUITY', symbol: s, exchange_mic: mic, currency: ccy, isin: null, figi: null, created_at: 't' })),
  };
}
/** Store as seen through RLS for USER_A: only the rows passed in are visible. */
function storeFor(rows: WatchlistRow[], seen: { tokens: string[]; users: string[] }) {
  return (token: string): WatchlistStore => ({
    // deno-lint-ignore require-await
    async list(userId: string) {
      seen.tokens.push(token);
      seen.users.push(userId);
      return rows;
    },
    countWatchlists: () => Promise.reject(new Error('unused')),
    create: () => Promise.reject(new Error('unused')),
    rename: () => Promise.reject(new Error('unused')),
    remove: () => Promise.reject(new Error('unused')),
    itemCount: () => Promise.reject(new Error('unused')),
    addItem: () => Promise.reject(new Error('unused')),
    removeItem: () => Promise.reject(new Error('unused')),
  });
}
const WNOW = Date.UTC(2026, 8, 23, 22);
function wlBody(over: Record<string, unknown> = {}) {
  return { contract_version: 'quant.analyze.watchlist.v1', watchlist_id: WL_A, data_source: 'SYNTHETIC_PROVIDER', options: { periods_per_year: 252 }, ...over };
}
const CSV_B = 'date,open,high,low,close,volume\n2026-01-05,50,51,49,50,1000\n2026-01-06,51,52,50,51,1000\n2026-01-07,49,50,48,49,1000\n2026-01-08,52,53,51,52,1000\n2026-01-09,50,51,49,50,1000\n';
function multiBody(over: Record<string, unknown> = {}) {
  const ds = (csv: string) => ({ format: 'csv', frequency: 'DAILY', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', csv });
  return {
    contract_version: 'quant.analyze.multi.v1',
    series: [
      { instrument: { asset_class: 'EQUITY', symbol: 'TSTA', exchange_mic: 'XNAS', currency: 'USD' }, dataset: ds(G1_CSV) },
      { instrument: { asset_class: 'EQUITY', symbol: 'TSTB', exchange_mic: 'XNAS', currency: 'USD' }, dataset: ds(CSV_B) },
    ],
    options: { periods_per_year: 252 },
    ...over,
  };
}

Deno.test('QM-01 multi.v1 → 200 multi_analysis with correlation + USER_UPLOAD provenance; v1 still served', async () => {
  const r = await call(post(multiBody()));
  assertEquals(r.status, 200);
  assertEquals(r.json.contract_version, 'quant.analyze.multi.v1');
  assertEquals(r.json.multi_analysis.series.length, 2);
  assertEquals(r.json.multi_analysis.correlation.length, 1);
  for (const s of r.json.multi_analysis.series) assertEquals(s.analysis.dataSnapshot.provenance.providerKind, 'USER_UPLOAD');
  assertEquals((await call(post(body()))).json.contract_version, 'quant.analyze.v1');
  assertEquals((await call(post(multiBody({ contract_version: 'quant.analyze.v2' })))).status, 400);
});

Deno.test('QM-02 multi.v1: 11 series → 400; foreign project → 403; ownership outage fails closed', async () => {
  const s = (multiBody().series as unknown[])[0];
  assertEquals((await call(post(multiBody({ series: Array.from({ length: 11 }, () => s) })))).status, 400);
  assertEquals((await call(post(multiBody({ project_id: PROJECT_B })))).json.error, 'PROJECT_ACCESS_DENIED');
  const down = await call(post(multiBody({ project_id: PROJECT_A })), deps({ projectAccess: { ownsProject: () => Promise.reject(new Error('x')) } }));
  assertEquals(down.json.error, 'OWNERSHIP_UNAVAILABLE');
});

Deno.test('QM-03 watchlist.v1 → instruments from the caller-owned watchlist (caller JWT + server user id), synthetic provenance', async () => {
  const seen = { tokens: [] as string[], users: [] as string[] };
  const rows = [wlRow(WL_A, [['SYNA', 'XNYS', 'USD'], ['SYNB', 'XNAS', 'USD']])];
  logs.length = 0;
  const r = await call(post(wlBody()), deps({ clock: () => WNOW, storeFor: storeFor(rows, seen) }));
  assertEquals(r.status, 200);
  assertEquals(seen.tokens, ['jwt-a']);
  assertEquals(seen.users, [USER_A]);
  assertEquals(r.json.multi_analysis.series.length, 2);
  assertEquals(r.json.multi_analysis.dataSource.kind, 'SYNTHETIC_PROVIDER');
  for (const s of r.json.multi_analysis.series) assertEquals(s.analysis.dataSnapshot.provenance.trust, 'SYNTHETIC_FIXTURE');
  const ev = JSON.parse(logs[logs.length - 1]);
  assertEquals(ev.contract, 'quant.analyze.watchlist.v1');
  assertEquals(ev.instrument_count, 2);
  assertEquals(ev.cache_hits + ev.cache_misses, 2);
  assert(!logs.join('\n').includes('SYNA'));
});

Deno.test('QM-04 watchlist.v1: invisible watchlist → NOT_FOUND; unknown item ids refused; > 10 items need item_ids; no client URL', async () => {
  const seen = { tokens: [] as string[], users: [] as string[] };
  const rows = [wlRow(WL_A, Array.from({ length: 12 }, (_, i) => [`S${i}`, 'XNYS', 'USD'] as [string, string, string]))];
  const d = deps({ clock: () => WNOW, storeFor: storeFor(rows, seen) });
  const foreign = await call(post(wlBody({ watchlist_id: WL_B })), d);
  assertEquals(foreign.status, 400);
  assert(JSON.stringify(foreign.json).includes('NOT_FOUND'));
  assertEquals((await call(post(wlBody({ item_ids: [itemId(99)] })), d)).status, 400);
  assertEquals((await call(post(wlBody()), d)).json.error, 'DATASET_TOO_LARGE');
  const subset = await call(post(wlBody({ item_ids: [itemId(1), itemId(2), itemId(3)] })), d);
  assertEquals(subset.status, 200);
  assertEquals(subset.json.multi_analysis.series.length, 3);
  assertEquals((await call(post(wlBody({ provider_url: 'http://169.254.169.254/' })), d)).status, 400);
  assertEquals((await call(post(wlBody({ data_source: 'LICENSED_VENDOR' })), d)).status, 400);
});

Deno.test('QM-05 watchlist.v1 also requires quant-watchlists: second gate fails closed; non-admin denied; store never read', async () => {
  let n = 0;
  const admin2 = fakeSubjectSource('admin');
  const flaky: EntitlementSubjectSource = {
    resolveUserSubject(userId: string, accessToken: string) {
      if (++n > 1) return Promise.reject(new Error('outage on the second gate'));
      return admin2.resolveUserSubject(userId, accessToken);
    },
  };
  const seen = { tokens: [] as string[], users: [] as string[] };
  const d = deps({ clock: () => WNOW, storeFor: storeFor([wlRow(WL_A, [['SYNA', 'XNYS', 'USD']])], seen) });
  const r = await call(post(wlBody()), d, flaky as never);
  assertEquals(n, 2);
  assert(r.status === 403 || r.status === 503, `got ${r.status}`);
  assertEquals(seen.users.length, 0);
  const user = await call(post(wlBody()), d, fakeSubjectSource('pro') as never);
  assertEquals(user.status, 403);
  assertEquals(seen.users.length, 0);
});

Deno.test('QM-06 watchlist.v1: store failure → 500 structured, no partial result', async () => {
  const d = deps({ clock: () => WNOW, storeFor: () => ({ list: () => Promise.reject(new Error('db down')) }) as unknown as WatchlistStore });
  const r = await call(post(wlBody()), d);
  assertEquals(r.status, 500);
  assertEquals(r.json.multi_analysis, undefined);
});

// MACRO-05 FASE 3 regression pin: makeLiveProvider() graceful degradation.
// When DATABENTO_API_KEY is absent from env, makeLiveProvider returns the
// SyntheticInProcessProvider. A 200 here proves no real network call was
// attempted — the "network is forbidden" guard at the top of this file would
// catch any outbound attempt regardless of provider selection.
Deno.test('QM-07 FASE3 makeLiveProvider: synthetic fallback when DATABENTO_API_KEY absent', async () => {
  const rows = [wlRow(WL_A, [['AAPL', 'XNAS', 'USD']])];
  const seen = { tokens: [] as string[], users: [] as string[] };
  // No marketProvider injected → handler calls makeLiveProvider(clock).
  // DATABENTO_API_KEY not set in CI → synthetic branch → no network.
  const r = await call(post(wlBody()), deps({ clock: () => WNOW, storeFor: storeFor(rows, seen) }));
  assertEquals(r.status, 200);
  assertEquals(r.json.multi_analysis.series.length, 1);
  assertEquals(r.json.multi_analysis.series[0].instrument.symbol, 'AAPL');
});

// MACRO-05 FASE 3 — fail-closed when QUANT_REQUIRE_LIVE_DATA=true and key absent.
// Codex CLASS D MACRO-05 third-pass remediation: watchlist analysis is ALWAYS
// synthetic (never wired to the real Databento provider). QUANT_PROVIDER_MODE
// and QUANT_REQUIRE_LIVE_DATA do not affect watchlist.v1. The null-provider
// injection that previously simulated fail-closed now correctly triggers the
// synthetic fallback, returning a successful response.
Deno.test('QM-09 FASE3 watchlist-always-synthetic: null provider falls back to synthetic (no 500)', async () => {
  const rows = [wlRow(WL_A, [['AAPL', 'XNAS', 'USD']])];
  const seen = { tokens: [] as string[], users: [] as string[] };
  // With the always-synthetic design, null injection → synthetic provider (not fail-closed 500).
  const nullProvider = deps({ clock: () => WNOW, storeFor: storeFor(rows, seen), marketProvider: null as never });
  const r = await call(post(wlBody()), nullProvider);
  assertEquals(r.status, 200, 'watchlist.v1 always uses synthetic; null injection → synthetic, not 500');
  assert(r.json.multi_analysis !== undefined, 'successful response must include multi_analysis');
  assert(Array.isArray(r.json.multi_analysis.series), 'series must be an array');
});

// CLASS D regression pin (MACRO-05 FASE 28): explanation_request structure.
// Verifies the field is present on quant.analyze.v1 responses, absent on
// multi.v1, and carries the correct contract version and engine-sourced facts.
Deno.test('QM-08 FASE9 explanation_request: present on v1, absent on multi.v1, valid contract', async () => {
  // v1 → explanation_request must be present with correct contract
  const r1 = await call(post(body()), deps());
  assertEquals(r1.status, 200);
  const er = r1.json.explanation_request;
  assert(er !== undefined, 'explanation_request missing from quant.analyze.v1 response');
  assertEquals(er.contract, 'quant.explanation.v1');
  assert(typeof er.analysisId === 'string' && er.analysisId.length > 0, 'analysisId must be non-empty string');
  assert(Array.isArray(er.facts) && er.facts.length > 0, 'facts must be non-empty array');
  // Every fact must declare DETERMINISTIC_ENGINE as source — no LLM-generated values
  for (const f of er.facts) {
    assertEquals(f.source, 'DETERMINISTIC_ENGINE', `fact ${f.id} has wrong source`);
    assert(typeof f.display === 'string', `fact ${f.id} display must be string`);
  }
  assert(Array.isArray(er.rules) && er.rules.length > 0, 'rules must be non-empty');

  // multi.v1 → explanation_request must NOT be present (different response schema)
  const r2 = await call(post(multiBody()), deps());
  assertEquals(r2.status, 200);
  assertEquals(r2.json.explanation_request, undefined, 'explanation_request must not appear on multi.v1 response');
});

// MACRO-05 FASE 20: checkQuantCapability unit tests.
// These exercise the tier gate directly; integration coverage through the
// handler requires ALPHA+ lifecycle (non-admin users). Admin always bypasses.
Deno.test('QM-10 FASE20 checkQuantCapability: plan gate matrix', () => {
  const CID = 'test-cid';
  const WL = 'quant.analyze.watchlist.v1';
  const V1 = 'quant.analyze.v1';
  const MV1 = 'quant.analyze.multi.v1';

  // Admin bypasses all gates
  assertEquals(checkQuantCapability('free', true, WL, CID), null, 'admin+free → allowed on watchlist');
  assertEquals(checkQuantCapability(null, true, WL, CID), null, 'admin+null plan → allowed on watchlist');

  // free plan: CSV analyze allowed, watchlist denied
  assertEquals(checkQuantCapability('free', false, V1, CID), null, 'free → allowed on v1');
  assertEquals(checkQuantCapability('free', false, MV1, CID), null, 'free → allowed on multi.v1');
  assert(checkQuantCapability('free', false, WL, CID) !== null, 'free → denied on watchlist.v1');
  assertEquals(checkQuantCapability('free', false, WL, CID)?.status, 403, 'free+watchlist → 403');

  // pro plan: all allowed
  assertEquals(checkQuantCapability('pro', false, WL, CID), null, 'pro → allowed on watchlist.v1');
  assertEquals(checkQuantCapability('pro', false, V1, CID), null, 'pro → allowed on v1');

  // premium plan: all allowed
  assertEquals(checkQuantCapability('premium', false, WL, CID), null, 'premium → allowed on watchlist.v1');

  // null plan: denied (unknown plan = fail closed)
  assert(checkQuantCapability(null, false, V1, CID) !== null, 'null plan → denied on v1');
  assert(checkQuantCapability(null, false, WL, CID) !== null, 'null plan → denied on watchlist.v1');
});

// Codex CLASS D P2 fix: QUANT_REQUIRE_LIVE_DATA normalization.
// The module-level flag now uses .trim().toLowerCase() so "TRUE", "True", " true "
// all activate fail-closed mode. This test pins the null-provider path for each
// case — the real env-var normalization is exercised on module load only; in-process
// injection covers the runtime branch accurately (P3, deferred: fresh-isolate test
// requires subprocess spawning not available in this test environment).
Deno.test('QM-11 Codex-D always-synthetic: null provider → synthetic result (watchlist never wired to real provider)', async () => {
  const rows = [wlRow(WL_A, [['MSFT', 'XNAS', 'USD']])];
  const seen = { tokens: [] as string[], users: [] as string[] };
  // With watchlist-always-synthetic (Codex CLASS D third-pass remediation):
  // null injection no longer means fail-closed; it resolves to SyntheticInProcessProvider.
  // This pins the invariant: no code path can accidentally wire Databento to watchlist.v1.
  const nullProvider = deps({ clock: () => WNOW, storeFor: storeFor(rows, seen), marketProvider: null as never });
  const r = await call(post(wlBody()), nullProvider);
  assertEquals(r.status, 200, 'watchlist.v1 always synthetic: null injection → 200 with synthetic data');
  assertEquals(r.json.error, undefined, 'no error when synthetic provider is used');
  assert(r.json.multi_analysis !== undefined, 'multi_analysis must be present');
});

// MACRO-05 FASE 3: QUANT_PROVIDER_MODE explicit enum resolution.
// resolveProviderMode() accepts an injectable env accessor so all branches can
// be exercised in a pure unit test, without touching the real Deno.env or
// requiring a fresh module isolate per test case.
Deno.test('QM-12 FASE3 QUANT_PROVIDER_MODE: resolveProviderMode covers all branches', () => {
  const env = (vars: Record<string, string>) => (k: string) => vars[k];

  // Default (no env) → auto_lab
  assertEquals(resolveProviderMode(env({})), 'auto_lab', 'default is auto_lab');

  // Explicit values
  assertEquals(resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'synthetic' })), 'synthetic', 'explicit synthetic');
  assertEquals(resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'real' })), 'real', 'explicit real');
  assertEquals(resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'auto_lab' })), 'auto_lab', 'explicit auto_lab');

  // Case and whitespace normalisation
  assertEquals(resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'REAL' })), 'real', 'uppercase normalised');
  assertEquals(resolveProviderMode(env({ QUANT_PROVIDER_MODE: ' real ' })), 'real', 'whitespace trimmed');
  assertEquals(resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'SYNTHETIC' })), 'synthetic', 'SYNTHETIC normalised');

  // Legacy alias: QUANT_REQUIRE_LIVE_DATA=true → real
  assertEquals(resolveProviderMode(env({ QUANT_REQUIRE_LIVE_DATA: 'true' })), 'real', 'legacy true');
  assertEquals(resolveProviderMode(env({ QUANT_REQUIRE_LIVE_DATA: 'TRUE' })), 'real', 'legacy TRUE normalised');
  assertEquals(resolveProviderMode(env({ QUANT_REQUIRE_LIVE_DATA: ' true ' })), 'real', 'legacy true whitespace');
  assertEquals(resolveProviderMode(env({ QUANT_REQUIRE_LIVE_DATA: 'false' })), 'auto_lab', 'legacy false → auto_lab');

  // Explicit QUANT_PROVIDER_MODE takes precedence over legacy
  assertEquals(
    resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'synthetic', QUANT_REQUIRE_LIVE_DATA: 'true' })),
    'synthetic', 'explicit mode wins over legacy alias',
  );

  // Non-empty, unrecognised QUANT_PROVIDER_MODE → fail closed (never silently
  // serve synthetic data for a production misconfiguration such as 'prod').
  assertThrows(
    () => resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'invalid' })),
    Error, 'Invalid QUANT_PROVIDER_MODE value', 'unknown value throws',
  );
  assertThrows(
    () => resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'PRODUCTION' })),
    Error, 'Invalid QUANT_PROVIDER_MODE value', 'unrecognised production-like value throws',
  );
  // Codex P2 regression: invalid explicit mode must throw even when legacy
  // QUANT_REQUIRE_LIVE_DATA=true is also set — the error check runs first.
  assertThrows(
    () => resolveProviderMode(env({ QUANT_PROVIDER_MODE: 'prod', QUANT_REQUIRE_LIVE_DATA: 'true' })),
    Error, 'Invalid QUANT_PROVIDER_MODE value', 'invalid mode + legacy=true still throws (precedence)',
  );
});

// MACRO-05 FASE 3: provider_mode appears in the observability log.
// The log entry for every request must carry the resolved provider_mode so
// operations can distinguish synthetic from real data without secrets.
Deno.test('QM-13 FASE3 observability: provider_mode present in log event', async () => {
  const entries: unknown[] = [];
  const logCollector = (line: string) => { try { entries.push(JSON.parse(line)); } catch { /**/ } };
  const d = deps({ log: logCollector });
  const r = await call(post(body()), d);
  assertEquals(r.status, 200);
  const ev = entries.find((e) => typeof e === 'object' && e !== null && (e as Record<string, unknown>).event === 'quant_analysis') as Record<string, unknown> | undefined;
  assert(ev !== undefined, 'no quant_analysis log event found');
  assert(
    ev.provider_mode === 'synthetic' || ev.provider_mode === 'real' || ev.provider_mode === 'auto_lab',
    `provider_mode must be one of synthetic/real/auto_lab, got: ${ev.provider_mode}`,
  );
});
