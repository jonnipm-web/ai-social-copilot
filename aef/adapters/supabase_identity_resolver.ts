/**
 * Real (non-test) UserVerifier adapter. Thin wrapper around the EXISTING,
 * already-shipped `resolveAuthenticatedUser()` from
 * supabase/functions/_shared/auth.ts -- per the mission's Section 5/6
 * (AUTH DISCOVERY FIRST / DO NOT INVENT AUTH), this file must not
 * reimplement identity verification, only adapt the existing real
 * boundary (bearer token -> supabase.auth.getUser() -> GoTrue) to the
 * kernel's `UserVerifier` interface.
 *
 * This file is the ONLY place in `aef/` that imports from
 * `supabase/functions/_shared/` -- the kernel core (identity_resolver.ts,
 * kernel.ts, etc.) never depends on it directly, so the kernel stays
 * testable without Supabase/network access and this adapter can be
 * swapped if the auth backend ever changes.
 */
import { AuthError, resolveAuthenticatedUser } from "../../supabase/functions/_shared/auth.ts";
import type { AuthClient } from "../../supabase/functions/_shared/auth.ts";
import type { UserVerification, UserVerifier } from "../identity_resolver.ts";

export class SupabaseUserVerifier implements UserVerifier {
  /** Optional injectable client -- production code omits it and gets the real Supabase Auth client via resolveAuthenticatedUser()'s own defaultClient(). */
  constructor(private readonly client?: AuthClient) {}

  async verify(token: string): Promise<UserVerification> {
    // resolveAuthenticatedUser() reads the Authorization header off a
    // Request object -- construct a minimal synthetic one carrying only
    // the token we were given, so we reuse its exact parsing/verification
    // logic rather than duplicating it.
    const syntheticRequest = new Request("https://internal.invalid/aef-identity-resolution", {
      headers: { Authorization: `Bearer ${token}` },
    });

    try {
      const user = await resolveAuthenticatedUser(syntheticRequest, this.client);
      return { ok: true, userId: user.id };
    } catch (err) {
      if (err instanceof AuthError) {
        // resolveAuthenticatedUser() does not itself distinguish
        // "expired" from "invalid/malformed/non-user" at the type level
        // (see its own source: both collapse into one AuthError message,
        // 'Invalid, expired, or non-user token'). Rather than invent a
        // more precise classification this repo's real auth boundary
        // does not actually provide, this adapter conservatively reports
        // INVALID for that case -- equally fail-closed, just less
        // granular than the IdentityResolutionStatus type otherwise
        // allows. "Auth service misconfigured" (missing env vars) is
        // reported as UNAVAILABLE instead, since that is an operational
        // condition of the identity backend, not evidence the presented
        // credential itself is bad.
        if (err.message.includes("misconfigured")) {
          return { ok: false, reason: "UNAVAILABLE", detail: err.message };
        }
        return { ok: false, reason: "INVALID", detail: err.message };
      }
      // Anything else is an unexpected failure of the identity backend
      // itself (e.g. a network error reaching GoTrue) -- not proof the
      // credential is invalid.
      return { ok: false, reason: "UNAVAILABLE", detail: `unexpected error verifying credential: ${String(err)}` };
    }
  }
}
