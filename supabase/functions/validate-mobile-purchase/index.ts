// IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D6/D7
// validate-mobile-purchase — server-side mobile receipt validation.
//
// SECURITY INVARIANTS:
//   - Authentication required: anonymous requests are rejected (401)
//   - NEVER grant entitlement based on client-supplied data alone
//   - Receipt validation is the ONLY trigger for mobile entitlement
//   - service_role key NEVER returned to the caller
//   - BILLING_NOT_ACTIVATED while real product IDs are not configured
//
// STUB DESIGN (IV-MOBILE-BILLING-01):
//   This function is an intentional stub. It performs auth + input validation
//   but returns BILLING_NOT_ACTIVATED (503) unconditionally. This is correct
//   behavior: the stub prevents any real charge or entitlement until the
//   full activation gate (below) is cleared by Paulo + Agente Martins.
//   The 503 response is the expected result for all calls during FASE D.
//
// ACTIVATION GATE (IV-MOBILE-BILLING-01 — do NOT enable unilaterally):
//   Before this function grants real entitlements:
//   1. Paulo + Agente Martins authorize live billing activation
//   2. MobileProductCatalog populated with real product IDs
//   3. GOOGLE_PLAY_SERVICE_ACCOUNT_JSON env var set in Supabase Vault
//   4. APPLE_SHARED_SECRET env var set in Supabase Vault
//   5. product_subscriptions migration applied (add google_play/apple_iap sources)
//   6. Platform validation logic implemented and end-to-end verified
//
// module_policy.ts kind: BILLING (no module gate — this owns billing boundary).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  AuthenticatedUser,
  AuthError,
  resolveAuthenticatedUser,
  unauthorizedResponse,
} from '../_shared/auth.ts';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const VALID_PLATFORMS = new Set(['google_play', 'apple_iap']);

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method_not_allowed' }), {
      status: 405,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  // SECURITY: always authenticate before any processing (fail-closed)
  let _authUser: AuthenticatedUser;
  try {
    _authUser = await resolveAuthenticatedUser(req);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(CORS_HEADERS);
    throw e;
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'invalid_request_body' }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  const platform = body['platform'] as string | undefined;
  const receipt = body['receipt'] as string | undefined;
  const productId = body['product_id'] as string | undefined;

  if (!platform || !VALID_PLATFORMS.has(platform)) {
    return new Response(
      JSON.stringify({
        error: 'invalid_platform',
        detail: `platform must be one of: ${[...VALID_PLATFORMS].join(', ')}`,
      }),
      { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }

  if (!receipt || receipt.length === 0) {
    return new Response(
      JSON.stringify({ error: 'missing_receipt' }),
      { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }

  if (!productId || productId.length === 0) {
    return new Response(
      JSON.stringify({ error: 'missing_product_id' }),
      { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }

  // ─── BILLING NOT ACTIVATED (intentional stub) ────────────────────────────
  // See STUB DESIGN comment at top of file. This 503 is CORRECT behavior.
  //
  // When implementing live validation (after IV-MOBILE-BILLING-01 gate):
  //   - Use _authUser.id as the subject for entitlement writes
  //   - Google Play: use GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, call
  //     androidpublisher.v3 purchases.subscriptions.get, verify
  //     purchaseState === 1 and expiryTimeMillis > now()
  //   - Apple IAP: use APPLE_SHARED_SECRET, call App Store verifyReceipt,
  //     verify status === 0 and latest_receipt_info has active subscription
  //   - CRITICAL: always derive entitled product from the STORE'S response,
  //     never from product_id sent by the client
  //   - Insert/update product_subscriptions for _authUser.id after
  //     successful server-side verification (never on client assertion)
  //   - Implement idempotency to handle duplicate receipt submissions
  //   - product_subscriptions must accept google_play/apple_iap source values

  return new Response(
    JSON.stringify({
      error: 'BILLING_NOT_ACTIVATED',
      detail:
        'Mobile billing validation is not yet implemented. '
        + 'See IV-MOBILE-BILLING-01 activation requirements.',
    }),
    { status: 503, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
  );
});
