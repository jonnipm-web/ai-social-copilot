/**
 * IVE-COMMERCIAL-BILLING-01 — create-checkout-session tests. Proves auth
 * gate, that client-supplied billing fields are ignored (the function
 * never even parses the request body), and that a new vs. returning
 * customer both resolve to a checkout URL built from server-controlled
 * values only.
 *
 * Execução:
 *   DENO_TESTING=1 STRIPE_PRICE_ID_PRO=price_test deno test --allow-env supabase/functions/create-checkout-session/index_test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { AuthClient } from '../_shared/auth.ts';
import { StripeFetch } from '../_shared/stripe.ts';

Deno.env.set('STRIPE_PRICE_ID_PRO', 'price_test_pro_monthly');
Deno.env.set('STRIPE_SECRET_KEY', 'sk_test_unused_because_client_is_faked');

const { handler, DbClient } = await import('./index.ts') as unknown as {
  handler: typeof import('./index.ts').handler;
  DbClient: unknown;
};

const validUserClient: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      if (token === 'test-session-jwt') return { data: { user: { id: 'user-abc', email: 'u@example.com' } }, error: null };
      return { data: { user: null }, error: { message: 'invalid token' } };
    },
  },
};

function req(body: unknown, headers: Record<string, string> = { Authorization: 'Bearer test-session-jwt' }): Request {
  return new Request('http://localhost/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

function fakeStripe(): StripeFetch & { calls: Array<{ path: string; params?: Record<string, unknown> }> } {
  const calls: Array<{ path: string; params?: Record<string, unknown> }> = [];
  return Object.assign(
    // deno-lint-ignore require-await
    async (path: string, opts: { method: string; params?: Record<string, unknown> }) => {
      calls.push({ path, params: opts.params });
      if (path === '/customers') return { ok: true, status: 200, json: () => Promise.resolve({ id: 'cus_new_123' }) };
      if (path === '/checkout/sessions') {
        return { ok: true, status: 200, json: () => Promise.resolve({ id: 'cs_123', url: 'https://checkout.stripe.com/cs_123' }) };
      }
      return { ok: false, status: 404, json: () => Promise.resolve({}) };
    },
    { calls },
  );
}

function fakeDb(existingCustomerId: string | null) {
  const upsertCalls: Array<Record<string, unknown>> = [];
  return {
    upsertCalls,
    from(_table: string) {
      return {
        select() {
          return {
            eq() {
              return {
                maybeSingle: () => Promise.resolve({
                  data: existingCustomerId ? { stripe_customer_id: existingCustomerId } : null,
                  error: null,
                }),
              };
            },
          };
        },
        upsert(row: Record<string, unknown>) {
          upsertCalls.push(row);
          return Promise.resolve({ error: null });
        },
      };
    },
  };
}

Deno.test('CCS-1: sem Authorization -> 401', async () => {
  const res = await handler(req({}, {}), validUserClient, fakeStripe(), fakeDb(null) as never);
  assertEquals(res.status, 401);
});

Deno.test('CCS-2: Bearer bem-formado mas sem sessão real (ex: chave anon) -> 401', async () => {
  const res = await handler(req({}, { Authorization: 'Bearer anon-public-key' }), validUserClient, fakeStripe(), fakeDb(null) as never);
  assertEquals(res.status, 401);
});

Deno.test('CCS-3: usuário novo (sem customer ainda) -> cria customer e sessão, retorna url', async () => {
  const stripe = fakeStripe();
  const db = fakeDb(null);
  const res = await handler(req({}), validUserClient, stripe, db as never);
  assertEquals(res.status, 200);
  const data = await res.json();
  assertEquals(data.url, 'https://checkout.stripe.com/cs_123');
  assertEquals(db.upsertCalls.length, 1);
  assertEquals(db.upsertCalls[0].stripe_customer_id, 'cus_new_123');
});

Deno.test('CCS-4: usuário com customer existente -> reaproveita, não cria outro', async () => {
  const stripe = fakeStripe();
  const db = fakeDb('cus_existing_456');
  const res = await handler(req({}), validUserClient, stripe, db as never);
  assertEquals(res.status, 200);
  const customerCalls = stripe.calls.filter((c) => c.path === '/customers');
  assertEquals(customerCalls.length, 0); // não criou um novo customer
  const sessionCall = stripe.calls.find((c) => c.path === '/checkout/sessions');
  assertEquals(sessionCall?.params?.customer, 'cus_existing_456');
});

Deno.test('CCS-5: campos de billing forjados no corpo são ignorados (nunca lidos)', async () => {
  const stripe = fakeStripe();
  const db = fakeDb(null);
  const spoofedBody = {
    user_id: '00000000-0000-0000-0000-000000000000',
    role: 'admin',
    monthly_limit: 999999999,
    price_id: 'price_attacker_controlled_free_forever',
    amount: 0,
  };
  const res = await handler(req(spoofedBody), validUserClient, stripe, db as never);
  assertEquals(res.status, 200);
  const sessionCall = stripe.calls.find((c) => c.path === '/checkout/sessions');
  // sempre o preço do servidor, nunca o forjado
  assertEquals(sessionCall?.params?.['line_items[0][price]'], 'price_test_pro_monthly');
  // sempre o id do usuário resolvido pelo token, nunca o forjado
  assertEquals(sessionCall?.params?.client_reference_id, 'user-abc');
});
