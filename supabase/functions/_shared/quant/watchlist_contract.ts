/**
 * quant-watchlists API contract — IV-QUANT-DATA-PLANE-AND-API-02
 * (docs/quant/QUANT_WATCHLIST_MODEL.md).
 *
 * Pure request validation + the storage port. The Edge Function
 * implements WatchlistStore with the CALLER's JWT, so Postgres RLS
 * (migration 20260924000000_quant_watchlists.sql) is the data-isolation
 * authority; this file adds canonical instrument identity, limits and a
 * strict schema (unknown fields rejected — no client user_id).
 */
import { fail, ok, type QuantResult } from './errors.ts';
import { createInstrument, type InstrumentIdentity, instrumentKey, requireFoundationSupported } from './instrument.ts';
import { MAX_WATCHLIST_ITEMS } from './domain_future.ts';

export const WATCHLISTS_CONTRACT_VERSION = 'quant.watchlists.v1' as const;
/** Per-user cap on watchlists (resource bound; mirrored by a DB trigger). */
export const MAX_WATCHLISTS_PER_USER = 50;
export const MAX_WATCHLIST_BODY_BYTES = 16 * 1024;
export { MAX_WATCHLIST_ITEMS };

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

export type WatchlistAction =
  | { readonly action: 'list' }
  | { readonly action: 'create'; readonly name: string; readonly projectId?: string }
  | { readonly action: 'rename'; readonly watchlistId: string; readonly name: string }
  | { readonly action: 'delete'; readonly watchlistId: string }
  | { readonly action: 'add_item'; readonly watchlistId: string; readonly instrument: InstrumentIdentity }
  | { readonly action: 'remove_item'; readonly watchlistId: string; readonly itemId: string };

export interface WatchlistItemRow {
  readonly id: string;
  readonly instrument_key: string;
  readonly asset_class: string;
  readonly symbol: string;
  readonly exchange_mic: string | null;
  readonly currency: string;
  readonly isin: string | null;
  readonly figi: string | null;
  readonly created_at: string;
}

export interface WatchlistRow {
  readonly id: string;
  readonly name: string;
  readonly project_id: string | null;
  readonly created_at: string;
  readonly updated_at: string;
  readonly items: readonly WatchlistItemRow[];
}

/**
 * Storage port. Implementations MUST act as the caller (their JWT → RLS);
 * `userId` is the server-derived id, used only for explicit filters/defaults
 * on top of RLS, never taken from the request.
 */
export interface WatchlistStore {
  list(userId: string): Promise<WatchlistRow[]>;
  countWatchlists(userId: string): Promise<number>;
  create(userId: string, name: string, projectId: string | null): Promise<WatchlistRow>;
  rename(userId: string, watchlistId: string, name: string): Promise<boolean>;
  remove(userId: string, watchlistId: string): Promise<boolean>;
  /** Returns the item count of an owned watchlist, or null if not found / not owned. */
  itemCount(userId: string, watchlistId: string): Promise<number | null>;
  addItem(userId: string, watchlistId: string, instrument: InstrumentIdentity): Promise<'ADDED' | 'DUPLICATE' | 'NOT_FOUND' | 'LIMIT'>;
  removeItem(userId: string, watchlistId: string, itemId: string): Promise<boolean>;
}

type Obj = Record<string, unknown>;
function isObj(v: unknown): v is Obj {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}
function onlyKeys(o: Obj, allowed: readonly string[]): QuantResult<Obj> {
  for (const k of Object.keys(o)) if (!allowed.includes(k)) return fail('INVALID_PARAMETER', 'unknown field', { field: k });
  return ok(o);
}
function uuid(v: unknown, field: string): QuantResult<string> {
  return typeof v === 'string' && UUID_RE.test(v) ? ok(v) : fail('INVALID_PARAMETER', 'must be a UUID', { field });
}
function name(v: unknown): QuantResult<string> {
  const n = typeof v === 'string' ? v.trim() : '';
  // Control/format characters are rejected so names render safely everywhere.
  if (n.length < 1 || n.length > 80 || /[\p{Cc}\p{Cf}]/u.test(n)) {
    return fail('INVALID_PARAMETER', 'name must be 1..80 printable characters', { field: 'name' });
  }
  return ok(n);
}

