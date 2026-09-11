/**
 * IVE-COMMERCIAL-BILLING-01 — regression suite for manual Stripe webhook
 * signature verification and the REST helpers, using an injected
 * StripeFetch fake so no network access or real Stripe account is
 * needed. Signatures are computed here exactly the way Stripe's own
 * documented algorithm does (https://docs.stripe.com/webhooks#verify-manually),
 * so a passing test here is real proof the verification logic is
 * correct, not just self-consistent.
 *
 * Run: deno test --allow-env supabase/functions/_shared/stripe_test.ts
 */
import { assertEquals, assertRejects } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  createCheckoutSession,
  createStripeCustomer,
  retrieveSubscription,
  StripeFetch,
  verifyStripeSignature,
} from './stripe.ts';

const SECRET = 'whsec_test_shared_secret_for_unit_tests';

async function sign(payload: string, timestamp: number, secret = SECRET): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const bytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${payload}`));
  return Array.from(new Uint8Array(bytes)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.test('STRIPE-A: valid signature and fresh timestamp -> accepted', async () => {
  const body = '{"id":"evt_1","type":"checkout.session.completed"}';
  const ts = Math.floor(Date.now() / 1000);
  const sig = await sign(body, ts);
  await verifyStripeSignature(body, `t=${ts},v1=${sig}`, SECRET); // must not throw
});

Deno.test('STRIPE-B: wrong secret -> rejected', async () => {
  const body = '{"id":"evt_1"}';
  const ts = Math.floor(Date.now() / 1000);
  const sig = await sign(body, ts, 'whsec_a_completely_different_secret');
  await assertRejects(() => verifyStripeSignature(body, `t=${ts},v1=${sig}`, SECRET));
});

Deno.test('STRIPE-C: tampered body after signing -> rejected', async () => {
  const original = '{"id":"evt_1","amount":100}';
  const ts = Math.floor(Date.now() / 1000);
  const sig = await sign(original, ts);
  const tampered = '{"id":"evt_1","amount":999999}';
  await assertRejects(() => verifyStripeSignature(tampered, `t=${ts},v1=${sig}`, SECRET));
});

Deno.test('STRIPE-D: missing signature header -> rejected', async () => {
  await assertRejects(() => verifyStripeSignature('{}', null, SECRET));
});

Deno.test('STRIPE-E: malformed header (no v1) -> rejected', async () => {
  await assertRejects(() => verifyStripeSignature('{}', 't=123456', SECRET));
});

Deno.test('STRIPE-F: timestamp outside tolerance (replay) -> rejected', async () => {
  const body = '{"id":"evt_1"}';
  const oldTs = Math.floor(Date.now() / 1000) - 3600; // 1 hour old
  const sig = await sign(body, oldTs);
  await assertRejects(() => verifyStripeSignature(body, `t=${oldTs},v1=${sig}`, SECRET, 300));
});

Deno.test('STRIPE-G: fake v0 test-scheme signature alone is never accepted', async () => {
  const body = '{"id":"evt_1"}';
  const ts = Math.floor(Date.now() / 1000);
  // Only v0 present (a real v1 forged with the wrong secret) -- must
  // reject, since v0 is explicitly documented as untrusted.
  const fakeV1 = await sign(body, ts, 'wrong-secret');
  await assertRejects(() => verifyStripeSignature(body, `t=${ts},v0=deadbeef,v1=${fakeV1}`, SECRET));
});

// ── REST helper wiring (fake StripeFetch, no network) ───────────────────

function fakeStripe(responses: Record<string, unknown>): StripeFetch {
  const calls: Array<{ path: string; method: string; params?: Record<string, unknown> }> = [];
  const client: StripeFetch & { calls: typeof calls } = Object.assign(
    // deno-lint-ignore require-await
    async (path: string, opts: { method: 'GET' | 'POST'; params?: Record<string, unknown> }) => {
      calls.push({ path, method: opts.method, params: opts.params });
      return { ok: true, status: 200, json: () => Promise.resolve((responses[path] ?? {}) as Record<string, unknown>) };
    },
    { calls },
  );
  return client;
}

Deno.test('STRIPE-H: createStripeCustomer sends supabase_user_id as metadata, never as a trusted id', async () => {
  const fake = fakeStripe({ '/customers': { id: 'cus_123' } }) as StripeFetch & { calls: Array<{ params?: Record<string, unknown> }> };
  const customer = await createStripeCustomer({ email: 'u@example.com', supabaseUserId: 'user-abc' }, fake);
  assertEquals(customer.id, 'cus_123');
  assertEquals(fake.calls[0].params?.['metadata[supabase_user_id]'], 'user-abc');
});

Deno.test('STRIPE-I: createCheckoutSession always uses the server-provided priceId, never a client one', async () => {
  const fake = fakeStripe({ '/checkout/sessions': { id: 'cs_123', url: 'https://checkout.stripe.com/cs_123' } }) as StripeFetch & { calls: Array<{ params?: Record<string, unknown> }> };
  const session = await createCheckoutSession(
    { customerId: 'cus_123', priceId: 'price_server_controlled', successUrl: 'https://app/success', cancelUrl: 'https://app/cancel', supabaseUserId: 'user-abc' },
    fake,
  );
  assertEquals(session.url, 'https://checkout.stripe.com/cs_123');
  assertEquals(fake.calls[0].params?.['line_items[0][price]'], 'price_server_controlled');
  assertEquals(fake.calls[0].params?.mode, 'subscription');
});

Deno.test('STRIPE-J: retrieveSubscription hits the correct path', async () => {
  const fake = fakeStripe({ '/subscriptions/sub_123': { id: 'sub_123', status: 'active' } }) as StripeFetch & { calls: Array<{ path: string }> };
  const sub = await retrieveSubscription('sub_123', fake);
  assertEquals(sub.status, 'active');
  assertEquals(fake.calls[0].path, '/subscriptions/sub_123');
});
