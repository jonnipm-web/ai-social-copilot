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
  };
  /** Wraps the subscriptions+profiles write in one Postgres transaction
   * (public.apply_stripe_subscription_state) -- see migrations
   * 20260911020000 and 20260911030000. Returns `data: true` if the write
   * was applied, `data: false` if skipped because a chronologically newer
   * event (by Stripe's own event.created) already won. Codex's
   * adversarial gate found the previous two separate .update() calls
   * could leave the two tables inconsistent if the second call failed
   * after the first succeeded, and that even one atomic RPC call per
   * event could still let an older event's snapshot overwrite a newer
   * one's if their GETs and commits raced -- this return value is how the
   * caller observes that the ordering guard did its job. */
  rpc(fn: string, args: Record<string, unknown>): Promise<{ data: boolean | null; error: unknown }>;
}

interface StripeEvent {
  id: string;
  type: string;
  created: number;
  data: { object: Record<string, unknown> };
}

const PRO_ROLE_LIMIT = { role: 'pro', monthly_limit: 300 } as const;
const FREE_ROLE_LIMIT = { role: 'free', monthly_limit: 15 } as const;

/** Deliberately all-or-nothing: any status other than the two that mean
 * "currently paying and in good standing" reverts to FREE. There is no
 * partial/grace tier in this MVP's pricing model. */
function entitlementForStatus(status: string): { role: string; monthly_limit: number } {
  if (status === 'active' || status === 'trialing') return { ...PRO_ROLE_LIMIT };
  return { ...FREE_ROLE_LIMIT };
}

// IV-WEB-ECOSYSTEM-UNIFICATION-01 — per-product price mapping.
//
// STRIPE_PRICE_MAP env var: JSON object mapping Stripe price_id to
// {product, tier}. Example:
//   {"price_pro_core_monthly":{"product":"core","tier":"pro"},
//    "price_pro_impact_monthly":{"product":"impact","tier":"pro"}}
//
// If a price_id is NOT in the map: falls back to product='core',
// tier from entitlementForStatus (backward compat with all existing prices).
// If the env var is absent or invalid: falls back silently (no throw).

interface PriceProductEntry { product: string; tier: string }

function parsePriceMap(): Map<string, PriceProductEntry> {
  const raw = Deno.env.get('STRIPE_PRICE_MAP');
  if (!raw) return new Map();
  try {
    const obj = JSON.parse(raw) as Record<string, unknown>;
    const m = new Map<string, PriceProductEntry>();
    for (const [k, v] of Object.entries(obj)) {
      if (v && typeof v === 'object') {
        const e = v as Record<string, unknown>;
        if (typeof e.product === 'string' && typeof e.tier === 'string') {
          m.set(k, { product: e.product, tier: e.tier });
        }
      }
    }
    return m;
  } catch {
    console.error('STRIPE_PRICE_MAP parse error: invalid JSON — falling back to core-only mode');
    return new Map();
  }
}

