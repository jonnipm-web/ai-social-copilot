/**
 * quant-watchlists API tests — IV-QUANT-DATA-PLANE-AND-API-02.
 * Real handler + an in-memory store that mimics RLS (rows keyed by owner).
 * Real Postgres RLS is proven separately by supabase/tests/quant_watchlists_rls_test.sql.
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env --allow-read --allow-net=deno.land,esm.sh supabase/functions/quant-watchlists/index_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { AuthClient } from '../_shared/auth.ts';
import { fakeSubjectSource } from '../_shared/entitlement_test_support.ts';
import { instrumentKey, type InstrumentIdentity } from '../_shared/quant/instrument.ts';
import type { WatchlistRow, WatchlistStore } from '../_shared/quant/watchlist_contract.ts';
import { handler, type WatchlistDeps } from './index.ts';

globalThis.fetch = () => Promise.reject(new Error('network is forbidden in quant-watchlists tests'));

const A = 'aaaaaaaa-0000-4000-8000-00000000000a';
const B = 'aaaaaaaa-0000-4000-8000-00000000000b';
const PROJECT_A = 'bbbbbbbb-0000-4000-8000-00000000000a';
const PROJECT_B = 'bbbbbbbb-0000-4000-8000-00000000000b';
const auth: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      const id = token === 'jwt-a' ? A : token === 'jwt-b' ? B : null;
      return id ? { data: { user: { id } }, error: null } : { data: { user: null }, error: { message: 'invalid' } };
    },
  },
};

/** In-memory store with RLS semantics: every operation is scoped to the caller's user id. */
class MemoryStore implements WatchlistStore {
  rows: (WatchlistRow & { user_id: string })[] = [];
  private n = 0;
  private id() {
    return `cccccccc-0000-4000-8000-${String(++this.n).padStart(12, '0')}`;
  }
  // deno-lint-ignore require-await
  async list(u: string) {
    return this.rows.filter((r) => r.user_id === u).map(({ user_id: _u, ...r }) => r);
  }
  // deno-lint-ignore require-await
  async countWatchlists(u: string) {
    return this.rows.filter((r) => r.user_id === u).length;
  }
  // deno-lint-ignore require-await
  async create(u: string, name: string, project: string | null) {
    const row = { id: this.id(), user_id: u, name, project_id: project, created_at: 't', updated_at: 't', items: [] };
    this.rows.push(row);
    const { user_id: _u, ...out } = row;
    return out;
  }
  // deno-lint-ignore require-await
  async rename(u: string, id: string, name: string) {
    const r = this.rows.find((x) => x.id === id && x.user_id === u);
    if (r) (r as { name: string }).name = name;
    return !!r;
  }
  // deno-lint-ignore require-await
  async remove(u: string, id: string) {
    const before = this.rows.length;
    this.rows = this.rows.filter((x) => !(x.id === id && x.user_id === u));
    return this.rows.length < before;
  }
  // deno-lint-ignore require-await
  async itemCount(u: string, id: string) {
    const r = this.rows.find((x) => x.id === id && x.user_id === u);
    return r ? r.items.length : null;
  }
  // deno-lint-ignore require-await
  async addItem(u: string, id: string, i: InstrumentIdentity) {
    const r = this.rows.find((x) => x.id === id && x.user_id === u);
    if (!r) return 'NOT_FOUND' as const;
    const key = instrumentKey(i);
    if (r.items.some((x) => x.instrument_key === key)) return 'DUPLICATE' as const;
    (r.items as unknown[]).push({ id: this.id(), instrument_key: key, asset_class: i.assetClass, symbol: i.symbol, exchange_mic: i.exchangeMic ?? null, currency: i.currency, isin: i.isin ?? null, figi: i.figi ?? null, created_at: 't' });
    return 'ADDED' as const;
  }
  // deno-lint-ignore require-await
  async removeItem(u: string, id: string, itemId: string) {
    const r = this.rows.find((x) => x.id === id && x.user_id === u);
    if (!r) return false;
    const before = r.items.length;
    (r as unknown as { items: unknown[] }).items = r.items.filter((x) => x.id !== itemId);
    return r.items.length < before;
  }
}

