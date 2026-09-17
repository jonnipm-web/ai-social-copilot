/**
 * Proves SupabaseUserVerifier correctly wraps resolveAuthenticatedUser()
 * without reimplementing it -- uses the SAME injectable-AuthClient test
 * pattern as supabase/functions/_shared/auth_test.ts, so this runs with
 * no network access and no live Supabase project.
 *
 * Run: deno test --allow-read aef/adapters/supabase_identity_resolver_test.ts
 */
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AuthClient } from "../../supabase/functions/_shared/auth.ts";
import { SupabaseUserVerifier } from "./supabase_identity_resolver.ts";

function fakeClient(result: { user: { id: string; email?: string } | null; error?: unknown }): AuthClient {
  return {
    auth: {
      // deno-lint-ignore require-await
      async getUser(_token: string) {
        return { data: { user: result.user }, error: result.error ?? null };
      },
    },
  };
}

Deno.test("SupabaseUserVerifier: valid token -> ok with the real GoTrue user id", async () => {
  const verifier = new SupabaseUserVerifier(fakeClient({ user: { id: "user-42", email: "a@b.com" } }));
  const result = await verifier.verify("real-session-jwt");
  assertEquals(result, { ok: true, userId: "user-42" });
});

Deno.test("SupabaseUserVerifier: GoTrue error -> INVALID (never throws, never proceeds)", async () => {
  const verifier = new SupabaseUserVerifier(fakeClient({ user: null, error: "invalid token" }));
  const result = await verifier.verify("garbage-token");
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.reason, "INVALID");
});

Deno.test("SupabaseUserVerifier: null user with no error -> INVALID", async () => {
  const verifier = new SupabaseUserVerifier(fakeClient({ user: null }));
  const result = await verifier.verify("anon-key-masquerading-as-a-session");
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.reason, "INVALID");
});

Deno.test("SupabaseUserVerifier: identity backend throws -> UNAVAILABLE, not INVALID", async () => {
  const throwingClient: AuthClient = {
    auth: {
      getUser(): Promise<{ data: { user: { id: string; email?: string | null } | null }; error: unknown }> {
        throw new Error("network unreachable");
      },
    },
  };
  const verifier = new SupabaseUserVerifier(throwingClient);
  const result = await verifier.verify("any-token");
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.reason, "UNAVAILABLE");
});
