/**
 * Server-side Entitlement Authority — INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02.
 *
 * Answers exactly one question: "may this SUBJECT use this MODULE right
 * now?". It does NOT answer "how much may they still consume" (quota —
 * _shared/quota.ts, unchanged) nor "may this ACTION execute, with which
 * approval/receipt" (AEF — aef/). Request order in every protected Edge
 * Function is: authenticate → entitlement → quota → operation.
 *
 * Domain model (MODULE_ARCHITECTURE.md §13):
 *   IDENTITY  subject {type, id}      — who (user today; organization/workspace later)
 *   ROLE      admin | beta_tester     — what they may administer/preview (NOT a plan)
 *   PLAN      free | pro | premium    — what they paid for (NOT a role)
 *   AVAILABILITY  module_policy.ts    — lifecycle + minimum plan per module
 *   USAGE     quota.ts                — how much they may still consume
 *
 * Storage: the legacy single column public.profiles.role carries BOTH a
 * plan value and a role value; mapLegacyProfileRole is the only place that
 * splits it. Migration 20260923000000_entitlement_subject_roles (Module
 * Lab, not yet applied) moves ROLES to public.subject_roles so billing can
 * never rewrite authorization; ProfilePlanAndSubjectRolesSource reads it
 * once the ENTITLEMENT_SUBJECT_ROLES rollout flag is set. profiles.role is
 * never modified here, and a user cannot write it
 * (prevent_self_privilege_escalation trigger + profiles_role_check).
 *
 * Default deny: unauthenticated, unknown module, unknown plan, deprecated
 * module, non-exposed lifecycle, insufficient plan, and ANY failure to
 * resolve the subject all deny. Nothing the client sends (body, headers
 * other than the bearer token) is read to decide access.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';
import type { AuthenticatedUser } from './auth.ts';
import { MODULE_POLICY, type ModuleLifecycle, type ModulePolicyDoc, type Plan } from './module_policy.ts';

export type SubjectType = 'user' | 'organization' | 'workspace';
export type Role = 'admin' | 'beta_tester';

export interface EntitlementSubject {
  type: SubjectType;
  id: string;
  /** null = plan could not be determined → every protected module denies. */
  plan: Plan | null;
  roles: ReadonlySet<Role>;
  source: SubjectSourceKind;
}

export type SubjectSourceKind = 'legacy_profiles_role' | 'profiles_plan_and_subject_roles';

export type EntitlementErrorCode =
  | 'AUTH_REQUIRED'
  | 'MODULE_NOT_AVAILABLE'
  | 'MODULE_DISABLED'
  | 'PLAN_REQUIRED'
  | 'ENTITLEMENT_UNAVAILABLE';

export type DecisionReason =
  | 'PLAN_ENTITLED'
  | 'BETA_ENTITLED'
  | 'ADMIN_ROLE'
  | 'UNAUTHENTICATED'
  | 'UNKNOWN_MODULE'
  | 'LIFECYCLE_DEPRECATED'
  | 'UNKNOWN_PLAN'
  | 'LIFECYCLE_NOT_EXPOSED'
  | 'BETA_ELIGIBILITY_REQUIRED'
  | 'INSUFFICIENT_PLAN'
  | 'SUBJECT_SOURCE_ERROR';

export interface EntitlementDecision {
  allowed: boolean;
  /** Present only when denied — the public, stable error contract. */
  code?: EntitlementErrorCode;
  /** Internal diagnostic reason — logged, never returned to the client. */
  reason: DecisionReason;
  moduleId: string;
  lifecycle?: ModuleLifecycle;
  requiredPlan?: Plan;
}

const PLAN_RANK: Record<Plan, number> = { free: 0, pro: 1, premium: 2 };

/** Lifecycles a beta_tester may reach (still subject to the plan check). */
const BETA_LIFECYCLES: ReadonlySet<ModuleLifecycle> = new Set(['ALPHA', 'BETA', 'RELEASE_CANDIDATE']);

/**
 * Legacy profiles.role → (plan, roles). Explicit, exhaustive mapping of the
 * five values allowed by profiles_role_check. Anything else → plan null
 * (fail closed). admin and beta_tester carry plan 'free': their extra
 * access comes from the ROLE policy below, never from a synthetic plan —
 * a beta tester is NOT an implicit premium user. (Quota limits for these
 * roles stay exactly as the SQL quota functions already define them.)
 */
