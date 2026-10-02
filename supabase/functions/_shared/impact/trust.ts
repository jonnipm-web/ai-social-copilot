/**
 * Impact trust boundary — IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01.
 *
 * Separates explicitly:
 *   AUTHENTICATION  — who is the user? (from JWT, never from body)
 *   AUTHORIZATION   — are they allowed to use Impact? (entitlement check)
 *   SERVICE IDENTITY — which backend service is acting? (constant per deploy)
 *   USER IDENTITY   — which user does the action belong to? (from authentication)
 *   TENANT/PROJECT SCOPE — which project? (from request body, validated by DB)
 *   ACTION AUTHORITY — what policy governs this action? (from classification)
 *
 * Service_role is a TECHNICAL CAPABILITY of the backend. It is NOT:
 *   - proof of authorization to a business action
 *   - proof of which user requested the action
 *   - proof of which project is in scope
 *   - a substitute for entitlement check
 *
 * Any consequential action must carry a CallerContext through the entire
 * call chain, so any component can answer: WHO requested? WHO authorized?
 * FOR WHICH user/project? UNDER WHICH policy?
 *
 * Note: CallerContext is defined here (not imported from AEF) so the Impact
 * core stays isolated from the AEF runtime. The AEF module imports this type.
 */

// ── CallerContext ─────────────────────────────────────────────────────────────

/**
 * CallerContext is the verified identity and authorization context for a
 * caller. It is built from server-verified sources ONLY (JWT claims,
 * entitlement check, server-side policy) — never from request body values.
 *
 * Parity with aef/types.ts CallerContext is checked in trust_test.ts.
 */
export interface CallerContext {
  /** Supabase auth.users.id, derived from the verified session JWT. */
  readonly authenticatedUserId: string;
  /** Which module entitlement is active (e.g. 'impact'). */
  readonly moduleId: string;
  /** The correlation id carried through the whole request chain. */
  readonly correlationId: string;
  /** Project scope if applicable (null = user-level scope). */
  readonly projectId: string | null;
  /** Service instance identifier (e.g. 'impact-lab', 'impact-monitor'). */
  readonly serviceId: string;
}

// ── Service identity registry ────────────────────────────────────────────────

/**
 * Allowed service identifiers. Each value corresponds to an exact Edge Function
 * or background job that may issue consequential Impact actions.
 * A service_role client held by an unknown service ID must not be treated as
 * an authorized caller.
 */
export const IMPACT_SERVICE_IDS = Object.freeze([
  'impact-lab',
  'impact-monitor',
] as const);

export type ImpactServiceId = typeof IMPACT_SERVICE_IDS[number];

export function isKnownServiceId(id: string): id is ImpactServiceId {
  return (IMPACT_SERVICE_IDS as readonly string[]).includes(id);
}

// ── Caller context builder ────────────────────────────────────────────────────

export interface TrustContextInput {
  readonly authenticatedUserId: string;
  readonly correlationId: string;
  readonly projectId: string | null;
  readonly serviceId: string;
}

/**
 * Build a CallerContext from server-verified inputs. All fields must be
 * derived from server-side sources (JWT, entitlement, config) — never from
 * the request body.
 *
 * Throws if serviceId is not in the allowed registry.
 */
export function buildCallerContext(input: TrustContextInput): CallerContext {
  if (!isKnownServiceId(input.serviceId)) {
    throw new Error(`TRUST_VIOLATION: unknown serviceId "${input.serviceId}"`);
  }
  if (!input.authenticatedUserId) {
    throw new Error('TRUST_VIOLATION: authenticatedUserId is required');
  }
  if (!input.correlationId) {
    throw new Error('TRUST_VIOLATION: correlationId is required');
  }
  return Object.freeze({
    authenticatedUserId: input.authenticatedUserId,
    moduleId: 'impact',
    correlationId: input.correlationId,
    projectId: input.projectId,
    serviceId: input.serviceId,
  });
}

// ── Project scope validation ─────────────────────────────────────────────────

/**
 * Validate that a project ID in a request actually belongs to the
 * authenticated user. This is a SECOND layer after RLS; it must be called
 * before any consequential action that names a projectId.
 *
 * Returns true if the project scope is valid. The caller must reject the
 * request with PROJECT_SCOPE_VIOLATION if this returns false.
 */
export function validateProjectScope(
  claimedProjectId: string | null,
  context: CallerContext,
  userOwnedProjectIds: ReadonlySet<string>,
): boolean {
  if (claimedProjectId === null) return true; // null = user-level scope, always valid
  if (claimedProjectId !== context.projectId) return false; // mismatch with context
  return userOwnedProjectIds.has(claimedProjectId);
}

// ── Trust audit entry ────────────────────────────────────────────────────────

/**
 * A structured trust audit entry. Contains only opaque IDs and codes —
 * no document content, no personal data, no secrets.
 */
export interface TrustAuditEntry {
  readonly correlationId: string;
  readonly serviceId: string;
  readonly userId: string; // opaque hash, not the raw UUID
  readonly projectId: string | null;
  readonly action: string;
  readonly outcome: 'ALLOWED' | 'DENIED' | 'SCOPE_VIOLATION';
  readonly at: string;
}

export function buildTrustAudit(
  context: CallerContext,
  action: string,
  outcome: TrustAuditEntry['outcome'],
  now: string,
  hashedUserId: string,
): TrustAuditEntry {
  return Object.freeze({
    correlationId: context.correlationId,
    serviceId: context.serviceId,
    userId: hashedUserId,
    projectId: context.projectId,
    action,
    outcome,
    at: now,
  });
}
