/**
 * module-access tests — INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02.
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env supabase/functions/module-access/index_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { AuthClient } from '../_shared/auth.ts';
import { type EntitlementSubjectSource, mapLegacyProfileRole } from '../_shared/entitlement.ts';
import { MODULE_POLICY } from '../_shared/module_policy.ts';

const { handler } = await import('./index.ts');

const auth: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      if (token === 'good') return { data: { user: { id: 'u1' } }, error: null };
      return { data: { user: null }, error: { message: 'bad' } };
    },
  },
};
const source = (role: unknown): EntitlementSubjectSource => ({
  // deno-lint-ignore require-await
  async resolveUserSubject(id: string) {
    const { plan, roles } = mapLegacyProfileRole(role);
    return { type: 'user', id, plan, roles, source: 'legacy_profiles_role' };
  },
});
const req = (token?: string, body: unknown = {}) =>
  new Request('http://localhost/', {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: JSON.stringify(body),
  });

Deno.test('MA-1 no/invalid session → 401, source never consulted', async () => {
  let called = false;
  const spy: EntitlementSubjectSource = {
    // deno-lint-ignore require-await
    async resolveUserSubject() { called = true; throw new Error('x'); },
  };
  assertEquals((await handler(req(), auth, spy)).status, 401);
  assertEquals((await handler(req('anon-key'), auth, spy)).status, 401);
  assertEquals(called, false);
});

Deno.test('MA-2 free user: every module listed once; released free modules allowed, unreleased denied', async () => {
  const res = await handler(req('good'), auth, source('free'));
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.subject, { type: 'user', plan: 'free', roles: [] });
  const byId = new Map((body.modules as { module_id: string; allowed: boolean; code?: string }[]).map((m) => [m.module_id, m]));
  assertEquals(byId.size, Object.keys(MODULE_POLICY.modules).length);
  assert(byId.get('knowledge-vault')!.allowed);
  assertEquals(byId.get('campaigns')!.allowed, false);
  assertEquals(byId.get('campaigns')!.code, 'MODULE_NOT_AVAILABLE');
  assertEquals((byId.get('campaigns') as Record<string, unknown>).lifecycle, undefined, 'lifecycle must not leak');
});

Deno.test('MA-3 forged body (plan/role/modules) is ignored', async () => {
  const res = await handler(req('good', { plan: 'premium', role: 'admin', roles: ['admin'] }), auth, source('free'));
  const body = await res.json();
  assertEquals(body.subject.plan, 'free');
  assertEquals(body.subject.roles, []);
  assertEquals(body.modules.find((m: { module_id: string }) => m.module_id === 'admin-panel').allowed, false);
});

Deno.test('MA-4 admin role is reported as a role, not a plan', async () => {
  const body = await (await handler(req('good'), auth, source('admin'))).json();
  assertEquals(body.subject, { type: 'user', plan: 'free', roles: ['admin'] });
});

Deno.test('MA-5 entitlement source failure → 503 ENTITLEMENT_UNAVAILABLE, no module list', async () => {
  const failing: EntitlementSubjectSource = {
    // deno-lint-ignore require-await
    async resolveUserSubject() { throw new Error('db down'); },
  };
  const res = await handler(req('good'), auth, failing);
  assertEquals(res.status, 503);
  const body = await res.json();
  assertEquals(body.error, 'ENTITLEMENT_UNAVAILABLE');
  assertEquals(body.modules, undefined);
});
