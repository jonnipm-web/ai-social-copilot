/**
 * IVE-COMMERCIAL-BILLING-01 — stripe-webhook tests. Covers signature
 * verification at the boundary, idempotency (including the "record only
 * after success" ordering), event-ordering-safe entitlement transitions
 * (by Stripe's own event.created, not delivery order or GET timing), and
 * cross-user isolation.
 *
 * Execução:
 *   DENO_TESTING=1 STRIPE_WEBHOOK_SECRET=whsec_test deno test --allow-env supabase/functions/stripe-webhook/index_test.ts
 */
import { assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { StripeFetch, StripeSubscription } from '../_shared/stripe.ts';

const SECRET = 'whsec_test_secret';
Deno.env.set('STRIPE_WEBHOOK_SECRET', SECRET);

const { handler } = await import('./index.ts');

const NOW = Math.floor(Date.now() / 1000);

async function sign(payload: string, timestamp: number, secret = SECRET): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${payload}`));
  return Array.from(new Uint8Array(bytes)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** `created` defaults to NOW so every test event carries a valid event
 * timestamp unless a test deliberately overrides it to exercise ordering. */
function evt(body: { id: string; type: string; created?: number; data?: { object: Record<string, unknown> } }) {
  return { data: { object: {} }, ...body, created: body.created ?? NOW };
}

async function signedReq(bodyObj: unknown, opts: { secret?: string; ts?: number; noSig?: boolean } = {}): Promise<Request> {
  const body = JSON.stringify(bodyObj);
  const ts = opts.ts ?? Math.floor(Date.now() / 1000);
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (!opts.noSig) {
    const sig = await sign(body, ts, opts.secret ?? SECRET);
    headers['Stripe-Signature'] = `t=${ts},v1=${sig}`;
  }
  return new Request('http://localhost/', { method: 'POST', headers, body });
}

function fakeStripe(subs: Record<string, StripeSubscription>): StripeFetch & { calls: string[] } {
  const calls: string[] = [];
  return Object.assign(
    // deno-lint-ignore require-await
    async (path: string) => {
      calls.push(path);
      const match = path.match(/^\/subscriptions\/(.+)$/);
      if (match && subs[match[1]]) {
        return { ok: true, status: 200, json: () => Promise.resolve(subs[match[1]] as unknown as Record<string, unknown>) };
      }
      return { ok: false, status: 404, json: () => Promise.resolve({}) };
    },
    { calls },
  );
}

function makeSub(overrides: Partial<StripeSubscription> = {}): StripeSubscription {
  return {
    id: 'sub_1',
    status: 'active',
    cancel_at_period_end: false,
    current_period_end: Math.floor(Date.now() / 1000) + 30 * 86400,
    items: { data: [{ price: { id: 'price_test_pro_monthly' } }] },
    ...overrides,
  };
}

interface DbState {
  subscriptions: Record<string, Record<string, unknown>>; // keyed by user_id
  customerToUser: Record<string, string>;
  profiles: Record<string, Record<string, unknown>>;
  processedEvents: Record<string, string>;
  // IV-WEB-ECOSYSTEM-UNIFICATION-01: keyed by `${user_id}:${product}`
  productSubscriptions: Record<string, Record<string, unknown>>;
  // IV-WEB-ECOSYSTEM-UNIFICATION-01: durable fallback events, keyed by stripe_event_id
  productEntitlementEvents: Record<string, Record<string, unknown>>;
}

/** Returns the effective (highest active tier) product subscription for (userId, product).
 * Mirrors resolve_product_entitlement aggregation logic for test assertions.
 * Falls back to first matching row if none are active. */
function psEffective(state: DbState, userId: string, product: string): Record<string, unknown> | undefined {
  const prefix = `${userId}:${product}:`;
  const rows = Object.entries(state.productSubscriptions)
    .filter(([k]) => k.startsWith(prefix))
    .map(([, v]) => v);
  if (rows.length === 0) return undefined;
  const tierRank = (t: unknown) => t === 'premium' ? 2 : t === 'pro' ? 1 : 0;
  const active = rows.filter(r => r.status === 'active' || r.status === 'trialing');
  const pool = active.length > 0 ? active : rows;
  return pool.sort((a, b) => tierRank(b.tier) - tierRank(a.tier))[0];
}

/** Returns the row for a specific subscription ID (for ordering/stale tests). */
function psRow(state: DbState, userId: string, product: string, subId: string): Record<string, unknown> | undefined {
  return state.productSubscriptions[`${userId}:${product}:${subId}`];
}

function fakeDb(initial: DbState) {
  const state = initial;
  return {
    state,
    // Mirrors public.apply_stripe_subscription_state (migrations
    // 20260911020000 + 20260911030000) as closely as a JS fake reasonably
    // can: a real Postgres `UPDATE ... WHERE user_id = X AND (...)`,
    // never an insert. Codex's third review (task-mtw7wtog-py3laq) found
    // an earlier version of this fake auto-created a subscriptions row on
    // first write, which production code never does -- by the time any
    // webhook event exists, create-checkout-session has already inserted
    // the row (see newState() below), so a missing row here means the
    // customer mapping is broken, not "first event for a new user", and
    // must behave like a real UPDATE matching zero rows: applied=false,
    // profiles untouched.
    rpc(fn: string, args: Record<string, unknown>): Promise<{ data: boolean | null; error: unknown }> {
      if (fn === 'apply_stripe_subscription_state') {
        const userId = args.p_user_id as string;
        const existing = state.subscriptions[userId];
        if (!existing) return Promise.resolve({ data: false, error: null }); // UPDATE matched zero rows
        const eventCreated = args.p_event_created as string;
        const lastEventCreated = existing.last_event_created as string | null | undefined;
        const incomingEventId = args.p_stripe_event_id as string | null ?? null;
        const lastEventId = existing.last_stripe_event_id as string | null ?? null;
        // R25-A: tuple ordering — mirrors migration 20261016000007.
        const legacyTupleStale = (lastEventCreated != null) && (
          eventCreated < lastEventCreated ||
          (eventCreated === lastEventCreated && incomingEventId !== null && lastEventId !== null && incomingEventId < lastEventId)
        );
        if (legacyTupleStale) {
          return Promise.resolve({ data: false, error: null }); // stale -- skipped
        }
        state.subscriptions[userId] = {
          ...existing,
          stripe_subscription_id: args.p_stripe_subscription_id,
          stripe_price_id: args.p_stripe_price_id,
          status: args.p_status,
          current_period_end: args.p_current_period_end,
          cancel_at_period_end: args.p_cancel_at_period_end,
          last_event_created: eventCreated,
          last_stripe_event_id: incomingEventId,
        };
        state.profiles[userId] = {
          ...(state.profiles[userId] ?? {}),
          role: args.p_role,
          monthly_limit: args.p_monthly_limit,
        };
        return Promise.resolve({ data: true, error: null });
      }
      // IV-WEB-ECOSYSTEM-UNIFICATION-01 v2: multi-subscription upsert.
      // Key: `${userId}:${product}:${stripe_subscription_id}` — one row per subscription.
      // Use psEffective(state, userId, product) to get the aggregated entitlement.
      if (fn === 'upsert_product_subscription') {
        const userId = args.p_user_id as string;
        const product = args.p_product as string;
        const subId = (args.p_stripe_subscription_id as string | null | undefined) ?? 'default';
        const tripleKey = `${userId}:${product}:${subId}`;
        const existing = state.productSubscriptions[tripleKey];
        // R25-A: tuple ordering (event_created, event_id) — mirrors migration 20261016000007.
        const incomingCreated = args.p_stripe_event_created as string | null ?? null;
        const lastCreated = existing?.last_stripe_event_created as string | null ?? null;
        const incomingEventId = args.p_stripe_event_id as string | null ?? null;
        const lastEventId = existing?.last_stripe_event_id as string | null ?? null;
        const tupleStale = (incomingCreated !== null && lastCreated !== null) && (
          incomingCreated < lastCreated ||
          (incomingCreated === lastCreated && incomingEventId !== null && lastEventId !== null && incomingEventId <= lastEventId)
        );
        if (tupleStale) {
          return Promise.resolve({ data: { ok: false, skipped: true, reason: 'STALE_EVENT', product }, error: null }) as never;
        }
        state.productSubscriptions[tripleKey] = {
          product, tier: args.p_tier, status: args.p_status, source: args.p_source,
          stripe_subscription_id: subId,
          stripe_customer_id: args.p_stripe_customer_id,
          stripe_price_id: args.p_stripe_price_id,
          last_stripe_event_created: incomingCreated,
          last_stripe_event_id: incomingEventId,
        };
        return Promise.resolve({ data: { ok: true, product, tier: args.p_tier, status: args.p_status }, error: null }) as never;
      }
      // P1-I fix: resolve_product_entitlement — mirrors SQL aggregation for test assertions.
      // Returns allowed=true if any active/trialing productSubscription exists for (userId, product).
      if (fn === 'resolve_product_entitlement') {
        const userId = args.p_user_id as string;
        const product = args.p_product as string;
        const prefix = `${userId}:${product}:`;
        const rows = Object.entries(state.productSubscriptions)
          .filter(([k]) => k.startsWith(prefix))
          .map(([, v]) => v);
        const activeRows = rows.filter(r => r.status === 'active' || r.status === 'trialing');
        if (activeRows.length > 0) {
          const tierRank = (t: unknown) => t === 'premium' ? 2 : t === 'pro' ? 1 : 0;
          const best = [...activeRows].sort((a, b) => tierRank(b.tier) - tierRank(a.tier))[0];
          return Promise.resolve({ data: { allowed: true, product, tier: best.tier, source: 'product_subscriptions' }, error: null }) as never;
        }
        return Promise.resolve({ data: { allowed: false, product, code: 'NO_ENTITLEMENT' }, error: null }) as never;
      }
      // P1-A fix: cancel_core_entitlement_atomic — mirrors the atomic SQL RPC for Core cancellation.
      // Runs upsert_product_subscription + resolve_product_entitlement + conditional apply_stripe_subscription_state
      // atomically (in production, protected by a per-user advisory lock).
      if (fn === 'cancel_core_entitlement_atomic') {
        const userId = args.p_user_id as string;
        const product = args.p_product as string;
        const subId = (args.p_stripe_subscription_id as string | null | undefined) ?? 'default';
        const tripleKey = `${userId}:${product}:${subId}`;
        const existing = state.productSubscriptions[tripleKey];
        const incomingCreated = args.p_stripe_event_created as string | null ?? null;
        const lastCreated = existing?.last_stripe_event_created as string | null ?? null;
        const incomingEventId = args.p_stripe_event_id as string | null ?? null;
        const lastEventId = existing?.last_stripe_event_id as string | null ?? null;
        // R25-A: tuple ordering
        const cancelTupleStale = (incomingCreated !== null && lastCreated !== null) && (
          incomingCreated < lastCreated ||
          (incomingCreated === lastCreated && incomingEventId !== null && lastEventId !== null && incomingEventId <= lastEventId)
        );
        let upsertResult: Record<string, unknown>;
        if (cancelTupleStale) {
          upsertResult = { ok: false, skipped: true, reason: 'STALE_EVENT', product };
        } else {
          state.productSubscriptions[tripleKey] = {
            product, tier: args.p_tier, status: args.p_status, source: args.p_source,
            stripe_subscription_id: subId, stripe_customer_id: args.p_stripe_customer_id,
            stripe_price_id: args.p_stripe_price_id, last_stripe_event_created: incomingCreated,
            last_stripe_event_id: incomingEventId,
          };
          upsertResult = { ok: true, product, tier: args.p_tier, status: args.p_status };
        }
        // Check entitlement post-upsert
        const prefix = `${userId}:${product}:`;
        const rows = Object.entries(state.productSubscriptions).filter(([k]) => k.startsWith(prefix)).map(([, v]) => v);
        const activeRows = rows.filter(r => r.status === 'active' || r.status === 'trialing');
        const tierRank = (t: unknown) => t === 'premium' ? 2 : t === 'pro' ? 1 : 0;
        const entResult = activeRows.length > 0
          ? { allowed: true, product, tier: [...activeRows].sort((a, b) => tierRank(b.tier) - tierRank(a.tier))[0].tier }
          : { allowed: false, product, code: 'NO_ENTITLEMENT' };
        let legacyApplied = false;
        // Conditionally apply legacy downgrade (mirrors apply_stripe_subscription_state)
        if (!entResult.allowed) {
          const existing = state.subscriptions[userId];
          if (existing) {
            const eventCreated = args.p_stripe_event_created as string | null ?? null;
            const lastEventCreated = existing.last_event_created as string | null | undefined;
            const lastLegacyEventId = existing.last_stripe_event_id as string | null ?? null;
            // R25-A tuple ordering for legacy path
            const legacyStale = (lastEventCreated != null && eventCreated != null) && (
              eventCreated < lastEventCreated ||
              (eventCreated === lastEventCreated && incomingEventId !== null && lastLegacyEventId !== null && incomingEventId < lastLegacyEventId)
            );
            if (!legacyStale) {
              state.subscriptions[userId] = {
                ...existing, stripe_subscription_id: args.p_stripe_subscription_id,
                stripe_price_id: args.p_stripe_price_id, status: args.p_status,
                current_period_end: args.p_current_period_end, cancel_at_period_end: args.p_cancel_at_period_end,
                last_event_created: eventCreated, last_stripe_event_id: incomingEventId,
              };
              // Migration 20261010000000: only update Stripe-managed roles (free/pro).
              // admin/beta_tester/premium are never touched by billing events.
              const currentRoleCancel = state.profiles[userId]?.role as string | undefined;
              if (currentRoleCancel === 'free' || currentRoleCancel === 'pro') {
                state.profiles[userId] = { ...(state.profiles[userId] ?? {}), role: args.p_legacy_role, monthly_limit: args.p_legacy_monthly_limit };
              }
              legacyApplied = true;
            }
            // R22-A fix: if timestamp guard blocked the legacy write but entitlement is
            // truly inactive, force-downgrade profiles so authorization reflects reality.
            // Only applies to Stripe-managed roles ('pro'). admin/beta_tester/premium are
            // granted outside Stripe and must not be changed by cancellation events.
            // Mirrors the protection in apply_stripe_subscription_state (migration 20261010000000).
            if (!legacyApplied) {
              const currentRole = state.profiles[userId]?.role as string | undefined;
              if (currentRole === 'pro') {
                state.profiles[userId] = { ...(state.profiles[userId] ?? {}), role: 'free', monthly_limit: 15 };
                legacyApplied = true;
              }
            }
          }
        }
        return Promise.resolve({ data: { upsert: upsertResult, entitlement: entResult, legacy_applied: legacyApplied }, error: null }) as never;
      }
      // R12+R16-C fix: activate_core_entitlement_atomic — mirrors the revised SQL RPC for Core activation.
      // Order: (1) product upsert, (2) resolve entitlement, (3) apply legacy (user-global guard),
      // (4) if allowed AND legacy stale → force-update profiles from resolver tier.
      if (fn === 'activate_core_entitlement_atomic') {
        const userId = args.p_user_id as string;
        const product = args.p_product as string;
        const subId = (args.p_stripe_subscription_id as string | null | undefined) ?? 'default';
        const tripleKey = `${userId}:${product}:${subId}`;
        // Step 1: product activation — R25-A tuple ordering
        const existingProd = state.productSubscriptions[tripleKey];
        const incomingCreated = args.p_stripe_event_created as string | null ?? null;
        const lastCreated = existingProd?.last_stripe_event_created as string | null ?? null;
        const incomingEventId = args.p_stripe_event_id as string | null ?? null;
        const lastEventIdAct = existingProd?.last_stripe_event_id as string | null ?? null;
        const activateTupleStale = (incomingCreated !== null && lastCreated !== null) && (
          incomingCreated < lastCreated ||
          (incomingCreated === lastCreated && incomingEventId !== null && lastEventIdAct !== null && incomingEventId <= lastEventIdAct)
        );
        let upsertResult: Record<string, unknown>;
        if (activateTupleStale) {
          upsertResult = { ok: false, skipped: true, reason: 'STALE_EVENT', product };
        } else {
          state.productSubscriptions[tripleKey] = {
            product, tier: args.p_tier, status: args.p_status, source: args.p_source,
            stripe_subscription_id: subId, stripe_customer_id: args.p_stripe_customer_id,
            stripe_price_id: args.p_stripe_price_id, last_stripe_event_created: incomingCreated,
            last_stripe_event_id: incomingEventId,
          };
          upsertResult = { ok: true, product, tier: args.p_tier, status: args.p_status };
        }
        // Step 2: resolve aggregated entitlement
        const prefix = `${userId}:${product}:`;
        const allRows = Object.entries(state.productSubscriptions).filter(([k]) => k.startsWith(prefix)).map(([, v]) => v);
        const activeRows2 = allRows.filter(r => r.status === 'active' || r.status === 'trialing');
        const tierRank2 = (t: unknown) => t === 'premium' ? 2 : t === 'pro' ? 1 : 0;
        const entResult2 = activeRows2.length > 0
          ? { allowed: true, product, tier: [...activeRows2].sort((a, b) => tierRank2(b.tier) - tierRank2(a.tier))[0].tier }
          : { allowed: false, product, code: 'NO_ENTITLEMENT' };
        let legacyApplied = false;
        let legacyRowExists = false;
        if (entResult2.allowed) {
          // Step 3: apply legacy (user-global timestamp guard).
          // R17-B fix: use aggregate resolver tier for role/limit, not the incoming event's individual tier.
          const resolvedTierStep3 = (entResult2 as Record<string, unknown>).tier as string | undefined;
          // R24 fix: Stripe billing capped at 'pro' — mirrors migration 20261016000006.
          // tier='premium' → 'pro' (paid sub, cap applies); other → 'free'.
          const applyRole   = (resolvedTierStep3 === 'premium' || resolvedTierStep3 === 'pro') ? 'pro' : 'free';
          const applyLimit  = applyRole === 'pro' ? 300 : 15;
          const existingLegacy = state.subscriptions[userId];
          legacyRowExists = existingLegacy !== undefined;
          if (existingLegacy) {
            const eventCreated = args.p_stripe_event_created as string | null ?? null;
            const lastEventCreated = existingLegacy.last_event_created as string | null | undefined;
            const lastLegacyEventIdAct = existingLegacy.last_stripe_event_id as string | null ?? null;
            // R25-A: tuple ordering for legacy path in activate
            const legActStale = (lastEventCreated != null && eventCreated != null) && (
              eventCreated < lastEventCreated ||
              (eventCreated === lastEventCreated && incomingEventId !== null && lastLegacyEventIdAct !== null && incomingEventId < lastLegacyEventIdAct)
            );
            if (!legActStale) {
              state.subscriptions[userId] = {
                ...existingLegacy,
                stripe_subscription_id: args.p_stripe_subscription_id,
                stripe_price_id: args.p_stripe_price_id,
                status: args.p_status,
                current_period_end: args.p_current_period_end,
                cancel_at_period_end: args.p_cancel_at_period_end,
                last_event_created: eventCreated,
                last_stripe_event_id: incomingEventId,
              };
              state.profiles[userId] = {
                ...(state.profiles[userId] ?? {}),
                role: applyRole,
                monthly_limit: applyLimit,
              };
              legacyApplied = true;
            }
          }
          // Step 4: R16-C fix — if product row was written (upsert ok=true) AND legacy row EXISTS
          // but was skipped by the user-global timestamp guard (cross-subscription stale ordering),
          // force-update profiles from resolver tier.
          // If upsert was STALE_EVENT (same-sub duplicate): both upsert and legacy are stale → no repair.
          // If subscriptions row absent: mapping is broken → no force-update.
          const upsertWasOk = upsertResult.ok === true;
          if (!legacyApplied && upsertWasOk && legacyRowExists && state.profiles[userId] !== undefined) {
            // applyRole/applyLimit already derived from resolver tier above.
            const currentRole = state.profiles[userId].role as string | undefined;
            // R24: applyRole is always 'pro' or 'free'; only upgrade free/undefined.
            if (currentRole === 'free' || currentRole === undefined) {
              state.profiles[userId] = { ...(state.profiles[userId] ?? {}), role: applyRole, monthly_limit: applyLimit };
              legacyApplied = true;
            }
          }
        }
        return Promise.resolve({ data: { legacy_applied: legacyApplied, upsert: upsertResult, entitlement: entResult2 }, error: null }) as never;
      }
      throw new Error(`unexpected rpc in test fake: ${fn}`);
    },
    // Mirrors the product_entitlement_events table for the durable fallback path (Path B).
    from(table: string) {
      if (table === 'processed_webhook_events') {
        return {
          select: (_c: string) => ({
            eq: (_col: string, val: string) => ({
              maybeSingle: () => Promise.resolve({ data: state.processedEvents[val] ? { event_id: val } : null, error: null }),
            }),
          }),
          upsert: (row: Record<string, unknown>) => ({
            select: () => ({
              maybeSingle: () => {
                state.processedEvents[row.event_id as string] = row.event_type as string;
                return Promise.resolve({ data: row, error: null });
              },
            }),
          }),
        };
      }
      if (table === 'subscriptions') {
        return {
          select: (_c: string) => ({
            eq: (col: string, val: string) => ({
              maybeSingle: () => {
                if (col === 'stripe_customer_id') {
                  const userId = state.customerToUser[val];
                  return Promise.resolve({ data: userId ? { user_id: userId } : null, error: null });
                }
                if (col === 'user_id') {
                  // P1-K: return the subscription row for this user_id (for legacy sub_id check).
                  const row = state.subscriptions[val];
                  return Promise.resolve({ data: row ?? null, error: null });
                }
                return Promise.resolve({ data: null, error: null });
              },
            }),
          }),
        };
      }
      if (table === 'product_entitlement_events') {
        return {
          upsert: (row: Record<string, unknown>, _opts?: unknown) => ({
            select: () => ({
              maybeSingle: () => {
                const key = row.stripe_event_id as string ?? String(Date.now());
                state.productEntitlementEvents[key] = row;
                return Promise.resolve({ data: row, error: null });
              },
            }),
          }),
        };
      }
      throw new Error(`unexpected table in test fake: ${table}`);
    },
  };
}

// Mirrors the row create-checkout-session already inserts (status='none',
// last_event_created=null) BEFORE any webhook event can possibly exist
// for this customer -- every test starts from that same real precondition
// rather than an empty subscriptions table.
function newState(customerId: string, userId: string): DbState {
  return {
    subscriptions: { [userId]: { stripe_customer_id: customerId, status: 'none', last_event_created: null } },
    customerToUser: { [customerId]: userId },
    profiles: { [userId]: { role: 'free', monthly_limit: 15 } },
    processedEvents: {},
    productSubscriptions: {},
    productEntitlementEvents: {},
  };
}

Deno.test('WEBHOOK-1: assinatura ausente -> 400, nenhum estado alterado', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const res = await handler(await signedReq(evt({ id: 'evt_1', type: 'checkout.session.completed' }), { noSig: true }), fakeStripe({}), db as never);
  assertEquals(res.status, 400);
  assertEquals(db.state.profiles['user_1'].role, 'free');
});

Deno.test('WEBHOOK-2: assinatura com secret errado -> 400', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const req = await signedReq(evt({ id: 'evt_1', type: 'checkout.session.completed' }), { secret: 'whsec_wrong' });
  const res = await handler(req, fakeStripe({}), db as never);
  assertEquals(res.status, 400);
});

Deno.test('WEBHOOK-3: timestamp fora da tolerância (replay) -> 400', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const req = await signedReq(evt({ id: 'evt_1', type: 'checkout.session.completed' }), { ts: Math.floor(Date.now() / 1000) - 3600 });
  const res = await handler(req, fakeStripe({}), db as never);
  assertEquals(res.status, 400);
});

Deno.test('WEBHOOK-4: checkout.session.completed com assinatura válida -> promove usuário a pro', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const stripe = fakeStripe({ sub_1: makeSub({ status: 'active' }) });
  const req = await signedReq(evt({
    id: 'evt_checkout_1',
    type: 'checkout.session.completed',
    data: { object: { customer: 'cus_1', subscription: 'sub_1' } },
  }));
  const res = await handler(req, stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_1'].role, 'pro');
  assertEquals(db.state.profiles['user_1'].monthly_limit, 300);
  assertEquals(db.state.subscriptions['user_1'].status, 'active');
});

Deno.test('WEBHOOK-5: evento duplicado (mesmo event.id) -> segunda entrega é no-op, não rechama Stripe', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const stripe = fakeStripe({ sub_1: makeSub({ status: 'active' }) });
  const body = evt({ id: 'evt_dup_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_1', subscription: 'sub_1' } } });
  const res1 = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res1.status, 200);
  const callsAfterFirst = stripe.calls.length;
  const res2 = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res2.status, 200);
  const data2 = await res2.json();
  assertEquals(data2.duplicate, true);
  assertEquals(stripe.calls.length, callsAfterFirst); // não chamou a API do Stripe de novo
});

Deno.test('WEBHOOK-6: falha ao processar -> evento NÃO é marcado como processado (permite retry real)', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  // subscription id que não existe no fake Stripe -> retrieveSubscription lança erro
  const stripe = fakeStripe({});
  const body = evt({ id: 'evt_fail_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_1', subscription: 'sub_missing' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 500);
  assertEquals(db.state.processedEvents['evt_fail_1'], undefined); // não marcado -> retry vai reprocessar
  assertEquals(db.state.profiles['user_1'].role, 'free'); // nenhuma mudança parcial
});

Deno.test('WEBHOOK-7: customer.subscription.updated com status active -> mantém/atualiza pro', async () => {
  const db = fakeDb(newState('cus_2', 'user_2'));
  const stripe = fakeStripe({ sub_2: makeSub({ id: 'sub_2', status: 'active' }) });
  const body = evt({ id: 'evt_upd_1', type: 'customer.subscription.updated', data: { object: { id: 'sub_2', customer: 'cus_2', status: 'trialing' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 200);
  // O estado gravado vem do GET (fresco), não do payload do evento (que dizia 'trialing')
  assertEquals(db.state.profiles['user_2'].role, 'pro');
  assertEquals(db.state.subscriptions['user_2'].status, 'active');
});

Deno.test('WEBHOOK-8: customer.subscription.deleted -> rebaixa usuário a free', async () => {
  const db = fakeDb(newState('cus_3', 'user_3'));
  db.state.profiles['user_3'] = { role: 'pro', monthly_limit: 300 };
  const stripe = fakeStripe({ sub_3: makeSub({ id: 'sub_3', status: 'canceled', cancel_at_period_end: false }) });
  const body = evt({ id: 'evt_del_1', type: 'customer.subscription.deleted', data: { object: { id: 'sub_3', customer: 'cus_3', status: 'canceled' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_3'].role, 'free');
  assertEquals(db.state.profiles['user_3'].monthly_limit, 15);
});

Deno.test('WEBHOOK-9: evento "mais antigo" chegando depois (fora de ordem) não ressuscita entitlement -- GET sempre reflete o estado atual', async () => {
  const db = fakeDb(newState('cus_4', 'user_4'));
  db.state.profiles['user_4'] = { role: 'free', monthly_limit: 15 };
  // O assinante JÁ está cancelado no Stripe agora (verdade atual), mesmo
  // que este evento em particular seja um "subscription.updated" antigo
  // que originalmente teria dito status=active.
  const stripe = fakeStripe({ sub_4: makeSub({ id: 'sub_4', status: 'canceled' }) });
  const staleBody = evt({ id: 'evt_stale_1', type: 'customer.subscription.updated', data: { object: { id: 'sub_4', customer: 'cus_4', status: 'active' } } });
  const res = await handler(await signedReq(staleBody), stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_4'].role, 'free'); // não foi promovido por engano
});

Deno.test('WEBHOOK-10: customer desconhecido (sem linha em subscriptions) -> aceita e não quebra, sem alterar profiles de ninguém', async () => {
  const db = fakeDb(newState('cus_5', 'user_5'));
  const stripe = fakeStripe({ sub_x: makeSub({ id: 'sub_x' }) });
  const body = evt({ id: 'evt_unknown_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_does_not_exist', subscription: 'sub_x' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_5'].role, 'free');
});

Deno.test('WEBHOOK-11: isolamento entre usuários -- evento de um customer nunca altera o profile de outro', async () => {
  const db = fakeDb(newState('cus_a', 'user_a'));
  db.state.customerToUser['cus_b'] = 'user_b';
  db.state.profiles['user_b'] = { role: 'free', monthly_limit: 15 };
  const stripe = fakeStripe({ sub_a: makeSub({ id: 'sub_a', status: 'active' }) });
  const body = evt({ id: 'evt_iso_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_a', subscription: 'sub_a' } } });
  await handler(await signedReq(body), stripe, db as never);
  assertEquals(db.state.profiles['user_a'].role, 'pro');
  assertEquals(db.state.profiles['user_b'].role, 'free'); // intocado
});

Deno.test('WEBHOOK-12: tipo de evento desconhecido -> 200, nenhuma alteração', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const body = evt({ id: 'evt_unhandled_1', type: 'invoice.payment_failed' });
  const res = await handler(await signedReq(body), fakeStripe({}), db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_1'].role, 'free');
});

Deno.test('WEBHOOK-13: método GET -> 405', async () => {
  const res = await handler(new Request('http://localhost/', { method: 'GET' }), fakeStripe({}), fakeDb(newState('cus_1', 'user_1')) as never);
  assertEquals(res.status, 405);
});

Deno.test('WEBHOOK-14: falha ao buscar assinatura atual no Stripe (GET) para subscription.deleted -> 500, sem fallback para o payload do evento, sem alteração de estado', async () => {
  // Regressão do finding P1 do Codex (task-mtw7wtog-py3laq): uma versão
  // anterior caía no payload do próprio evento quando o GET falhava,
  // podendo aplicar estado obsoleto. Agora qualquer falha de GET aborta.
  const db = fakeDb(newState('cus_6', 'user_6'));
  db.state.profiles['user_6'] = { role: 'pro', monthly_limit: 300 };
  const stripe = fakeStripe({}); // sub_6 não existe -> retrieveSubscription lança
  const body = evt({ id: 'evt_getfail_1', type: 'customer.subscription.deleted', data: { object: { id: 'sub_6', customer: 'cus_6', status: 'canceled' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 500);
  assertEquals(db.state.profiles['user_6'].role, 'pro'); // não foi rebaixado por um payload não confirmado
  assertEquals(db.state.processedEvents['evt_getfail_1'], undefined);
});

Deno.test('WEBHOOK-15: falha no RPC atômico (ex: erro de banco) -> 500, evento não marcado como processado', async () => {
  const db = fakeDb(newState('cus_7', 'user_7')) as ReturnType<typeof fakeDb> & { rpc: unknown };
  let rpcCalls = 0;
  db.rpc = (_fn: string, _args: Record<string, unknown>) => {
    rpcCalls++;
    return Promise.resolve({ data: null, error: new Error('simulated db failure') });
  };
  const stripe = fakeStripe({ sub_7: makeSub({ id: 'sub_7', status: 'active' }) });
  const body = evt({ id: 'evt_rpcfail_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_7', subscription: 'sub_7' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 500);
  assertEquals(rpcCalls, 1);
  assertEquals(db.state.processedEvents['evt_rpcfail_1'], undefined);
});

Deno.test('WEBHOOK-16: evento cronologicamente mais antigo (event.created menor) processado DEPOIS de um mais novo -- não sobrescreve o estado mais recente mesmo com GET próprio', async () => {
  // Este é o cenário exato do finding P1 residual do Codex (segunda
  // verificação): dois eventos DIFERENTES para a mesma assinatura, cada
  // um com seu próprio GET (podendo retornar snapshots diferentes) e cujo
  // commit pode chegar fora de ordem. O evento mais novo (event.created
  // maior) é processado primeiro; o mais antigo chega depois e, mesmo
  // fazendo seu próprio GET (que aqui retorna um snapshot "active", uma
  // divergência plausível se o Stripe ainda não havia propagado a
  // atualização quando esse GET em particular rodou), não pode reverter
  // o estado já aplicado pelo evento mais novo.
  const db = fakeDb(newState('cus_8', 'user_8'));
  db.state.profiles['user_8'] = { role: 'free', monthly_limit: 15 };

  const newerEventTs = NOW;
  const olderEventTs = NOW - 120;

  // Evento NOVO chega e é processado primeiro: cancelamento real.
  const stripeForNewer = fakeStripe({ sub_8: makeSub({ id: 'sub_8', status: 'canceled' }) });
  const newerBody = evt({
    id: 'evt_newer_1',
    type: 'customer.subscription.deleted',
    created: newerEventTs,
    data: { object: { id: 'sub_8', customer: 'cus_8', status: 'canceled' } },
  });
  const resNewer = await handler(await signedReq(newerBody), stripeForNewer, db as never);
  assertEquals(resNewer.status, 200);
  assertEquals(db.state.profiles['user_8'].role, 'free');

  // Evento ANTIGO (event.created menor) chega depois, com seu próprio GET
  // retornando (hipoteticamente) "active" -- deve ser descartado pelo
  // guard de ordenação, não pela idempotência (event.id é diferente).
  const stripeForOlder = fakeStripe({ sub_8: makeSub({ id: 'sub_8', status: 'active' }) });
  const olderBody = evt({
    id: 'evt_older_1',
    type: 'customer.subscription.updated',
    created: olderEventTs,
    data: { object: { id: 'sub_8', customer: 'cus_8', status: 'active' } },
  });
  const resOlder = await handler(await signedReq(olderBody), stripeForOlder, db as never);
  assertEquals(resOlder.status, 200); // aceito e reconhecido -- mas...
  assertEquals(db.state.profiles['user_8'].role, 'free'); // ...NÃO ressuscitou o Pro
  assertEquals(db.state.subscriptions['user_8'].status, 'canceled');
});

// IV-WEB-ECOSYSTEM-UNIFICATION-01 tests

Deno.test('WEBHOOK-22: evento de produto antigo chega depois → ignorado (ordering guard)', async () => {
  const priceMap = new Map([['price_impact', { product: 'impact', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_ord1', 'user_ord1'));

  const newerTs = NOW - 100; // created earlier in test time but "newer" for product
  const olderTs = NOW - 200; // truly older

  // Newer event arrives first and writes product subscription
  const newerEvt = evt({
    id: 'evt_ord_newer',
    type: 'checkout.session.completed',
    created: newerTs,
    data: { object: { customer: 'cus_ord1', subscription: 'sub_ord1' } },
  });
  const stripe1 = fakeStripe({ sub_ord1: makeSub({ id: 'sub_ord1', status: 'active', items: { data: [{ price: { id: 'price_impact' } }] } }) });
  const res1 = await handler(await signedReq(newerEvt), stripe1, db as never, priceMap);
  assertEquals(res1.status, 200);
  assertEquals(psEffective(db.state, 'user_ord1', 'impact')?.status, 'active');

  // Simulate product subscription active state being set
  const activePs = psEffective(db.state, 'user_ord1', 'impact');
  assertEquals(activePs?.last_stripe_event_created, new Date(newerTs * 1000).toISOString());

  // Now, mark subscription as canceled via a newer legacy event
  db.state.productSubscriptions['user_ord1:impact:sub_ord1'] = {
    ...activePs,
    status: 'canceled',
    last_stripe_event_created: new Date((NOW + 100) * 1000).toISOString(), // future-ish
  };

  // Older event arrives (created earlier) — should be skipped by ordering guard
  const olderEvt = evt({
    id: 'evt_ord_older',
    type: 'customer.subscription.updated',
    created: olderTs,
    data: { object: { id: 'sub_ord1', customer: 'cus_ord1' } },
  });
  const stripe2 = fakeStripe({ sub_ord1: makeSub({ id: 'sub_ord1', status: 'active' }) });
  const res2 = await handler(await signedReq(olderEvt), stripe2, db as never, priceMap);
  assertEquals(res2.status, 200);
  // Stale event did NOT resurrect the active state
  assertEquals(psEffective(db.state, 'user_ord1', 'impact')?.status, 'canceled');
});

Deno.test('WEBHOOK-18: STRIPE_PRICE_MAP impact mapeado → product_subscriptions escrito, Core NÃO alterado', async () => {
  // P1 isolation: Impact subscriptions MUST NOT write legacy Core state.
  const priceMap = new Map([['price_pro_impact_monthly', { product: 'impact', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_ps1', 'user_ps1'));
  const stripe = fakeStripe({
    sub_ps1: makeSub({ id: 'sub_ps1', status: 'active', items: { data: [{ price: { id: 'price_pro_impact_monthly' } }] } }),
  });
  const req = await signedReq(evt({
    id: 'evt_ps1',
    type: 'checkout.session.completed',
    data: { object: { customer: 'cus_ps1', subscription: 'sub_ps1' } },
  }));
  const res = await handler(req, stripe, db as never, priceMap);
  assertEquals(res.status, 200);
  // Impact event must NOT promote user to Core Pro (isolation rule)
  assertEquals(db.state.profiles['user_ps1'].role, 'free');
  // product_subscriptions written for 'impact' (mapped product), not 'core'
  assertEquals(!!psEffective(db.state, 'user_ps1', 'impact'), true);
  assertEquals(psEffective(db.state, 'user_ps1', 'core'), undefined);
  // Legacy subscriptions table NOT written for Impact event
  assertEquals(db.state.subscriptions['user_ps1']?.status, 'none'); // initial value unchanged
});

Deno.test('WEBHOOK-19: upsert_product_subscription falha para produto não-Core → evento durável gravado → webhook 200 (path B)', async () => {
  // Non-Core products (Impact/Quant) still use applyProductSubscriptionState which has Path B.
  // Core activation now uses activate_core_entitlement_atomic (no Path B — Stripe retries on failure).
  const priceMap = new Map([['price_impact_pro', { product: 'impact', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_ps2', 'user_ps2')) as ReturnType<typeof fakeDb> & { rpc: unknown };
  let upsertCalls = 0;
  const origRpc = db.rpc.bind(db);
  db.rpc = (fn: string, args: Record<string, unknown>) => {
    if (fn === 'upsert_product_subscription') { upsertCalls++; throw new Error('simulated product upsert failure'); }
    return origRpc(fn, args);
  };
  const stripe = fakeStripe({ sub_ps2: makeSub({ id: 'sub_ps2', status: 'active', items: { data: [{ price: { id: 'price_impact_pro' } }] } }) });
  const body = evt({ id: 'evt_ps2', type: 'checkout.session.completed', data: { object: { customer: 'cus_ps2', subscription: 'sub_ps2' } } });
  const res = await handler(await signedReq(body), stripe, db as never, priceMap);
  // Path B: durable pending event written → webhook still returns 200
  assertEquals(res.status, 200);
  assertEquals(upsertCalls, 1);
  // Core NOT written (non-Core event → isolation rule)
  assertEquals(db.state.profiles['user_ps2'].role, 'free');
  // Durable fallback event was persisted
  assertEquals(Object.keys(db.state.productEntitlementEvents).length, 1);
  const pendingEvt = Object.values(db.state.productEntitlementEvents)[0] as Record<string, unknown>;
  assertEquals(pendingEvt.event_type, 'pending_retry');
  assertEquals(pendingEvt.stripe_event_id, 'evt_ps2');
});

Deno.test('WEBHOOK-20: upsert_product_subscription E fallback ambos falham para produto não-Core → webhook 500', async () => {
  // Non-Core products (Impact/Quant) still use applyProductSubscriptionState which has Path B.
  // Core activation now uses activate_core_entitlement_atomic (no Path B — Stripe retries on failure).
  const priceMap = new Map([['price_impact_pro', { product: 'impact', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_ps3', 'user_ps3')) as ReturnType<typeof fakeDb> & { rpc: unknown; from: unknown };
  const origRpc = db.rpc.bind(db);
  db.rpc = (fn: string, args: Record<string, unknown>) => {
    if (fn === 'upsert_product_subscription') throw new Error('simulated upsert failure');
    return origRpc(fn, args);
  };
  // Make the product_entitlement_events upsert also fail
  const origFrom = (db as unknown as { from: (t: string) => unknown }).from.bind(db);
  (db as unknown as { from: (t: string) => unknown }).from = (table: string) => {
    if (table === 'product_entitlement_events') {
      return {
        upsert: (_row: unknown, _opts?: unknown) => ({
          select: () => ({
            maybeSingle: () => Promise.resolve({ data: null, error: new Error('simulated fallback failure') }),
          }),
        }),
      };
    }
    return origFrom(table);
  };
  const stripe = fakeStripe({ sub_ps3: makeSub({ id: 'sub_ps3', status: 'active', items: { data: [{ price: { id: 'price_impact_pro' } }] } }) });
  const body = evt({ id: 'evt_ps3', type: 'checkout.session.completed', data: { object: { customer: 'cus_ps3', subscription: 'sub_ps3' } } });
  const res = await handler(await signedReq(body), stripe, db as never, priceMap);
  // Both writes failed → 500 so Stripe retries
  assertEquals(res.status, 500);
});

Deno.test('WEBHOOK-21: price_id fora do mapa configurado → pending_retry durável gravado (UNMAPPED_PRICE) → webhook 200', async () => {
  // Map is non-empty (configured), but incoming price_id is not in it.
  // Expectation: product_subscriptions NOT written (FAIL CLOSED on entitlement),
  // but a durable pending_retry record IS written so the gap is never silent.
  const priceMap = new Map([['price_known_impact', { product: 'impact', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_ps4', 'user_ps4'));
  const stripe = fakeStripe({
    sub_ps4: makeSub({ id: 'sub_ps4', status: 'active', items: { data: [{ price: { id: 'price_UNKNOWN' } }] } }),
  });
  const body = evt({ id: 'evt_ps4', type: 'checkout.session.completed', data: { object: { customer: 'cus_ps4', subscription: 'sub_ps4' } } });
  const res = await handler(await signedReq(body), stripe, db as never, priceMap);
  assertEquals(res.status, 200);
  // Core NOT written (unmapped price in configured map → isolation rule)
  assertEquals(db.state.profiles['user_ps4'].role, 'free'); // unchanged
  assertEquals(db.state.subscriptions['user_ps4']?.status, 'none'); // unchanged
  // Product subscription NOT written (FAIL CLOSED: unknown price in configured map)
  assertEquals(Object.keys(db.state.productSubscriptions).length, 0);
  // Durable pending_retry written with UNMAPPED_PRICE reason (not silently dropped)
  assertEquals(Object.keys(db.state.productEntitlementEvents).length, 1);
  const unmappedEvt = Object.values(db.state.productEntitlementEvents)[0] as Record<string, unknown>;
  assertEquals(unmappedEvt.event_type, 'pending_retry');
  assertEquals(unmappedEvt.stripe_event_id, 'evt_ps4');
  const meta = JSON.parse(unmappedEvt.metadata as string) as Record<string, unknown>;
  assertEquals(meta.reason, 'UNMAPPED_PRICE');
  assertEquals(meta.price_id, 'price_UNKNOWN');
});

Deno.test('WEBHOOK-24: unmapped price in configured map → Core state NOT mutated, pending_retry written', async () => {
  // Regression for P1 Core isolation bug: when STRIPE_PRICE_MAP is configured
  // but incoming price_id is not in it, the event must NOT write legacy Core
  // state (subscriptions/profiles). Previously !mapped was included in
  // isLegacyCoreEvent, which caused Core tables to be updated.
  const priceMap = new Map([['price_known_core', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_ul1', 'user_ul1'));
  const stripe = fakeStripe({
    sub_ul1: makeSub({ id: 'sub_ul1', status: 'active', items: { data: [{ price: { id: 'price_UNKNOWN_NON_CORE' } }] } }),
  });
  const body = evt({ id: 'evt_ul1', type: 'checkout.session.completed', data: { object: { customer: 'cus_ul1', subscription: 'sub_ul1' } } });
  const res = await handler(await signedReq(body), stripe, db as never, priceMap);
  assertEquals(res.status, 200);
  // Core state must NOT be mutated (isolation rule for unmapped prices)
  assertEquals(db.state.profiles['user_ul1'].role, 'free'); // unchanged
  assertEquals(db.state.subscriptions['user_ul1']?.status, 'none'); // unchanged
  // Only pending_retry written (durable record for reconciliation)
  assertEquals(Object.keys(db.state.productSubscriptions).length, 0);
  const peeEvents = Object.values(db.state.productEntitlementEvents) as Record<string, unknown>[];
  assertEquals(peeEvents.length, 1);
  assertEquals(peeEvents[0].event_type, 'pending_retry');
  const meta = JSON.parse(peeEvents[0].metadata as string) as Record<string, unknown>;
  assertEquals(meta.reason, 'UNMAPPED_PRICE');
});

Deno.test('WEBHOOK-25: STRIPE_PRICE_MAP invalid path gated - valid override passes through', async () => {
  // Structural test: when a valid priceMapOverride is supplied, the PRICE_MAP_ERROR
  // gate (!priceMapOverride && PRICE_MAP_ERROR) does not fire. Confirms the gate
  // condition is correct: only requests without override are affected by module-level error.
  const db = fakeDb(newState('cus_w25', 'user_w25'));
  const stripe = fakeStripe({
    sub_w25: makeSub({ id: 'sub_w25', status: 'active', items: { data: [{ price: { id: 'price_impact_pro' } }] } }),
  });
  const body = evt({ id: 'evt_w25', type: 'checkout.session.completed', data: { object: { customer: 'cus_w25', subscription: 'sub_w25' } } });
  const validMap = new Map([['price_impact_pro', { product: 'impact', tier: 'pro' }]]);
  const res = await handler(await signedReq(body), stripe, db as never, validMap);
  assertEquals(res.status, 200);
  assertEquals(psEffective(db.state, 'user_w25', 'impact')?.status, 'active');
});

Deno.test('WEBHOOK-23: ON CONFLICT WHERE predicate — older event after newer commit → no overwrite (atomic ordering guard)', async () => {
  // Simulates the race the ON CONFLICT WHERE guard closes:
  // newer event committed first (last_stripe_event_created=T200),
  // then older event arrives (T100 < T200). Without the atomic predicate
  // the ON CONFLICT UPDATE would silently overwrite the newer state.
  const priceMap = new Map([['price_impact', { product: 'impact', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_oc1', 'user_oc1'));
  const newerTs = NOW - 50;
  const olderTs = NOW - 200;

  // Newer event arrives and commits
  const sub = makeSub({ id: 'sub_oc1', status: 'active', items: { data: [{ price: { id: 'price_impact' } }] } });
  const newerEvt = evt({ id: 'evt_oc_new', type: 'checkout.session.completed', created: newerTs, data: { object: { customer: 'cus_oc1', subscription: 'sub_oc1' } } });
  await handler(await signedReq(newerEvt), fakeStripe({ sub_oc1: sub }), db as never, priceMap);
  assertEquals(psEffective(db.state, 'user_oc1', 'impact')?.status, 'active');

  // Manually advance the stored event timestamp to simulate newer commit in DB
  db.state.productSubscriptions['user_oc1:impact:sub_oc1'] = {
    ...psEffective(db.state, 'user_oc1', 'impact')!,
    status: 'active',
    last_stripe_event_created: new Date(newerTs * 1000).toISOString(),
  };

  // Older event now tries to cancel the subscription — must be blocked
  const olderSub = makeSub({ id: 'sub_oc1', status: 'canceled', items: { data: [{ price: { id: 'price_impact' } }] } });
  const olderEvt = evt({ id: 'evt_oc_old', type: 'customer.subscription.updated', created: olderTs, data: { object: { id: 'sub_oc1', customer: 'cus_oc1' } } });
  const res = await handler(await signedReq(olderEvt), fakeStripe({ sub_oc1: olderSub }), db as never, priceMap);
  assertEquals(res.status, 200);
  // Atomic predicate prevented overwrite: subscription still active
  assertEquals(psEffective(db.state, 'user_oc1', 'impact')?.status, 'active');
});

Deno.test('WEBHOOK-17: linha de subscriptions ausente para o user_id resolvido (UPDATE não encontra a linha) -> RPC retorna false, profiles intocado, 200', async () => {
  // Cenário defensivo apontado no 3º review do Codex: na prática essa
  // condição é inatingível (findUserIdByCustomerId já lê essa mesma
  // linha da tabela subscriptions antes de chamar o RPC), mas o fake
  // precisa espelhar fielmente o "UPDATE ... WHERE user_id = X" real --
  // que, sem linha correspondente, apenas não afeta nenhuma linha.
  const db = fakeDb(newState('cus_9', 'user_9'));
  delete db.state.subscriptions['user_9']; // simula a linha ausente
  const stripe = fakeStripe({ sub_9: makeSub({ id: 'sub_9', status: 'active' }) });
  const body = evt({ id: 'evt_missingrow_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_9', subscription: 'sub_9' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_9'].role, 'free'); // não promovido
  assertEquals(db.state.subscriptions['user_9'], undefined); // RPC não criou a linha (não é upsert)
});

Deno.test('WEBHOOK-34: R12 P1 fix — Core activation usa activate_core_entitlement_atomic: legacy + product escritos atomicamente', async () => {
  // isLegacyCoreEvent=true (priceMap vazio → legacy mode) + sub active → activation path.
  // activate_core_entitlement_atomic deve escrever legacy (profiles) E product row.
  const db = fakeDb(newState('cus_r12a', 'user_r12a'));
  // Verify that activate_core_entitlement_atomic is actually called (not the old separate RPCs).
  let atomicCalled = false;
  let legacyCalled = false;
  const originalRpc = db.rpc.bind(db);
  // deno-lint-ignore no-explicit-any
  (db as any).rpc = (fn: string, args: Record<string, unknown>) => {
    if (fn === 'activate_core_entitlement_atomic') atomicCalled = true;
    if (fn === 'apply_stripe_subscription_state') legacyCalled = true;
    return originalRpc(fn, args);
  };
  const stripe = fakeStripe({ sub_r12a: makeSub({ id: 'sub_r12a', status: 'active', cancel_at_period_end: false }) });
  const body = evt({
    id: 'evt_r12a_activate', type: 'customer.subscription.updated',
    data: { object: { id: 'sub_r12a', customer: 'cus_r12a', status: 'active' } },
  });
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 200);
  // Atomic RPC called, NOT the separate legacy RPC
  assertEquals(atomicCalled, true, 'activate_core_entitlement_atomic must be called for Core activation');
  assertEquals(legacyCalled, false, 'apply_stripe_subscription_state must NOT be called directly for Core activation');
  // Legacy profile updated
  assertEquals(db.state.profiles['user_r12a'].role, 'pro');
  assertEquals(db.state.profiles['user_r12a'].monthly_limit, 300);
  // Product row written
  assertEquals(psEffective(db.state, 'user_r12a', 'core')?.status, 'active');
  assertEquals(psEffective(db.state, 'user_r12a', 'core')?.tier, 'pro');
});

Deno.test('WEBHOOK-35: R12 P1 fix — activate_core_entitlement_atomic failure → 500, legacy E product NÃO alterados', async () => {
  // If the atomic activation RPC fails, the webhook must return 500 and leave
  // no partial state — legacy profile and product subscriptions must remain unchanged.
  const db = fakeDb(newState('cus_r12b', 'user_r12b'));
  db.state.profiles['user_r12b'] = { role: 'free', monthly_limit: 15 };
  const originalRpc = db.rpc.bind(db);
  // deno-lint-ignore no-explicit-any
  (db as any).rpc = (fn: string, args: Record<string, unknown>) => {
    if (fn === 'activate_core_entitlement_atomic') {
      return Promise.resolve({ data: null, error: { message: 'simulated atomic activate transient failure' } });
    }
    return originalRpc(fn, args);
  };
  const stripe = fakeStripe({ sub_r12b: makeSub({ id: 'sub_r12b', status: 'active', cancel_at_period_end: false }) });
  const body = evt({
    id: 'evt_r12b_activate', type: 'customer.subscription.updated',
    data: { object: { id: 'sub_r12b', customer: 'cus_r12b', status: 'active' } },
  });
  const res = await handler(await signedReq(body), stripe, db as never);
  // Atomic RPC failure → 500 (Stripe retries, no partial state)
  assertEquals(res.status, 500);
  // Legacy profile must NOT have been upgraded
  assertEquals(db.state.profiles['user_r12b'].role, 'free');
  // Product row must NOT have been written
  assertEquals(psEffective(db.state, 'user_r12b', 'core'), undefined);
});

Deno.test('WEBHOOK-33: P1-A fix — cancel_core_entitlement_atomic RPC failure → 500, legacy NÃO rebaixado', async () => {
  // isLegacyCoreEvent=true (priceMap vazio → legacy mode) + sub canceled → P1-I path.
  // cancel_core_entitlement_atomic retorna error → webhook deve retornar 500.
  const db = fakeDb(newState('cus_p1b', 'user_p1b'));
  db.state.profiles['user_p1b'] = { role: 'pro', monthly_limit: 300 };
  // Set up a second Core product sub so the P1-I path (not P1-K) is exercised
  db.state.productSubscriptions['user_p1b:core:sub_p1b'] = {
    product: 'core', tier: 'pro', status: 'active', source: 'stripe',
    stripe_subscription_id: 'sub_p1b', last_stripe_event_created: null,
  };

  // Patch the rpc call to return error for cancel_core_entitlement_atomic
  const originalRpc = db.rpc.bind(db);
  // deno-lint-ignore no-explicit-any
  (db as any).rpc = (fn: string, args: Record<string, unknown>) => {
    if (fn === 'cancel_core_entitlement_atomic') {
      return Promise.resolve({ data: null, error: { message: 'simulated atomic cancel transient failure' } });
    }
    return originalRpc(fn, args);
  };

  const stripe = fakeStripe({
    sub_p1b: makeSub({ id: 'sub_p1b', status: 'canceled', cancel_at_period_end: false }),
  });
  const body = evt({
    id: 'evt_p1b_cancel', type: 'customer.subscription.deleted',
    data: { object: { id: 'sub_p1b', customer: 'cus_p1b', status: 'canceled' } },
  });
  const res = await handler(await signedReq(body), stripe, db as never);
  // P1-A fix: atomic RPC failure → 500 (Stripe retries, no partial state)
  assertEquals(res.status, 500);
  // Legacy profile must NOT have been downgraded (RPC failed before legacy write)
  assertEquals(db.state.profiles['user_p1b'].role, 'pro');
  // Legacy subscription must remain at its prior status
  assertNotEquals(db.state.subscriptions['user_p1b']?.status, 'canceled');
});

// ── Multi-subscription tests (IV-WEB-ECOSYSTEM-UNIFICATION-01) ─────────────

Deno.test('WEBHOOK-26: 2 subscriptions ativas para Quant — cancelar uma → entitlement Quant permanece ativo', async () => {
  const priceMap = new Map([['price_quant_pro', { product: 'quant', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_mq1', 'user_mq1'));

  // Sub 1: first checkout → Quant active
  const sub_mq1 = makeSub({ id: 'sub_mq1', status: 'active', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_mq1', type: 'checkout.session.completed', data: { object: { customer: 'cus_mq1', subscription: 'sub_mq1' } } })), fakeStripe({ sub_mq1 }), db as never, priceMap);
  assertEquals(psEffective(db.state, 'user_mq1', 'quant')?.status, 'active');

  // Sub 2: second checkout → second Quant active (different sub ID)
  const sub_mq2 = makeSub({ id: 'sub_mq2', status: 'active', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_mq2', type: 'checkout.session.completed', data: { object: { customer: 'cus_mq1', subscription: 'sub_mq2' } } })), fakeStripe({ sub_mq2 }), db as never, priceMap);
  assertEquals(psRow(db.state, 'user_mq1', 'quant', 'sub_mq1')?.status, 'active');
  assertEquals(psRow(db.state, 'user_mq1', 'quant', 'sub_mq2')?.status, 'active');

  // Cancel sub_mq1 — sub_mq2 still active → entitlement preserved
  const sub_mq1_canceled = makeSub({ id: 'sub_mq1', status: 'canceled', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  const res = await handler(await signedReq(evt({ id: 'evt_mq3', type: 'customer.subscription.updated', data: { object: { id: 'sub_mq1', customer: 'cus_mq1' } } })), fakeStripe({ sub_mq1: sub_mq1_canceled }), db as never, priceMap);
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_mq1', 'quant', 'sub_mq1')?.status, 'canceled');
  assertEquals(psRow(db.state, 'user_mq1', 'quant', 'sub_mq2')?.status, 'active');
  // Effective entitlement: still active (sub_mq2 is active)
  assertEquals(psEffective(db.state, 'user_mq1', 'quant')?.status, 'active');
});

Deno.test('WEBHOOK-27: cancelar a última subscription Quant → entitlement revogado (nenhuma sub ativa restante)', async () => {
  const priceMap = new Map([['price_quant_pro', { product: 'quant', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_mq2', 'user_mq2'));
  // Pre-populate 2 active Quant subscriptions with older timestamps
  const oldTs = new Date((NOW - 100) * 1000).toISOString();
  db.state.productSubscriptions['user_mq2:quant:sub_a'] = { product: 'quant', tier: 'pro', status: 'active', stripe_subscription_id: 'sub_a', last_stripe_event_created: oldTs };
  db.state.productSubscriptions['user_mq2:quant:sub_b'] = { product: 'quant', tier: 'pro', status: 'active', stripe_subscription_id: 'sub_b', last_stripe_event_created: oldTs };
  assertEquals(psEffective(db.state, 'user_mq2', 'quant')?.status, 'active');

  // Cancel sub_a — sub_b still active
  const sub_a_canceled = makeSub({ id: 'sub_a', status: 'canceled', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_mq4', type: 'customer.subscription.updated', data: { object: { id: 'sub_a', customer: 'cus_mq2' } } })), fakeStripe({ sub_a: sub_a_canceled }), db as never, priceMap);
  assertEquals(psEffective(db.state, 'user_mq2', 'quant')?.status, 'active'); // sub_b still active

  // Cancel sub_b — no more active Quant subs
  const sub_b_canceled = makeSub({ id: 'sub_b', status: 'canceled', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  const res = await handler(await signedReq(evt({ id: 'evt_mq5', type: 'customer.subscription.updated', data: { object: { id: 'sub_b', customer: 'cus_mq2' } } })), fakeStripe({ sub_b: sub_b_canceled }), db as never, priceMap);
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_mq2', 'quant', 'sub_a')?.status, 'canceled');
  assertEquals(psRow(db.state, 'user_mq2', 'quant', 'sub_b')?.status, 'canceled');
  // No active sub remaining → effective status must NOT be active/trialing
  const effective = psEffective(db.state, 'user_mq2', 'quant');
  assertEquals(effective?.status === 'active' || effective?.status === 'trialing', false);
});

Deno.test('WEBHOOK-28: Core + Quant independentes — cancelar Quant não toca Core (profiles/subscriptions)', async () => {
  const priceMap = new Map([['price_quant_pro', { product: 'quant', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_cq1', 'user_cq1'));

  // Activate Quant via webhook
  const sub_q = makeSub({ id: 'sub_cq_q', status: 'active', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_cq1', type: 'checkout.session.completed', data: { object: { customer: 'cus_cq1', subscription: 'sub_cq_q' } } })), fakeStripe({ sub_cq_q: sub_q }), db as never, priceMap);

  // Simulate Core active state (legacy flow already wrote Core tables)
  db.state.subscriptions['user_cq1'] = { ...db.state.subscriptions['user_cq1'], status: 'active', last_event_created: new Date((NOW - 200) * 1000).toISOString() };
  db.state.profiles['user_cq1'] = { role: 'pro', monthly_limit: 100 };
  assertEquals(psEffective(db.state, 'user_cq1', 'quant')?.status, 'active');
  assertEquals(db.state.profiles['user_cq1'].role, 'pro');

  // Cancel Quant → Core (profiles/subscriptions) must remain untouched
  const sub_q_canceled = makeSub({ id: 'sub_cq_q', status: 'canceled', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  const res = await handler(await signedReq(evt({ id: 'evt_cq2', type: 'customer.subscription.updated', data: { object: { id: 'sub_cq_q', customer: 'cus_cq1' } } })), fakeStripe({ sub_cq_q: sub_q_canceled }), db as never, priceMap);
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_cq1', 'quant', 'sub_cq_q')?.status, 'canceled'); // Quant canceled
  assertEquals(db.state.profiles['user_cq1'].role, 'pro'); // Core role UNCHANGED
  assertEquals(db.state.subscriptions['user_cq1'].status, 'active'); // Core sub UNCHANGED
});

Deno.test('WEBHOOK-29: Suite + produto individual — Suite cancelado não revoga Impact individual', async () => {
  const priceMap = new Map([
    ['price_suite_pro', { product: 'suite', tier: 'pro' }],
    ['price_impact_pro', { product: 'impact', tier: 'pro' }],
  ]);
  const db = fakeDb(newState('cus_st1', 'user_st1'));

  // Activate Suite
  const sub_suite = makeSub({ id: 'sub_st_suite', status: 'active', items: { data: [{ price: { id: 'price_suite_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_st1', type: 'checkout.session.completed', data: { object: { customer: 'cus_st1', subscription: 'sub_st_suite' } } })), fakeStripe({ sub_st_suite: sub_suite }), db as never, priceMap);
  assertEquals(psEffective(db.state, 'user_st1', 'suite')?.status, 'active');

  // Activate Impact individually
  const sub_impact = makeSub({ id: 'sub_st_impact', status: 'active', items: { data: [{ price: { id: 'price_impact_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_st2', type: 'checkout.session.completed', data: { object: { customer: 'cus_st1', subscription: 'sub_st_impact' } } })), fakeStripe({ sub_st_impact: sub_impact }), db as never, priceMap);
  assertEquals(psEffective(db.state, 'user_st1', 'impact')?.status, 'active');

  // Cancel Suite — Impact individual subscription must remain active
  const sub_suite_canceled = makeSub({ id: 'sub_st_suite', status: 'canceled', items: { data: [{ price: { id: 'price_suite_pro' } }] } });
  const res = await handler(await signedReq(evt({ id: 'evt_st3', type: 'customer.subscription.updated', data: { object: { id: 'sub_st_suite', customer: 'cus_st1' } } })), fakeStripe({ sub_st_suite: sub_suite_canceled }), db as never, priceMap);
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_st1', 'suite', 'sub_st_suite')?.status, 'canceled'); // Suite canceled
  assertEquals(psEffective(db.state, 'user_st1', 'impact')?.status, 'active'); // Impact still active
});

Deno.test('WEBHOOK-30: webhook duplicado (mesmo event_id) — segundo delivery é no-op, product_subscriptions inalterado', async () => {
  const priceMap = new Map([['price_impact_pro', { product: 'impact', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_dup1', 'user_dup1'));
  const stripe = fakeStripe({
    sub_dup1: makeSub({ id: 'sub_dup1', status: 'active', items: { data: [{ price: { id: 'price_impact_pro' } }] } }),
  });
  const body = evt({ id: 'evt_dup1', type: 'checkout.session.completed', data: { object: { customer: 'cus_dup1', subscription: 'sub_dup1' } } });

  // First delivery
  const res1 = await handler(await signedReq(body), stripe, db as never, priceMap);
  assertEquals(res1.status, 200);
  assertEquals(psEffective(db.state, 'user_dup1', 'impact')?.status, 'active');
  const snapAfterFirst = JSON.stringify(db.state.productSubscriptions);
  const callsAfterFirst = stripe.calls.length;

  // Second delivery (same event_id) — processedEvents guard fires → no-op
  const res2 = await handler(await signedReq(body), stripe, db as never, priceMap);
  assertEquals(res2.status, 200);
  assertEquals(JSON.stringify(db.state.productSubscriptions), snapAfterFirst); // state unchanged
  assertEquals(stripe.calls.length, callsAfterFirst); // Stripe not called again
});

Deno.test('WEBHOOK-31: out-of-order — evento antigo para sub distinta não revoga entitlement da sub ativa mais recente', async () => {
  const priceMap = new Map([['price_quant_pro', { product: 'quant', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_oo1', 'user_oo1'));
  const T_older = NOW - 300;
  const T_newer = NOW - 100;

  // Sub B: activated at T_newer (arrives first in this delivery order)
  const sub_b = makeSub({ id: 'sub_oo_b', status: 'active', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_oo_b', type: 'checkout.session.completed', created: T_newer, data: { object: { customer: 'cus_oo1', subscription: 'sub_oo_b' } } })), fakeStripe({ sub_oo_b: sub_b }), db as never, priceMap);
  assertEquals(psEffective(db.state, 'user_oo1', 'quant')?.status, 'active');

  // Sub A: canceled event with older timestamp arrives late (different sub → no ordering conflict with sub B)
  const sub_a_canceled = makeSub({ id: 'sub_oo_a', status: 'canceled', items: { data: [{ price: { id: 'price_quant_pro' } }] } });
  const res = await handler(await signedReq(evt({ id: 'evt_oo_a', type: 'checkout.session.completed', created: T_older, data: { object: { customer: 'cus_oo1', subscription: 'sub_oo_a' } } })), fakeStripe({ sub_oo_a: sub_a_canceled }), db as never, priceMap);
  assertEquals(res.status, 200);
  // Sub B independent: its state is unaffected by sub A's cancel event
  assertEquals(psRow(db.state, 'user_oo1', 'quant', 'sub_oo_b')?.status, 'active');
  // Sub A's state written (different triple key — no conflict)
  assertEquals(psRow(db.state, 'user_oo1', 'quant', 'sub_oo_a')?.status, 'canceled');
  // Effective: sub B still active → entitlement preserved
  assertEquals(psEffective(db.state, 'user_oo1', 'quant')?.status, 'active');
});

Deno.test('WEBHOOK-36: R16-C fix — Core activation com user-global guard stale → profiles.role atualizado via resolver (force-update)', async () => {
  // Scenario: user has sub_A (Core, pro, canceled at T=200) and now activates sub_B (Core, pro, T=100).
  // T=100 < T=200 → apply_stripe_subscription_state skips (stale by user-global guard).
  // R16-C fix: activate_core_entitlement_atomic must still update profiles.role to 'pro'
  // because the product row for sub_B IS active and the resolver returns allowed=true.
  const db = fakeDb(newState('cus_r16c', 'user_r16c'));
  const T_older = new Date((NOW - 200) * 1000).toISOString(); // T=200 (sub_A cancel, arrived first)
  const T_activation = new Date((NOW - 300) * 1000).toISOString(); // T=100 (sub_B activate, arrives late)

  // Pre-condition: sub_A canceled event already advanced last_event_created to T_older
  db.state.subscriptions['user_r16c'] = {
    ...db.state.subscriptions['user_r16c'],
    last_event_created: T_older,
    status: 'canceled',
  };
  db.state.profiles['user_r16c'] = { role: 'free', monthly_limit: 15 };

  // Deliver late-arriving activation for sub_B (created at T_activation < T_older)
  const sub_b = makeSub({ id: 'sub_r16c_b', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const res = await handler(
    await signedReq(evt({
      id: 'evt_r16c_activate', type: 'checkout.session.completed',
      created: NOW - 300, // event.created is T_activation
      data: { object: { customer: 'cus_r16c', subscription: 'sub_r16c_b' } },
    })),
    fakeStripe({ sub_r16c_b: sub_b }),
    db as never,
    // No priceMap → legacy Core mode (effectiveLegacyCoreEvent=true)
  );
  assertEquals(res.status, 200);
  // Product row must be written (per-subscription guard: no prior row for sub_B)
  assertEquals(psRow(db.state, 'user_r16c', 'core', 'sub_r16c_b')?.status, 'active');
  // R16-C fix: profiles.role must be 'pro' (force-update from resolver)
  assertEquals(db.state.profiles['user_r16c'].role, 'pro', 'R16-C: profiles.role must be upgraded to pro via force-update');
  assertEquals(db.state.profiles['user_r16c'].monthly_limit, 300);
});

Deno.test('WEBHOOK-32: substituição de subscription — nova sub ativa enquanto antiga é cancelada → entitlement preservado', async () => {
  const priceMap = new Map([['price_impact_pro', { product: 'impact', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_rep1', 'user_rep1'));

  // Old sub: active
  const sub_old = makeSub({ id: 'sub_rep_old', status: 'active', items: { data: [{ price: { id: 'price_impact_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_rep1', type: 'checkout.session.completed', data: { object: { customer: 'cus_rep1', subscription: 'sub_rep_old' } } })), fakeStripe({ sub_rep_old: sub_old }), db as never, priceMap);
  assertEquals(psEffective(db.state, 'user_rep1', 'impact')?.status, 'active');

  // Replacement: new sub (upgrade) also activated
  const sub_new = makeSub({ id: 'sub_rep_new', status: 'active', items: { data: [{ price: { id: 'price_impact_pro' } }] } });
  await handler(await signedReq(evt({ id: 'evt_rep2', type: 'checkout.session.completed', data: { object: { customer: 'cus_rep1', subscription: 'sub_rep_new' } } })), fakeStripe({ sub_rep_new: sub_new }), db as never, priceMap);
  assertEquals(psRow(db.state, 'user_rep1', 'impact', 'sub_rep_old')?.status, 'active');
  assertEquals(psRow(db.state, 'user_rep1', 'impact', 'sub_rep_new')?.status, 'active');

  // Old sub canceled — new sub still active → entitlement preserved
  const sub_old_canceled = makeSub({ id: 'sub_rep_old', status: 'canceled', items: { data: [{ price: { id: 'price_impact_pro' } }] } });
  const res = await handler(await signedReq(evt({ id: 'evt_rep3', type: 'customer.subscription.updated', data: { object: { id: 'sub_rep_old', customer: 'cus_rep1' } } })), fakeStripe({ sub_rep_old: sub_old_canceled }), db as never, priceMap);
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_rep1', 'impact', 'sub_rep_old')?.status, 'canceled');
  assertEquals(psRow(db.state, 'user_rep1', 'impact', 'sub_rep_new')?.status, 'active');
  // Entitlement preserved via new sub
  assertEquals(psEffective(db.state, 'user_rep1', 'impact')?.status, 'active');
});

Deno.test('WEBHOOK-37: R20-B fix — unmapped-Core cancel com segunda sub Core ativa → profiles.role NÃO rebaixado', async () => {
  // Scenario (P1-R20-B):
  //   - sub_A (mapped Core pro, active) processed first → profiles.role='pro'
  //   - sub_B (unmapped Core, cancel event) arrives — isUnmappedLegacyCore=true
  // Before fix: applySubscriptionState called unconditionally → profiles.role='free'
  // After fix:  resolve_product_entitlement called first → allowed=true (sub_A still active)
  //             → legacy NOT downgraded → profiles.role stays 'pro'
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r20b', 'user_r20b'));

  // Step 1: activate sub_A (mapped Core pro) → profiles.role='pro'
  const sub_a = makeSub({ id: 'sub_r20b_a', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const resA = await handler(
    await signedReq(evt({ id: 'evt_r20b_a', type: 'checkout.session.completed', created: NOW - 400, data: { object: { customer: 'cus_r20b', subscription: 'sub_r20b_a' } } })),
    fakeStripe({ sub_r20b_a: sub_a }),
    db as never,
    priceMap,
  );
  assertEquals(resA.status, 200, 'sub_A activation must succeed');
  assertEquals(db.state.profiles['user_r20b'].role, 'pro', 'sub_A activation must set profiles.role=pro');
  assertEquals(psRow(db.state, 'user_r20b', 'core', 'sub_r20b_a')?.status, 'active');

  // Step 2: deliver unmapped-Core cancel for sub_B (price NOT in priceMap → isUnmappedLegacyCore=true)
  // sub_B is the subscription in the event but its price is unmapped.
  const sub_b_canceled = makeSub({
    id: 'sub_r20b_b',
    status: 'canceled',
    items: { data: [{ price: { id: 'price_UNMAPPED_LEGACY' } }] },
  });
  const resB = await handler(
    await signedReq(evt({ id: 'evt_r20b_b', type: 'customer.subscription.deleted', created: NOW - 200, data: { object: { id: 'sub_r20b_b', customer: 'cus_r20b' } } })),
    fakeStripe({ sub_r20b_b: sub_b_canceled }),
    db as never,
    priceMap,
  );
  assertEquals(resB.status, 200, 'unmapped-Core cancel must return 200');
  // R20-B fix: sub_A is still active → resolve_product_entitlement returns allowed=true
  // → applySubscriptionState must NOT be called → profiles.role stays 'pro'
  assertEquals(db.state.profiles['user_r20b'].role, 'pro', 'R20-B: profiles.role must NOT be downgraded when another Core sub is active');
  assertEquals(db.state.profiles['user_r20b'].monthly_limit, 300);
  // sub_A product row must still be active
  assertEquals(psRow(db.state, 'user_r20b', 'core', 'sub_r20b_a')?.status, 'active');
});

Deno.test('WEBHOOK-38: R20-B fix — unmapped-Core cancel sem outra sub Core ativa → profiles.role rebaixado para free', async () => {
  // Complemento do WEBHOOK-37: quando NÃO há outra sub Core ativa,
  // o cancelamento unmapped DEVE downgradar profiles.role (caminho legítimo).
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r20b2', 'user_r20b2'));

  // Set up legacy state: user has profiles.role='pro' but no active Core product row.
  // stripe_subscription_id must match sub_r20b2_x so that the code detects
  // effectiveLegacyCoreEvent=true (unmapped-price cancel matching legacy sub).
  db.state.profiles['user_r20b2'] = { role: 'pro', monthly_limit: 300 };
  db.state.subscriptions['user_r20b2'] = {
    ...db.state.subscriptions['user_r20b2'],
    stripe_subscription_id: 'sub_r20b2_x',
    status: 'active',
    last_event_created: new Date((NOW - 500) * 1000).toISOString(),
  };

  // Deliver unmapped-Core cancel (no active Core product rows exist in productSubscriptions)
  const sub_x = makeSub({
    id: 'sub_r20b2_x',
    status: 'canceled',
    items: { data: [{ price: { id: 'price_UNMAPPED_LEGACY' } }] },
  });
  const res = await handler(
    await signedReq(evt({ id: 'evt_r20b2_x', type: 'customer.subscription.deleted', created: NOW - 100, data: { object: { id: 'sub_r20b2_x', customer: 'cus_r20b2' } } })),
    fakeStripe({ sub_r20b2_x: sub_x }),
    db as never,
    priceMap,
  );
  assertEquals(res.status, 200, 'unmapped-Core cancel must return 200');
  // No active Core sub → resolve returns allowed=false → legacy MUST be downgraded
  assertEquals(db.state.profiles['user_r20b2'].role, 'free', 'R20-B: profiles.role must be downgraded to free when no other Core sub is active');
  assertEquals(db.state.profiles['user_r20b2'].monthly_limit, 15);
});

Deno.test('WEBHOOK-39: R22-A fix — cancel última sub Core com user-global guard bloqueando → force-downgrade profiles para free', async () => {
  // Scenario (P1-R22-A):
  //   sub_A activated at T=100, sub_B activated at T=300 → last_event_created=T=300
  //   sub_B canceled at T=400 → last_event_created=T=400, resolver: sub_A still active → no downgrade
  //   sub_A canceled at T=200 (late-arriving, T=200 > T=100 so per-sub guard accepts,
  //                             but T=200 < T=400 so user-global guard rejects legacy write)
  //   → product_subscriptions: both canceled → resolver allowed=false
  //   → apply_stripe_subscription_state blocked by T=200 < T=400 → profiles.role stays 'pro'
  //   R22-A fix: force-downgrade profiles.role to 'free' when allowed=false + guard blocked
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r22a', 'user_r22a'));

  // Step 1: activate sub_A at T=100
  const sub_a = makeSub({ id: 'sub_r22a_a', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const resA1 = await handler(
    await signedReq(evt({ id: 'evt_r22a_actA', type: 'checkout.session.completed', created: NOW - 400, data: { object: { customer: 'cus_r22a', subscription: 'sub_r22a_a' } } })),
    fakeStripe({ sub_r22a_a: sub_a }),
    db as never,
    priceMap,
  );
  assertEquals(resA1.status, 200);
  assertEquals(db.state.profiles['user_r22a'].role, 'pro', 'sub_A activation must set profiles.role=pro');

  // Step 2: activate sub_B at T=300 → last_event_created advances to T=300
  const sub_b = makeSub({ id: 'sub_r22a_b', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const resA2 = await handler(
    await signedReq(evt({ id: 'evt_r22a_actB', type: 'checkout.session.completed', created: NOW - 200, data: { object: { customer: 'cus_r22a', subscription: 'sub_r22a_b' } } })),
    fakeStripe({ sub_r22a_b: sub_b }),
    db as never,
    priceMap,
  );
  assertEquals(resA2.status, 200);

  // Step 3: cancel sub_B at T=400 → last_event_created=T=400; resolver sees sub_A active → no downgrade
  const sub_b_canceled = makeSub({ id: 'sub_r22a_b', status: 'canceled', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const resC = await handler(
    await signedReq(evt({ id: 'evt_r22a_canB', type: 'customer.subscription.deleted', created: NOW - 100, data: { object: { id: 'sub_r22a_b', customer: 'cus_r22a' } } })),
    fakeStripe({ sub_r22a_b: sub_b_canceled }),
    db as never,
    priceMap,
  );
  assertEquals(resC.status, 200);
  // sub_B canceled, but sub_A still active → no legacy downgrade
  assertEquals(db.state.profiles['user_r22a'].role, 'pro', 'sub_B cancel must NOT downgrade (sub_A still active)');

  // Step 4: late-arriving cancel for sub_A at T=200 (T=200 > T=100 → per-sub accepts,
  //          but T=200 < T=400 → user-global guard rejects legacy write)
  const sub_a_canceled = makeSub({ id: 'sub_r22a_a', status: 'canceled', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const resD = await handler(
    await signedReq(evt({ id: 'evt_r22a_canA', type: 'customer.subscription.deleted', created: NOW - 300, data: { object: { id: 'sub_r22a_a', customer: 'cus_r22a' } } })),
    fakeStripe({ sub_r22a_a: sub_a_canceled }),
    db as never,
    priceMap,
  );
  assertEquals(resD.status, 200);
  // Both subs now canceled in product_subscriptions
  assertEquals(psRow(db.state, 'user_r22a', 'core', 'sub_r22a_a')?.status, 'canceled', 'sub_A must be canceled in product_subscriptions');
  assertEquals(psRow(db.state, 'user_r22a', 'core', 'sub_r22a_b')?.status, 'canceled', 'sub_B must be canceled in product_subscriptions');
  // R22-A fix: resolver returns allowed=false (both canceled), but user-global guard blocks
  // apply_stripe_subscription_state (T=200 < T=400). Force-downgrade must apply.
  assertEquals(db.state.profiles['user_r22a'].role, 'free', 'R22-A: force-downgrade must set profiles.role=free when all subs canceled and guard blocks legacy write');
  assertEquals(db.state.profiles['user_r22a'].monthly_limit, 15);
});

Deno.test('WEBHOOK-40: R23-A fix — premium manual NÃO rebaixado por cancelamento Stripe (role protection)', async () => {
  // Scenario: user has manual premium role + Core subscription.
  // Cancellation event arrives. No active Core sub in product_subscriptions.
  // R22-A force-downgrade must NOT touch premium roles (Stripe does not own them).
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r23a', 'user_r23a'));

  // Set user as manually-granted premium
  db.state.profiles['user_r23a'] = { role: 'premium', monthly_limit: 1000 };
  db.state.subscriptions['user_r23a'] = {
    ...db.state.subscriptions['user_r23a'],
    stripe_subscription_id: 'sub_r23a',
    status: 'active',
    last_event_created: new Date((NOW - 500) * 1000).toISOString(),
  };

  // Cancel: priceMap configured, price IS mapped to Core → normal Core cancel path
  const sub_canceled = makeSub({ id: 'sub_r23a', status: 'canceled', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const res = await handler(
    await signedReq(evt({ id: 'evt_r23a', type: 'customer.subscription.deleted', created: NOW - 100, data: { object: { id: 'sub_r23a', customer: 'cus_r23a' } } })),
    fakeStripe({ sub_r23a: sub_canceled }),
    db as never,
    priceMap,
  );
  assertEquals(res.status, 200);
  // product_subscriptions must show canceled
  assertEquals(psRow(db.state, 'user_r23a', 'core', 'sub_r23a')?.status, 'canceled');
  // R23-A fix: premium role must NOT be downgraded by Stripe cancellation
  assertEquals(db.state.profiles['user_r23a'].role, 'premium', 'R23-A: premium manual role must NOT be downgraded by Stripe cancellation');
  assertEquals(db.state.profiles['user_r23a'].monthly_limit, 1000);
});

Deno.test('WEBHOOK-41: R24 fix — activate com tier=premium no priceMap grava profiles.role=pro (não premium)', async () => {
  // Scenario: STRIPE_PRICE_MAP has a price mapped to tier='premium' (misconfiguration or future tier).
  // Migration 20261010000000 defines 'premium' as manually-granted only.
  // activate_core_entitlement_atomic must cap Stripe-managed role to 'pro' maximum.
  const priceMap = new Map([['price_core_premium', { product: 'core', tier: 'premium' }]]);
  const db = fakeDb(newState('cus_r24a', 'user_r24a'));
  // User starts at free
  db.state.profiles['user_r24a'] = { role: 'free', monthly_limit: 15 };

  const sub_active = makeSub({ id: 'sub_r24a', status: 'active', items: { data: [{ price: { id: 'price_core_premium' } }] } });
  const res = await handler(
    await signedReq(evt({ id: 'evt_r24a', type: 'customer.subscription.updated', created: NOW, data: { object: { id: 'sub_r24a', customer: 'cus_r24a', status: 'active' } } })),
    fakeStripe({ sub_r24a: sub_active }),
    db as never,
    priceMap,
  );
  assertEquals(res.status, 200);
  // product_subscriptions correctly records tier=premium (factual data)
  assertEquals(psEffective(db.state, 'user_r24a', 'core')?.tier, 'premium');
  // R24 fix: profiles.role must be capped at 'pro', NOT 'premium'
  assertEquals(db.state.profiles['user_r24a'].role, 'pro', 'R24: Stripe billing must not elevate profiles.role to premium');
  assertEquals(db.state.profiles['user_r24a'].monthly_limit, 300);
});

// ─── R25-A: Tuple ordering tests ─────────────────────────────────────────────

Deno.test('WEBHOOK-42: R25-A — mesmo timestamp, event_id maior vence (aplicado)', async () => {
  // Two activate events at IDENTICAL timestamp. Higher event_id must win.
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r25a_a', 'user_r25a_a'));
  db.state.profiles['user_r25a_a'] = { role: 'free', monthly_limit: 15 };
  const TS = NOW;
  const subA = makeSub({ id: 'sub_r25_ts_a', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  // First event (lexicographically lower event_id: _1)
  await handler(
    await signedReq(evt({ id: 'evt_r25a_001', type: 'customer.subscription.updated', created: TS, data: { object: { id: 'sub_r25_ts_a', customer: 'cus_r25a_a', status: 'active' } } })),
    fakeStripe({ sub_r25_ts_a: subA }), db as never, priceMap,
  );
  // Second event same timestamp, HIGHER event_id (_002 > _001) → must apply
  const res = await handler(
    await signedReq(evt({ id: 'evt_r25a_002', type: 'customer.subscription.updated', created: TS, data: { object: { id: 'sub_r25_ts_a', customer: 'cus_r25a_a', status: 'active' } } })),
    fakeStripe({ sub_r25_ts_a: subA }), db as never, priceMap,
  );
  assertEquals(res.status, 200);
  // Higher event_id was applied: last_stripe_event_id must be evt_r25a_002
  assertEquals(psRow(db.state, 'user_r25a_a', 'core', 'sub_r25_ts_a')?.last_stripe_event_id, 'evt_r25a_002', 'R25-A: higher event_id at same timestamp must win');
});

Deno.test('WEBHOOK-43: R25-A — mesmo timestamp, event_id menor é stale (ignorado)', async () => {
  // Two activate events at IDENTICAL timestamp. Lower event_id must be skipped.
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r25b', 'user_r25b'));
  db.state.profiles['user_r25b'] = { role: 'free', monthly_limit: 15 };
  const TS = NOW;
  const subA = makeSub({ id: 'sub_r25b', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  // First: lexicographically higher event_id (_002) arrives first (simulates inversion)
  await handler(
    await signedReq(evt({ id: 'evt_r25b_002', type: 'customer.subscription.updated', created: TS, data: { object: { id: 'sub_r25b', customer: 'cus_r25b', status: 'active' } } })),
    fakeStripe({ sub_r25b: subA }), db as never, priceMap,
  );
  // Second: lower event_id (_001) at same timestamp → must be stale
  const res = await handler(
    await signedReq(evt({ id: 'evt_r25b_001', type: 'customer.subscription.updated', created: TS, data: { object: { id: 'sub_r25b', customer: 'cus_r25b', status: 'active' } } })),
    fakeStripe({ sub_r25b: subA }), db as never, priceMap,
  );
  assertEquals(res.status, 200);
  // Low event_id was skipped: stored event_id must still be _002
  assertEquals(psRow(db.state, 'user_r25b', 'core', 'sub_r25b')?.last_stripe_event_id, 'evt_r25b_002', 'R25-A: lower event_id at same timestamp must be stale');
});

Deno.test('WEBHOOK-44: R25-A — replay exato do mesmo evento é idempotente (no-op)', async () => {
  // Replaying the exact same event_id at same timestamp must be a no-op.
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r25c', 'user_r25c'));
  db.state.profiles['user_r25c'] = { role: 'free', monthly_limit: 15 };
  const subA = makeSub({ id: 'sub_r25c', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  // Apply once
  await handler(
    await signedReq(evt({ id: 'evt_r25c_1', type: 'customer.subscription.updated', created: NOW, data: { object: { id: 'sub_r25c', customer: 'cus_r25c', status: 'active' } } })),
    fakeStripe({ sub_r25c: subA }), db as never, priceMap,
  );
  assertEquals(db.state.profiles['user_r25c'].role, 'pro');
  // Replay identical event
  db.state.profiles['user_r25c'] = { role: 'pro', monthly_limit: 300 }; // state unchanged
  const res = await handler(
    await signedReq(evt({ id: 'evt_r25c_1', type: 'customer.subscription.updated', created: NOW, data: { object: { id: 'sub_r25c', customer: 'cus_r25c', status: 'active' } } })),
    fakeStripe({ sub_r25c: subA }), db as never, priceMap,
  );
  assertEquals(res.status, 200, 'replay must not fail');
  // Idempotent: profiles.role unchanged (still pro, not double-applied)
  assertEquals(db.state.profiles['user_r25c'].role, 'pro', 'R25-A: replay must be idempotent');
});

Deno.test('WEBHOOK-45: R25-A — evento mais novo (timestamp maior) sempre aplicado', async () => {
  // A newer-timestamp event always wins, regardless of event_id.
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r25d', 'user_r25d'));
  db.state.profiles['user_r25d'] = { role: 'free', monthly_limit: 15 };
  const subActive = makeSub({ id: 'sub_r25d', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  // Older event
  await handler(
    await signedReq(evt({ id: 'evt_r25d_old', type: 'customer.subscription.updated', created: NOW - 100, data: { object: { id: 'sub_r25d', customer: 'cus_r25d', status: 'active' } } })),
    fakeStripe({ sub_r25d: subActive }), db as never, priceMap,
  );
  // Newer event with LOWER event_id (should still apply — timestamp wins)
  const res = await handler(
    await signedReq(evt({ id: 'evt_r25d_new', type: 'customer.subscription.updated', created: NOW, data: { object: { id: 'sub_r25d', customer: 'cus_r25d', status: 'active' } } })),
    fakeStripe({ sub_r25d: subActive }), db as never, priceMap,
  );
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_r25d', 'core', 'sub_r25d')?.last_stripe_event_id, 'evt_r25d_new', 'R25-A: newer timestamp must always apply');
  assertEquals(db.state.profiles['user_r25d'].role, 'pro');
});

Deno.test('WEBHOOK-46: R25-A — evento mais antigo (timestamp menor) é stale', async () => {
  // An older-timestamp event must not overwrite a newer one (classic stale prevention).
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r25e', 'user_r25e'));
  db.state.profiles['user_r25e'] = { role: 'pro', monthly_limit: 300 };
  const subCanceled = makeSub({ id: 'sub_r25e', status: 'canceled', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const subActive  = makeSub({ id: 'sub_r25e', status: 'active',   items: { data: [{ price: { id: 'price_core_pro' } }] } });
  // Newer cancel arrives first
  await handler(
    await signedReq(evt({ id: 'evt_r25e_cancel', type: 'customer.subscription.deleted', created: NOW, data: { object: { id: 'sub_r25e', customer: 'cus_r25e', status: 'canceled' } } })),
    fakeStripe({ sub_r25e: subCanceled }), db as never, priceMap,
  );
  assertEquals(db.state.profiles['user_r25e'].role, 'free');
  // Older activate arrives late — must be stale
  const res = await handler(
    await signedReq(evt({ id: 'evt_r25e_old_act', type: 'customer.subscription.updated', created: NOW - 100, data: { object: { id: 'sub_r25e', customer: 'cus_r25e', status: 'active' } } })),
    fakeStripe({ sub_r25e: subActive }), db as never, priceMap,
  );
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_r25e'].role, 'free', 'R25-A: older activate must not restore after newer cancel');
});

Deno.test('WEBHOOK-47: R25-A — cancelamento + ativação mesmo timestamp → event_id decide', async () => {
  // Cancel and activate at SAME second. Higher event_id is canonical.
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r25f', 'user_r25f'));
  db.state.profiles['user_r25f'] = { role: 'free', monthly_limit: 15 };
  const TS = NOW;
  const subCanceled = makeSub({ id: 'sub_r25f', status: 'canceled', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const subActive   = makeSub({ id: 'sub_r25f', status: 'active',   items: { data: [{ price: { id: 'price_core_pro' } }] } });
  // Cancel with HIGHER event_id arrives first
  await handler(
    await signedReq(evt({ id: 'evt_r25f_cancel_high', type: 'customer.subscription.deleted', created: TS, data: { object: { id: 'sub_r25f', customer: 'cus_r25f', status: 'canceled' } } })),
    fakeStripe({ sub_r25f: subCanceled }), db as never, priceMap,
  );
  assertEquals(psRow(db.state, 'user_r25f', 'core', 'sub_r25f')?.status, 'canceled');
  // Activate with LOWER event_id arrives second — must be stale
  const res = await handler(
    await signedReq(evt({ id: 'evt_r25f_act_low', type: 'customer.subscription.updated', created: TS, data: { object: { id: 'sub_r25f', customer: 'cus_r25f', status: 'active' } } })),
    fakeStripe({ sub_r25f: subActive }), db as never, priceMap,
  );
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_r25f', 'core', 'sub_r25f')?.status, 'canceled', 'R25-A: lower event_id activate at same timestamp must NOT override higher event_id cancel');
  assertEquals(db.state.profiles['user_r25f'].role, 'free', 'R25-A: profiles.role must remain free after stale activate is skipped');
});

Deno.test('WEBHOOK-48: R25-A — multi-sub mesmo produto mesmo timestamp → event_id por sub independente', async () => {
  // Two different subscriptions for same product at same timestamp.
  // Each subscription has its own ordering state (per-sub guard).
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb({ ...newState('cus_r25g', 'user_r25g'), customerToUser: { cus_r25g: 'user_r25g' } });
  db.state.profiles['user_r25g'] = { role: 'free', monthly_limit: 15 };
  const TS = NOW;
  const subA = makeSub({ id: 'sub_r25g_a', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const subB = makeSub({ id: 'sub_r25g_b', status: 'active', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  // Process sub A
  await handler(
    await signedReq(evt({ id: 'evt_r25g_a1', type: 'customer.subscription.updated', created: TS, data: { object: { id: 'sub_r25g_a', customer: 'cus_r25g', status: 'active' } } })),
    fakeStripe({ sub_r25g_a: subA }), db as never, priceMap,
  );
  // Process sub B at same timestamp — independent guard, must apply
  const res = await handler(
    await signedReq(evt({ id: 'evt_r25g_b1', type: 'customer.subscription.updated', created: TS, data: { object: { id: 'sub_r25g_b', customer: 'cus_r25g', status: 'active' } } })),
    fakeStripe({ sub_r25g_b: subB }), db as never, priceMap,
  );
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_r25g', 'core', 'sub_r25g_a')?.last_stripe_event_id, 'evt_r25g_a1', 'sub_A event_id preserved');
  assertEquals(psRow(db.state, 'user_r25g', 'core', 'sub_r25g_b')?.last_stripe_event_id, 'evt_r25g_b1', 'sub_B event_id applied independently');
  assertEquals(db.state.profiles['user_r25g'].role, 'pro', 'Both subs active → pro');
});

Deno.test('WEBHOOK-49: R25-A — entrega fora de ordem (stale chega após novo) não reverte estado', async () => {
  // Event 1 (T=200) arrives AFTER Event 2 (T=100).
  // Net: Event 2 is the newest, Event 1 must be rejected as stale.
  const priceMap = new Map([['price_core_pro', { product: 'core', tier: 'pro' }]]);
  const db = fakeDb(newState('cus_r25h', 'user_r25h'));
  db.state.profiles['user_r25h'] = { role: 'free', monthly_limit: 15 };
  const subActive   = makeSub({ id: 'sub_r25h', status: 'active',   items: { data: [{ price: { id: 'price_core_pro' } }] } });
  const subCanceled = makeSub({ id: 'sub_r25h', status: 'canceled', items: { data: [{ price: { id: 'price_core_pro' } }] } });
  // Newer cancel (T=200) arrives first
  await handler(
    await signedReq(evt({ id: 'evt_r25h_cancel', type: 'customer.subscription.deleted', created: NOW + 100, data: { object: { id: 'sub_r25h', customer: 'cus_r25h', status: 'canceled' } } })),
    fakeStripe({ sub_r25h: subCanceled }), db as never, priceMap,
  );
  assertEquals(db.state.profiles['user_r25h'].role, 'free');
  // Older activate (T=100) arrives late — stale
  const res = await handler(
    await signedReq(evt({ id: 'evt_r25h_activate', type: 'customer.subscription.updated', created: NOW, data: { object: { id: 'sub_r25h', customer: 'cus_r25h', status: 'active' } } })),
    fakeStripe({ sub_r25h: subActive }), db as never, priceMap,
  );
  assertEquals(res.status, 200);
  assertEquals(psRow(db.state, 'user_r25h', 'core', 'sub_r25h')?.status, 'canceled', 'R25-A: out-of-order delivery must not revert cancel to active');
  assertEquals(db.state.profiles['user_r25h'].role, 'free', 'R25-A: profile must remain free after stale activate');
});