export function parseWatchlistAction(body: unknown): QuantResult<WatchlistAction> {
  if (!isObj(body)) return fail('INVALID_PARAMETER', 'body must be a JSON object');
  if (body.contract_version !== WATCHLISTS_CONTRACT_VERSION) {
    return fail('INVALID_PARAMETER', `contract_version must be ${WATCHLISTS_CONTRACT_VERSION}`, { field: 'contract_version' });
  }
  const base = ['contract_version', 'action'];
  switch (body.action) {
    case 'list': {
      const k = onlyKeys(body, base);
      return k.ok ? ok({ action: 'list' }) : k;
    }
    case 'create': {
      const k = onlyKeys(body, [...base, 'name', 'project_id']);
      if (!k.ok) return k;
      const n = name(body.name);
      if (!n.ok) return n;
      if (body.project_id === undefined) return ok({ action: 'create', name: n.value });
      const p = uuid(body.project_id, 'project_id');
      return p.ok ? ok({ action: 'create', name: n.value, projectId: p.value }) : p;
    }
    case 'rename': {
      const k = onlyKeys(body, [...base, 'watchlist_id', 'name']);
      if (!k.ok) return k;
      const w = uuid(body.watchlist_id, 'watchlist_id');
      if (!w.ok) return w;
      const n = name(body.name);
      return n.ok ? ok({ action: 'rename', watchlistId: w.value, name: n.value }) : n;
    }
    case 'delete': {
      const k = onlyKeys(body, [...base, 'watchlist_id']);
      if (!k.ok) return k;
      const w = uuid(body.watchlist_id, 'watchlist_id');
      return w.ok ? ok({ action: 'delete', watchlistId: w.value }) : w;
    }
    case 'add_item': {
      const k = onlyKeys(body, [...base, 'watchlist_id', 'instrument']);
      if (!k.ok) return k;
      const w = uuid(body.watchlist_id, 'watchlist_id');
      if (!w.ok) return w;
      if (!isObj(body.instrument)) return fail('INVALID_INSTRUMENT', 'instrument must be an object');
      const ik = onlyKeys(body.instrument, ['asset_class', 'symbol', 'exchange_mic', 'currency', 'isin', 'figi']);
      if (!ik.ok) return fail('INVALID_INSTRUMENT', 'unknown instrument field', ik.error.details);
      const i = body.instrument;
      const inst = createInstrument({
        assetClass: i.asset_class as InstrumentIdentity['assetClass'],
        symbol: i.symbol as string,
        currency: i.currency as string,
        ...(i.exchange_mic !== undefined ? { exchangeMic: i.exchange_mic as string } : {}),
        ...(i.isin !== undefined ? { isin: i.isin as string } : {}),
        ...(i.figi !== undefined ? { figi: i.figi as string } : {}),
      });
      if (!inst.ok) return inst;
      // A watchlist may only hold what quant-analytics can analyze today.
      const sup = requireFoundationSupported(inst.value);
      return sup.ok ? ok({ action: 'add_item', watchlistId: w.value, instrument: inst.value }) : sup;
    }
    case 'remove_item': {
      const k = onlyKeys(body, [...base, 'watchlist_id', 'item_id']);
      if (!k.ok) return k;
      const w = uuid(body.watchlist_id, 'watchlist_id');
      if (!w.ok) return w;
      const it = uuid(body.item_id, 'item_id');
      return it.ok ? ok({ action: 'remove_item', watchlistId: w.value, itemId: it.value }) : it;
    }
    default:
      return fail('INVALID_PARAMETER', 'unknown action', { field: 'action' });
  }
}

/** Column values for a canonical instrument (instrument_key is also recomputed by the DB). */
export function itemColumns(i: InstrumentIdentity): Record<string, string | null> {
  return {
    instrument_key: instrumentKey(i),
    asset_class: i.assetClass,
    symbol: i.symbol,
    exchange_mic: i.exchangeMic ?? null,
    currency: i.currency,
    isin: i.isin ?? null,
    figi: i.figi ?? null,
  };
}
