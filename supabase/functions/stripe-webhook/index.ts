import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { retrieveSubscription, StripeFetch, StripeSubscription, verifyStripeSignature } from '../_shared/stripe.ts';
import { createServiceClient } from '../_shared/service_client.ts';

/**
 * IVE-COMMERCIAL-BILLING-01 (Fast Track IV) — Stripe webhook. This
 * function has NO user session and is never called from the app; Stripe
 * calls it directly. Its entire trust boundary is the signature check
 * below — there is no Authorization header to validate, and no CORS
 * concern (no browser is involved).
 *
 * Trust model: service_role is used to write subscriptions/profiles, which
 * is exactly the carve-out the pre-existing X4B self-promotion trigger on
 * profiles already allows (`auth.role() = 'service_role'`). This does not
 * weaken that protection.
 */

export interface DbClient {
  from(table: string): {
    select(cols: string): {
      eq(col: string, val: unknown): {
        maybeSingle(): Promise<{ data: Record<string, unknown> | null; error: unknown }>;
      };
    };
    upsert(
      row: Record<string, unknown>,
      opts?: { onConflict?: string; ignoreDuplicates?: boolean },
    ): { select(): { maybeSingle(): Promise<{ data: Record<string, unknown> | null; error: unknown }> } };
    update(row: Record<string, unknown>): {
      eq(col: string, val: unknown): Promise<{ error: unknown }>;
    };
  };
}

interface StripeEvent {
  id: string;
  type: string;
  data: { object: Record<string, unknown> };
}

const PRO_ROLE_LIMIT = { role: 'pro', monthly_limit: 300 } as const;
const FREE_ROLE_LIMIT = { role: 'free', monthly_limit: 5 } as const;

/** Deliberately all-or-nothing: any status other than the two that mean
 * "currently paying and in good standing" reverts to FREE. There is no
 * partial/grace tier in this MVP's pricing model. */
function entitlementForStatus(status: string): { role: string; monthly_limit: number } {
  if (status === 'active' || status === 'trialing') return { ...PRO_ROLE_LIMIT };
  return { ...FREE_ROLE_LIMIT };
}

async function isEventAlreadyProcessed(db: DbClient, eventId: string): Promise<boolean> {
  const { data, error } = await db.from('processed_webhook_events').select('event_id').eq('event_id', eventId).maybeSingle();
  if (error) throw error;
  return data !== null;
}

/** Best-effort dedup record, written only AFTER processing succeeds so a
 * failed attempt is retried by Stripe rather than silently swallowed.
 * `ignoreDuplicates` makes a concurrent duplicate delivery's own record
 * attempt a harmless no-op instead of a unique-violation error. */
async function recordEventProcessed(db: DbClient, eventId: string, eventType: string): Promise<void> {
  const { error } = await db
    .from('processed_webhook_events')
    .upsert({ event_id: eventId, event_type: eventType }, { onConflict: 'event_id', ignoreDuplicates: true })
    .select()
    .maybeSingle();
  if (error) throw error;
}

async function findUserIdByCustomerId(db: DbClient, customerId: string): Promise<string | null> {
  const { data, error } = await db.from('subscriptions').select('user_id').eq('stripe_customer_id', customerId).maybeSingle();
  if (error) throw error;
  return (data?.user_id as string | undefined) ?? null;
}

/** Writes the CURRENT Stripe-reported subscription state as absolute
 * values (never deltas), which is what makes reprocessing the same or an
 * out-of-order event safe: whichever event is handled last always ends up
 * setting the same fields to whatever Stripe's API says is true right
 * now, not to something derived from the event payload's own age. */
async function applySubscriptionState(db: DbClient, userId: string, sub: StripeSubscription): Promise<void> {
  const priceId = sub.items?.data?.[0]?.price?.id ?? null;
  const { error: subError } = await db
    .from('subscriptions')
    .update({
      stripe_subscription_id: sub.id,
      stripe_price_id: priceId,
      status: sub.status,
      current_period_end: sub.current_period_end ? new Date(sub.current_period_end * 1000).toISOString() : null,
      cancel_at_period_end: !!sub.cancel_at_period_end,
    })
    .eq('user_id', userId);
  if (subError) throw subError;

  const { error: profileError } = await db.from('profiles').update(entitlementForStatus(sub.status)).eq('id', userId);
  if (profileError) throw profileError;
}

export async function handler(req: Request, stripeClient?: StripeFetch, dbClient?: DbClient): Promise<Response> {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');
  if (!webhookSecret) {
    console.error('STRIPE_WEBHOOK_SECRET not configured');
    return new Response('Server misconfigured', { status: 500 });
  }

  // MUST capture the raw text before any JSON parsing -- Stripe's
  // signature covers the exact bytes it sent over the wire. Re-serializing
  // a parsed-then-stringified body would not reliably match and would
  // make signature verification meaningless.
  const rawBody = await req.text();
  const signatureHeader = req.headers.get('Stripe-Signature');

  try {
    await verifyStripeSignature(rawBody, signatureHeader, webhookSecret);
  } catch (e) {
    console.error('Stripe webhook signature verification failed:', e);
    return new Response('Invalid signature', { status: 400 });
  }

  let event: StripeEvent;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }
  if (!event?.id || !event?.type) {
    return new Response('Malformed event', { status: 400 });
  }

  const db = (dbClient ?? createServiceClient()) as unknown as DbClient;

  try {
    if (await isEventAlreadyProcessed(db, event.id)) {
      // Duplicate delivery -- Stripe does not guarantee exactly-once. Ack
      // without reprocessing or calling the Stripe API again.
      return new Response(JSON.stringify({ received: true, duplicate: true }), { status: 200 });
    }

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as { customer?: string; subscription?: string };
        if (!session.customer || !session.subscription) break;
        const userId = await findUserIdByCustomerId(db, session.customer);
        if (!userId) {
          console.error('checkout.session.completed for unmapped customer', session.customer);
          break;
        }
        const sub = await retrieveSubscription(session.subscription, stripeClient);
        await applySubscriptionState(db, userId, sub);
        break;
      }
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const obj = event.data.object as unknown as StripeSubscription & { customer?: string };
        if (!obj.customer) break;
        const userId = await findUserIdByCustomerId(db, obj.customer);
        if (!userId) {
          console.error(`${event.type} for unmapped customer`, obj.customer);
          break;
        }
        // Re-fetch current truth from Stripe instead of trusting the
        // event payload -- delivery order is not guaranteed, so a stale
        // "active" event arriving after a newer "canceled" one must never
        // resurrect entitlement. Canceled subscriptions remain retrievable
        // in Stripe's API (they are not hard-deleted), so this GET
        // succeeds for both event types; the event's own payload is only
        // a fallback if retrieval itself errors.
        let sub: StripeSubscription;
        try {
          sub = await retrieveSubscription(obj.id, stripeClient);
        } catch (fetchErr) {
          console.error('retrieveSubscription failed, falling back to event payload:', fetchErr);
          sub = obj;
        }
        await applySubscriptionState(db, userId, sub);
        break;
      }
      default:
        // Unhandled event type: acknowledged, no action taken.
        break;
    }

    // Recorded only after successful processing -- if anything above
    // threw, this line never runs, so Stripe's retry re-enters processing
    // instead of being silently absorbed as a "duplicate".
    await recordEventProcessed(db, event.id, event.type);
  } catch (e) {
    console.error('stripe-webhook processing error:', e);
    return new Response(JSON.stringify({ error: 'processing failed' }), { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), { status: 200 });
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
