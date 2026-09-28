// strategy-builder — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05.
//
// Strategy Specification CRUD for module 'strategy-builder' (REVERSIBLE
// user config, EXPERIMENTAL/admin-only). Configuration only -- this
// function never runs a backtest and never touches AEF (§14: "Strategy
// configuration must not be executable merely because it exists").
//
// authenticate -> entitlement -> body limits -> op dispatch -> ownership
// (via the caller's own JWT; Postgres RLS from
// 20261002000000_strategy_builder.sql is the isolation authority; no
// service role).
//
// NOT DEPLOYED (Lab). Not on .github/deploy-allowlist.tsv.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthenticatedUser, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import { EntitlementSubjectSource, requireModuleAccess } from '../_shared/entitlement.ts';
import type { QuotaClient } from '../_shared/quota.ts';
import {
  bearerToken, readJsonBody, strategyCorsHeaders, StrategyLimitReachedError, SupabaseStrategyStore,
  type StrategyBacktestJobRow, type StrategyStore,
} from '../_shared/strategy_server.ts';
import { createStrategySpecification, type StrategySpecification, type StrategySpecificationInput } from '../_shared/strategy/strategy_spec.ts';
import { parseNaturalLanguageStrategyDraft } from '../_shared/strategy/nl_draft.ts';
import type { StrategyErrorCode } from '../_shared/strategy/errors.ts';
import { getDataset } from '../_shared/strategy/dataset_registry.ts';
import { ENGINE_REGISTRY, engineAcceptsRunRequest, getEngine, type EngineId } from '../_shared/strategy/engine_registry.ts';
import { runGenericRuleEngine } from '../_shared/strategy/generic_rule_engine.ts';
import { syntheticFixtureBars, syntheticFixtureHoldoutBars, syntheticFixtureResearchBars } from '../_shared/strategy/generic_engine_fixtures.ts';
import type { OhlcvBar } from '../_shared/strategy/ohlcv.ts';
import { validateOhlcvBars } from '../_shared/strategy/ohlcv.ts';
import { buildCanonicalBacktestResult, type CanonicalBacktestResult, type CanonicalBacktestResultInput } from '../_shared/strategy/backtest_result.ts';
import { compareBacktestResults } from '../_shared/strategy/comparison.ts';
import {
  checkEngineAvailability, runV10ViaBridge, DEFAULT_BRIDGE_TIMEOUT_MS, type BridgeCostConfig,
} from '../_shared/strategy/backtest_bridge.ts';
import { V10_REFERENCE_SPEC_INPUT } from '../_shared/strategy/v10_reference.ts';
import { GENERIC_REFERENCE_SPEC_INPUT } from '../_shared/strategy/generic_reference_strategy.ts';
import { analyzeBacktestResult } from '../_shared/strategy/ive_strategy_analyst.ts';
import { computeMarketStatistics } from '../_shared/strategy/market_statistics.ts';
import { analyzeStrategyMarketFit } from '../_shared/strategy/strategy_market_fit.ts';
import { MAX_BOUNDED_VARIANTS, proposeBoundedStopVariants } from '../_shared/strategy/bounded_exploration.ts';
import { directionalBalance, executionAmbiguityRate, sampleSizeSufficiency } from '../_shared/strategy/robustness.ts';
import { computeStrategyScore } from '../_shared/strategy/strategy_score.ts';
import { STRATEGY_OBJECTIVES, type StrategyObjective } from '../_shared/strategy/user_objective.ts';
import {
  computeContamination, validateStrategyExperimentInput, type ExperimentCategory, type ExperimentSegment, type ExperimentSource,
} from '../_shared/strategy/experiment_provenance.ts';

export interface StrategyBuilderDeps {
  storeFor?: (accessToken: string) => StrategyStore;
  log?: (line: string) => void;
  bridgeBaseUrl?: string;
}

const OPS = new Set([
  'validate', 'draft_from_text', 'create', 'list', 'get',
  'create_version', 'list_versions', 'run_backtest', 'compare_versions', 'clone_reference',
  'analyze_backtest_result', 'engine_status',
  'propose_variants', 'record_experiment', 'list_experiments', 'run_research_loop', 'run_simulation',
]);

/** MACRO-07 §33-35: robustness/experiment ops are the first real
 * plan-gated Strategy Intelligence surface -- validation, security and
 * the safety-critical ops above stay ungated (§35: "Safety is not
 * Premium"); only the RESEARCH capability itself requires pro/premium. */
const RESEARCH_OPS = new Set(['propose_variants', 'record_experiment', 'list_experiments', 'run_research_loop', 'run_simulation']);
const PLAN_RANK: Record<string, number> = { free: 0, pro: 1, premium: 2 };

/**
 * Extracted as a pure function specifically so it is unit-testable
 * without a real HTTP round-trip: the module's CURRENT lifecycle
 * (EXPERIMENTAL) makes it impossible to reach this code at all as a
 * non-admin caller (requireModuleAccess denies everyone else first),
 * so an end-to-end test can only ever exercise the ADMIN_ROLE bypass
 * branch, never the plan-tier denial branch it exists to enforce for
 * a FUTURE non-admin caller. This function lets that denial branch be
 * verified directly, honestly, rather than left untested because the
 * integration path to reach it does not exist yet.
 */
export function planAllowsResearchOp(op: string, plan: string, decisionReason: string): boolean {
  if (!RESEARCH_OPS.has(op)) return true;
  if (decisionReason === 'ADMIN_ROLE') return true;
  return (PLAN_RANK[plan] ?? 0) >= PLAN_RANK.pro;
}