// IV-WEB-ECOSYSTEM-UNIFICATION-01 — BLOCKING product entitlement write.
//
// Returns only after (A) product_subscriptions updated successfully OR
// (B) a durable pending record written to product_entitlement_events.
// Throws only when both (A) and (B) fail — in that case the caller
// returns 500 and Stripe retries the webhook.
//
// FAIL CLOSED routing: when STRIPE_PRICE_MAP is configured (non-empty)
// and the incoming price_id has no mapping, a durable pending_retry record
// is written (not silently dropped) and the caller returns 200. This is
// intentionally NOT a 5xx: a Stripe price that is genuinely legacy or
// discontinued should not cause infinite retries; the pending_retry record
// allows operator alerting and reconciliation. Legacy 'core' fallback only
// applies when the map is empty (no map configured at all).
async function applyProductSubscriptionState(
  db: DbClient,
  userId: string,
  sub: StripeSubscription,
  stripeEventId: string,
  stripeEventCreated: string,
  priceMap: Map<string, PriceProductEntry>,
): Promise<void> {
  const priceId = sub.items?.data?.[0]?.price?.id ?? null;
  const legacyTier = entitlementForStatus(sub.status).role; // 'pro' | 'free'
  const mapped = priceId ? priceMap.get(priceId) : undefined;

  // FAIL CLOSED: map configured + price unknown → write durable pending_retry
  // so the gap is never silent. 200 is still returned (not 5xx) to avoid
  // infinite Stripe retries for genuinely legacy or future price IDs that
  // will never appear in the map. The pending_retry record allows
  // reconciliation and operator alerting.
  if (priceMap.size > 0 && priceId !== null && !mapped) {
    console.warn(`applyProductSubscriptionState: price_id ${priceId} not in STRIPE_PRICE_MAP — writing durable pending_retry`);
    const { error: unmappedErr } = await db
      .from('product_entitlement_events')
      .upsert({
        user_id:         userId,
        product:         'unknown',
        event_type:      'pending_retry',
        to_status:       sub.status,
        to_tier:         'free',
        source:          'stripe',
        stripe_event_id: stripeEventId,
        metadata:        JSON.stringify({ reason: 'UNMAPPED_PRICE', price_id: priceId }),
      })
      .select()
      .maybeSingle();
    if (unmappedErr) {
      throw new Error(`UNMAPPED_PRICE durable record failed: ${String(unmappedErr)}`);
    }
    return;
  }

  const product = mapped?.product ?? 'core';
  const tier    = mapped?.tier    ?? legacyTier;
  const effectiveTier = sub.status === 'active' || sub.status === 'trialing' ? tier : 'free';

  let upsertError: unknown = null;
  try {
    const { error } = await (db as unknown as {
      rpc(fn: string, args: Record<string, unknown>): Promise<{ data: unknown; error: unknown }>;
    }).rpc('upsert_product_subscription', {
      p_user_id:                userId,
      p_product:                product,
      p_tier:                   effectiveTier,
      p_status:                 sub.status,
      p_source:                 'stripe',
      p_stripe_subscription_id: sub.id,
      p_stripe_price_id:        priceId,
      p_current_period_end:     sub.current_period_end ? new Date(sub.current_period_end * 1000).toISOString() : null,
      p_cancel_at_period_end:   !!sub.cancel_at_period_end,
      p_stripe_event_id:        stripeEventId,
      p_stripe_event_created:   stripeEventCreated,
      p_metadata:               {},
    });
    if (!error) return; // Path A: success
    upsertError = error;
  } catch (e) {
    upsertError = e;
  }

  // Path B: upsert_product_subscription failed — persist a durable pending
  // record to product_entitlement_events so the event is not silently lost.
  // A paid subscription confirmed by Stripe with no entitlement write is a
  // commercial failure; the durable record allows reconciliation or retry.
  // No onConflict: auto-generated UUID PK means each call is always an insert
  // (no unique constraint on stripe_event_id in this table).
  console.error('upsert_product_subscription failed; writing durable pending event:', upsertError);
  const { error: fallbackError } = await db
    .from('product_entitlement_events')
    .upsert(
      {
        user_id:         userId,
        product,
        event_type:      'pending_retry',
        to_status:       sub.status,
        to_tier:         effectiveTier,
        source:          'stripe',
        stripe_event_id: stripeEventId,
        metadata:        JSON.stringify({ error: String(upsertError), attempt: 1 }),
      },
    )
    .select()
    .maybeSingle();

  if (fallbackError) {
    // Both writes failed: throw so the caller returns 500 and Stripe retries.
    throw new Error(
      `Product entitlement write completely failed: upsert=${String(upsertError)}, fallback=${String(fallbackError)}`,
    );
  }
  // Durable pending record written (path B) — caller returns 200.
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
 * values (never deltas). Both tables are written in one Postgres
 * transaction via RPC, and the write is itself ordered by the webhook
 * event's own `created` timestamp -- Stripe's stable per-event creation
 * time, not delivery order -- so even if two different events for the
 * same subscription race on their Stripe GET and their commits land out
 * of order, the chronologically older one's snapshot can never overwrite
 * the newer one's (see migrations 20260911020000 and 20260911030000).
 * Returns false if this event was skipped as stale -- that is a normal,
 * expected outcome, not an error. */
async function applySubscriptionState(
  db: DbClient,
  userId: string,
  eventCreatedIso: string,
  sub: StripeSubscription,
): Promise<boolean> {
  const priceId = sub.items?.data?.[0]?.price?.id ?? null;
  const entitlement = entitlementForStatus(sub.status);
  const { data, error } = await db.rpc('apply_stripe_subscription_state', {
    p_user_id: userId,
    p_event_created: eventCreatedIso,
    p_stripe_subscription_id: sub.id,
    p_stripe_price_id: priceId,
    p_status: sub.status,
    p_current_period_end: sub.current_period_end ? new Date(sub.current_period_end * 1000).toISOString() : null,
    p_cancel_at_period_end: !!sub.cancel_at_period_end,
    p_role: entitlement.role,
    p_monthly_limit: entitlement.monthly_limit,
  });
  if (error) throw error;
  return data === true;
}

// Parsed once per cold start; safe to share across invocations.
const PRICE_MAP = parsePriceMap();

export async function handler(
  req: Request,
  stripeClient?: StripeFetch,
  dbClient?: DbClient,
  priceMapOverride?: Map<string, PriceProductEntry>,
): Promise<Response> {
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
  if (!event?.id || !event?.type || !event?.created) {
    return new Response('Malformed event', { status: 400 });
  }

  const db = (dbClient ?? createServiceClient()) as unknown as DbClient;
  const priceMap = priceMapOverride ?? PRICE_MAP;
  const eventCreatedIso = new Date(event.created * 1000).toISOString();

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
        const applied = await applySubscriptionState(db, userId, eventCreatedIso, sub);
        if (!applied) console.log(`checkout.session.completed ${event.id} skipped: superseded by a newer event`);
        if (applied) await applyProductSubscriptionState(db, userId, sub, event.id, eventCreatedIso, priceMap);
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
        // in Stripe's API (they are not hard-deleted), so this GET always
        // succeeds for both event types in normal operation.
        //
        // Codex's adversarial gate found an earlier version of this code
        // fell back to the event's OWN payload when this GET failed --
        // but a GET failure (network blip, transient 5xx) is unrelated to
        // whether the payload is stale, so that fallback could apply
        // exactly the stale state this re-fetch exists to prevent. There
        // is no safe fallback here: any failure must abort and let
        // Stripe's own retry re-attempt the fresh GET.
        const sub = await retrieveSubscription(obj.id, stripeClient);
        const applied = await applySubscriptionState(db, userId, eventCreatedIso, sub);
        if (!applied) console.log(`${event.type} ${event.id} skipped: superseded by a newer event`);
        if (applied) await applyProductSubscriptionState(db, userId, sub, event.id, eventCreatedIso, priceMap);
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
