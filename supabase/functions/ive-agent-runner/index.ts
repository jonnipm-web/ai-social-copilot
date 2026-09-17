// ive-agent-runner — RETIRED / CONTAINED (IV-SECURITY-REMEDIATION-02)
//
// SR-04: the original implementation was frozen since X4A; its source
// lived only on git branch `release/phase-10-stabilization`, never
// canonicalized to `main` (see .github/deploy-allowlist.tsv and
// docs/ive/SR04_SR05_CLOSURE.md). This file is a fresh, minimal
// retirement stub — it does NOT reconstruct, copy, or reference the
// frozen implementation in any way. It is now the canonical source for
// what actually runs in production under this function slug, closing
// the repository/runtime drift that SR-04 identified.
//
// SR-05: verify_jwt is now true (was false), and every request
// additionally passes through the same identity check used by every
// other real Edge Function in this project (mirrors
// supabase/functions/_shared/auth.ts::resolveAuthenticatedUser — inlined
// here because this slug is deployed as a single self-contained file,
// outside the canonical CI bundle). The handler performs no business
// logic regardless of identity: everyone gets 410 Gone. Zero known
// client callers were confirmed before this change
// (IV-SECURITY-REMEDIATION-02, DISCOVER phase: zero matches in lib/,
// zero matches in any Edge Function, across every branch).
//
// This slug remains permanently excluded from the canonical deploy
// workflow (.github/deploy-allowlist.tsv hard-block, IVE-X4R-DG2) even
// though a canonical source now exists — any future change to this file
// must be deployed the same way this one was: directly, outside CI,
// under an explicit mission.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.116.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function resolveAuthenticatedUser(req: Request): Promise<{ id: string }> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new Error("Missing Authorization header");
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  const token = match?.[1]?.trim();
  if (!token) throw new Error("Malformed Authorization header");

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) throw new Error("Auth service misconfigured");

  const client = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.auth.getUser(token);
  if (error || !data?.user?.id) throw new Error("Invalid, expired, or non-user token");
  return { id: data.user.id };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    await resolveAuthenticatedUser(req);
  } catch {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      error: "gone",
      message: "This function has been retired and is pending replacement by the AEF execution layer.",
    }),
    { status: 410, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
