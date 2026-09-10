/**
 * Fail-closed authenticated-user resolution — IVE-COMMERCIAL-AUTH-01.
 *
 * verify_jwt=true on its own is NOT proof of a real signed-in user: the
 * project's public anon/publishable key is itself a validly-signed JWT and
 * passes the platform gate. This helper is the actual identity boundary —
 * it calls Supabase Auth's getUser(token), which resolves a real GoTrue
 * session and rejects the anon key (and any other non-session JWT) even
 * though that key would pass verify_jwt. See docs/ive/X4R_FINDINGS.md and
 * the IVE-COMMERCIAL-AUTH-01 Codex adversarial audit for the full finding.
 *
 * Contract: resolveAuthenticatedUser() either returns a real user or
 * throws AuthError. It never returns null/undefined for a caller to
 * accidentally treat as "proceed anyway" — every call site must wrap it in
 * try/catch and return unauthorizedResponse() on failure, before any
 * downstream paid AI call.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';

export interface AuthenticatedUser {
  id: string;
  email?: string;
}

export class AuthError extends Error {}

/** Minimal shape resolveAuthenticatedUser needs — lets tests inject a fake
 * client instead of hitting a real Supabase project or stubbing fetch. */
export interface AuthClient {
  auth: {
    getUser(token: string): Promise<{
      data: { user: { id: string; email?: string | null } | null };
      error: unknown;
    }>;
  };
}

export async function resolveAuthenticatedUser(
  req: Request,
  client?: AuthClient,
): Promise<AuthenticatedUser> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) throw new AuthError('Missing Authorization header');

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  const token = match?.[1]?.trim();
  if (!token) throw new AuthError('Malformed Authorization header');

  const authClient = client ?? defaultClient();
  const { data, error } = await authClient.auth.getUser(token);
  if (error || !data?.user?.id) throw new AuthError('Invalid, expired, or non-user token');

  return { id: data.user.id, email: data.user.email ?? undefined };
}

function defaultClient(): AuthClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !anonKey) throw new AuthError('Auth service misconfigured');

  return createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export function unauthorizedResponse(corsHeaders: Record<string, string>): Response {
  return new Response(JSON.stringify({ error: 'Unauthorized' }), {
    status: 401,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