interface ValidateOp { readonly op: 'validate'; readonly spec: StrategySpecificationInput }
interface DraftFromTextOp { readonly op: 'draft_from_text'; readonly text: string }
interface CreateOp { readonly op: 'create'; readonly spec: StrategySpecificationInput }
interface ListOp { readonly op: 'list' }
interface GetOp { readonly op: 'get'; readonly strategyId: string }
interface CreateVersionOp { readonly op: 'create_version'; readonly strategyId: string; readonly spec: StrategySpecificationInput }
interface ListVersionsOp { readonly op: 'list_versions'; readonly strategyId: string }
interface RunBacktestOp {
  readonly op: 'run_backtest';
  readonly strategyVersionId: string;
  readonly datasetId: string;
  readonly engineId: string;
  readonly costConfig: BridgeCostConfig | null;
}
interface CompareVersionsOp {
  readonly op: 'compare_versions';
  readonly versionAId: string;
  readonly versionBId: string;
  readonly objective: StrategyObjective | null;
}
interface CloneReferenceOp { readonly op: 'clone_reference'; readonly reference: 'V10' | 'GENERIC' }
interface AnalyzeBacktestResultOp { readonly op: 'analyze_backtest_result'; readonly strategyVersionId: string }
interface EngineStatusOp { readonly op: 'engine_status' }
interface ProposeVariantsOp { readonly op: 'propose_variants'; readonly strategyVersionId: string; readonly datasetId: string }
interface RecordExperimentOp {
  readonly op: 'record_experiment';
  readonly strategyVersionId: string;
  readonly category: string;
  readonly datasetId: string;
  readonly segment: string;
  readonly parametersChanged: Record<string, unknown> | null;
  readonly reason: string;
  readonly resultId: string | null;
  readonly source: string;
}
interface ListExperimentsOp { readonly op: 'list_experiments'; readonly strategyId: string }
interface RunResearchLoopOp { readonly op: 'run_research_loop'; readonly strategyVersionId: string; readonly datasetId: string }
interface RunSimulationOp { readonly op: 'run_simulation'; readonly strategyVersionId: string; readonly datasetId: string }
type ParsedOp =
  | ValidateOp | DraftFromTextOp | CreateOp | ListOp | GetOp
  | CreateVersionOp | ListVersionsOp | RunBacktestOp | CompareVersionsOp | CloneReferenceOp
  | AnalyzeBacktestResultOp | EngineStatusOp
  | ProposeVariantsOp | RecordExperimentOp | ListExperimentsOp | RunResearchLoopOp | RunSimulationOp;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(v: unknown): v is string {
  return typeof v === 'string' && UUID_RE.test(v);
}

function parseCostConfig(v: unknown): BridgeCostConfig | null {
  if (v === null || v === undefined) return null;
  if (typeof v !== 'object') return null;
  const c = v as Record<string, unknown>;
  if (typeof c.brokeragePerContract !== 'number' || typeof c.exchangeFeePerContract !== 'number' || typeof c.slippageTicks !== 'number') {
    return null;
  }
  return { brokeragePerContract: c.brokeragePerContract, exchangeFeePerContract: c.exchangeFeePerContract, slippageTicks: c.slippageTicks };
}

function parseOp(body: unknown): { ok: true; value: ParsedOp } | { ok: false; code: string } {
  if (!body || typeof body !== 'object') return { ok: false, code: 'INVALID_BODY' };
  const b = body as Record<string, unknown>;
  if (typeof b.op !== 'string' || !OPS.has(b.op)) return { ok: false, code: 'UNKNOWN_OP' };
  switch (b.op) {
    case 'validate':
    case 'create':
      if (!b.spec || typeof b.spec !== 'object') return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: b.op, spec: b.spec as StrategySpecificationInput } };
    case 'draft_from_text':
      if (typeof b.text !== 'string' || b.text.length === 0 || b.text.length > 2000) return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'draft_from_text', text: b.text } };
    case 'list':
      return { ok: true, value: { op: 'list' } };
    case 'get':
      if (!isUuid(b.strategyId)) return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'get', strategyId: b.strategyId } };
    case 'create_version':
      if (!isUuid(b.strategyId) || !b.spec || typeof b.spec !== 'object') return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'create_version', strategyId: b.strategyId, spec: b.spec as StrategySpecificationInput } };
    case 'list_versions':
      if (!isUuid(b.strategyId)) return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'list_versions', strategyId: b.strategyId } };
    case 'run_backtest':
      if (!isUuid(b.strategyVersionId) || typeof b.datasetId !== 'string' || typeof b.engineId !== 'string') {
        return { ok: false, code: 'INVALID_BODY' };
      }
      return {
        ok: true,
        value: {
          op: 'run_backtest', strategyVersionId: b.strategyVersionId, datasetId: b.datasetId, engineId: b.engineId,
          costConfig: parseCostConfig(b.costConfig),
        },
      };
    case 'compare_versions': {
      if (!isUuid(b.versionAId) || !isUuid(b.versionBId)) return { ok: false, code: 'INVALID_BODY' };
      const objective = typeof b.objective === 'string' && STRATEGY_OBJECTIVES.includes(b.objective as StrategyObjective) ? (b.objective as StrategyObjective) : null;
      return { ok: true, value: { op: 'compare_versions', versionAId: b.versionAId, versionBId: b.versionBId, objective } };
    }
    case 'clone_reference':
      if (b.reference !== 'V10' && b.reference !== 'GENERIC') return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'clone_reference', reference: b.reference } };
    case 'analyze_backtest_result':
      if (!isUuid(b.strategyVersionId)) return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'analyze_backtest_result', strategyVersionId: b.strategyVersionId } };
    case 'engine_status':
      return { ok: true, value: { op: 'engine_status' } };
    case 'propose_variants':
      if (!isUuid(b.strategyVersionId) || typeof b.datasetId !== 'string') return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'propose_variants', strategyVersionId: b.strategyVersionId, datasetId: b.datasetId } };
    case 'record_experiment': {
      if (
        !isUuid(b.strategyVersionId) || typeof b.category !== 'string' || typeof b.datasetId !== 'string'
        || typeof b.segment !== 'string' || typeof b.reason !== 'string' || typeof b.source !== 'string'
      ) {
        return { ok: false, code: 'INVALID_BODY' };
      }
      if (b.parametersChanged !== null && b.parametersChanged !== undefined && (typeof b.parametersChanged !== 'object' || Array.isArray(b.parametersChanged))) {
        return { ok: false, code: 'INVALID_BODY' };
      }
      if (b.resultId !== null && b.resultId !== undefined && !isUuid(b.resultId)) return { ok: false, code: 'INVALID_BODY' };
      return {
        ok: true,
        value: {
          op: 'record_experiment', strategyVersionId: b.strategyVersionId, category: b.category, datasetId: b.datasetId,
          segment: b.segment, parametersChanged: (b.parametersChanged as Record<string, unknown> | null) ?? null,
          reason: b.reason, resultId: (b.resultId as string | null) ?? null, source: b.source,
        },
      };
    }
    case 'list_experiments':
      if (!isUuid(b.strategyId)) return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'list_experiments', strategyId: b.strategyId } };
    case 'run_research_loop':
      if (!isUuid(b.strategyVersionId) || typeof b.datasetId !== 'string') return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'run_research_loop', strategyVersionId: b.strategyVersionId, datasetId: b.datasetId } };
    case 'run_simulation':
      if (!isUuid(b.strategyVersionId) || typeof b.datasetId !== 'string') return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'run_simulation', strategyVersionId: b.strategyVersionId, datasetId: b.datasetId } };
    default:
      return { ok: false, code: 'UNKNOWN_OP' };
  }
}