export function mapLegacyProfileRole(role: unknown): { plan: Plan | null; roles: Set<Role> } {
  switch (role) {
    case 'free': return { plan: 'free', roles: new Set() };
    case 'pro': return { plan: 'pro', roles: new Set() };
    case 'premium': return { plan: 'premium', roles: new Set() };
    case 'beta_tester': return { plan: 'free', roles: new Set(['beta_tester']) };
    case 'admin': return { plan: 'free', roles: new Set(['admin']) };
    default: return { plan: null, roles: new Set() };
  }
}

function isPlan(v: unknown): v is Plan {
  return v === 'free' || v === 'pro' || v === 'premium';
}

/**
 * Pure, deterministic decision. Same inputs → same output; no I/O.
 * Order matters and is part of the contract (tested):
 *   1 unauthenticated → deny   2 unknown module → deny
 *   3 deprecated → deny        4 unknown plan → deny
 *   5 admin role → allow (audited; parity with the legacy client route
 *     guard, which lets admins reach every module)
 *   6 EXPERIMENTAL/INTERNAL → deny   7 ALPHA/BETA/RC → beta_tester required
 *   8 plan rank < minimumPlan → deny  9 allow
 */
export function decideModuleAccess(
  subject: EntitlementSubject | null,
  moduleId: string,
  policy: ModulePolicyDoc = MODULE_POLICY,
): EntitlementDecision {
  if (!subject || !subject.id) {
    return { allowed: false, code: 'AUTH_REQUIRED', reason: 'UNAUTHENTICATED', moduleId };
  }
  const module = Object.prototype.hasOwnProperty.call(policy.modules, moduleId)
    ? policy.modules[moduleId]
    : undefined;
  if (!module) {
    return { allowed: false, code: 'MODULE_NOT_AVAILABLE', reason: 'UNKNOWN_MODULE', moduleId };
  }
  const lifecycle = module.lifecycle;
  if (lifecycle === 'DEPRECATED') {
    return { allowed: false, code: 'MODULE_DISABLED', reason: 'LIFECYCLE_DEPRECATED', moduleId, lifecycle };
  }
  if (!isPlan(subject.plan) || !isPlan(module.minimumPlan)) {
    return { allowed: false, code: 'ENTITLEMENT_UNAVAILABLE', reason: 'UNKNOWN_PLAN', moduleId, lifecycle };
  }
  if (subject.roles.has('admin')) {
    return { allowed: true, reason: 'ADMIN_ROLE', moduleId, lifecycle };
  }
  if (lifecycle === 'EXPERIMENTAL' || lifecycle === 'INTERNAL') {
    return { allowed: false, code: 'MODULE_NOT_AVAILABLE', reason: 'LIFECYCLE_NOT_EXPOSED', moduleId, lifecycle };
  }
  const viaBeta = BETA_LIFECYCLES.has(lifecycle);
  if (viaBeta && !subject.roles.has('beta_tester')) {
    return { allowed: false, code: 'MODULE_NOT_AVAILABLE', reason: 'BETA_ELIGIBILITY_REQUIRED', moduleId, lifecycle };
  }
  if (lifecycle !== 'COMMERCIAL' && !viaBeta) {
    // Unreachable with the typed lifecycle set; kept so a future lifecycle
    // value added to the type without a rule here denies instead of falling
    // through to the plan check.
    return { allowed: false, code: 'MODULE_NOT_AVAILABLE', reason: 'LIFECYCLE_NOT_EXPOSED', moduleId, lifecycle };
  }
  if (PLAN_RANK[subject.plan] < PLAN_RANK[module.minimumPlan]) {
    return {
      allowed: false,
      code: 'PLAN_REQUIRED',
      reason: 'INSUFFICIENT_PLAN',
      moduleId,
      lifecycle,
      requiredPlan: module.minimumPlan,
    };
  }
  return { allowed: true, reason: viaBeta ? 'BETA_ENTITLED' : 'PLAN_ENTITLED', moduleId, lifecycle };
}

/** Every module in the policy with this subject's decision — the capability
 * set IVE and clients may discover (module-access Edge Function). */
export function listModuleDecisions(
  subject: EntitlementSubject | null,
  policy: ModulePolicyDoc = MODULE_POLICY,
): EntitlementDecision[] {
  return Object.keys(policy.modules).sort().map((id) => decideModuleAccess(subject, id, policy));
}

// ── Subject resolution (I/O) ────────────────────────────────────────────

export class EntitlementSourceError extends Error {}

/** Injectable so tests never touch a real database. */
export interface EntitlementSubjectSource {
  resolveUserSubject(userId: string, accessToken: string): Promise<EntitlementSubject>;
}

/**
 * Legacy source: reads the caller's OWN profiles.role with the caller's
 * own JWT (RLS "users_own_profile" — no service role, no cross-user read).
 * Any error, or a missing row, throws → the gate fails closed.
 */
