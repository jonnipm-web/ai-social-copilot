// impact-lab — IV-IMPACT-I1-PERSISTENCE-RLS-01.
//
// InsightValues Impact Lab API. EXPERIMENTAL module "impact": ADMIN ONLY via
// the server-side Entitlement Core (free/pro/premium/beta are denied).
//
// Request order (every path, fail closed):
//   AUTH (resolveAuthenticatedUser: real session JWT, user id derived from it)
//   → ENTITLEMENT (requireModuleAccess 'impact'; nothing the client sends is read)
//   → body limit + strict schema (lab_contract.ts)
//   → OWNERSHIP (RLS-scoped read with the caller's JWT + owner check)
//   → DOMAIN VALIDATION → ENGINE (server provider registry, server clock)
//   → PERSISTENCE (service role; database re-enforces invariants)
//   → STRUCTURED RESPONSE (codes, never narrative-only; no verdict fields).
//
// No LLM, no outbound fetch, no quota (no paid AI call), no class C action.
// NOT DEPLOYED by this mission. Not on .github/deploy-allowlist.tsv.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthenticatedUser, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import { EntitlementSubjectSource, requireModuleAccess } from '../_shared/entitlement.ts';
import type { ImpactError, ImpactErrorCode } from '../_shared/impact/errors.ts';
import { LAB_LIMITS, parseLabRequest } from '../_shared/impact/lab_contract.ts';
import { handleLabRequest } from '../_shared/impact/lab_service.ts';
import type { ImpactLabStore } from '../_shared/impact/lab_store.ts';
import { buildImpactEvent } from '../_shared/impact/observability.ts';
import { IMPACT_POLICY_VERSION } from '../_shared/impact/verification.ts';
import { createSupabaseImpactLabStore } from './supabase_store.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-correlation-id',
};

export interface ImpactLabDeps {
  /** Store factory (tests inject an in-memory store bound to the caller). */
  store?: (req: Request, user: AuthenticatedUser) => ImpactLabStore;
  now?: () => string;
  log?: (line: string) => void;
}

const HTTP: Readonly<Partial<Record<ImpactErrorCode, number>>> = {
  INVALID_REQUEST: 400,
  INVALID_CLAIM: 400,
  INVALID_EVIDENCE: 400,
  INVALID_SOURCE: 400,
  UNSAFE_REFERENCE: 400,
  SENSITIVE_DATA_REJECTED: 400,
  CAPABILITY_NOT_SUPPORTED: 400,
  CROSS_INVESTIGATION_DENIED: 404, // indistinguishable from "not found": no existence oracle
  INVESTIGATION_NOT_FOUND: 404,
  ORGANIZATION_NOT_FOUND: 404,
  ACTION_BLOCKED: 403,
  ALREADY_EXISTS: 409,
  INVESTIGATION_NOT_ACTIVE: 409,
  LIMIT_EXCEEDED: 429,
  PAYLOAD_TOO_LARGE: 413,
  REGISTRY_UNAVAILABLE: 503,
  INTERNAL_ERROR: 500,
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

function errorResponse(e: ImpactError, correlationId: string): Response {
  const status = HTTP[e.code] ?? 400;
  const body: Record<string, unknown> = { ok: false, error: e.code, correlation_id: correlationId };
  if (status < 500) body.message = e.message;
  if (e.code === 'ACTION_BLOCKED') body.requires = 'AEF_HUMAN_GATE';
  return json(status, body);
}

async function readBody(req: Request): Promise<{ ok: true; text: string } | { ok: false; code: ImpactErrorCode }> {
  const declared = Number(req.headers.get('Content-Length') ?? '0');
  if (declared > LAB_LIMITS.maxBodyBytes) return { ok: false, code: 'PAYLOAD_TOO_LARGE' };
  const buf = new Uint8Array(await req.arrayBuffer());
  if (buf.byteLength > LAB_LIMITS.maxBodyBytes) return { ok: false, code: 'PAYLOAD_TOO_LARGE' };
  return { ok: true, text: new TextDecoder().decode(buf) };
}

export async function handler(
  req: Request,
  authClient?: AuthClient,
  _quotaClient?: unknown, // signature parity with every MODULE Edge Function; Impact makes no paid call
  subjectSource?: EntitlementSubjectSource,
  deps: ImpactLabDeps = {},
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const started = performance.now();
  const log = deps.log ?? ((l: string) => console.log(l));

  let user: AuthenticatedUser;
  try {
    user = await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  const access = await requireModuleAccess(req, user, 'impact', corsHeaders, subjectSource);
  if (!access.allowed) return access.response;
  const correlationId = access.correlationId;

  if (req.method !== 'POST') return errorResponse({ code: 'INVALID_REQUEST', message: 'POST only' }, correlationId);
  const body = await readBody(req);
  if (!body.ok) return errorResponse({ code: body.code, message: 'request body too large' }, correlationId);
  let raw: unknown;
  try {
    raw = JSON.parse(body.text);
  } catch {
    return errorResponse({ code: 'INVALID_REQUEST', message: 'body must be JSON' }, correlationId);
  }
  const parsed = parseLabRequest(raw);
  if (!parsed.ok) return errorResponse(parsed.error, correlationId);

  let result;
  try {
    const store = deps.store ? deps.store(req, user) : createSupabaseImpactLabStore(req);
    const now = deps.now ? deps.now() : new Date().toISOString();
    result = await handleLabRequest(store, { userId: user.id }, parsed.value, now);
  } catch {
    result = { ok: false as const, error: { code: 'INTERNAL_ERROR' as const, message: 'internal error' } };
  }

  const investigationId = 'investigationId' in parsed.value ? parsed.value.investigationId : undefined;
  const event = buildImpactEvent({
    event: `impact.lab.${parsed.value.action}`,
    correlation_id: correlationId,
    ...(investigationId ? { investigation_id: investigationId } : {}),
    latency_ms: performance.now() - started,
    policy_version: IMPACT_POLICY_VERSION,
    ...(result.ok
      ? {
        ...(result.value.metrics?.claims !== undefined ? { claims_count: result.value.metrics.claims } : {}),
        ...(result.value.metrics?.evidence !== undefined ? { evidence_count: result.value.metrics.evidence } : {}),
        ...(result.value.metrics?.conflicts !== undefined ? { conflicts_count: result.value.metrics.conflicts } : {}),
        ...(result.value.metrics?.status ? { verification_status: result.value.metrics.status } : {}),
      }
      : { error_code: result.error.code }),
  });
  if (event) log(JSON.stringify(event));

  if (!result.ok) return errorResponse(result.error, correlationId);
  return json(200, { ok: true, action: result.value.action, data: result.value.data, correlation_id: correlationId });
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
