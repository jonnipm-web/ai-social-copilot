/**
 * Quant Lab LOCAL dev server — IV-QUANT-REAL-DATA-READINESS-03 (physical
 * Android validation). NOT a deployment artifact.
 *
 * Runs the REAL `quant-analyze` and `quant-watchlists` handlers on the PC so a
 * DEBUG build on a USB-connected phone can exercise the full flow through
 * `adb reverse tcp:<port> tcp:<port>`, without deploying anything:
 *   - authentication: the real Supabase Auth (the caller's own JWT is
 *     verified by `auth.getUser`; read-only);
 *   - entitlement: the real server-side gate, reading the caller's OWN
 *     profile row with the caller's JWT (read-only, RLS);
 *   - watchlists: IN-MEMORY store scoped by the server-derived user id
 *     (nothing is written to any database; lost on exit);
 *   - rate limits: in-memory fixed window (same limits as production SQL);
 *   - project ownership: always "not owned" (no project-scoped calls in the Lab);
 *   - market data: the in-process SYNTHETIC provider through the cache.
 *
 * Binds to 127.0.0.1 only. Needs SUPABASE_URL and SUPABASE_ANON_KEY in the
 * environment (public client values; never committed).
 *
 *   DENO_TESTING=1 deno run --allow-net=127.0.0.1,<project>.supabase.co --allow-env tool/quant_lab_dev_server.ts
 *   (DENO_TESTING=1 only stops the imported Edge Function modules from binding their own serve())
 */
import { handler as analyzeHandler } from '../supabase/functions/quant-analyze/index.ts';
import { handler as watchlistsHandler } from '../supabase/functions/quant-watchlists/index.ts';
import { InMemoryRateLimiter } from '../supabase/functions/_shared/quant_server.ts';
import { instrumentKey, type InstrumentIdentity } from '../supabase/functions/_shared/quant/instrument.ts';
import { MAX_WATCHLIST_ITEMS, type WatchlistRow, type WatchlistStore } from '../supabase/functions/_shared/quant/watchlist_contract.ts';

const PORT = Number(Deno.env.get('QUANT_DEV_PORT') ?? '54321');
if (!Deno.env.get('SUPABASE_URL') || !Deno.env.get('SUPABASE_ANON_KEY')) {
  console.error('SUPABASE_URL and SUPABASE_ANON_KEY must be set (runtime only; never commit them).');
  Deno.exit(2);
}

/** In-memory store with RLS semantics: every operation is scoped to the caller's server-derived user id. */
class DevMemoryStore implements WatchlistStore {
  private rows: (WatchlistRow & { user_id: string })[] = [];
  private id() {
    return crypto.randomUUID();
  }
  private own(u: string, id: string) {
    return this.rows.find((x) => x.id === id && x.user_id === u);
  }
  // deno-lint-ignore require-await
  async list(u: string) {
    return this.rows.filter((r) => r.user_id === u).map(({ user_id: _u, ...r }) => structuredClone(r));
  }
  // deno-lint-ignore require-await
  async countWatchlists(u: string) {
    return this.rows.filter((r) => r.user_id === u).length;
  }
  // deno-lint-ignore require-await
  async create(u: string, name: string, project: string | null) {
    const now = new Date().toISOString();
    const row = { id: this.id(), user_id: u, name, project_id: project, created_at: now, updated_at: now, items: [] };
    this.rows.push(row);
    const { user_id: _u, ...out } = row;
    return structuredClone(out);
  }
  // deno-lint-ignore require-await
  async rename(u: string, id: string, name: string) {
    const r = this.own(u, id);
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
    return this.own(u, id)?.items.length ?? null;
  }
  // deno-lint-ignore require-await
  async addItem(u: string, id: string, i: InstrumentIdentity) {
    const r = this.own(u, id);
    if (!r) return 'NOT_FOUND' as const;
    if (r.items.length >= MAX_WATCHLIST_ITEMS) return 'LIMIT' as const;
    const key = instrumentKey(i);
    if (r.items.some((x) => x.instrument_key === key)) return 'DUPLICATE' as const;
    (r.items as unknown[]).push({
      id: this.id(), instrument_key: key, asset_class: i.assetClass, symbol: i.symbol, exchange_mic: i.exchangeMic ?? null,
      currency: i.currency, isin: i.isin ?? null, figi: i.figi ?? null, created_at: new Date().toISOString(),
    });
    return 'ADDED' as const;
  }
  // deno-lint-ignore require-await
  async removeItem(u: string, id: string, itemId: string) {
    const r = this.own(u, id);
    if (!r) return false;
    const before = r.items.length;
    (r as unknown as { items: unknown[] }).items = r.items.filter((x) => x.id !== itemId);
    return r.items.length < before;
  }
}

const store = new DevMemoryStore();
const rateLimiter = new InMemoryRateLimiter();
const noProjects = { ownsProject: () => Promise.resolve(false) };
const log = (line: string) => console.log(line); // allowlisted Quant log events only

Deno.serve({ hostname: '127.0.0.1', port: PORT }, (req) => {
  const path = new URL(req.url).pathname;
  if (path === '/quant-analyze') return analyzeHandler(req, undefined, undefined, undefined, { storeFor: () => store, rateLimiter, projectAccess: noProjects, log });
  if (path === '/quant-watchlists') return watchlistsHandler(req, undefined, undefined, undefined, { storeFor: () => store, rateLimiter, projectAccess: noProjects, log });
  return new Response('not found', { status: 404 });
});
console.log(`quant-lab dev server on http://127.0.0.1:${PORT} (in-memory watchlists, synthetic data, no writes)`);
