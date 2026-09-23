/**
 * IVE Intelligence Core orchestrator (IVE-INTELLIGENCE-CORE-01).
 *
 * Order (enforced here and asserted by tests):
 *   AUTH → ENTITLEMENT → VALIDATE → INTENT/RISK ROUTING
 *        → (consequential? → ACTION_REQUIRES_AEF, no context, no quota, no model)
 *        → CONTEXT (fail closed on project) → QUOTA → MODEL → RESPONSE
 *
 * A denial at any step before QUOTA never consumes quota; a model failure
 * after QUOTA refunds it. Nothing here executes an action.
 */
import { type AuthClient, AuthError, type AuthenticatedUser, resolveAuthenticatedUser, unauthorizedResponse } from '../auth.ts';
import { decideModuleAccess, type EntitlementSubject, type EntitlementSubjectSource, requireModuleAccess } from '../entitlement.ts';
import { MODULE_POLICY } from '../module_policy.ts';
import { type QuotaClient, quotaBlockedResponse, refundQuota, reserveQuota } from '../quota.ts';
import {
  type IveActionIntent,
  type IveErrorCode,
  type IveIntelligenceRequest,
  type IveIntelligenceResponse,
  parseIntelligenceRequest,
  type SuggestedAction,
} from './contracts.ts';
import {
  assembleContext,
  ContextUnavailableError,
  type IveDataSource,
  type IveIntelligenceContext,
  ProjectForbiddenError,
  SupabaseIveDataSource,
} from './context_assembler.ts';
import { routeIntent, type RoutedIntent } from './intent_router.ts';
import { extractMemoryCandidates } from './memory_policy.ts';
import { buildMessages } from './prompt_builder.ts';
import { GroqChatProvider, type IntelligenceProvider, ProviderUnavailableError } from './provider.ts';

/** The module whose entitlement gates the Intelligence Core: the existing
 * commercial IVE assistant capability (registry `context-copilot`). */
export const IVE_CORE_MODULE_ID = 'context-copilot';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-correlation-id',
};

export interface IveCoreDeps {
  authClient?: AuthClient;
  quotaClient?: QuotaClient;
  subjectSource?: EntitlementSubjectSource;
  dataSource?: (accessToken: string) => IveDataSource;
  provider?: IntelligenceProvider;
  now?: () => number;
}

const STATUS: Record<IveErrorCode, number> = {
  AUTH_REQUIRED: 401,
  INVALID_REQUEST: 400,
  SURFACE_NOT_SUPPORTED: 400,
  PROJECT_FORBIDDEN: 403,
  CONTEXT_UNAVAILABLE: 503,
  MODEL_UNAVAILABLE: 503,
  INTERNAL_ERROR: 500,
};