export class LegacyProfileRoleSubjectSource implements EntitlementSubjectSource {
  async resolveUserSubject(userId: string, accessToken: string): Promise<EntitlementSubject> {
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!url || !anonKey) throw new EntitlementSourceError('entitlement source misconfigured');
    const client = createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
    const { data, error } = await client.from('profiles').select('role').eq('id', userId).maybeSingle();
    if (error) throw new EntitlementSourceError('profile read failed');
    if (!data) throw new EntitlementSourceError('profile not found');
    const { plan, roles } = mapLegacyProfileRole((data as { role?: unknown }).role);
    return { type: 'user', id: userId, plan, roles, source: 'legacy_profiles_role' };
  }
}

const KNOWN_ROLES: ReadonlySet<string> = new Set(['admin', 'beta_tester']);

/**
 * Role ≠ plan storage (migration 20260923000000_entitlement_subject_roles):
 *   plan  = profiles.role when it is a plan value, else 'free'
 *   roles = legacy role in profiles.role ∪ public.subject_roles rows
 * Both reads use the caller's own JWT (RLS: own row only). Any error —
 * including the table not existing because the migration was not applied —
 * throws, so the gate fails closed. Selected only when the Edge Function
 * environment sets ENTITLEMENT_SUBJECT_ROLES=1 (rollout flag, see
 * defaultSubjectSource); until then the legacy source above is used.
 */
export class ProfilePlanAndSubjectRolesSource implements EntitlementSubjectSource {
  async resolveUserSubject(userId: string, accessToken: string): Promise<EntitlementSubject> {
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!url || !anonKey) throw new EntitlementSourceError('entitlement source misconfigured');
    const client = createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
    const profile = await client.from('profiles').select('role').eq('id', userId).maybeSingle();
    if (profile.error) throw new EntitlementSourceError('profile read failed');
    if (!profile.data) throw new EntitlementSourceError('profile not found');
    const extra = await client.from('subject_roles').select('role').eq('subject_type', 'user').eq('subject_id', userId);
    if (extra.error) throw new EntitlementSourceError('subject roles read failed');
    return subjectFromPlanAndRoleRows(userId, (profile.data as { role?: unknown }).role, extra.data ?? []);
  }
}

/** Pure merge used by ProfilePlanAndSubjectRolesSource: plan from the
 * legacy column, roles = legacy role ∪ known subject_roles rows (unknown
 * role strings are ignored, never promoted). */
export function subjectFromPlanAndRoleRows(
  userId: string,
  profileRole: unknown,
  roleRows: readonly { role?: unknown }[],
): EntitlementSubject {
  const legacy = mapLegacyProfileRole(profileRole);
  const roles = new Set<Role>(legacy.roles);
  for (const row of roleRows) {
    if (typeof row.role === 'string' && KNOWN_ROLES.has(row.role)) roles.add(row.role as Role);
  }
  return { type: 'user', id: userId, plan: legacy.plan, roles, source: 'profiles_plan_and_subject_roles' };
}

/** Operational rollout switch (a FEATURE FLAG in the §14 sense — it changes
 * where roles are read from, never who is entitled to what by policy). */
export function defaultSubjectSource(): EntitlementSubjectSource {
  return Deno.env.get('ENTITLEMENT_SUBJECT_ROLES') === '1'
    ? new ProfilePlanAndSubjectRolesSource()
    : new LegacyProfileRoleSubjectSource();
}

const KNOWN_SOURCES: ReadonlySet<string> = new Set(['legacy_profiles_role', 'profiles_plan_and_subject_roles']);

/**
 * Codex Gate 1 CX1-04 — the authority never trusts what a source returns:
 * the subject must be exactly the authenticated user, from a known source,
 * with a real plan (or null) and only known roles. Anything else is treated
 * as a source failure (fail closed).
 */
export function isSubjectBoundTo(subject: unknown, userId: string): subject is EntitlementSubject {
  if (!subject || typeof subject !== 'object') return false;
  const s = subject as Record<string, unknown>;
  if (s.type !== 'user' || s.id !== userId) return false;
  if (typeof s.source !== 'string' || !KNOWN_SOURCES.has(s.source)) return false;
  if (!(s.plan === null || isPlan(s.plan))) return false;
  if (!(s.roles instanceof Set)) return false;
  for (const r of s.roles) if (typeof r !== 'string' || !KNOWN_ROLES.has(r)) return false;
  return true;
}

function bearerToken(req: Request): string | null {
  const m = req.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i);
  return m?.[1]?.trim() || null;
}

const CORRELATION_RE = /^[A-Za-z0-9-]{8,64}$/;

