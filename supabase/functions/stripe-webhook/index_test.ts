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
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
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
        if (lastEventCreated != null && eventCreated < lastEventCreated) {
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
        };
        state.profiles[userId] = {
          ...(state.profiles[userId] ?? {}),
          role: args.p_role,
          monthly_limit: args.p_monthly_limit,
        };
        return Promise.resolve({ data: true, error: null });
      }
      // IV-WEB-ECOSYSTEM-UNIFICATION-01: product subscription upsert with ordering.
      if (fn === 'upsert_product_subscription') {
        const userId = args.p_user_id as string;
        const product = args.p_product as string;
        const key = `${userId}:${product}`;
        const existing = state.productSubscriptions[key];
        // Event ordering guard: reject stale events (mirrors SQL function)
        const incomingCreated = args.p_stripe_event_created as string | null ?? null;
        const lastCreated = existing?.last_stripe_event_created as string | null ?? null;
        if (incomingCreated !== null && lastCreated !== null && incomingCreated < lastCreated) {
          return Promise.resolve({ data: { ok: false, skipped: true, reason: 'STALE_EVENT', product }, error: null }) as never;
        }
        state.productSubscriptions[key] = {
          product, tier: args.p_tier, status: args.p_status, source: args.p_source,
          stripe_subscription_id: args.p_stripe_subscription_id,
          stripe_price_id: args.p_stripe_price_id,
          last_stripe_event_created: incomingCreated,
        };
        return Promise.resolve({ data: { ok: true, product, tier: args.p_tier, status: args.p_status }, error: null }) as never;
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
            eq: (_col: string, val: string) => ({
              maybeSingle: () => {
                const userId = state.customerToUser[val];
                return Promise.resolve({ data: userId ? { user_id: userId } : null, error: null });
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
  assertEquals(db.state.productSubscriptions['user_ord1:impact']?.status, 'active');

  // Simulate product subscription active state being set
  const activePs = db.state.productSubscriptions['user_ord1:impact'];
  assertEquals(activePs?.last_stripe_event_created, new Date(newerTs * 1000).toISOString());

  // Now, mark subscription as canceled via a newer legacy event
  db.state.productSubscriptions['user_ord1:impact'] = {
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
  assertEquals(db.state.productSubscriptions['user_ord1:impact']?.status, 'canceled');
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
  assertEquals(!!db.state.productSubscriptions['user_ps1:impact'], true);
  assertEquals(db.state.productSubscriptions['user_ps1:core'], undefined);
  // Legacy subscriptions table NOT written for Impact event
  assertEquals(db.state.subscriptions['user_ps1']?.status, 'none'); // initial value unchanged
});

Deno.test('WEBHOOK-19: upsert_product_subscription falha → evento durável gravado → webhook 200 (path B)', async () => {
  const db = fakeDb(newState('cus_ps2', 'user_ps2')) as ReturnType<typeof fakeDb> & { rpc: unknown };
  let applyCalls = 0;
  let upsertCalls = 0;
  const origRpc = db.rpc.bind(db);
  db.rpc = (fn: string, args: Record<string, unknown>) => {
    if (fn === 'apply_stripe_subscription_state') { applyCalls++; return origRpc(fn, args); }
    if (fn === 'upsert_product_subscription') { upsertCalls++; throw new Error('simulated product upsert failure'); }
    return origRpc(fn, args);
  };
  const stripe = fakeStripe({ sub_ps2: makeSub({ id: 'sub_ps2', status: 'active' }) });
  const body = evt({ id: 'evt_ps2', type: 'checkout.session.completed', data: { object: { customer: 'cus_ps2', subscription: 'sub_ps2' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
  // Path B: durable pending event written → webhook still returns 200
  assertEquals(res.status, 200);
  assertEquals(applyCalls, 1);
  assertEquals(upsertCalls, 1);
  assertEquals(db.state.profiles['user_ps2'].role, 'pro'); // legacy write succeeded
  // Durable fallback event was persisted
  assertEquals(Object.keys(db.state.productEntitlementEvents).length, 1);
  const pendingEvt = Object.values(db.state.productEntitlementEvents)[0] as Record<string, unknown>;
  assertEquals(pendingEvt.event_type, 'pending_retry');
  assertEquals(pendingEvt.stripe_event_id, 'evt_ps2');
});

Deno.test('WEBHOOK-20: upsert_product_subscription E fallback ambos falham → webhook 500', async () => {
  const db = fakeDb(newState('cus_ps3', 'user_ps3')) as ReturnType<typeof fakeDb> & { rpc: unknown; from: unknown };
  const origRpc = db.rpc.bind(db);
  db.rpc = (fn: string, args: Record<string, unknown>) => {
    if (fn === 'apply_stripe_subscription_state') return origRpc(fn, args);
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
  const stripe = fakeStripe({ sub_ps3: makeSub({ id: 'sub_ps3', status: 'active' }) });
  const body = evt({ id: 'evt_ps3', type: 'checkout.session.completed', data: { object: { customer: 'cus_ps3', subscription: 'sub_ps3' } } });
  const res = await handler(await signedReq(body), stripe, db as never);
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
  // Legacy write still applied (pre-existing profiles table)
  assertEquals(db.state.profiles['user_ps4'].role, 'pro');
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
  assertEquals(db.state.productSubscriptions['user_oc1:impact']?.status, 'active');

  // Manually advance the stored event timestamp to simulate newer commit in DB
  db.state.productSubscriptions['user_oc1:impact'] = {
    ...db.state.productSubscriptions['user_oc1:impact'],
    status: 'active',
    last_stripe_event_created: new Date(newerTs * 1000).toISOString(),
  };

  // Older event now tries to cancel the subscription — must be blocked
  const olderSub = makeSub({ id: 'sub_oc1', status: 'canceled', items: { data: [{ price: { id: 'price_impact' } }] } });
  const olderEvt = evt({ id: 'evt_oc_old', type: 'customer.subscription.updated', created: olderTs, data: { object: { id: 'sub_oc1', customer: 'cus_oc1' } } });
  const res = await handler(await signedReq(olderEvt), fakeStripe({ sub_oc1: olderSub }), db as never, priceMap);
  assertEquals(res.status, 200);
  // Atomic predicate prevented overwrite: subscription still active
  assertEquals(db.state.productSubscriptions['user_oc1:impact']?.status, 'active');
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