export function errorResponse(code: IveErrorCode, correlationId: string, extra: Record<string, unknown> = {}): Response {
  return new Response(JSON.stringify({ error: code, correlation_id: correlationId, ...extra }), {
    status: STATUS[code],
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function json(body: unknown): Response {
  return new Response(JSON.stringify(body), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

function bearer(req: Request): string {
  return req.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() ?? '';
}

function latencyBucket(ms: number): string {
  return ms < 1000 ? '<1s' : ms < 3000 ? '1-3s' : ms < 10000 ? '3-10s' : '>10s';
}

/** Suggested actions carry validated capability ids only. A module the
 * subject cannot use is never offered as available: it becomes an
 * `upgrade` suggestion when the only obstacle is the plan, and is omitted
 * otherwise (unreleased/internal modules are never advertised). */
export function suggestActions(subject: EntitlementSubject, routed: RoutedIntent): SuggestedAction[] {
  if (!routed.capabilityId || routed.requiresAef) return [];
  const d = decideModuleAccess(subject, routed.capabilityId, MODULE_POLICY);
  if (d.allowed) return [{ kind: 'open_module', capabilityId: routed.capabilityId, available: true }];
  if (d.code === 'PLAN_REQUIRED') {
    return [{ kind: 'upgrade', capabilityId: routed.capabilityId, available: false, requiredPlan: d.requiredPlan }];
  }
  return [];
}

function telemetry(fields: Record<string, unknown>): void {
  // Shape only: never the prompt, message, documents, memory text or tokens.
  console.log(JSON.stringify({ event: 'ive_intelligence', ...fields }));
}

export async function handleIveIntelligence(req: Request, deps: IveCoreDeps = {}): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const started = (deps.now ?? Date.now)();

  // AUTH
  let user: AuthenticatedUser;
  try {
    user = await resolveAuthenticatedUser(req, deps.authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  // ENTITLEMENT (the IVE assistant capability itself)
  // Literal id (not IVE_CORE_MODULE_ID) so the static Promotion Gate check
  // MP-06 can verify it; ive_intelligence_test.ts asserts they are equal.
  const access = await requireModuleAccess(req, user, 'context-copilot', corsHeaders, deps.subjectSource);
  if (!access.allowed) return access.response;
  const subject = access.subject;
  const correlationId = access.correlationId;

  // VALIDATE
  if (req.method !== 'POST') return errorResponse('INVALID_REQUEST', correlationId, { field: 'method' });
  const body = await req.json().catch(() => undefined);
  const parsed = parseIntelligenceRequest(body);
  if (!parsed.ok) {
    telemetry({ correlation_id: correlationId, status: parsed.code, field: parsed.field });
    return errorResponse(parsed.code, correlationId, { field: parsed.field });
  }
  const request: IveIntelligenceRequest = parsed.request;
  // Codex Gate 1 IG1-07 — the correlation id is SERVER-owned (header-derived
  // or minted in requireModuleAccess). A client-supplied id is only echoed
  // in telemetry as `client_correlation_id`, never used as the audit key.
  const effectiveCorrelation = correlationId;
  const clientCorrelation = request.correlationId;

  // INTENT / RISK ROUTING — consequential intents never reach context,
  // quota or the model: IVE prepares an intent for AEF and stops.
  const routed = routeIntent(
    request.message,
    request.requestedCapability,
    undefined,
    request.conversation.filter((t) => t.role === 'user').map((t) => t.content),
  );
  if (routed.requiresAef) {
    const intent: IveActionIntent = {
      capabilityId: routed.capabilityId,
      requestedAction: routed.requestedAction ?? 'unknown',
      projectId: request.projectId,
      riskClass: 'CONSEQUENTIAL',
      contextRef: effectiveCorrelation,
      parameters: {},
    };
    telemetry({ correlation_id: effectiveCorrelation, client_correlation_id: clientCorrelation, surface: request.surface, status: 'ACTION_REQUIRES_AEF', action: intent.requestedAction });
    const res: IveIntelligenceResponse = {
      status: 'ACTION_REQUIRES_AEF',
      answer: null,
      locale: request.locale,
      capabilitiesUsed: [],
      sources: [],
      suggestedActions: [],
      requiresAef: true,
      actionIntent: intent,
      memoryCandidates: [],
      degraded: [],
      contextStatus: null,
      correlationId: effectiveCorrelation,
    };
    return json(res);
  }

  // CONTEXT
  let ctx: IveIntelligenceContext;
  try {
    const data = (deps.dataSource ?? ((t: string) => new SupabaseIveDataSource(t)))(bearer(req));
    ctx = await assembleContext(subject, request, data);
  } catch (e) {
    if (e instanceof ProjectForbiddenError) {
      telemetry({ correlation_id: effectiveCorrelation, surface: request.surface, status: 'PROJECT_FORBIDDEN' });
      return errorResponse('PROJECT_FORBIDDEN', effectiveCorrelation);
    }
    if (e instanceof ContextUnavailableError) return errorResponse('CONTEXT_UNAVAILABLE', effectiveCorrelation);
    return errorResponse('INTERNAL_ERROR', effectiveCorrelation);
  }

  const { messages, conversationTruncated } = buildMessages(ctx, request.message, request.conversation, request.locale);

  // QUOTA — only now, after every free check passed.
  const quota = await reserveQuota(req, deps.quotaClient, request.idempotencyKey, 'ive-intelligence');
  if (!quota.allowed) return quotaBlockedResponse(corsHeaders, quota);

  // MODEL
  let answer: string;
  try {
    const out = await (deps.provider ?? new GroqChatProvider()).generate(messages);
    answer = out.text.trim();
  } catch (e) {
    // Refund is best-effort in the shared quota helper (debt, see report);
    // the attempt is recorded so reconciliation can find it.
    await refundQuota(req, deps.quotaClient, quota);
    telemetry({ correlation_id: effectiveCorrelation, surface: request.surface, status: 'MODEL_UNAVAILABLE', provider_error: e instanceof ProviderUnavailableError ? e.kind : 'unknown', quota_refund_attempted: true });
    return errorResponse('MODEL_UNAVAILABLE', effectiveCorrelation);
  }

  const capabilitiesUsed = [IVE_CORE_MODULE_ID];
  if (ctx.opportunities.length) capabilitiesUsed.push('opportunity-lab');
  if (ctx.actions.length) capabilitiesUsed.push('action-engine');
  if (ctx.knowledge.length) capabilitiesUsed.push('knowledge-vault');

  telemetry({
    correlation_id: effectiveCorrelation,
    client_correlation_id: clientCorrelation,
    surface: request.surface,
    locale: request.locale,
    status: 'ANSWERED',
    source_module: request.sourceModule,
    has_project: ctx.project !== null,
    knowledge_items: ctx.knowledge.length,
    memory_items: ctx.memories.length,
    context_sources: ctx.provenance.length,
    degraded: ctx.degraded,
    truncated: { ...ctx.truncation, conversation: conversationTruncated },
    latency: latencyBucket((deps.now ?? Date.now)() - started),
  });

  const res: IveIntelligenceResponse = {
    status: 'ANSWERED',
    answer,
    locale: request.locale,
    capabilitiesUsed,
    sources: ctx.provenance
      .filter((p) => p.sourceType !== 'user_input')
      .map((p) => ({ sourceType: p.sourceType, sourceId: p.sourceId, label: p.label })),
    suggestedActions: suggestActions(subject, routed),
    requiresAef: false,
    actionIntent: null,
    memoryCandidates: extractMemoryCandidates(request.message),
    degraded: ctx.degraded,
    contextStatus: ctx.contextStatus,
    correlationId: effectiveCorrelation,
  };
  return json(res);
}
