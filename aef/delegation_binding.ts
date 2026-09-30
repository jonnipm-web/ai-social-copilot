/**
 * Delegation identity-binding checks (Section 8/9) that are implementable
 * TODAY, independent of whether a SERVICE identity can be cryptographically
 * verified (it cannot, in v0 -- see identity_resolver.ts's module doc).
 *
 * Audience/scope/request binding (audience mismatch, wrong-request binding)
 * are already implemented and adversarially tested in
 * contracts/aef/validators.ts's `validateRequestAgainstDelegation` -- this
 * file does not duplicate that, it only adds the ONE binding check that
 * genuinely lives at the kernel layer: the delegation's claimed `subject`
 * must match the INDEPENDENTLY VERIFIED requester identity, not merely the
 * requester's own self-claimed actor.id (which contracts/aef correctly
 * has no way to check, since it does no identity verification at all).
 *
 * Kept as a small, pure, directly-testable function so the
 * subject-mismatch defense can be proven correct in isolation, separate
 * from the (currently unreachable in production) question of whether a
 * delegation's issuer can itself be verified -- see kernel.ts's own
 * comment on why, in AEF v0, a real DelegationEnvelope's issuer can never
 * pass identity resolution (no SERVICE identity verification exists yet),
 * making the full delegated flow AUTH_FAILED end-to-end today regardless
 * of this check. This function exists so that guarantee is not silently
 * lost the day SERVICE identity verification is added in a future
 * mission -- the binding logic already exists and is tested now.
 */
import type { DelegationEnvelope } from "../contracts/aef/types.ts";
import type { PolicyDecision } from "./types.ts";

export function checkSubjectBinding(delegation: DelegationEnvelope, resolvedRequesterId: string): PolicyDecision | null {
  if (delegation.subject.id !== resolvedRequesterId) {
    return {
      decision: "DENY",
      reason: `delegation subject mismatch: delegation subject.id='${delegation.subject.id}' does not match the independently verified requester id='${resolvedRequesterId}'.`,
    };
  }
  return null;
}
