/**
 * Testes de auth + cota para generate-campaign Edge Function —
 * IVE-COMMERCIAL-AUTH-01 / IVE-COMMERCIAL-ENTITLEMENTS-01.
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env supabase/functions/generate-campaign/index_test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { AuthClient } from '../_shared/auth.ts';
import { QuotaClient } from '../_shared/quota.ts';
import { failingSubjectSource, fakeSubjectSource, withSubject } from '../_shared/entitlement_test_support.ts';

let groqCalled = false;
let groqShouldFail = false;
let quotaRefundCalls = 0;
let quotaRpcOverride: { data: unknown; error: unknown } | null = null;
const fakeQuotaClient: QuotaClient = {
  // deno-lint-ignore require-await
  async rpc(fn: string) {
    if (fn === 'refund_ai_quota') { quotaRefundCalls++; return { data: null, error: null }; }
    if (quotaRpcOverride) return quotaRpcOverride;
    return { data: { allowed: true, used: 1, limit: 100, role: 'free' }, error: null };
  },
};

const originalFetch = globalThis.fetch;
globalThis.fetch = async (input: string | URL | Request): Promise<Response> => {
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
  if (url.includes('groq.com')) {
    groqCalled = true;
    if (groqShouldFail) return new Response('erro simulado', { status: 502 });
    return new Response(JSON.stringify({
      choices: [{ message: { content: '{"campaign_name":"c","tagline":"t","objective":"venda","duration_days":30,"channels":["Instagram"],"overview":"","target_cpa":"","expected_results":[],"calendar":[],"email_sequence":[],"key_messages":[],"success_metrics":[]}' } }],
    }), { status: 200 });
  }
  return originalFetch(input);
};

// DENO_TESTING deve estar definido antes desta linha para suprimir serve().
const { handler: moduleHandler } = await import('./index.ts');
// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — the handler now checks server-side
// entitlement; 'campaigns' is INTERNAL (admin-only) in the server policy, so the pre-existing
// success-path tests run as an admin; GC-ENT-* below cover the free-user denial.
const handler = withSubject(moduleHandler, 'admin');

const validUserClient: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      if (token === 'test-session-jwt') return { data: { user: { id: 'u1', email: 'u1@example.com' } }, error: null };
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

const BODY = { title: 'Produto Teste', objective: 'venda', duration_days: 7, channels: ['Instagram'] };

Deno.test('GC-1: sem Authorization -> 401, Groq nunca chamado', async () => {
  groqCalled = false;
  const res = await handler(req(BODY, {}), validUserClient, fakeQuotaClient);
  assertEquals(res.status, 401);
  assertEquals(groqCalled, false);
});

Deno.test('GC-2: Bearer bem-formado mas sem sessão real (ex: chave anon) -> 401, Groq nunca chamado', async () => {
  groqCalled = false;
  const res = await handler(req(BODY, { Authorization: 'Bearer anon-public-key' }), validUserClient, fakeQuotaClient);
  assertEquals(res.status, 401);
  assertEquals(groqCalled, false);
});

Deno.test('GC-3: usuário autenticado válido -> Groq é chamado, retorna 200', async () => {
  groqCalled = false;
  const res = await handler(req(BODY), validUserClient, fakeQuotaClient);
  assertEquals(res.status, 200);
  assertEquals(groqCalled, true);
  const data = await res.json();
  assertEquals(data.campaign_name, 'c');
});

Deno.test('GC-4: cota esgotada -> 429, Groq nunca chamado', async () => {
  groqCalled = false;
  quotaRpcOverride = { data: { allowed: false, reason: 'quota_exceeded', used: 5, limit: 5, role: 'free' }, error: null };
  try {
    const res = await handler(req(BODY), validUserClient, fakeQuotaClient);
    assertEquals(res.status, 429);
    assertEquals(groqCalled, false);
  } finally {
    quotaRpcOverride = null;
  }
});

Deno.test('GC-5: Groq falha depois da cota reservada -> devolve a unidade', async () => {
  groqShouldFail = true;
  quotaRefundCalls = 0;
  try {
    const res = await handler(req(BODY), validUserClient, fakeQuotaClient);
    assertEquals(res.status, 502);
    assertEquals(quotaRefundCalls, 1);
  } finally {
    groqShouldFail = false;
  }
});

// ── MODULE-FOUNDATION-AND-ENTITLEMENT-02 — server-side entitlement ──────

Deno.test('GC-ENT-1: free user calling the INTERNAL campaigns module directly -> 403 MODULE_NOT_AVAILABLE, no quota, no Groq', async () => {
  groqCalled = false;
  let quotaCalls = 0;
  const countingQuota: QuotaClient = {
    // deno-lint-ignore require-await
    async rpc() { quotaCalls++; return { data: { allowed: true, used: 1, limit: 100, role: 'free' }, error: null }; },
  };
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    const res = await moduleHandler(req({ ...BODY, plan: 'premium', role: 'admin' }), validUserClient, countingQuota, fakeSubjectSource(role));
    assertEquals(res.status, 403, role);
    assertEquals((await res.json()).error, 'MODULE_NOT_AVAILABLE');
  }
  assertEquals(quotaCalls, 0);
  assertEquals(groqCalled, false);
});

Deno.test('GC-ENT-2: entitlement source outage -> 503 ENTITLEMENT_UNAVAILABLE, fail closed, no Groq', async () => {
  groqCalled = false;
  const res = await moduleHandler(req(BODY), validUserClient, fakeQuotaClient, failingSubjectSource);
  assertEquals(res.status, 503);
  assertEquals((await res.json()).error, 'ENTITLEMENT_UNAVAILABLE');
  assertEquals(groqCalled, false);
});