export function correlationIdFor(req: Request): string {
  const h = req.headers.get('x-correlation-id');
  return h && CORRELATION_RE.test(h) ? h : crypto.randomUUID();
}

/**
 * Audit trail: denials and admin-role allows are logged as one structured
 * line (Supabase function logs). Plain plan-entitled allows are not logged
 * (volume). No request body, no token, no user content, no raw user id is
 * ever logged.
 */
export async function subjectRef(id: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`entitlement:${id}`));
  return Array.from(new Uint8Array(digest).slice(0, 8), (b) => b.toString(16).padStart(2, '0')).join('');
}

export async function logEntitlementDecision(
  subject: EntitlementSubject | null,
  decision: EntitlementDecision,
  correlationId: string,
): Promise<void> {
  if (decision.allowed && decision.reason !== 'ADMIN_ROLE') return;
  // Codex Gate 1 CX1-07 — pseudonymous subject reference (stable per user,
  // not the raw id) to limit what a broad log reader learns; the raw id can
  // be recomputed by an operator who already knows it.
  console.log(JSON.stringify({
    event: 'entitlement_decision',
    subject_type: subject?.type ?? null,
    subject_ref: subject ? await subjectRef(subject.id) : null,
    plan: subject?.plan ?? null,
    roles: subject ? [...subject.roles].sort() : [],
    module_id: decision.moduleId,
    lifecycle: decision.lifecycle ?? null,
    allowed: decision.allowed,
    code: decision.code ?? null,
    reason: decision.reason,
    correlation_id: correlationId,
    ts: new Date().toISOString(),
  }));
}

const STATUS_BY_CODE: Record<EntitlementErrorCode, number> = {
  AUTH_REQUIRED: 401,
  MODULE_NOT_AVAILABLE: 403,
  MODULE_DISABLED: 403,
  PLAN_REQUIRED: 403,
  ENTITLEMENT_UNAVAILABLE: 503,
};

/** Stable error contract: `error` is a machine code (same shape as the
 * existing QUOTA_EXCEEDED contract); the client translates it. Lifecycle
 * and internal reasons are deliberately NOT exposed. */
export function entitlementDeniedResponse(
  decision: EntitlementDecision,
  correlationId: string,
  corsHeaders: Record<string, string>,
): Response {
  const code = decision.code ?? 'ENTITLEMENT_UNAVAILABLE';
  const body: Record<string, unknown> = { error: code, module_id: decision.moduleId, correlation_id: correlationId };
  if (code === 'PLAN_REQUIRED' && decision.requiredPlan) body.required_plan = decision.requiredPlan;
  return new Response(JSON.stringify(body), {
    status: STATUS_BY_CODE[code],
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export async function resolveSubject(
  req: Request,
  user: AuthenticatedUser | null,
  source: EntitlementSubjectSource = defaultSubjectSource(),
): Promise<{ subject: EntitlementSubject | null; error: boolean }> {
  const token = bearerToken(req);
  if (!user?.id || !token) return { subject: null, error: false };
  try {
    const subject = await source.resolveUserSubject(user.id, token);
    if (!isSubjectBoundTo(subject, user.id)) return { subject: null, error: true };
    return { subject, error: false };
  } catch {
    return { subject: null, error: true };
  }
}

export type ModuleAccessResult =
  | { allowed: true; decision: EntitlementDecision; subject: EntitlementSubject; correlationId: string }
  | { allowed: false; decision: EntitlementDecision; response: Response; correlationId: string };

/**
 * The single call every MODULE-kind Edge Function makes, right after
 * resolveAuthenticatedUser() and before reserveQuota(). Fails closed on
 * every path, including an exception inside the subject source.
 */
export async function requireModuleAccess(
  req: Request,
  user: AuthenticatedUser | null,
  moduleId: string,
  corsHeaders: Record<string, string>,
  source?: EntitlementSubjectSource,
): Promise<ModuleAccessResult> {
  const correlationId = correlationIdFor(req);
  const { subject, error } = await resolveSubject(req, user, source);
  const decision: EntitlementDecision = error
    ? { allowed: false, code: 'ENTITLEMENT_UNAVAILABLE', reason: 'SUBJECT_SOURCE_ERROR', moduleId }
    : decideModuleAccess(subject, moduleId);
  await logEntitlementDecision(subject, decision, correlationId);
  if (decision.allowed && subject) return { allowed: true, decision, subject, correlationId };
  const denied = decision.allowed
    ? { ...decision, allowed: false, code: 'AUTH_REQUIRED' as const, reason: 'UNAUTHENTICATED' as const }
    : decision;
  return { allowed: false, decision: denied, response: entitlementDeniedResponse(denied, correlationId, corsHeaders), correlationId };
}
