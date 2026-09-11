/**
 * IVE-COMMERCIAL-BILLING-01 — stripe-webhook tests. Covers signature
 * verification at the boundary, idempotency (including the "record only
 * after success" ordering), out-of-order-safe entitlement transitions,
 * and cross-user isolation.
 *
 * Execução:
 *   DENO_TESTING=1 STRIPE_WEBHOOK_SECRET=whsec_test deno test --allow-env supabase/functions/stripe-webhook/index_test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { StripeFetch, StripeSubscription } from '../_shared/stripe.ts';

const SECRET = 'whsec_test_secret';
Deno.env.set('STRIPE_WEBHOOK_SECRET', SECRET);

const { handler } = await import('./index.ts');

async function sign(payload: string, timestamp: number, secret = SECRET): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const bytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${payload}`));
  return Array.from(new Uint8Array(bytes)).map((b) => b.toString(16).padStart(2, '0')).join('');
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
}

function fakeDb(initial: DbState) {
  const state = initial;
  return {
    state,
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
      throw new Error(`unexpected table in test fake: ${table}`);
    },
    // Mirrors public.apply_stripe_subscription_state (migration
    // 20260911020000) -- both writes applied together, matching the real
    // RPC's atomicity.
    rpc(fn: string, args: Record<string, unknown>): Promise<{ error: unknown }> {
      if (fn !== 'apply_stripe_subscription_state') throw new Error(`unexpected rpc in test fake: ${fn}`);
      const userId = args.p_user_id as string;
      state.subscriptions[userId] = {
        ...(state.subscriptions[userId] ?? {}),
        stripe_subscription_id: args.p_stripe_subscription_id,
        stripe_price_id: args.p_stripe_price_id,
        status: args.p_status,
        current_period_end: args.p_current_period_end,
        cancel_at_period_end: args.p_cancel_at_period_end,
      };
      state.profiles[userId] = {
        ...(state.profiles[userId] ?? {}),
        role: args.p_role,
        monthly_limit: args.p_monthly_limit,
      };
      return Promise.resolve({ error: null });
    },
  };
}

function newState(customerId: string, userId: string): DbState {
  return {
    subscriptions: {},
    customerToUser: { [customerId]: userId },
    profiles: { [userId]: { role: 'free', monthly_limit: 5 } },
    processedEvents: {},
  };
}

Deno.test('WEBHOOK-1: assinatura ausente -> 400, nenhum estado alterado', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const res = await handler(await signedReq({ id: 'evt_1', type: 'checkout.session.completed', data: { object: {} } }, { noSig: true }), fakeStripe({}), db as never);
  assertEquals(res.status, 400);
  assertEquals(db.state.profiles['user_1'].role, 'free');
});

Deno.test('WEBHOOK-2: assinatura com secret errado -> 400', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const req = await signedReq({ id: 'evt_1', type: 'checkout.session.completed' }, { secret: 'whsec_wrong' });
  const res = await handler(req, fakeStripe({}), db as never);
  assertEquals(res.status, 400);
});

Deno.test('WEBHOOK-3: timestamp fora da tolerância (replay) -> 400', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const req = await signedReq({ id: 'evt_1', type: 'checkout.session.completed' }, { ts: Math.floor(Date.now() / 1000) - 3600 });
  const res = await handler(req, fakeStripe({}), db as never);
  assertEquals(res.status, 400);
});

Deno.test('WEBHOOK-4: checkout.session.completed com assinatura válida -> promove usuário a pro', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const stripe = fakeStripe({ sub_1: makeSub({ status: 'active' }) });
  const req = await signedReq({
    id: 'evt_checkout_1',
    type: 'checkout.session.completed',
    data: { object: { customer: 'cus_1', subscription: 'sub_1' } },
  });
  const res = await handler(req, stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_1'].role, 'pro');
  assertEquals(db.state.profiles['user_1'].monthly_limit, 300);
  assertEquals(db.state.subscriptions['user_1'].status, 'active');
});

Deno.test('WEBHOOK-5: evento duplicado (mesmo event.id) -> segunda entrega é no-op, não rechama Stripe', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const stripe = fakeStripe({ sub_1: makeSub({ status: 'active' }) });
  const body = { id: 'evt_dup_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_1', subscription: 'sub_1' } } };
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
  const body = { id: 'evt_fail_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_1', subscription: 'sub_missing' } } };
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 500);
  assertEquals(db.state.processedEvents['evt_fail_1'], undefined); // não marcado -> retry vai reprocessar
  assertEquals(db.state.profiles['user_1'].role, 'free'); // nenhuma mudança parcial
});

Deno.test('WEBHOOK-7: customer.subscription.updated com status active -> mantém/atualiza pro', async () => {
  const db = fakeDb(newState('cus_2', 'user_2'));
  const stripe = fakeStripe({ sub_2: makeSub({ id: 'sub_2', status: 'active' }) });
  const body = { id: 'evt_upd_1', type: 'customer.subscription.updated', data: { object: { id: 'sub_2', customer: 'cus_2', status: 'trialing' } } };
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
  const body = { id: 'evt_del_1', type: 'customer.subscription.deleted', data: { object: { id: 'sub_3', customer: 'cus_3', status: 'canceled' } } };
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_3'].role, 'free');
  assertEquals(db.state.profiles['user_3'].monthly_limit, 5);
});

Deno.test('WEBHOOK-9: evento "mais antigo" chegando depois (fora de ordem) não ressuscita entitlement -- GET sempre reflete o estado atual', async () => {
  const db = fakeDb(newState('cus_4', 'user_4'));
  db.state.profiles['user_4'] = { role: 'free', monthly_limit: 5 };
  // O assinante JÁ está cancelado no Stripe agora (verdade atual), mesmo
  // que este evento em particular seja um "subscription.updated" antigo
  // que originalmente teria dito status=active.
  const stripe = fakeStripe({ sub_4: makeSub({ id: 'sub_4', status: 'canceled' }) });
  const staleBody = { id: 'evt_stale_1', type: 'customer.subscription.updated', data: { object: { id: 'sub_4', customer: 'cus_4', status: 'active' } } };
  const res = await handler(await signedReq(staleBody), stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_4'].role, 'free'); // não foi promovido por engano
});

Deno.test('WEBHOOK-10: customer desconhecido (sem linha em subscriptions) -> aceita e não quebra, sem alterar profiles de ninguém', async () => {
  const db = fakeDb(newState('cus_5', 'user_5'));
  const stripe = fakeStripe({ sub_x: makeSub({ id: 'sub_x' }) });
  const body = { id: 'evt_unknown_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_does_not_exist', subscription: 'sub_x' } } };
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 200);
  assertEquals(db.state.profiles['user_5'].role, 'free');
});

Deno.test('WEBHOOK-11: isolamento entre usuários -- evento de um customer nunca altera o profile de outro', async () => {
  const db = fakeDb(newState('cus_a', 'user_a'));
  db.state.customerToUser['cus_b'] = 'user_b';
  db.state.profiles['user_b'] = { role: 'free', monthly_limit: 5 };
  const stripe = fakeStripe({ sub_a: makeSub({ id: 'sub_a', status: 'active' }) });
  const body = { id: 'evt_iso_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_a', subscription: 'sub_a' } } };
  await handler(await signedReq(body), stripe, db as never);
  assertEquals(db.state.profiles['user_a'].role, 'pro');
  assertEquals(db.state.profiles['user_b'].role, 'free'); // intocado
});

Deno.test('WEBHOOK-12: tipo de evento desconhecido -> 200, nenhuma alteração', async () => {
  const db = fakeDb(newState('cus_1', 'user_1'));
  const body = { id: 'evt_unhandled_1', type: 'invoice.payment_failed', data: { object: {} } };
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
  const body = { id: 'evt_getfail_1', type: 'customer.subscription.deleted', data: { object: { id: 'sub_6', customer: 'cus_6', status: 'canceled' } } };
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
    return Promise.resolve({ error: new Error('simulated db failure') });
  };
  const stripe = fakeStripe({ sub_7: makeSub({ id: 'sub_7', status: 'active' }) });
  const body = { id: 'evt_rpcfail_1', type: 'checkout.session.completed', data: { object: { customer: 'cus_7', subscription: 'sub_7' } } };
  const res = await handler(await signedReq(body), stripe, db as never);
  assertEquals(res.status, 500);
  assertEquals(rpcCalls, 1);
  assertEquals(db.state.processedEvents['evt_rpcfail_1'], undefined);
});
