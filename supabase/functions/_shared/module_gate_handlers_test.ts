/**
 * EXECUTED entitlement gate tests for EVERY MODULE-kind Edge Function —
 * INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02 (Codex Gate 1 CX1-05:
 * the static MP-06 tripwire is not proof on its own).
 *
 * Each real handler is imported and called. For every denial path we assert
 * the response AND that nothing downstream ran: no quota RPC, no outbound
 * fetch (AI provider / database), no body-dependent work.
 *
 * Execução:
 *   DENO_TESTING=1 GROQ_API_KEY=test deno test --allow-env --allow-read supabase/functions/_shared/module_gate_handlers_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { AuthClient } from './auth.ts';
import type { QuotaClient } from './quota.ts';
import { failingSubjectSource, fakeSubjectSource } from './entitlement_test_support.ts';
import { MODULE_POLICY } from './module_policy.ts';

let fetchCalls: string[] = [];
globalThis.fetch = (input: string | URL | Request): Promise<Response> => {
  fetchCalls.push(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
  return Promise.resolve(new Response('blocked by test', { status: 599 }));
};

let quotaCalls = 0;
const quota: QuotaClient = {
  // deno-lint-ignore require-await
  async rpc() {
    quotaCalls++;
    return { data: { allowed: true, used: 1, limit: 100, role: 'free' }, error: null };
  },
};
const auth: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      if (token === 'session-jwt') return { data: { user: { id: 'u-gate' } }, error: null };
      return { data: { user: null }, error: { message: 'invalid' } };
    },
  },
};

type Handler = (req: Request, a?: AuthClient, q?: QuotaClient, s?: unknown) => Promise<Response>;

const moduleFunctions = Object.entries(MODULE_POLICY.edgeFunctions)
  .filter(([, p]) => p.kind === 'MODULE')
  .map(([fn, p]) => ({ fn, moduleId: p.moduleId!, lifecycle: MODULE_POLICY.modules[p.moduleId!].lifecycle }));

const handlers = new Map<string, Handler>();
for (const { fn } of moduleFunctions) {
  const mod = await import(`../${fn}/index.ts`);
  assert(typeof mod.handler === 'function', `${fn} must export handler`);
  handlers.set(fn, mod.handler as Handler);
}

function req(token: string | null, body: unknown = { plan: 'premium', role: 'admin', module_id: 'knowledge-vault' }): Request {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return new Request('http://localhost/', { method: 'POST', headers, body: JSON.stringify(body) });
}

function reset() {
  fetchCalls = [];
  quotaCalls = 0;
}

Deno.test('GH-00 every MODULE-kind function (19) exports an injectable handler', () => {
  assertEquals(handlers.size, moduleFunctions.length);
  // 17 + quant-analyze + quant-watchlists (IV-QUANT-DATA-PLANE-AND-API-02).
  assertEquals(moduleFunctions.length, 19);
});

for (const { fn, moduleId, lifecycle } of moduleFunctions) {
  Deno.test(`GH ${fn}: no session → 401 before entitlement, nothing downstream`, async () => {
    reset();
    const src = fakeSubjectSource('premium');
    const res = await handlers.get(fn)!(req(null), auth, quota, src);
    assertEquals(res.status, 401);
    assertEquals(src.calls, 0);
    assertEquals(quotaCalls, 0);
    assertEquals(fetchCalls, []);
  });

  Deno.test(`GH ${fn}: anon/invalid token → 401, nothing downstream`, async () => {
    reset();
    const res = await handlers.get(fn)!(req('anon-public-key'), auth, quota, fakeSubjectSource('premium'));
    assertEquals(res.status, 401);
    assertEquals(quotaCalls, 0);
    assertEquals(fetchCalls, []);
  });

  Deno.test(`GH ${fn}: entitlement source outage → 503 ENTITLEMENT_UNAVAILABLE, fail closed`, async () => {
    reset();
    const res = await handlers.get(fn)!(req('session-jwt'), auth, quota, failingSubjectSource);
    assertEquals(res.status, 503);
    assertEquals((await res.json()).error, 'ENTITLEMENT_UNAVAILABLE');
    assertEquals(quotaCalls, 0);
    assertEquals(fetchCalls, []);
  });

  Deno.test(`GH ${fn}: unknown legacy plan → 503, never a guessed plan`, async () => {
    reset();
    const res = await handlers.get(fn)!(req('session-jwt'), auth, quota, fakeSubjectSource('enterprise'));
    assertEquals(res.status, 503);
    assertEquals(quotaCalls, 0);
    assertEquals(fetchCalls, []);
  });

  if (lifecycle !== 'COMMERCIAL') {
    Deno.test(`GH ${fn}: '${moduleId}' is ${lifecycle} → every non-admin plan gets 403 MODULE_NOT_AVAILABLE (forged body ignored)`, async () => {
      for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
        reset();
        const res = await handlers.get(fn)!(req('session-jwt'), auth, quota, fakeSubjectSource(role));
        assertEquals(res.status, 403, role);
        const body = await res.json();
        assertEquals(body.error, 'MODULE_NOT_AVAILABLE');
        assertEquals(body.module_id, moduleId);
        assertEquals(quotaCalls, 0, role);
        assertEquals(fetchCalls, [], role);
      }
    });
  } else {
    Deno.test(`GH ${fn}: '${moduleId}' is COMMERCIAL/free → a free user passes the gate (legacy behavior preserved)`, async () => {
      reset();
      const src = fakeSubjectSource('free');
      const res = await handlers.get(fn)!(req('session-jwt', {}), auth, quota, src);
      // Codex Final CXF-06 — prove the gate actually ran (a removed gate
      // would leave the source unconsulted), not just that nothing denied.
      assertEquals(src.calls, 1, `${fn} must consult the entitlement source exactly once`);
      const body = await res.clone().json().catch(() => ({}));
      assert(![401, 403, 503].includes(res.status) || !['AUTH_REQUIRED', 'MODULE_NOT_AVAILABLE', 'MODULE_DISABLED', 'PLAN_REQUIRED', 'ENTITLEMENT_UNAVAILABLE'].includes(body.error),
        `${fn} was blocked by entitlement: ${res.status} ${JSON.stringify(body)}`);
    });
  }
}
