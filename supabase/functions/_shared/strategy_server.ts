/**
 * Server adapter for the Strategy Builder Edge Function —
 * INSIGHTVALUES-ROBOT-BUILDER-MACRO-05.
 *
 * Everything with I/O lives here, NOT in _shared/strategy/ (which stays
 * pure, matching the Quant Foundation's own split between quant/ and
 * quant_server.ts). Persistence goes through the CALLER's own JWT (never a
 * service-role client), so Postgres RLS from
 * 20261002000000_strategy_builder.sql is the real isolation authority.
 */
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';
import { sha256Hex } from '../../../aef/persistence/canonical.ts';
import type { StrategySpecification } from './strategy/strategy_spec.ts';
import type { StrategyStatus } from './strategy/lifecycle.ts';

export const strategyCorsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-correlation-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function bearerToken(req: Request): string | null {
  const m = (req.headers.get('Authorization') ?? '').match(/^Bearer\s+(.+)$/i);
  return m?.[1]?.trim() || null;
}

const MAX_BODY_BYTES = 64 * 1024;

export async function readJsonBody(
  req: Request,
): Promise<{ ok: true; value: unknown } | { ok: false; code: 'BODY_TOO_LARGE' | 'UNSUPPORTED_MEDIA_TYPE' | 'INVALID_JSON' }> {
  const mediaType = (req.headers.get('Content-Type') ?? '').split(';')[0].trim().toLowerCase();
  if (mediaType !== 'application/json') return { ok: false, code: 'UNSUPPORTED_MEDIA_TYPE' };
  const declared = Number(req.headers.get('Content-Length') ?? '0');
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) return { ok: false, code: 'BODY_TOO_LARGE' };
  if (!req.body) return { ok: false, code: 'INVALID_JSON' };
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_BODY_BYTES) {
      await reader.cancel().catch(() => {});
      return { ok: false, code: 'BODY_TOO_LARGE' };
    }
    chunks.push(value);
  }
  try {
    const text = new TextDecoder().decode(chunks.length === 1 ? chunks[0] : concat(chunks, total));
    return { ok: true, value: JSON.parse(text) };
  } catch {
    return { ok: false, code: 'INVALID_JSON' };
  }
}

function concat(chunks: Uint8Array[], total: number): Uint8Array {
  const out = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.byteLength;
  }
  return out;
}

function callerClient(accessToken: string): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!url || !anonKey) throw new Error('strategy server misconfigured');
  return createClient(url, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
}

export interface StrategyRow {
  readonly id: string;
  readonly name: string;
  readonly status: StrategyStatus;
  readonly currentVersion: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface StrategyVersionRow {
  readonly id: string;
  readonly strategyId: string;
  readonly versionNumber: number;
  readonly spec: StrategySpecification;
  readonly specHash: string;
  readonly createdAt: string;
}

export interface StrategyStore {
  list(userId: string): Promise<StrategyRow[]>;
  /** Creates a strategy AND its version-1 snapshot atomically (via an RPC
   * would be ideal; two sequential caller-scoped inserts are used here
   * since both are covered by the SAME owner RLS and a failure on the
   * second insert leaves only a harmless orphaned DRAFT the owner can see
   * and delete themselves — never a different user's data). */
  create(userId: string, spec: StrategySpecification): Promise<{ strategy: StrategyRow; version: StrategyVersionRow }>;
  getWithLatestVersion(userId: string, strategyId: string): Promise<{ strategy: StrategyRow; version: StrategyVersionRow } | null>;
}

const STRATEGY_SELECT = 'id, name, status, current_version, created_at, updated_at';

function rowToStrategy(row: Record<string, unknown>): StrategyRow {
  return {
    id: String(row.id),
    name: String(row.name),
    status: row.status as StrategyStatus,
    currentVersion: Number(row.current_version),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
  };
}

function rowToVersion(row: Record<string, unknown>): StrategyVersionRow {
  return {
    id: String(row.id),
    strategyId: String(row.strategy_id),
    versionNumber: Number(row.version_number),
    spec: row.spec as StrategySpecification,
    specHash: String(row.spec_hash),
    createdAt: String(row.created_at),
  };
}

export class SupabaseStrategyStore implements StrategyStore {
  private readonly db: SupabaseClient;
  constructor(accessToken: string) {
    this.db = callerClient(accessToken);
  }

  async list(userId: string): Promise<StrategyRow[]> {
    const { data, error } = await this.db.from('strategies').select(STRATEGY_SELECT).eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(100);
    if (error) throw new Error('strategy list failed');
    return (data ?? []).map(rowToStrategy);
  }

  async create(userId: string, spec: StrategySpecification): Promise<{ strategy: StrategyRow; version: StrategyVersionRow }> {
    const { data: strategyData, error: strategyError } = await this.db.from('strategies')
      .insert({ user_id: userId, name: spec.name, status: 'DRAFT', current_version: 1 })
      .select(STRATEGY_SELECT).single();
    if (strategyError || !strategyData) throw new Error('strategy create failed');
    const strategy = rowToStrategy(strategyData);

    const specHash = (await sha256Hex(JSON.stringify(spec))).slice(0, 32);
    const { data: versionData, error: versionError } = await this.db.from('strategy_versions')
      .insert({ strategy_id: strategy.id, user_id: userId, version_number: 1, spec, spec_hash: specHash })
      .select('id, strategy_id, version_number, spec, spec_hash, created_at').single();
    if (versionError || !versionData) throw new Error('strategy version create failed');
    return { strategy, version: rowToVersion(versionData) };
  }

  async getWithLatestVersion(userId: string, strategyId: string): Promise<{ strategy: StrategyRow; version: StrategyVersionRow } | null> {
    const { data: strategyData, error: strategyError } = await this.db.from('strategies').select(STRATEGY_SELECT)
      .eq('id', strategyId).eq('user_id', userId).maybeSingle();
    if (strategyError) throw new Error('strategy get failed');
    if (!strategyData) return null;
    const strategy = rowToStrategy(strategyData);
    const { data: versionData, error: versionError } = await this.db.from('strategy_versions')
      .select('id, strategy_id, version_number, spec, spec_hash, created_at')
      .eq('strategy_id', strategyId).eq('user_id', userId)
      .order('version_number', { ascending: false }).limit(1).maybeSingle();
    if (versionError) throw new Error('strategy version get failed');
    if (!versionData) return null;
    return { strategy, version: rowToVersion(versionData) };
  }
}
