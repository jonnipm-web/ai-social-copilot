import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import { createCheckoutSession, createStripeCustomer, StripeFetch } from '../_shared/stripe.ts';
import { createServiceClient } from '../_shared/service_client.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/** Minimal surface of the supabase-js query builder this function
 * actually uses — lets tests inject a fake instead of a real DB. */
export interface DbClient {
  from(table: string): {
    select(cols: string): {
      eq(col: string, val: unknown): {
        maybeSingle(): Promise<{ data: Record<string, unknown> | null; error: unknown }>;
      };
    };
    upsert(row: Record<string, unknown>, opts?: { onConflict?: string }): Promise<{ error: unknown }>;
  };
}

// IVE-COMMERCIAL-BILLING-01 — server determines everything billing-
// relevant. body.user_id / body.role / body.monthly_limit / body.price_id
// are deliberately never read at all (the request body isn't even
// parsed) -- there is no field a client could send that this function
// would act on.
export async function handler(
  req: Request,
  authClient?: AuthClient,
  stripeClient?: StripeFetch,
  dbClient?: DbClient,
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  let user;
  try {
    user = await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  try {
    const priceId = Deno.env.get('STRIPE_PRICE_ID_PRO');
    if (!priceId) {
      console.error('STRIPE_PRICE_ID_PRO not configured');
      return new Response(
        JSON.stringify({ error: 'Assinatura indisponível no momento.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const db = (dbClient ?? createServiceClient()) as unknown as DbClient;

    const { data: existing } = await db
      .from('subscriptions')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .maybeSingle();

    let customerId = existing?.stripe_customer_id as string | undefined;
    if (!customerId) {
      const customer = await createStripeCustomer({ email: user.email, supabaseUserId: user.id }, stripeClient);
      customerId = customer.id;
      const { error: upsertError } = await db
        .from('subscriptions')
        .upsert({ user_id: user.id, stripe_customer_id: customerId, status: 'none' }, { onConflict: 'user_id' });
      if (upsertError) throw upsertError;
    }

    const successUrl = Deno.env.get('APP_CHECKOUT_SUCCESS_URL') ?? 'https://insightvalues.example/upgrade/success';
    const cancelUrl = Deno.env.get('APP_CHECKOUT_CANCEL_URL') ?? 'https://insightvalues.example/upgrade/cancel';

    const session = await createCheckoutSession(
      { customerId, priceId, successUrl, cancelUrl, supabaseUserId: user.id },
      stripeClient,
    );

    if (!session.url) {
      throw new Error('Stripe returned a checkout session without a url');
    }

    return new Response(
      JSON.stringify({ url: session.url }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('create-checkout-session error:', e);
    return new Response(
      JSON.stringify({ error: 'Não foi possível iniciar o checkout. Tente novamente.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
