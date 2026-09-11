/**
 * Service-role Supabase client — IVE-COMMERCIAL-BILLING-01.
 *
 * The ONLY two call sites in this codebase that legitimately need the
 * service-role key: create-checkout-session (writes the
 * user_id<->stripe_customer_id mapping on behalf of an already-verified
 * authenticated user) and stripe-webhook (has no user JWT at all --
 * Stripe calls it directly; its trust boundary is signature
 * verification, not a session). Both already satisfy the existing X4B
 * self-promotion trigger's carve-out (`auth.role() = 'service_role'`),
 * so this does not weaken that protection -- it's the exact exception
 * that trigger was written to allow.
 *
 * Never send this client, or the key it holds, to any client-facing
 * response. Never construct it from a request body value.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';

export function createServiceClient() {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error('service_client: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  }
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
