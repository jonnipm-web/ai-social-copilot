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
import type { BacktestCostAssumptions, CanonicalBacktestResult } from './strategy/backtest_result.ts';
import type { ExperimentCategory, ExperimentSegment, ExperimentSource } from './strategy/experiment_provenance.ts';

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
  /** MACRO-07 §14: set exactly once, by the strategy_experiments_mark_
   * holdout_viewed trigger, at the FIRST HOLDOUT-segment experiment
   * ever recorded for this strategy -- see experiment_provenance.ts's
   * computeContamination. Never written by the application directly. */
  readonly holdoutFirstViewedAt: string | null;
}

export interface StrategyExperimentRow {
  readonly id: string;
  readonly strategyId: string;
  readonly strategyVersionId: string;
  readonly category: ExperimentCategory;
  readonly datasetId: string;
  readonly segment: ExperimentSegment;
  readonly parametersChanged: Readonly<Record<string, unknown>> | null;
  readonly reason: string;
  readonly resultId: string | null;
  readonly costAssumptions: BacktestCostAssumptions | null;
  readonly source: ExperimentSource;
  readonly contaminated: boolean;
  readonly createdAt: string;
}

export interface StrategyVersionRow {
  readonly id: string;
  readonly strategyId: string;
  readonly versionNumber: number;
  readonly spec: StrategySpecification;
  readonly specHash: string;
  readonly createdAt: string;
}

export type ResultKind = 'BACKTEST' | 'SIMULATION';

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
  /** Codex final audit (P1-02 fix): set authoritatively by whichever
   * server code path produced this row (run_backtest -> 'BACKTEST',
   * run_simulation -> 'SIMULATION') -- never client-supplied. Lets
   * every consumer (compare_versions, analyze_backtest_result) tell a
   * real historical backtest apart from a simulation without relying
   * solely on a separate, client-writable experiment row. */
  readonly resultKind: ResultKind;
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

/** Codex adversarial review (2nd re-verification): a caller reused an
 * idempotency key with a DIFFERENT spec than the one it already created
 * -- a distinct request, not a genuine retry. Rejected rather than
 * silently returning the mismatched prior row. */
export class IdempotencyKeyConflictError extends Error {
  constructor() {
    super('IDEMPOTENCY_KEY_CONFLICT');
  }
}

export interface StrategyStore {
  list(userId: string): Promise<StrategyRow[]>;
  /** Creates a strategy AND its version-1 snapshot atomically. Codex
   * adversarial review (Macro-08, diff vs 15d4177): the original design
   * here assumed a partial failure was "harmless" (owner deletes the
   * orphan themselves) -- untrue, since no delete op was ever built, and
   * the orphan still burns a real, finite plan-limit slot. Routed through
   * strategies_create_with_version(), a SECURITY DEFINER RPC
   * (20261008000000) that performs both inserts in one Postgres
   * transaction. `idempotencyKey`, when supplied, makes a genuine retry
   * (not just a same-request timeout) return the ORIGINAL strategy/
   * version instead of creating a duplicate. */
  create(userId: string, spec: StrategySpecification, idempotencyKey?: string | null): Promise<{ strategy: StrategyRow; version: StrategyVersionRow }>;
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
    resultKind: ResultKind,
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
  /** MACRO-07 §15: records one experiment. `contaminated` must be
   * computed by the CALLER (experiment_provenance.ts's
   * computeContamination) from the strategy's holdoutFirstViewedAt AS
   * IT STOOD BEFORE this insert -- the store persists what it is given,
   * it does not recompute contamination itself. */
  insertExperiment(userId: string, input: {
    strategyId: string;
    strategyVersionId: string;
    category: ExperimentCategory;
    datasetId: string;
    segment: ExperimentSegment;
    parametersChanged: Readonly<Record<string, unknown>> | null;
    reason: string;
    resultId: string | null;
    costAssumptions: BacktestCostAssumptions | null;
    source: ExperimentSource;
    contaminated: boolean;
  }): Promise<StrategyExperimentRow>;
  listExperiments(userId: string, strategyId: string): Promise<StrategyExperimentRow[]>;
}

const STRATEGY_SELECT = 'id, name, status, current_version, created_at, updated_at, holdout_first_viewed_at';

