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
import type { CanonicalBacktestResult } from './strategy/backtest_result.ts';

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

export interface StrategyBacktestResultRow {
  readonly id: string;
  readonly strategyVersionId: string;
  readonly datasetId: string;
  readonly datasetHash: string;
  readonly methodologyStatus: string;
  readonly netPnl: number;
  readonly tradeCount: number;
  readonly resultHash: string;
  readonly canonicalResult: CanonicalBacktestResult;
  readonly createdAt: string;
}

export interface StrategyBacktestJobRow {
  readonly id: string;
  readonly strategyVersionId: string;
  readonly datasetId: string;
  readonly engineId: string;
  readonly status: 'SUCCEEDED' | 'FAILED';
  readonly startedAt: string;
  readonly completedAt: string;
  readonly failureReason: string | null;
  readonly resultId: string | null;
  readonly createdAt: string;
}

/**
 * Thrown by `create` when the database's own strategies_enforce_plan_limit
 * trigger (Codex final audit, P1 fix) rejects the insert -- the
 * race-safe, authoritative check. The app-level pre-check in
 * strategy-builder/index.ts stays as a fast, friendly early exit, but this
 * is what actually fires when a caller wins the race the app-level check
 * alone could not close.
 */
export class StrategyLimitReachedError extends Error {
  constructor() {
    super('STRATEGY_LIMIT_REACHED');
  }
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
  /** §9/§29: editing a strategy's behavior creates a NEW version -- never
   * mutates an existing one. `strategy_versions_unique` (strategy_id,
   * version_number) makes a race on the next version number fail
   * (23505), surfaced here as a thrown Error so the caller can retry. */
  createNewVersion(userId: string, strategyId: string, spec: StrategySpecification): Promise<StrategyVersionRow>;
  listVersions(userId: string, strategyId: string): Promise<StrategyVersionRow[]>;
  getVersionById(userId: string, versionId: string): Promise<StrategyVersionRow | null>;
  insertBacktestResult(
    userId: string,
    strategyVersionId: string,
    result: CanonicalBacktestResult,
  ): Promise<StrategyBacktestResultRow>;
  insertFailedBacktestJob(
    userId: string,
    strategyVersionId: string,
    datasetId: string,
    engineId: string,
    startedAt: string,
    failureReason: string,
  ): Promise<StrategyBacktestJobRow>;
  insertSucceededBacktestJob(
    userId: string,
    strategyVersionId: string,
    datasetId: string,
    engineId: string,
    startedAt: string,
    resultId: string,
  ): Promise<StrategyBacktestJobRow>;
  listBacktestResultsForVersion(userId: string, strategyVersionId: string): Promise<StrategyBacktestResultRow[]>;
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

function rowToBacktestResult(row: Record<string, unknown>): StrategyBacktestResultRow {
  return {
    id: String(row.id),
    strategyVersionId: String(row.strategy_version_id),
    datasetId: String(row.dataset_id),
    datasetHash: String(row.dataset_hash),
    methodologyStatus: String(row.methodology_status),
    netPnl: Number(row.net_pnl),
    tradeCount: Number(row.trade_count),
    resultHash: String(row.result_hash),
    canonicalResult: row.canonical_result as CanonicalBacktestResult,
    createdAt: String(row.created_at),
  };
}

function rowToBacktestJob(row: Record<string, unknown>): StrategyBacktestJobRow {
  return {
    id: String(row.id),
    strategyVersionId: String(row.strategy_version_id),
    datasetId: String(row.dataset_id),
    engineId: String(row.engine_id),
    status: row.status as 'SUCCEEDED' | 'FAILED',
    startedAt: String(row.started_at),
    completedAt: String(row.completed_at),
    failureReason: row.failure_reason === null ? null : String(row.failure_reason),
    resultId: row.result_id === null ? null : String(row.result_id),
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
    if (strategyError?.message?.includes('STRATEGY_LIMIT_REACHED')) throw new StrategyLimitReachedError();
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

  async createNewVersion(userId: string, strategyId: string, spec: StrategySpecification): Promise<StrategyVersionRow> {
    const { data: existing, error: listError } = await this.db.from('strategy_versions')
      .select('version_number').eq('strategy_id', strategyId).eq('user_id', userId)
      .order('version_number', { ascending: false }).limit(1);
    if (listError) throw new Error('strategy version lookup failed');
    const nextVersion = ((existing?.[0]?.version_number as number | undefined) ?? 0) + 1;
    const specHash = (await sha256Hex(JSON.stringify(spec))).slice(0, 32);
    const { data, error } = await this.db.from('strategy_versions')
      .insert({ strategy_id: strategyId, user_id: userId, version_number: nextVersion, spec, spec_hash: specHash })
      .select('id, strategy_id, version_number, spec, spec_hash, created_at').single();
    if (error || !data) throw new Error('strategy version create failed');
    return rowToVersion(data);
  }

  async listVersions(userId: string, strategyId: string): Promise<StrategyVersionRow[]> {
    const { data, error } = await this.db.from('strategy_versions')
      .select('id, strategy_id, version_number, spec, spec_hash, created_at')
      .eq('strategy_id', strategyId).eq('user_id', userId)
      .order('version_number', { ascending: true }).limit(200);
    if (error) throw new Error('strategy version list failed');
    return (data ?? []).map(rowToVersion);
  }

  async getVersionById(userId: string, versionId: string): Promise<StrategyVersionRow | null> {
    const { data, error } = await this.db.from('strategy_versions')
      .select('id, strategy_id, version_number, spec, spec_hash, created_at')
      .eq('id', versionId).eq('user_id', userId).maybeSingle();
    if (error) throw new Error('strategy version get failed');
    return data ? rowToVersion(data) : null;
  }

  async insertBacktestResult(
    userId: string,
    strategyVersionId: string,
    result: CanonicalBacktestResult,
  ): Promise<StrategyBacktestResultRow> {
    const { data, error } = await this.db.from('strategy_backtest_results').insert({
      strategy_version_id: strategyVersionId,
      user_id: userId,
      dataset_id: result.datasetId,
      dataset_hash: result.datasetHash,
      methodology_status: result.methodologyStatus,
      net_pnl: result.netPnl,
      trade_count: result.tradeCount,
      result_hash: result.resultHash,
      canonical_result: result,
    }).select('id, strategy_version_id, dataset_id, dataset_hash, methodology_status, net_pnl, trade_count, result_hash, canonical_result, created_at').single();
    if (error || !data) throw new Error('backtest result insert failed');
    return rowToBacktestResult(data);
  }

  async insertFailedBacktestJob(
    userId: string,
    strategyVersionId: string,
    datasetId: string,
    engineId: string,
    startedAt: string,
    failureReason: string,
  ): Promise<StrategyBacktestJobRow> {
    const { data, error } = await this.db.from('strategy_backtest_jobs').insert({
      user_id: userId, strategy_version_id: strategyVersionId, dataset_id: datasetId, engine_id: engineId,
      status: 'FAILED', started_at: startedAt, completed_at: new Date().toISOString(), failure_reason: failureReason,
    }).select('id, strategy_version_id, dataset_id, engine_id, status, started_at, completed_at, failure_reason, result_id, created_at').single();
    if (error || !data) throw new Error('backtest job insert failed');
    return rowToBacktestJob(data);
  }

  async insertSucceededBacktestJob(
    userId: string,
    strategyVersionId: string,
    datasetId: string,
    engineId: string,
    startedAt: string,
    resultId: string,
  ): Promise<StrategyBacktestJobRow> {
    const { data, error } = await this.db.from('strategy_backtest_jobs').insert({
      user_id: userId, strategy_version_id: strategyVersionId, dataset_id: datasetId, engine_id: engineId,
      status: 'SUCCEEDED', started_at: startedAt, completed_at: new Date().toISOString(), result_id: resultId,
    }).select('id, strategy_version_id, dataset_id, engine_id, status, started_at, completed_at, failure_reason, result_id, created_at').single();
    if (error || !data) throw new Error('backtest job insert failed');
    return rowToBacktestJob(data);
  }

  async listBacktestResultsForVersion(userId: string, strategyVersionId: string): Promise<StrategyBacktestResultRow[]> {
    const { data, error } = await this.db.from('strategy_backtest_results')
      .select('id, strategy_version_id, dataset_id, dataset_hash, methodology_status, net_pnl, trade_count, result_hash, canonical_result, created_at')
      .eq('strategy_version_id', strategyVersionId).eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(50);
    if (error) throw new Error('backtest result list failed');
    return (data ?? []).map(rowToBacktestResult);
  }
}