function errorResponse(code: string, correlationId: string, status: number): Response {
  return new Response(JSON.stringify({ error: code, correlation_id: correlationId }), {
    status,
    headers: { ...strategyCorsHeaders, 'Content-Type': 'application/json' },
  });
}

function jsonResponse(body: unknown): Response {
  return new Response(JSON.stringify(body), { status: 200, headers: { ...strategyCorsHeaders, 'Content-Type': 'application/json' } });
}

/**
 * Runs the GENERIC_RULE_ENGINE against `bars` and folds the result into
 * a CanonicalBacktestResult, exactly once -- shared by run_backtest's
 * IN_PROCESS branch and run_research_loop, so a bounded-exploration
 * candidate is built by the SAME code path as an ordinary backtest,
 * never a second, drifting implementation.
 */
async function runGenericEngineAndBuildResult(
  spec: StrategySpecification,
  bars: readonly OhlcvBar[],
  commonInput: Pick<CanonicalBacktestResultInput,
    'strategyId' | 'strategyVersion' | 'strategySpecHash' | 'datasetId' | 'datasetHash' | 'instrumentSymbol' | 'periodStart' | 'periodEnd' | 'timeframes' | 'limitations'>,
): Promise<{ ok: true; value: CanonicalBacktestResult } | { ok: false; code: string; message: string }> {
  const barsError = validateOhlcvBars(bars);
  if (barsError) return { ok: false, code: 'INVALID_STRATEGY_SPEC', message: barsError };
  const runResult = runGenericRuleEngine(spec, bars);
  if (!runResult.ok) return { ok: false, code: runResult.error.code, message: runResult.error.message };
  const wins = runResult.value.trades.filter((t) => t.grossPnlPoints > 0).length;
  const losses = runResult.value.trades.filter((t) => t.grossPnlPoints < 0).length;
  const grossProfit = runResult.value.trades.filter((t) => t.grossPnlPoints > 0).reduce((s, t) => s + t.grossPnlPoints, 0);
  const grossLoss = -runResult.value.trades.filter((t) => t.grossPnlPoints < 0).reduce((s, t) => s + t.grossPnlPoints, 0);
  const netPnl = runResult.value.trades.reduce((s, t) => s + t.grossPnlPoints, 0);
  const resultInput: CanonicalBacktestResultInput = {
    ...commonInput,
    tradeCount: runResult.value.trades.length,
    longCount: runResult.value.trades.filter((t) => t.direction === 'LONG').length,
    shortCount: runResult.value.trades.filter((t) => t.direction === 'SHORT').length,
    wins, losses, grossPnl: netPnl, grossProfit, grossLoss, totalCost: 0, netPnl,
    maxDrawdown: null,
    targetTouches: runResult.value.trades.filter((t) => t.exitReason === 'TARGET').length,
    stopTouches: runResult.value.trades.filter((t) => t.exitReason === 'STOP').length,
    executionAmbiguityCount: 0,
    methodologyStatus: 'ZERO_COST_RESEARCH',
    costAssumptions: null,
    provenance: 'GENERIC_RULE_ENGINE, in-process, this request.',
  };
  const built = await buildCanonicalBacktestResult(resultInput);
  if (!built.ok) return { ok: false, code: built.error.code, message: built.error.message };
  return { ok: true, value: built.value };
}

/** MACRO-07 §14: the only three in-process dataset ids ever resolve to
 * bars this way -- an id outside this map never reaches this function
 * (engine_registry.ts's allowlist and the rowsAvailableInProcess check
 * both refuse it first). */
const IN_PROCESS_BARS_BY_DATASET_ID: Readonly<Record<string, () => readonly OhlcvBar[]>> = Object.freeze({
  'synthetic-fixture-5min-v1': syntheticFixtureBars,
  'synthetic-fixture-5min-v1-research': syntheticFixtureResearchBars,
  'synthetic-fixture-5min-v1-holdout': syntheticFixtureHoldoutBars,
});

/**
 * Records the SUCCEEDED job row for an already-persisted backtest result.
 * By this point the real result is durably saved -- if the job-row write
 * itself throws, that must NOT fall through to run_backtest's outer catch,
 * which would otherwise insert a FAILED job for a backtest that actually
 * succeeded, misrepresenting the audit trail and orphaning the real result
 * (Codex final audit, P2 fix). The result is still returned to the caller
 * either way; only the job-row bookkeeping is best-effort here.
 */
async function recordSucceededJob(
  store: StrategyStore, userId: string, versionId: string, datasetId: string, engineId: string, startedAt: string, resultId: string,
): Promise<StrategyBacktestJobRow | null> {
  try {
    return await store.insertSucceededBacktestJob(userId, versionId, datasetId, engineId, startedAt, resultId);
  } catch (e) {
    console.error('recordSucceededJob: job-row write failed after a successful backtest result was already saved', e);
    return null;
  }
}

/**
 * §43: candidate per-plan strategy count limits. Safety controls (spec
 * validation, RLS, engine allowlisting) are NEVER paywalled -- only the
 * count of strategies a plan may hold is. `strategy-builder` itself stays
 * EXPERIMENTAL/admin-only for now (module_policy.ts) -- these limits are
 * real, enforced architecture ready for the day the module is released
 * to non-admin plans, not yet a live commercial gate.
 */
