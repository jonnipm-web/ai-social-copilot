// module-access — INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02.
//
// Capability discovery for IVE and clients (Android/Web today; any future
// surface): "which modules may the CALLER use right now?". The answer is
// computed by the same server authority every protected Edge Function uses
// (_shared/entitlement.ts), from the caller's verified identity only — the
// request body is never read. It is informational: holding a positive
// answer grants nothing, because each module's own Edge Function re-checks
// entitlement on every call. No quota is consumed; no AI is called.
//
// Response 200:
//   { subject: { type, plan, roles }, correlation_id,
//     modules: [{ module_id, allowed, code?, required_plan? }] }
// Denials use the shared error contract (AUTH_REQUIRED / ENTITLEMENT_UNAVAILABLE).
// Lifecycle and internal reasons are deliberately not exposed.
//
// NOT DEPLOYED by this mission (Module Lab). Not yet on
// .github/deploy-allowlist.tsv.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import {
  correlationIdFor,
  entitlementDeniedResponse,
  EntitlementSubjectSource,
  listModuleDecisions,
  resolveSubject,
} from '../_shared/entitlement.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-correlation-id',
};

export async function handler(
  req: Request,
  authClient?: AuthClient,
  subjectSource?: EntitlementSubjectSource,
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  let authUser;
  try {
    authUser = await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  const correlationId = correlationIdFor(req);
  const { subject, error } = await resolveSubject(req, authUser, subjectSource);
  if (error || !subject) {
    return entitlementDeniedResponse(
      { allowed: false, code: 'ENTITLEMENT_UNAVAILABLE', reason: 'SUBJECT_SOURCE_ERROR', moduleId: '*' },
      correlationId,
      corsHeaders,
    );
  }

  const modules = listModuleDecisions(subject).map((d) => {
    const out: Record<string, unknown> = { module_id: d.moduleId, allowed: d.allowed };
    if (!d.allowed) out.code = d.code;
    if (d.code === 'PLAN_REQUIRED' && d.requiredPlan) out.required_plan = d.requiredPlan;
    return out;
  });

  return new Response(
    JSON.stringify({
      subject: { type: subject.type, plan: subject.plan, roles: [...subject.roles].sort() },
      correlation_id: correlationId,
      modules,
    }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