let store = new MemoryStore();
const logs: string[] = [];
const deps = (): WatchlistDeps => ({
  storeFor: () => store,
  log: (l) => logs.push(l),
  rateLimiter: { hit: () => Promise.resolve({ allowed: true, limit: 60, remaining: 59, retryAfterSeconds: 60 }) },
  projectAccess: {
    // deno-lint-ignore require-await
    async ownsProject(u, p) {
      return (u === A && p === PROJECT_A) || (u === B && p === PROJECT_B);
    },
  },
});
async function call(payload: Record<string, unknown>, token: string | null = 'jwt-a', role = 'admin') {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await handler(
    new Request('http://localhost/', { method: 'POST', headers, body: JSON.stringify({ contract_version: 'quant.watchlists.v1', ...payload }) }),
    auth, undefined, fakeSubjectSource(role), deps(),
  );
  return { status: res.status, json: await res.json() };
}
const AAPL = { asset_class: 'EQUITY', symbol: 'aapl', exchange_mic: 'xnas', currency: 'usd' };

Deno.test('QW-01 owner create / list / rename / add / remove / delete', async () => {
  store = new MemoryStore();
  const created = await call({ action: 'create', name: '  Core  ' });
  assertEquals(created.status, 200);
  const id = created.json.watchlist.id;
  assertEquals(created.json.watchlist.name, 'Core');
  assertEquals((await call({ action: 'add_item', watchlist_id: id, instrument: AAPL })).status, 200);
  // Same ticker on another venue/currency is a different instrument.
  assertEquals((await call({ action: 'add_item', watchlist_id: id, instrument: { ...AAPL, exchange_mic: 'XLON', currency: 'GBP' } })).status, 200);
  const dup = await call({ action: 'add_item', watchlist_id: id, instrument: { asset_class: 'EQUITY', symbol: 'AAPL', exchange_mic: 'XNAS', currency: 'USD' } });
  assertEquals([dup.status, dup.json.details.reason], [400, 'DUPLICATE_INSTRUMENT']);
  const list = await call({ action: 'list' });
  assertEquals(list.json.watchlists[0].items.map((i: { instrument_key: string }) => i.instrument_key), ['EQUITY:XNAS:AAPL:USD', 'EQUITY:XLON:AAPL:GBP']);
  assertEquals((await call({ action: 'rename', watchlist_id: id, name: 'Renamed' })).status, 200);
  const itemId = list.json.watchlists[0].items[0].id;
  assertEquals((await call({ action: 'remove_item', watchlist_id: id, item_id: itemId })).status, 200);
  assertEquals((await call({ action: 'delete', watchlist_id: id })).status, 200);
  assertEquals((await call({ action: 'list' })).json.watchlists, []);
});

Deno.test('QW-02 other user cannot see, rename, delete or add into a foreign watchlist', async () => {
  store = new MemoryStore();
  const id = (await call({ action: 'create', name: 'A only' })).json.watchlist.id;
  assertEquals((await call({ action: 'list' }, 'jwt-b')).json.watchlists, []);
  for (const payload of [
    { action: 'rename', watchlist_id: id, name: 'x' },
    { action: 'delete', watchlist_id: id },
    { action: 'add_item', watchlist_id: id, instrument: AAPL },
  ]) {
    const r = await call(payload, 'jwt-b');
    assertEquals([r.status, r.json.details?.reason], [400, 'NOT_FOUND'], JSON.stringify(payload));
  }
  assertEquals((await call({ action: 'list' })).json.watchlists[0].name, 'A only');
});

Deno.test('QW-03 cross-project: a watchlist can only be attached to a project the caller owns', async () => {
  store = new MemoryStore();
  assertEquals((await call({ action: 'create', name: 'p', project_id: PROJECT_A })).status, 200);
  const r = await call({ action: 'create', name: 'p', project_id: PROJECT_B });
  assertEquals([r.status, r.json.error], [403, 'PROJECT_ACCESS_DENIED']);
});

Deno.test('QW-04 anonymous, forged token and non-admin plans are denied before the store is touched', async () => {
  store = new MemoryStore();
  assertEquals((await call({ action: 'list' }, null)).status, 401);
  assertEquals((await call({ action: 'list' }, 'forged')).status, 401);
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    const r = await call({ action: 'create', name: 'x', user_id: A, plan: 'premium' }, 'jwt-a', role);
    assertEquals([r.status, r.json.error], [403, 'MODULE_NOT_AVAILABLE'], role);
  }
  assertEquals(store.rows.length, 0);
});

