/**
 * aef-runtime — LAB-only HTTP boundary for IVE → AEF (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
 *
 * Order (asserted by tests):
 *   AUTH → ENTITLEMENT ('aef-runtime-lab', EXPERIMENTAL: admin only)
 *     → LAB KILL SWITCH → STRICT BODY → IveAefRuntime → AefGovernance
 * The kill switch runs before the runtime (store, tools) is ever built.
 *
 * NOT deployable: hard-blocked in scripts/ci/resolve_deploy_selection.sh and
 * absent from .github/deploy-allowlist.tsv; the kill switch additionally
 * refuses any non-local Supabase URL and the production project, so even a
 * manual deploy with a partial configuration answers 503 before any AEF work.
 *
 * The body carries no authority: the subject is the verified JWT holder, the
 * plan/role come from the server entitlement source, tools/risk/gate come
 * from the server registry and policy. Unknown keys are refused.
 */
import { type AuthClient, AuthError, type AuthenticatedUser, resolveAuthenticatedUser, unauthorizedResponse } from './auth.ts';
import { type EntitlementSubjectSource, requireModuleAccess } from './entitlement.ts';
import { checkLabRuntime, type RuntimeEnv } from '../../../aef/runtime/runtime_guard.ts';
import type { IveAefRuntime } from '../../../aef/runtime/ive_aef_runtime.ts';
import type { RuntimePresentation } from '../../../aef/runtime/presentation.ts';

export const AEF_RUNTIME_MODULE_ID = 'aef-runtime-lab';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-correlation-id',
};

export interface AefRuntimeEndpointDeps {
  env?: RuntimeEnv;
  authClient?: AuthClient;
  subjectSource?: EntitlementSubjectSource;
  /** Built lazily with the service_role store only after every check passed. */
  runtime: () => IveAefRuntime;
}

const OPS: Record<string, readonly string[]> = {
  propose: ['op', 'intent'],
  execute: ['op', 'intent'],
  decide: ['op', 'gate'],
  status: ['op', 'operationId'],
  cancel: ['op', 'operationId'],
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

function statusFor(p: RuntimePresentation): number {
  if (p.phase !== 'DENIED') return 200;
  return p.denialCode === 'AUTH_FAILED' ? 401 : p.denialCode === 'STORE_UNAVAILABLE' ? 503 : 403;
}

function bearer(req: Request): string {
  return req.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() ?? '';
}

export async function handleAefRuntime(req: Request, deps: AefRuntimeEndpointDeps): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  // AUTH
  let user: AuthenticatedUser;
  try {
    user = await resolveAuthenticatedUser(req, deps.authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  // ENTITLEMENT — server-side plan/role; EXPERIMENTAL module (admin only).
  const access = await requireModuleAccess(req, user, 'aef-runtime-lab', corsHeaders, deps.subjectSource);
  if (!access.allowed) return access.response;

  // LAB KILL SWITCH — before the runtime (store, tools) is ever built.
  const guard = checkLabRuntime(deps.env ?? Deno.env);
  if (!guard.ok) return json(503, { error: 'RUNTIME_DISABLED', reason: guard.reason, correlation_id: access.correlationId });

  // STRICT BODY
  if (req.method !== 'POST') return json(400, { error: 'INVALID_REQUEST', field: 'method' });
  const body = await req.json().catch(() => undefined);
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return json(400, { error: 'INVALID_REQUEST' });
  const op = (body as Record<string, unknown>).op;
  if (typeof op !== 'string' || !Object.prototype.hasOwnProperty.call(OPS, op)) return json(400, { error: 'INVALID_REQUEST', field: 'op' });
  const keys = Object.keys(body);
  const expected = OPS[op];
  if (keys.length !== expected.length || !expected.every((k) => keys.includes(k))) return json(400, { error: 'INVALID_REQUEST', field: 'body' });
  const b = body as Record<string, unknown>;

  const credential = { kind: 'bearer_jwt' as const, token: bearer(req) };
  const runtime = deps.runtime();
  let result: RuntimePresentation;
  switch (op) {
    case 'propose':
      result = await runtime.propose(b.intent, user.id, credential);
      break;
    case 'execute':
      result = await runtime.execute(b.intent, user.id, credential);
      break;
    case 'decide':
      result = await runtime.decide(b.gate, user.id, credential);
      break;
    case 'status':
      result = await runtime.status(b.operationId, user.id, credential);
      break;
    default:
      result = await runtime.cancel(b.operationId, user.id, credential);
  }
  return json(statusFor(result), { result, correlation_id: access.correlationId });
}
