/**
 * IVE-COMMERCIAL-AUTH-01 — regression suite for the shared fail-closed
 * identity boundary. Proves the negative matrix required by the mission:
 * every failure mode throws AuthError (never resolves/returns null for a
 * caller to accidentally treat as "proceed anyway"), and a real user JWT
 * resolves correctly. The fake AuthClient stands in for Supabase Auth so
 * this runs with no network access and no live project.
 *
 * Run: deno test --allow-env supabase/functions/_shared/auth_test.ts
 */
import { assertEquals, assertRejects } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { AuthClient, AuthError, resolveAuthenticatedUser } from './auth.ts';

function req(authHeader?: string): Request {
  const headers = new Headers();
  if (authHeader !== undefined) headers.set('Authorization', authHeader);
  return new Request('https://example.test/fn', { method: 'POST', headers });
}

function fakeClient(
  result: { user: { id: string; email?: string } | null; error?: unknown },
): AuthClient {
  return {
    auth: {
      // deno-lint-ignore require-await
      async getUser(_token: string) {
        return { data: { user: result.user }, error: result.error ?? null };
      },
    },
  };
}

Deno.test('AUTH-A: no Authorization header -> AuthError', async () => {
  await assertRejects(() => resolveAuthenticatedUser(req(undefined), fakeClient({ user: null })), AuthError);
});

Deno.test('AUTH-B: malformed Authorization (no Bearer prefix) -> AuthError', async () => {
  await assertRejects(() => resolveAuthenticatedUser(req('Token abc123'), fakeClient({ user: null })), AuthError);
});

Deno.test('AUTH-B2: Authorization is just "Bearer" with nothing after -> AuthError', async () => {
  await assertRejects(() => resolveAuthenticatedUser(req('Bearer'), fakeClient({ user: null })), AuthError);
  await assertRejects(() => resolveAuthenticatedUser(req('Bearer   '), fakeClient({ user: null })), AuthError);
});

Deno.test('AUTH-C: Bearer publishable/anon key (valid JWT, no real session) -> AuthError', async () => {
  // This is the exact case verify_jwt=true alone would let through: a
  // syntactically valid, correctly-signed JWT (the public anon key) that
  // does not correspond to a real user session. getUser() must reject it.
  const client = fakeClient({ user: null, error: { message: 'invalid claim: missing sub claim' } });
  await assertRejects(() => resolveAuthenticatedUser(req('Bearer eyJpublishable-anon-key'), client), AuthError);
});

Deno.test('AUTH-D: invalid JWT -> AuthError', async () => {
  const client = fakeClient({ user: null, error: { message: 'invalid JWT' } });
  await assertRejects(() => resolveAuthenticatedUser(req('Bearer not-a-real-jwt'), client), AuthError);
});

Deno.test('AUTH-E: expired JWT -> AuthError', async () => {
  const client = fakeClient({ user: null, error: { message: 'JWT expired' } });
  await assertRejects(() => resolveAuthenticatedUser(req('Bearer expired.jwt.token'), client), AuthError);
});

Deno.test('AUTH-F2: truthy user object with empty id -> AuthError (Codex Gate C hardening)', async () => {
  // deno-lint-ignore no-explicit-any
  const client = fakeClient({ user: { id: '' } as any });
  await assertRejects(() => resolveAuthenticatedUser(req('Bearer some.token'), client), AuthError);
});

Deno.test('AUTH-F: auth resolution returns no user, no error -> AuthError', async () => {
  const client = fakeClient({ user: null });
  await assertRejects(() => resolveAuthenticatedUser(req('Bearer some.token'), client), AuthError);
});

Deno.test('AUTH-G: auth service error -> AuthError (fails closed, not open)', async () => {
  const client = fakeClient({ user: null, error: new Error('auth service unreachable') });
  await assertRejects(() => resolveAuthenticatedUser(req('Bearer some.token'), client), AuthError);
});

Deno.test('AUTH-H: valid user JWT -> resolves the authenticated user', async () => {
  const client = fakeClient({ user: { id: 'user-123', email: 'paulo@example.com' } });
  const user = await resolveAuthenticatedUser(req('Bearer valid.session.jwt'), client);
  assertEquals(user.id, 'user-123');
  assertEquals(user.email, 'paulo@example.com');
});

Deno.test('AUTH-I: env misconfiguration falls closed when no client is injected and env vars are absent', async () => {
  const prevUrl = Deno.env.get('SUPABASE_URL');
  const prevKey = Deno.env.get('SUPABASE_ANON_KEY');
  Deno.env.delete('SUPABASE_URL');
  Deno.env.delete('SUPABASE_ANON_KEY');
  try {
    await assertRejects(() => resolveAuthenticatedUser(req('Bearer some.token')), AuthError);
  } finally {
    if (prevUrl !== undefined) Deno.env.set('SUPABASE_URL', prevUrl);
    if (prevKey !== undefined) Deno.env.set('SUPABASE_ANON_KEY', prevKey);
  }
});