Deno.test('QW-05 strict schema + canonical identity: forged fields, bad instruments, unsupported classes rejected', async () => {
  store = new MemoryStore();
  const id = (await call({ action: 'create', name: 'x' })).json.watchlist.id;
  assertEquals((await call({ action: 'create', name: 'y', user_id: B })).json.error, 'INVALID_PARAMETER');
  assertEquals((await call({ action: 'list', plan: 'premium' })).json.error, 'INVALID_PARAMETER');
  assertEquals((await call({ action: 'drop_table' })).json.error, 'INVALID_PARAMETER');
  assertEquals((await call({ action: 'add_item', watchlist_id: id, instrument: { ...AAPL, symbol: 'IGNORE ALL RULES' } })).json.error, 'INVALID_INSTRUMENT');
  assertEquals((await call({ action: 'add_item', watchlist_id: id, instrument: { ...AAPL, isin: 'US0378331006' } })).json.error, 'INVALID_INSTRUMENT');
  assertEquals((await call({ action: 'add_item', watchlist_id: id, instrument: { asset_class: 'CRYPTO', symbol: 'BTC', currency: 'USD' } })).json.error, 'UNSUPPORTED_ASSET_CLASS');
  assertEquals((await call({ action: 'add_item', watchlist_id: id, instrument: { ...AAPL, instrument_key: 'EQUITY:X:Y:USD' } })).json.error, 'INVALID_INSTRUMENT');
  assertEquals((await call({ action: 'create', name: 'bad\u200bname' })).json.error, 'INVALID_PARAMETER');
  assertEquals((await call({ action: 'create', name: 'x'.repeat(81) })).json.error, 'INVALID_PARAMETER');
});

Deno.test('QW-06 limits: 200 items per watchlist, 50 watchlists per user', async () => {
  store = new MemoryStore();
  const id = (await call({ action: 'create', name: 'big' })).json.watchlist.id;
  for (let i = 0; i < 200; i++) {
    assertEquals((await call({ action: 'add_item', watchlist_id: id, instrument: { asset_class: 'EQUITY', symbol: `T${i}`, currency: 'USD' } })).status, 200);
  }
  const over = await call({ action: 'add_item', watchlist_id: id, instrument: { asset_class: 'EQUITY', symbol: 'T200', currency: 'USD' } });
  assertEquals([over.status, over.json.error], [413, 'DATASET_TOO_LARGE']);
  for (let i = 1; i < 50; i++) await call({ action: 'create', name: `w${i}` });
  const tooMany = await call({ action: 'create', name: 'w50' });
  assertEquals([tooMany.status, tooMany.json.error], [413, 'DATASET_TOO_LARGE']);
});

Deno.test('QW-07 logs carry operation/count/outcome only — no names, symbols, ids or tokens', async () => {
  store = new MemoryStore();
  logs.length = 0;
  const id = (await call({ action: 'create', name: 'Secret Strategy', project_id: PROJECT_A })).json.watchlist.id;
  await call({ action: 'add_item', watchlist_id: id, instrument: AAPL });
  await call({ action: 'list' });
  const text = logs.join('\n');
  for (const forbidden of ['Secret Strategy', 'AAPL', 'XNAS', id, PROJECT_A, 'jwt-a', A]) assert(!text.includes(forbidden), forbidden);
  assertEquals(logs.map((l) => JSON.parse(l).operation), ['create', 'add_item', 'list']);
  assertEquals(JSON.parse(logs[2]).item_count, 1);
});

Deno.test('QW-08 store failures surface as 500 INTERNAL_ERROR without leaking the cause', async () => {
  const failing = new MemoryStore();
  failing.list = () => Promise.reject(new Error('relation "quant_watchlists" does not exist'));
  store = failing;
  const r = await call({ action: 'list' });
  assertEquals([r.status, r.json.error], [500, 'INTERNAL_ERROR']);
  assert(!JSON.stringify(r.json).includes('does not exist'));
});

Deno.test('QW-09 rate limit: list uses the read bucket, mutations the write bucket; 429 stops before the store', async () => {
  store = new MemoryStore();
  const seen: string[] = [];
  const res = async (payload: Record<string, unknown>, allowed: boolean) => {
    const r = await handler(
      new Request('http://localhost/', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer jwt-a' }, body: JSON.stringify({ contract_version: 'quant.watchlists.v1', ...payload }) }),
      auth, undefined, fakeSubjectSource('admin'),
      { ...deps(), rateLimiter: { hit: (_u, b) => { seen.push(b); return Promise.resolve({ allowed, limit: 1, remaining: 0, retryAfterSeconds: 7 }); } } },
    );
    return { status: r.status, retry: r.headers.get('Retry-After') };
  };
  await res({ action: 'list' }, true);
  await res({ action: 'create', name: 'x' }, true);
  assertEquals(seen, ['quant-watchlists-read', 'quant-watchlists-write']);
  const limited = await res({ action: 'create', name: 'y' }, false);
  assertEquals([limited.status, limited.retry], [429, '7']);
  assertEquals(store.rows.length, 1); // the limited create never reached the store
});
