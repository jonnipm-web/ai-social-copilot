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
import { bearerToken, readJsonBody, strategyCorsHeaders, SupabaseStrategyStore, type StrategyStore } from '../_shared/strategy_server.ts';
import { createStrategySpecification, type StrategySpecificationInput } from '../_shared/strategy/strategy_spec.ts';
import { parseNaturalLanguageStrategyDraft } from '../_shared/strategy/nl_draft.ts';
import type { StrategyErrorCode } from '../_shared/strategy/errors.ts';

export interface StrategyBuilderDeps {
  storeFor?: (accessToken: string) => StrategyStore;
  log?: (line: string) => void;
}

const OPS = new Set(['validate', 'draft_from_text', 'create', 'list', 'get']);

interface ValidateOp { readonly op: 'validate'; readonly spec: StrategySpecificationInput }
interface DraftFromTextOp { readonly op: 'draft_from_text'; readonly text: string }
interface CreateOp { readonly op: 'create'; readonly spec: StrategySpecificationInput }
interface ListOp { readonly op: 'list' }
interface GetOp { readonly op: 'get'; readonly strategyId: string }
type ParsedOp = ValidateOp | DraftFromTextOp | CreateOp | ListOp | GetOp;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
      if (typeof b.strategyId !== 'string' || !UUID_RE.test(b.strategyId)) return { ok: false, code: 'INVALID_BODY' };
      return { ok: true, value: { op: 'get', strategyId: b.strategyId } };
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
        const created = await store.create(authUser.id, validated.value);
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
    }
  } catch {
    finish(500, 'INTERNAL_ERROR');
    return errorResponse('INTERNAL_ERROR', cid, 500);
  }
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
