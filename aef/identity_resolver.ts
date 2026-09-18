/**
 * IdentityResolver (Section 7) -- the component that closes Finding F-02
 * ("auth_ref atualmente prova apenas boa formação... SCHEMA_VALID !=
 * AUTHENTICATED") at the kernel level, which contracts/aef explicitly
 * could not do (no cryptography in that mission's scope -- see
 * contracts/aef/README.md's escalated architectural decision).
 *
 * Per the mission's own Section 5/6 (AUTH DISCOVERY FIRST / DO NOT INVENT
 * AUTH) and the read-only audit performed before writing this file:
 *
 *   - `usr:` actors CAN be independently, cryptographically verified
 *     today, by reusing the exact pattern already used by every real
 *     business Edge Function in this repo: bearer token ->
 *     `supabase.auth.getUser(token)` (a real GoTrue call, not a local JWT
 *     decode) -- see supabase/functions/_shared/auth.ts's
 *     `resolveAuthenticatedUser()`. This resolver WRAPS that pattern via
 *     the `UserVerifier` interface below (see
 *     adapters/supabase_identity_resolver.ts for the concrete adapter);
 *     it does not reimplement it.
 *
 *   - `svc:` and `system:internal` actors CANNOT be independently
 *     verified today: the only server-to-server pattern in this repo is
 *     a shared `SUPABASE_SERVICE_ROLE_KEY` (proves possession of an env
 *     var, not a distinct per-service identity) plus one vendor-specific
 *     HMAC check (Stripe webhooks) that does not generalize. Per Section
 *     6, this resolver returns UNSUPPORTED for both -- fail-closed, not
 *     invented.
 */
import { validateActor } from "../contracts/aef/validators.ts";
import type { Actor } from "../contracts/aef/types.ts";
import type { IdentityResolution, IdentityResolver, RawCredential } from "./types.ts";

/**
 * The minimal boundary this resolver needs from a real auth backend.
 * Deliberately narrow (one method) so:
 *   (a) the real adapter is a thin wrapper around
 *       `resolveAuthenticatedUser()`, not a reimplementation of it;
 *   (b) tests can supply a fake without touching Supabase Auth/GoTrue or
 *       the network at all.
 */
export interface UserVerifier {
  /**
   * Verifies a raw bearer token against the real trust boundary. Returns
   * the verified user id on success. Returns a typed failure reason
   * instead of throwing -- callers must not have to guess whether a
   * thrown error means INVALID vs EXPIRED vs UNAVAILABLE.
   */
  verify(token: string): Promise<UserVerification>;
}

export type UserVerification =
  | { ok: true; userId: string }
  | { ok: false; reason: "INVALID" | "EXPIRED" | "UNAVAILABLE"; detail: string };

/**
 * The only IdentityResolver implementation in AEF v0. Domain-agnostic:
 * takes a UserVerifier so the same resolver logic runs against the real
 * Supabase adapter in production wiring and a fake in tests.
 */
export class AefIdentityResolver implements IdentityResolver {
  constructor(private readonly userVerifier: UserVerifier) {}

  async resolve(actor: Actor, credential: RawCredential): Promise<IdentityResolution> {
    // Defensive: never trust an actor shape we haven't independently
    // checked, even though the kernel also runs full contract validation
    // separately (Section 7 pipeline step precedes Section 6's full
    // ExecutionRequest validation -- this resolver must not assume it).
    const actorCheck = validateActor(actor);
    if (!actorCheck.ok) {
      return { status: "INVALID", reason: `malformed actor: ${actorCheck.errors.join("; ")}` };
    }

    if (actor.type === "service" || actor.type === "system") {
      // Section 6: DO NOT INVENT AUTH. No service-identity registry, no
      // signed service tokens, no scheduler attestation exist in this
      // repo today (see auth discovery evidence in the mission report).
      // A syntactically valid `svc:`/`system:internal` auth_ref is NOT
      // treated as verified -- this is the literal fix for F-02's
      // "SCHEMA_VALID != AUTHENTICATED" invariant for these actor types.
      return {
        status: "UNSUPPORTED",
        reason: `actor.type='${actor.type}' has no real identity-verification mechanism in this repository (no service registry, no signed assertions, no scheduler attestation) -- AEF v0 supports USER identity only`,
      };
    }

    // actor.type === "user" from here.
    if (credential.kind !== "bearer_jwt") {
      return {
        status: "UNAVAILABLE",
        reason: "no bearer credential supplied -- a user actor cannot be verified from auth_ref alone",
      };
    }

    let verification: UserVerification;
    try {
      verification = await this.userVerifier.verify(credential.token);
    } catch (err) {
      // The real adapter should itself never throw (see its own
      // contract), but a resolver must fail closed even if a future
      // implementation regresses that guarantee.
      return { status: "UNAVAILABLE", reason: `identity backend threw unexpectedly: ${String(err)}` };
    }

    if (!verification.ok) {
      if (verification.reason === "EXPIRED") return { status: "EXPIRED", reason: verification.detail };
      if (verification.reason === "UNAVAILABLE") return { status: "UNAVAILABLE", reason: verification.detail };
      return { status: "INVALID", reason: verification.detail };
    }

    // Identity binding (Section 8): the independently-verified id is the
    // only thing this resolver trusts. If it does not match what the
    // request CLAIMED (actor.id), that is a confused-deputy/actor-mismatch
    // attempt, not a verified identity -- deny, never "verify the claim
    // because the token was valid for *someone*."
    if (verification.userId !== actor.id) {
      return {
        status: "INVALID",
        reason: `verified identity '${verification.userId}' does not match claimed actor.id '${actor.id}' (actor mismatch)`,
      };
    }

    return { status: "VERIFIED", verifiedId: verification.userId, verifiedType: "user", source: "supabase_auth" };
  }
}