function rowToStrategy(row: Record<string, unknown>): StrategyRow {
  return {
    id: String(row.id),
    name: String(row.name),
    status: row.status as StrategyStatus,
    currentVersion: Number(row.current_version),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
    holdoutFirstViewedAt: row.holdout_first_viewed_at === null || row.holdout_first_viewed_at === undefined ? null : String(row.holdout_first_viewed_at),
  };
}

function rowToExperiment(row: Record<string, unknown>): StrategyExperimentRow {
  return {
    id: String(row.id),
    strategyId: String(row.strategy_id),
    strategyVersionId: String(row.strategy_version_id),
    category: row.category as ExperimentCategory,
    datasetId: String(row.dataset_id),
    segment: row.segment as ExperimentSegment,
    parametersChanged: row.parameters_changed === null ? null : row.parameters_changed as Record<string, unknown>,
    reason: String(row.reason),
    resultId: row.result_id === null ? null : String(row.result_id),
    costAssumptions: row.cost_assumptions === null ? null : row.cost_assumptions as BacktestCostAssumptions,
    source: row.source as ExperimentSource,
    contaminated: Boolean(row.contaminated),
    createdAt: String(row.created_at),
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
    resultKind: (row.result_kind as ResultKind | undefined) ?? 'BACKTEST',
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

/**
 * Macro-08 continuation §27 (testability assessment, documented per its
 * own instruction: "assess risk... if the refactor would be
 * disproportionate, preserve indirect integration coverage and document
 * the residual" rather than performing an automatic large refactor):
 *
 * This class has no dedicated unit test of its own -- index_test.ts
 * exercises the Edge Function handler against MemoryStore (a fake), so
 * SupabaseStrategyStore's actual Supabase calls are never invoked in
 * CI. Making it directly testable would mean accepting an injectable
 * SupabaseClient (or a query-builder seam) through the constructor and
 * threading that through every one of its ~15 methods -- a real
 * surface-wide change, not a small seam.
 *
 * Decision: DEFERRED, not attempted this pass. Reasons:
 *   1. Local Postgres remains ENVIRONMENT_BLOCKED (standing project
 *      decision) -- even WITH an injectable client, nothing here could
 *      be verified against a real database in this environment; only a
 *      fake query builder could be exercised, which duplicates
 *      MemoryStore's own coverage without testing anything genuinely
 *      new (RLS, grants and RPC behavior cannot be faked meaningfully).
 *   2. The actual defect class Codex found in this exact area (the RLS
 *      predicate drift, the non-atomic create, the inert idempotency
 *      key) was caught and is now pinned by SQL-content assertions
 *      against the migration files themselves (SB-48/49/57 in
 *      strategy-builder/index_test.ts) -- a technique that has already
 *      proven effective for this class of risk without requiring a
 *      live database or a client-injection refactor.
 *   3. A surface-wide constructor change here is exactly the kind of
 *      broad, speculative refactor this session's own conventions
 *      avoid absent a concrete need ("don't design for hypothetical
 *      future requirements").
 * Residual risk, disclosed: a bug specific to how THIS class shapes a
 * PostgREST query (as opposed to what the RLS/RPC layer permits) would
 * not be caught by either MemoryStore or the SQL-content tests. Revisit
 * if/when a disposable or CI Postgres instance becomes available (§28).
 */
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

  async create(userId: string, spec: StrategySpecification, idempotencyKey?: string | null): Promise<{ strategy: StrategyRow; version: StrategyVersionRow }> {
    const specHash = (await sha256Hex(JSON.stringify(spec))).slice(0, 32);
    // Codex adversarial review (Macro-08, diff vs 15d4177): both inserts now
    // happen inside ONE Postgres transaction (the RPC's function body), so
    // a version-insert failure can no longer leave an orphan `strategies`
    // row behind -- true atomicity, not a best-effort compensating delete.
    const { data, error } = await this.db.rpc('strategies_create_with_version', {
      p_name: spec.name, p_spec: spec, p_spec_hash: specHash, p_idempotency_key: idempotencyKey ?? null,
    }).single();
    if (error?.message?.includes('STRATEGY_LIMIT_REACHED')) throw new StrategyLimitReachedError();
    if (error?.message?.includes('IDEMPOTENCY_KEY_CONFLICT')) throw new IdempotencyKeyConflictError();
    if (error || !data) throw new Error('strategy create failed');
    const row = data as Record<string, unknown>;
    return {
      strategy: rowToStrategy({
        id: row.strategy_id, name: row.strategy_name, status: row.strategy_status, current_version: row.strategy_current_version,
        created_at: row.strategy_created_at, updated_at: row.strategy_updated_at, holdout_first_viewed_at: row.strategy_holdout_first_viewed_at,
      }),
      version: rowToVersion({
        id: row.version_id, strategy_id: row.version_strategy_id, version_number: row.version_number, spec: row.version_spec, spec_hash: row.version_spec_hash,
        created_at: row.version_created_at,
      }),
    };
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
    resultKind: ResultKind,
  ): Promise<StrategyBacktestResultRow> {
    // Codex final audit re-verification (P1-02 remaining gap, fixed by
    // 20261007000000): routed through the strategy_backtest_results_
    // insert SECURITY DEFINER RPC, not a direct table insert --
    // `authenticated` has no INSERT grant on strategy_backtest_results
    // at all anymore, closing the same "bypass the app entirely via
    // PostgREST" class of gap P1-01 already closed for
    // strategy_experiments.
    const { data, error } = await this.db.rpc('strategy_backtest_results_insert', {
      p_strategy_version_id: strategyVersionId,
      p_dataset_id: result.datasetId,
      p_dataset_hash: result.datasetHash,
      p_methodology_status: result.methodologyStatus,
      p_net_pnl: result.netPnl,
      p_trade_count: result.tradeCount,
      p_result_hash: result.resultHash,
      p_canonical_result: result,
      p_result_kind: resultKind,
    }).single();
    if (error || !data) throw new Error('backtest result insert failed');
    return rowToBacktestResult(data as Record<string, unknown>);
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
      .select('id, strategy_version_id, dataset_id, dataset_hash, methodology_status, net_pnl, trade_count, result_hash, canonical_result, result_kind, created_at')
      .eq('strategy_version_id', strategyVersionId).eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(50);
    if (error) throw new Error('backtest result list failed');
    return (data ?? []).map(rowToBacktestResult);
  }

  async insertExperiment(userId: string, input: {
    strategyId: string; strategyVersionId: string; category: ExperimentCategory; datasetId: string; segment: ExperimentSegment;
    parametersChanged: Readonly<Record<string, unknown>> | null; reason: string; resultId: string | null;
    costAssumptions: BacktestCostAssumptions | null; source: ExperimentSource; contaminated: boolean;
  }): Promise<StrategyExperimentRow> {
    // Codex final audit (P1-01 fix): routed through the
    // strategy_experiments_insert SECURITY DEFINER RPC
    // (20261006000000), not a direct table insert -- `authenticated`
    // has no INSERT grant on strategy_experiments at all anymore. The
    // RPC re-validates ownership/result-dataset/category-vs-result-kind
    // itself and computes `contaminated`/`created_at` server-side;
    // `input.contaminated` (the caller's own best-effort preview,
    // computed the same way in index.ts before this call) is NOT
    // forwarded -- the RPC's own computation is authoritative and is
    // what the returned row actually reflects.
    const { data, error } = await this.db.rpc('strategy_experiments_insert', {
      p_strategy_id: input.strategyId, p_strategy_version_id: input.strategyVersionId, p_category: input.category,
      p_dataset_id: input.datasetId, p_segment: input.segment, p_parameters_changed: input.parametersChanged,
      p_reason: input.reason, p_result_id: input.resultId, p_cost_assumptions: input.costAssumptions, p_source: input.source,
    }).single();
    if (error || !data) throw new Error('experiment insert failed');
    return rowToExperiment(data as Record<string, unknown>);
  }

  async listExperiments(userId: string, strategyId: string): Promise<StrategyExperimentRow[]> {
    const { data, error } = await this.db.from('strategy_experiments')
      .select('id, strategy_id, strategy_version_id, category, dataset_id, segment, parameters_changed, reason, result_id, cost_assumptions, source, contaminated, created_at')
      .eq('strategy_id', strategyId).eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(200);
    if (error) throw new Error('experiment list failed');
    return (data ?? []).map(rowToExperiment);
  }
}