const STRATEGY_LIMIT_BY_PLAN: Record<string, number> = { free: 3, pro: 20, premium: Number.POSITIVE_INFINITY };
const DEFAULT_STRATEGY_LIMIT = STRATEGY_LIMIT_BY_PLAN.free;

const STRATEGY_ERROR_STATUS: Record<StrategyErrorCode, number> = {
  INVALID_STRATEGY_SPEC: 400,
  UNSUPPORTED_RULE: 400,
  UNSUPPORTED_TIMEFRAME: 400,
  MISSING_REQUIRED_RULE: 400,
  CONTRADICTORY_CONFIGURATION: 400,
  INVALID_MARKET_PROFILE: 400,
  INVALID_SESSION_WINDOW: 400,
  INVALID_POSITION_SIZE: 400,
  INVALID_RISK_PARAMETER: 400,
  DATA_REQUIREMENT_UNMET: 400,
  PROMOTION_DENIED: 409,
  NOT_COMPARABLE: 409,
  AMBIGUOUS_NATURAL_LANGUAGE: 400,
};

export async function handler(
  req: Request,
  authClient?: AuthClient,
  _quotaClient?: QuotaClient,
  subjectSource?: EntitlementSubjectSource,
  deps: StrategyBuilderDeps = {},
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: strategyCorsHeaders });

  let authUser: AuthenticatedUser;
  try {
    authUser = await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(strategyCorsHeaders);
    throw e;
  }

  const access = await requireModuleAccess(req, authUser, 'strategy-builder', strategyCorsHeaders, subjectSource);
  if (!access.allowed) return access.response;
  const cid = access.correlationId;
  const log = deps.log ?? ((line: string) => console.log(line));

  if (req.method !== 'POST') return errorResponse('METHOD_NOT_ALLOWED', cid, 405);
  const bodyResult = await readJsonBody(req);
  if (!bodyResult.ok) return errorResponse(bodyResult.code, cid, bodyResult.code === 'BODY_TOO_LARGE' ? 413 : 400);
  const parsed = parseOp(bodyResult.value);
  if (!parsed.ok) return errorResponse(parsed.code, cid, 400);
  const action = parsed.value;

  if (!planAllowsResearchOp(action.op, access.subject.plan ?? 'free', access.decision.reason)) {
    return errorResponse('PLAN_UPGRADE_REQUIRED', cid, 403);
  }

  const started = performance.now();
  const finish = (status: number, errorCode: string | null) => {
    log(JSON.stringify({
      event: 'strategy_builder', operation: action.op, status, error_code: errorCode,
      latency_ms: Math.round(performance.now() - started), correlation_id: cid,
    }));
  };

  try {
    switch (action.op) {
      case 'validate': {
        const result = createStrategySpecification(action.spec);
        finish(200, result.ok ? null : result.error.code);
        return jsonResponse({ correlation_id: cid, valid: result.ok, spec: result.ok ? result.value : null, error: result.ok ? null : result.error });
      }
      case 'draft_from_text': {
        const draft = parseNaturalLanguageStrategyDraft(action.text);
        finish(200, null);
        return jsonResponse({ correlation_id: cid, draft });
      }
      case 'create': {
        const validated = createStrategySpecification(action.spec);
        if (!validated.ok) {
          finish(STRATEGY_ERROR_STATUS[validated.error.code], validated.error.code);
          return errorResponse(validated.error.code, cid, STRATEGY_ERROR_STATUS[validated.error.code]);
        }
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const plan = access.subject.plan ?? 'free';
        const limit = STRATEGY_LIMIT_BY_PLAN[plan] ?? DEFAULT_STRATEGY_LIMIT;
        const existing = await store.list(authUser.id);
        if (existing.length >= limit) {
          finish(403, 'STRATEGY_LIMIT_REACHED');
          return errorResponse('STRATEGY_LIMIT_REACHED', cid, 403);
        }
        // Codex final audit (P1): the check above is a fast, friendly
        // pre-check only -- it has a time-of-check-to-time-of-use gap a
        // concurrent request can win. The database's own
        // strategies_enforce_plan_limit trigger (migration
        // 20261004000000) is the race-safe authority; StrategyLimitReachedError
        // is what it raises when a caller actually wins that race.
        let created;
        try {
          created = await store.create(authUser.id, validated.value);
        } catch (e) {
          if (e instanceof StrategyLimitReachedError) {
            finish(403, 'STRATEGY_LIMIT_REACHED');
            return errorResponse('STRATEGY_LIMIT_REACHED', cid, 403);
          }
          throw e;
        }
        finish(200, null);
        return jsonResponse({ correlation_id: cid, strategy: created.strategy, version: created.version });
      }
      case 'list': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const strategies = await store.list(authUser.id);
        finish(200, null);
        return jsonResponse({ correlation_id: cid, strategies });
      }
      case 'get': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const found = await store.getWithLatestVersion(authUser.id, action.strategyId);
        finish(found ? 200 : 404, found ? null : 'NOT_FOUND');
        if (!found) return errorResponse('NOT_FOUND', cid, 404);
        return jsonResponse({ correlation_id: cid, strategy: found.strategy, version: found.version });
      }
      case 'create_version': {
        const validated = createStrategySpecification(action.spec);
        if (!validated.ok) {
          finish(STRATEGY_ERROR_STATUS[validated.error.code], validated.error.code);
          return errorResponse(validated.error.code, cid, STRATEGY_ERROR_STATUS[validated.error.code]);
        }
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        try {
          // §9/§29: this always creates a NEW row -- the prior version's
          // spec is never touched (immutable, enforced by the migration's
          // own missing UPDATE grant, not merely by this code path).
          const version = await store.createNewVersion(authUser.id, action.strategyId, validated.value);
          finish(200, null);
          return jsonResponse({ correlation_id: cid, version });
        } catch {
          finish(404, 'NOT_FOUND');
          return errorResponse('NOT_FOUND', cid, 404);
        }
      }
      case 'list_versions': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const versions = await store.listVersions(authUser.id, action.strategyId);
        finish(200, null);
        return jsonResponse({ correlation_id: cid, versions });
      }
      case 'clone_reference': {
        const specInput = action.reference === 'V10' ? V10_REFERENCE_SPEC_INPUT : GENERIC_REFERENCE_SPEC_INPUT;
        const validated = createStrategySpecification(specInput);
        if (!validated.ok) {
          // Would only happen if a reference spec itself regressed -- not
          // a caller error, but still never silently succeed.
          finish(500, validated.error.code);
          return errorResponse('INTERNAL_ERROR', cid, 500);
        }
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const clonePlan = access.subject.plan ?? 'free';
        const cloneLimit = STRATEGY_LIMIT_BY_PLAN[clonePlan] ?? DEFAULT_STRATEGY_LIMIT;
        if ((await store.list(authUser.id)).length >= cloneLimit) {
          finish(403, 'STRATEGY_LIMIT_REACHED');
          return errorResponse('STRATEGY_LIMIT_REACHED', cid, 403);
        }
        // §10: cloning creates the CALLER's own new strategy identity --
        // the reference's own historical version is never touched (there
        // is, in fact, no persisted "reference" row at all to touch;
        // V10_REFERENCE_SPEC_INPUT/GENERIC_REFERENCE_SPEC_INPUT are code
        // constants, not database rows).
        let clonedCreated;
        try {
          clonedCreated = await store.create(authUser.id, validated.value);
        } catch (e) {
          if (e instanceof StrategyLimitReachedError) {
            finish(403, 'STRATEGY_LIMIT_REACHED');
            return errorResponse('STRATEGY_LIMIT_REACHED', cid, 403);
          }
          throw e;
        }
        finish(200, null);
        return jsonResponse({ correlation_id: cid, strategy: clonedCreated.strategy, version: clonedCreated.version, clonedFrom: action.reference });
      }
      case 'run_backtest': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const version = await store.getVersionById(authUser.id, action.strategyVersionId);
        if (!version) {
          finish(404, 'NOT_FOUND');
          return errorResponse('NOT_FOUND', cid, 404);
        }
        const dataset = getDataset(action.datasetId);
        if (!dataset) {
          finish(400, 'UNKNOWN_DATASET');
          return errorResponse('UNKNOWN_DATASET', cid, 400);
        }
        const engine = getEngine(action.engineId);
        if (!engine) {
          finish(400, 'UNKNOWN_ENGINE');
          return errorResponse('UNKNOWN_ENGINE', cid, 400);
        }
        const spec = version.spec;
        const ruleIds = [
          spec.entry.ruleId, spec.stop.ruleId, spec.target.ruleId,
          ...(spec.breakEven ? [spec.breakEven.ruleId] : []),
          spec.session.ruleId, spec.forcedExit.ruleId, spec.positionSize.ruleId,
        ];
        const refusal = engineAcceptsRunRequest(action.engineId, ruleIds, action.datasetId);
        const startedAt = new Date().toISOString();
        if (refusal) {
          const job = await store.insertFailedBacktestJob(authUser.id, version.id, action.datasetId, action.engineId, startedAt, refusal);
          finish(200, 'ENGINE_REFUSED');
          return jsonResponse({ correlation_id: cid, job, result: null });
        }

        const commonInput = {
          strategyId: version.strategyId,
          strategyVersion: version.versionNumber,
          strategySpecHash: version.specHash,
          datasetId: dataset.datasetId,
          datasetHash: dataset.hash,
          instrumentSymbol: dataset.instrumentSymbol,
          periodStart: dataset.periodStart,
          periodEnd: dataset.periodEnd,
          timeframes: [dataset.timeframe],
          limitations: engine.engineId === 'GENERIC_RULE_ENGINE'
            ? ['Generic in-process engine: single-direction session-open entry only, no no-trade-reason taxonomy.']
            : ['5-minute dataset only; no real 1-minute execution data available.'],
        };

        try {
          if (engine.kind === 'IN_PROCESS') {
            const barsFn = dataset.rowsAvailableInProcess ? IN_PROCESS_BARS_BY_DATASET_ID[dataset.datasetId] : undefined;
            if (!barsFn) {
              const job = await store.insertFailedBacktestJob(authUser.id, version.id, action.datasetId, action.engineId, startedAt, 'dataset has no in-process rows');
              finish(200, 'DATA_REQUIREMENT_UNMET');
              return jsonResponse({ correlation_id: cid, job, result: null });
            }
            const bars = barsFn();
            const built = await runGenericEngineAndBuildResult(spec, bars, commonInput);
            if (!built.ok) {
              const job = await store.insertFailedBacktestJob(authUser.id, version.id, action.datasetId, action.engineId, startedAt, built.message);
              finish(200, built.code);
              return jsonResponse({ correlation_id: cid, job, result: null });
            }
            const savedResult = await store.insertBacktestResult(authUser.id, version.id, built.value);
            const job = await recordSucceededJob(store, authUser.id, version.id, action.datasetId, action.engineId, startedAt, savedResult.id);
            finish(200, null);
            return jsonResponse({ correlation_id: cid, job, result: savedResult });
          }

          // EXTERNAL_PYTHON_SERVICE (PAULO_TREND_FIBONACCI_V10)
          const baseUrl = deps.bridgeBaseUrl ?? Deno.env.get('BACKTEST_BRIDGE_URL') ?? 'http://127.0.0.1:8737';
          const bridgeResult = await runV10ViaBridge({ baseUrl, timeoutMs: DEFAULT_BRIDGE_TIMEOUT_MS }, action.datasetId, spec, action.costConfig);
          if (!bridgeResult.ok) {
            const job = await store.insertFailedBacktestJob(authUser.id, version.id, action.datasetId, action.engineId, startedAt, bridgeResult.error.message);
            finish(200, bridgeResult.error.code);
            return jsonResponse({ correlation_id: cid, job, result: null });
          }
          const b = bridgeResult.value;
          const resultInput: CanonicalBacktestResultInput = {
            ...commonInput,
            datasetHash: b.datasetHash,
            tradeCount: b.tradeCount,
            longCount: b.longCount,
            shortCount: b.shortCount,
            wins: b.wins,
            losses: b.losses,
            grossPnl: b.grossPnl,
            grossProfit: b.grossProfit,
            grossLoss: b.grossLoss,
            totalCost: b.totalCost,
            netPnl: b.netPnl,
            maxDrawdown: null,
            targetTouches: b.targetTouches,
            stopTouches: b.stopTouches,
            executionAmbiguityCount: b.executionAmbiguityCount,
            methodologyStatus: action.costConfig ? 'COST_ADJUSTED' : 'ZERO_COST_RESEARCH',
            costAssumptions: action.costConfig ? { ...action.costConfig, source: 'run_backtest request' } : null,
            provenance: `Python V10 bridge (${b.engine}); bridge result_hash=${b.resultHash}.`,
          };
          const built = await buildCanonicalBacktestResult(resultInput);
          if (!built.ok) {
            const job = await store.insertFailedBacktestJob(authUser.id, version.id, action.datasetId, action.engineId, startedAt, built.error.message);
            finish(200, built.error.code);
            return jsonResponse({ correlation_id: cid, job, result: null });
          }
          const savedResult = await store.insertBacktestResult(authUser.id, version.id, built.value);
          const job = await recordSucceededJob(store, authUser.id, version.id, action.datasetId, action.engineId, startedAt, savedResult.id);
          finish(200, null);
          return jsonResponse({ correlation_id: cid, job, result: savedResult });
        } catch (e) {
          const job = await store.insertFailedBacktestJob(
            authUser.id, version.id, action.datasetId, action.engineId, startedAt,
            e instanceof Error ? e.message : 'unknown error',
          ).catch(() => null);
          finish(500, 'INTERNAL_ERROR');
          return jsonResponse({ correlation_id: cid, job, result: null });
        }
      }
      case 'compare_versions': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const [resultsA, resultsB] = await Promise.all([
          store.listBacktestResultsForVersion(authUser.id, action.versionAId),
          store.listBacktestResultsForVersion(authUser.id, action.versionBId),
        ]);
        if (resultsA.length === 0 || resultsB.length === 0) {
          finish(404, 'NOT_FOUND');
          return errorResponse('NO_BACKTEST_RESULT', cid, 404);
        }
        const comparison = compareBacktestResults(resultsA[0].canonicalResult, resultsB[0].canonicalResult);
        if (!comparison.ok) {
          finish(STRATEGY_ERROR_STATUS[comparison.error.code], comparison.error.code);
          return errorResponse(comparison.error.code, cid, STRATEGY_ERROR_STATUS[comparison.error.code]);
        }
        // §21 Comparison 2.0: alongside the raw P&L/trade-count delta,
        // surface robustness and score for EACH side independently --
        // never a single "winner" verdict, never language claiming a
        // guaranteed best strategy (§18).
        const resultA = resultsA[0].canonicalResult;
        const resultB = resultsB[0].canonicalResult;
        const robustnessFor = (r: typeof resultA) => ({
          sampleSize: sampleSizeSufficiency(r), executionAmbiguity: executionAmbiguityRate(r), directionalBalance: directionalBalance(r),
        });
        finish(200, null);
        return jsonResponse({
          correlation_id: cid,
          comparison: comparison.value,
          robustnessA: robustnessFor(resultA),
          robustnessB: robustnessFor(resultB),
          scoreA: computeStrategyScore(resultA, action.objective),
          scoreB: computeStrategyScore(resultB, action.objective),
        });
      }
      case 'analyze_backtest_result': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const results = await store.listBacktestResultsForVersion(authUser.id, action.strategyVersionId);
        if (results.length === 0) {
          finish(404, 'NOT_FOUND');
          return errorResponse('NO_BACKTEST_RESULT', cid, 404);
        }
        // §23/§28: claims are derived ONLY from the caller's OWN, already
        // server-persisted result -- no raw object is ever handed to any
        // LLM here; analyzeBacktestResult is pure and deterministic.
        const claims = analyzeBacktestResult(results[0].canonicalResult);
        finish(200, null);
        return jsonResponse({ correlation_id: cid, claims });
      }
      case 'engine_status': {
        // MACRO-07 §5: lets the UI show "V10 unavailable right now" up
        // front instead of only after a user clicks Run and waits for a
        // failed job. IN_PROCESS engines never leave this process, so
        // they are always available; only EXTERNAL_PYTHON_SERVICE
        // engines need an actual health check against the bridge.
        const baseUrl = deps.bridgeBaseUrl ?? Deno.env.get('BACKTEST_BRIDGE_URL') ?? 'http://127.0.0.1:8737';
        const engines = await Promise.all(ENGINE_REGISTRY.map(async (e) => {
          if (e.kind === 'IN_PROCESS') return { engineId: e.engineId, available: true, reason: null };
          const status = await checkEngineAvailability({ baseUrl, timeoutMs: DEFAULT_BRIDGE_TIMEOUT_MS });
          return { engineId: e.engineId, available: status.available, reason: status.reason };
        }));
        finish(200, null);
        return jsonResponse({ correlation_id: cid, engines });
      }
      case 'propose_variants': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const version = await store.getVersionById(authUser.id, action.strategyVersionId);
        if (!version) {
          finish(404, 'NOT_FOUND');
          return errorResponse('NOT_FOUND', cid, 404);
        }
        const dataset = getDataset(action.datasetId);
        if (!dataset) {
          finish(400, 'UNKNOWN_DATASET');
          return errorResponse('UNKNOWN_DATASET', cid, 400);
        }
        const barsFn = dataset.rowsAvailableInProcess ? IN_PROCESS_BARS_BY_DATASET_ID[dataset.datasetId] : undefined;
        if (!barsFn) {
          finish(400, 'DATA_REQUIREMENT_UNMET');
          return errorResponse('DATA_REQUIREMENT_UNMET', cid, 400);
        }
        const bars = barsFn();
        const statsResult = computeMarketStatistics(bars, dataset.timeframe);
        if (!statsResult.ok) {
          finish(STRATEGY_ERROR_STATUS[statsResult.error.code], statsResult.error.code);
          return errorResponse(statsResult.error.code, cid, STRATEGY_ERROR_STATUS[statsResult.error.code]);
        }
        const fitEvidence = analyzeStrategyMarketFit(version.spec, statsResult.value, bars);
        const proposals = proposeBoundedStopVariants(version.spec, fitEvidence);
        finish(200, null);
        return jsonResponse({ correlation_id: cid, fitEvidence, proposals });
      }
      case 'record_experiment': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const version = await store.getVersionById(authUser.id, action.strategyVersionId);
        if (!version) {
          finish(404, 'NOT_FOUND');
          return errorResponse('NOT_FOUND', cid, 404);
        }
        const dataset = getDataset(action.datasetId);
        if (!dataset) {
          finish(400, 'UNKNOWN_DATASET');
          return errorResponse('UNKNOWN_DATASET', cid, 400);
        }
        // The dataset itself, not the caller's say-so, decides whether
        // this experiment may be labeled RESEARCH/HOLDOUT/FULL --
        // otherwise a caller could claim a HOLDOUT segment for a FULL
        // dataset run and never trigger contamination tracking.
        const expectedSegment: ExperimentSegment = dataset.segmentKind ?? 'FULL';
        if (action.segment !== expectedSegment) {
          finish(400, 'INVALID_BODY');
          return errorResponse('INVALID_BODY', cid, 400);
        }
        let resultId: string | null = null;
        if (action.resultId) {
          const results = await store.listBacktestResultsForVersion(authUser.id, version.id);
          const match = results.find((r) => r.id === action.resultId);
          if (!match || match.datasetId !== action.datasetId) {
            finish(400, 'INVALID_BODY');
            return errorResponse('INVALID_BODY', cid, 400);
          }
          resultId = match.id;
        }
        const candidateInput = {
          strategyId: version.strategyId, strategyVersionId: version.id, category: action.category as ExperimentCategory,
          datasetId: action.datasetId, segment: action.segment as ExperimentSegment, parametersChanged: action.parametersChanged,
          reason: action.reason, resultId, costAssumptions: null, source: action.source as ExperimentSource,
        };
        const validated = validateStrategyExperimentInput(candidateInput);
        if (!validated.ok) {
          finish(STRATEGY_ERROR_STATUS[validated.error.code] ?? 400, validated.error.code);
          return errorResponse(validated.error.code, cid, STRATEGY_ERROR_STATUS[validated.error.code] ?? 400);
        }
        const strategyWithVersion = await store.getWithLatestVersion(authUser.id, version.strategyId);
        const holdoutFirstViewedAt = strategyWithVersion?.strategy.holdoutFirstViewedAt ?? null;
        const nowIso = new Date().toISOString();
        const contaminated = computeContamination(holdoutFirstViewedAt, nowIso, expectedSegment === 'HOLDOUT');
        const experiment = await store.insertExperiment(authUser.id, { ...validated.value, contaminated });
        finish(200, null);
        return jsonResponse({ correlation_id: cid, experiment });
      }
      case 'list_experiments': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const experiments = await store.listExperiments(authUser.id, action.strategyId);
        finish(200, null);
        return jsonResponse({ correlation_id: cid, experiments });
      }
      case 'run_research_loop': {
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const version = await store.getVersionById(authUser.id, action.strategyVersionId);
        if (!version) {
          finish(404, 'NOT_FOUND');
          return errorResponse('NOT_FOUND', cid, 404);
        }
        const dataset = getDataset(action.datasetId);
        if (!dataset) {
          finish(400, 'UNKNOWN_DATASET');
          return errorResponse('UNKNOWN_DATASET', cid, 400);
        }
        const barsFn = dataset.rowsAvailableInProcess ? IN_PROCESS_BARS_BY_DATASET_ID[dataset.datasetId] : undefined;
        if (!barsFn) {
          finish(400, 'DATA_REQUIREMENT_UNMET');
          return errorResponse('DATA_REQUIREMENT_UNMET', cid, 400);
        }
        const spec = version.spec;
        const ruleIds = [
          spec.entry.ruleId, spec.stop.ruleId, spec.target.ruleId,
          ...(spec.breakEven ? [spec.breakEven.ruleId] : []),
          spec.session.ruleId, spec.forcedExit.ruleId, spec.positionSize.ruleId,
        ];
        // §31: the automated research loop is deliberately restricted to
        // the safe, in-process engine -- it never dispatches a bounded
        // loop iteration against the external Python bridge.
        const refusal = engineAcceptsRunRequest('GENERIC_RULE_ENGINE', ruleIds, action.datasetId);
        if (refusal) {
          finish(400, 'ENGINE_REFUSED');
          return errorResponse('ENGINE_REFUSED', cid, 400);
        }
        const bars = barsFn();
        const statsResult = computeMarketStatistics(bars, dataset.timeframe);
        if (!statsResult.ok) {
          finish(STRATEGY_ERROR_STATUS[statsResult.error.code], statsResult.error.code);
          return errorResponse(statsResult.error.code, cid, STRATEGY_ERROR_STATUS[statsResult.error.code]);
        }
        const fitEvidence = analyzeStrategyMarketFit(spec, statsResult.value, bars);
        // §16: already capped at MAX_BOUNDED_VARIANTS inside
        // proposeBoundedStopVariants -- this loop adds no further cap
        // of its own because it needs none; it trusts the one bound
        // already enforced at the source.
        const proposals = proposeBoundedStopVariants(spec, fitEvidence);
        const segment: ExperimentSegment = dataset.segmentKind ?? 'FULL';
        const strategyWithVersion = await store.getWithLatestVersion(authUser.id, version.strategyId);
        const holdoutFirstViewedAt = strategyWithVersion?.strategy.holdoutFirstViewedAt ?? null;
        const commonInputBase = {
          strategyId: version.strategyId, strategySpecHash: version.specHash, datasetId: dataset.datasetId, datasetHash: dataset.hash,
          instrumentSymbol: dataset.instrumentSymbol, periodStart: dataset.periodStart, periodEnd: dataset.periodEnd, timeframes: [dataset.timeframe],
          limitations: ['Generic in-process engine: single-direction session-open entry only, no no-trade-reason taxonomy.'],
        };
        const candidates: Array<{
          label: string; versionId: string | null; result: unknown; experimentId: string | null; error: string | null;
        }> = [];
        for (const proposal of proposals.slice(0, MAX_BOUNDED_VARIANTS)) {
          const stopChange = proposal.parametersChanged['stop.distance'];
          const modifiedInput = { ...spec, stop: { ...spec.stop, distance: stopChange.to } };
          const validatedSpec = createStrategySpecification(modifiedInput);
          if (!validatedSpec.ok) {
            candidates.push({ label: proposal.label, versionId: null, result: null, experimentId: null, error: validatedSpec.error.message });
            continue;
          }
          const candidateVersion = await store.createNewVersion(authUser.id, version.strategyId, validatedSpec.value);
          const built = await runGenericEngineAndBuildResult(validatedSpec.value, bars, { ...commonInputBase, strategyVersion: candidateVersion.versionNumber });
          if (!built.ok) {
            candidates.push({ label: proposal.label, versionId: candidateVersion.id, result: null, experimentId: null, error: built.message });
            continue;
          }
          const savedResult = await store.insertBacktestResult(authUser.id, candidateVersion.id, built.value);
          await recordSucceededJob(store, authUser.id, candidateVersion.id, action.datasetId, 'GENERIC_RULE_ENGINE', new Date().toISOString(), savedResult.id);
          const contaminated = computeContamination(holdoutFirstViewedAt, new Date().toISOString(), segment === 'HOLDOUT');
          const experiment = await store.insertExperiment(authUser.id, {
            strategyId: version.strategyId, strategyVersionId: candidateVersion.id, category: 'ROBUSTNESS_EXPERIMENT',
            datasetId: action.datasetId, segment, parametersChanged: proposal.parametersChanged, reason: proposal.reason,
            resultId: savedResult.id, costAssumptions: null, source: 'AUTOMATED_RESEARCH_LOOP', contaminated,
          });
          candidates.push({ label: proposal.label, versionId: candidateVersion.id, result: savedResult, experimentId: experiment.id, error: null });
        }
        finish(200, null);
        return jsonResponse({ correlation_id: cid, fitEvidence, proposals, candidates });
      }
      case 'run_simulation': {
        // MACRO-07 §24-25: the first real INTERNAL simulation capability.
        // Deliberately built as a thin, explicitly-labeled variant of the
        // SAME deterministic in-process path run_backtest already uses --
        // no broker, no external data, no new execution surface. What
        // makes this a "simulation" rather than a "backtest" is entirely
        // in how the result is RECORDED (category SIMULATION in
        // strategy_experiments, never BACKTEST) -- the computation itself
        // is identical and equally safe. A caller who wants this
        // simulation formally governed through Human Gate/AEF calls the
        // separate strategy-simulation-runtime Edge Function
        // (aef/runtime/strategy_simulation_tools.ts) afterward with this
        // response's experiment id -- that governance ceremony is kept
        // OUT of this op on purpose, matching quant-runtime's own
        // separation between "Quant computes a signal" (here) and "a
        // human acknowledges it through AEF" (a distinct governed call).
        const token = bearerToken(req) ?? '';
        const store = (deps.storeFor ?? ((t: string) => new SupabaseStrategyStore(t)))(token);
        const version = await store.getVersionById(authUser.id, action.strategyVersionId);
        if (!version) {
          finish(404, 'NOT_FOUND');
          return errorResponse('NOT_FOUND', cid, 404);
        }
        const dataset = getDataset(action.datasetId);
        if (!dataset) {
          finish(400, 'UNKNOWN_DATASET');
          return errorResponse('UNKNOWN_DATASET', cid, 400);
        }
        const barsFn = dataset.rowsAvailableInProcess ? IN_PROCESS_BARS_BY_DATASET_ID[dataset.datasetId] : undefined;
        if (!barsFn) {
          finish(400, 'DATA_REQUIREMENT_UNMET');
          return errorResponse('DATA_REQUIREMENT_UNMET', cid, 400);
        }
        const spec = version.spec;
        const ruleIds = [
          spec.entry.ruleId, spec.stop.ruleId, spec.target.ruleId,
          ...(spec.breakEven ? [spec.breakEven.ruleId] : []),
          spec.session.ruleId, spec.forcedExit.ruleId, spec.positionSize.ruleId,
        ];
        const refusal = engineAcceptsRunRequest('GENERIC_RULE_ENGINE', ruleIds, action.datasetId);
        if (refusal) {
          finish(400, 'ENGINE_REFUSED');
          return errorResponse('ENGINE_REFUSED', cid, 400);
        }
        const bars = barsFn();
        const built = await runGenericEngineAndBuildResult(spec, bars, {
          strategyId: version.strategyId, strategyVersion: version.versionNumber, strategySpecHash: version.specHash,
          datasetId: dataset.datasetId, datasetHash: dataset.hash, instrumentSymbol: dataset.instrumentSymbol,
          periodStart: dataset.periodStart, periodEnd: dataset.periodEnd, timeframes: [dataset.timeframe],
          limitations: ['SIMULATION -- deterministic in-process replay, not a live or paper trading fill.'],
        });
        if (!built.ok) {
          finish(STRATEGY_ERROR_STATUS[built.code as StrategyErrorCode] ?? 400, built.code);
          return errorResponse(built.code, cid, STRATEGY_ERROR_STATUS[built.code as StrategyErrorCode] ?? 400);
        }
        const savedResult = await store.insertBacktestResult(authUser.id, version.id, built.value);
        const segment: ExperimentSegment = dataset.segmentKind ?? 'FULL';
        const strategyWithVersion = await store.getWithLatestVersion(authUser.id, version.strategyId);
        const holdoutFirstViewedAt = strategyWithVersion?.strategy.holdoutFirstViewedAt ?? null;
        const contaminated = computeContamination(holdoutFirstViewedAt, new Date().toISOString(), segment === 'HOLDOUT');
        const experiment = await store.insertExperiment(authUser.id, {
          strategyId: version.strategyId, strategyVersionId: version.id, category: 'SIMULATION', datasetId: action.datasetId,
          segment, parametersChanged: null, reason: 'internal simulation run', resultId: savedResult.id,
          costAssumptions: null, source: 'USER', contaminated,
        });
        finish(200, null);
        return jsonResponse({ correlation_id: cid, result: savedResult, experiment, label: 'SIMULATION' });
      }
    }
  } catch {
    finish(500, 'INTERNAL_ERROR');
    return errorResponse('INTERNAL_ERROR', cid, 500);
  }
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
