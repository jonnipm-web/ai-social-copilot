/**
 * Entitlement authority tests — INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02.
 *
 * Execução:
 *   deno test --allow-env supabase/functions/_shared/entitlement_test.ts
 */
import { assert, assertEquals, assertFalse } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  decideModuleAccess,
  type EntitlementSubject,
  type EntitlementSubjectSource,
  EntitlementSourceError,
  listModuleDecisions,
  mapLegacyProfileRole,
  requireModuleAccess,
  type Role,
  subjectFromPlanAndRoleRows,
} from './entitlement.ts';
import type { ModulePolicyDoc, Plan } from './module_policy.ts';

const POLICY: ModulePolicyDoc = {
  version: 1,
  modules: {
    'm-free': { lifecycle: 'COMMERCIAL', minimumPlan: 'free', actionClass: 'READ_ONLY' },
    'm-pro': { lifecycle: 'COMMERCIAL', minimumPlan: 'pro', actionClass: 'REVERSIBLE' },
    'm-premium': { lifecycle: 'COMMERCIAL', minimumPlan: 'premium', actionClass: 'REVERSIBLE' },
    'm-beta': { lifecycle: 'BETA', minimumPlan: 'free', actionClass: 'REVERSIBLE' },
    'm-beta-pro': { lifecycle: 'BETA', minimumPlan: 'pro', actionClass: 'REVERSIBLE' },
    'm-alpha': { lifecycle: 'ALPHA', minimumPlan: 'free', actionClass: 'REVERSIBLE' },
    'm-rc': { lifecycle: 'RELEASE_CANDIDATE', minimumPlan: 'free', actionClass: 'REVERSIBLE' },
    'm-internal': { lifecycle: 'INTERNAL', minimumPlan: 'free', actionClass: 'READ_ONLY' },
    'm-experimental': { lifecycle: 'EXPERIMENTAL', minimumPlan: 'free', actionClass: 'CONSEQUENTIAL' },
    'm-deprecated': { lifecycle: 'DEPRECATED', minimumPlan: 'free', actionClass: 'READ_ONLY' },
  },
  edgeFunctions: {},
};

function subject(plan: Plan | null, roles: Role[] = []): EntitlementSubject {
  return { type: 'user', id: 'u1', plan, roles: new Set(roles), source: 'legacy_profiles_role' };
}
function legacy(role: string): EntitlementSubject {
  const { plan, roles } = mapLegacyProfileRole(role);
  return { type: 'user', id: 'u1', plan, roles, source: 'legacy_profiles_role' };
}
const allow = (s: EntitlementSubject | null, m: string) => decideModuleAccess(s, m, POLICY).allowed;
const code = (s: EntitlementSubject | null, m: string) => decideModuleAccess(s, m, POLICY).code;

// ── Role ≠ plan (legacy mapping) ─────────────────────────────────────────

Deno.test('EN-01 legacy mapping: plans stay plans, admin/beta_tester become ROLES on the free plan', () => {
  assertEquals(mapLegacyProfileRole('free').plan, 'free');
  assertEquals(mapLegacyProfileRole('pro').plan, 'pro');
  assertEquals(mapLegacyProfileRole('premium').plan, 'premium');
  assertEquals(mapLegacyProfileRole('admin').plan, 'free');
  assert(mapLegacyProfileRole('admin').roles.has('admin'));
  assertEquals(mapLegacyProfileRole('beta_tester').plan, 'free');
  assert(mapLegacyProfileRole('beta_tester').roles.has('beta_tester'));
  for (const r of ['free', 'pro', 'premium']) assertEquals(mapLegacyProfileRole(r).roles.size, 0);
});

Deno.test('EN-02 unknown/garbage legacy role → plan null (fail closed), never a guessed plan', () => {
  for (const r of ['PREMIUM', 'enterprise', '', null, undefined, 42, { plan: 'premium' }]) {
    const m = mapLegacyProfileRole(r);
    assertEquals(m.plan, null, `role=${JSON.stringify(r)}`);
    assertEquals(m.roles.size, 0);
  }
});

// ── Plan matrix on COMMERCIAL modules ────────────────────────────────────

Deno.test('EN-03 FREE: free module allowed, pro/premium → PLAN_REQUIRED with required_plan', () => {
  assert(allow(legacy('free'), 'm-free'));
  assertEquals(code(legacy('free'), 'm-pro'), 'PLAN_REQUIRED');
  assertEquals(decideModuleAccess(legacy('free'), 'm-pro', POLICY).requiredPlan, 'pro');
  assertEquals(code(legacy('free'), 'm-premium'), 'PLAN_REQUIRED');
});

Deno.test('EN-04 PRO: free+pro allowed, premium denied', () => {
  assert(allow(legacy('pro'), 'm-free'));
  assert(allow(legacy('pro'), 'm-pro'));
  assertEquals(code(legacy('pro'), 'm-premium'), 'PLAN_REQUIRED');
});

Deno.test('EN-05 PREMIUM: every commercial tier allowed', () => {
  for (const m of ['m-free', 'm-pro', 'm-premium']) assert(allow(legacy('premium'), m), m);
});

// ── Roles ────────────────────────────────────────────────────────────────

Deno.test('EN-06 ADMIN role reaches every non-deprecated module (legacy parity), reason ADMIN_ROLE', () => {
  for (const m of ['m-free', 'm-premium', 'm-beta', 'm-alpha', 'm-rc', 'm-internal', 'm-experimental']) {
    const d = decideModuleAccess(legacy('admin'), m, POLICY);
    assert(d.allowed, m);
    assertEquals(d.reason, 'ADMIN_ROLE');
  }
  assertEquals(code(legacy('admin'), 'm-deprecated'), 'MODULE_DISABLED');
  assertEquals(code(legacy('admin'), 'no-such-module'), 'MODULE_NOT_AVAILABLE');
});

Deno.test('EN-07 BETA role: ALPHA/BETA/RC reachable on its own plan; NOT premium, NOT internal', () => {
  const b = legacy('beta_tester');
  assert(allow(b, 'm-beta'));
  assert(allow(b, 'm-alpha'));
  assert(allow(b, 'm-rc'));
  assertEquals(decideModuleAccess(b, 'm-beta', POLICY).reason, 'BETA_ENTITLED');
  assertEquals(code(b, 'm-beta-pro'), 'PLAN_REQUIRED', 'beta_tester is not an implicit pro');
  assertEquals(code(b, 'm-premium'), 'PLAN_REQUIRED', 'beta_tester is not an implicit premium');
  assertEquals(code(b, 'm-internal'), 'MODULE_NOT_AVAILABLE');
  assertEquals(code(b, 'm-experimental'), 'MODULE_NOT_AVAILABLE');
});

Deno.test('EN-08 beta/alpha/RC modules denied to non-beta users of ANY plan', () => {
  for (const r of ['free', 'pro', 'premium']) {
    for (const m of ['m-beta', 'm-alpha', 'm-rc']) assertEquals(code(legacy(r), m), 'MODULE_NOT_AVAILABLE', `${r}/${m}`);
  }
});

Deno.test('EN-09 INTERNAL/EXPERIMENTAL denied to every non-admin plan (premium does not unlock unreleased)', () => {
  for (const r of ['free', 'pro', 'premium', 'beta_tester']) {
    assertEquals(code(legacy(r), 'm-internal'), 'MODULE_NOT_AVAILABLE', r);
    assertEquals(code(legacy(r), 'm-experimental'), 'MODULE_NOT_AVAILABLE', r);
  }
});

// ── Default deny ─────────────────────────────────────────────────────────

Deno.test('EN-10 unauthenticated → AUTH_REQUIRED on every module', () => {
  for (const m of Object.keys(POLICY.modules)) assertEquals(code(null, m), 'AUTH_REQUIRED');
  assertEquals(code({ ...subject('premium'), id: '' }, 'm-free'), 'AUTH_REQUIRED');
});

Deno.test('EN-11 unknown module → MODULE_NOT_AVAILABLE, including prototype keys', () => {
  for (const m of ['nope', '', '__proto__', 'constructor', 'toString', 'M-FREE', 'm-free ']) {
    assertEquals(code(legacy('premium'), m), 'MODULE_NOT_AVAILABLE', JSON.stringify(m));
  }
});

Deno.test('EN-12 unknown plan → ENTITLEMENT_UNAVAILABLE even on a free module', () => {
  assertEquals(code(subject(null), 'm-free'), 'ENTITLEMENT_UNAVAILABLE');
  // deno-lint-ignore no-explicit-any
  assertEquals(code(subject('enterprise' as any), 'm-free'), 'ENTITLEMENT_UNAVAILABLE');
});

Deno.test('EN-13 deprecated module → MODULE_DISABLED for everyone', () => {
  for (const r of ['free', 'pro', 'premium', 'beta_tester', 'admin']) assertEquals(code(legacy(r), 'm-deprecated'), 'MODULE_DISABLED');
});

Deno.test('EN-14 corrupted policy value (minimumPlan not a plan) fails closed', () => {
  // deno-lint-ignore no-explicit-any
  const bad: ModulePolicyDoc = { version: 1, modules: { x: { lifecycle: 'COMMERCIAL', minimumPlan: 'gold' as any, actionClass: 'READ_ONLY' } }, edgeFunctions: {} };
  assertFalse(decideModuleAccess(legacy('premium'), 'x', bad).allowed);
  // deno-lint-ignore no-explicit-any
  const badLifecycle: ModulePolicyDoc = { version: 1, modules: { x: { lifecycle: 'GA' as any, minimumPlan: 'free', actionClass: 'READ_ONLY' } }, edgeFunctions: {} };
  assertFalse(decideModuleAccess(legacy('premium'), 'x', badLifecycle).allowed);
});

Deno.test('EN-15 determinism: identical inputs give identical decisions', () => {
  for (const r of ['free', 'pro', 'premium', 'beta_tester', 'admin', 'weird']) {
    for (const m of Object.keys(POLICY.modules)) {
      assertEquals(decideModuleAccess(legacy(r), m, POLICY), decideModuleAccess(legacy(r), m, POLICY));
    }
  }
});

Deno.test('EN-16 listModuleDecisions covers every module exactly once, sorted', () => {
  const ds = listModuleDecisions(legacy('free'), POLICY);
  assertEquals(ds.map((d) => d.moduleId), Object.keys(POLICY.modules).sort());
});

// ── requireModuleAccess (gate wiring, adversarial) ───────────────────────

const USER = { id: 'u1' };
const CORS = { 'Access-Control-Allow-Origin': '*' };

function fakeSource(role: unknown): EntitlementSubjectSource & { calls: string[] } {
  const calls: string[] = [];
  return {
    calls,
    // deno-lint-ignore require-await
    async resolveUserSubject(userId: string, token: string) {
      calls.push(`${userId}:${token}`);
      const { plan, roles } = mapLegacyProfileRole(role);
      return { type: 'user', id: userId, plan, roles, source: 'legacy_profiles_role' };
    },
  };
}

function reqWith(headers: Record<string, string> = {}, body: unknown = {}): Request {
  return new Request('http://localhost/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer user-jwt', ...headers },
    body: JSON.stringify(body),
  });
}

Deno.test('EN-20 real registry: free user allowed on a COMMERCIAL free module', async () => {
  const r = await requireModuleAccess(reqWith(), USER, 'knowledge-vault', CORS, fakeSource('free'));
  assert(r.allowed);
});

Deno.test('EN-21 forged client state: body plan=premium / role=admin and forged headers are ignored', async () => {
  const forged = reqWith(
    { 'x-plan': 'premium', 'x-role': 'admin', 'x-user-role': 'admin' },
    { plan: 'premium', role: 'admin', is_admin: true, module_id: 'knowledge-vault', entitlements: ['*'] },
  );
  const r = await requireModuleAccess(forged, USER, 'campaigns', CORS, fakeSource('free'));
  assertFalse(r.allowed);
  if (!r.allowed) {
    assertEquals(r.response.status, 403);
    const body = await r.response.json();
    assertEquals(body.error, 'MODULE_NOT_AVAILABLE');
    assertEquals(body.module_id, 'campaigns');
    assertEquals(body.lifecycle, undefined, 'internal lifecycle must not leak');
    assertEquals(body.reason, undefined, 'internal reason must not leak');
  }
});

Deno.test('EN-22 the subject id comes from the AUTHENTICATED user, never from the request', async () => {
  const src = fakeSource('free');
  await requireModuleAccess(reqWith({}, { user_id: 'victim' }), USER, 'knowledge-vault', CORS, src);
  assertEquals(src.calls, ['u1:user-jwt']);
});

Deno.test('EN-23 no authenticated user / missing bearer → 401 AUTH_REQUIRED, source never called', async () => {
  const src = fakeSource('premium');
  const r1 = await requireModuleAccess(reqWith(), null, 'knowledge-vault', CORS, src);
  assertFalse(r1.allowed);
  if (!r1.allowed) assertEquals(r1.response.status, 401);
  const noBearer = new Request('http://localhost/', { method: 'POST' });
  const r2 = await requireModuleAccess(noBearer, USER, 'knowledge-vault', CORS, src);
  assertFalse(r2.allowed);
  if (!r2.allowed) assertEquals((await r2.response.json()).error, 'AUTH_REQUIRED');
  assertEquals(src.calls.length, 0);
});

Deno.test('EN-24 server entitlement unavailable (source throws) → 503 ENTITLEMENT_UNAVAILABLE, fail closed', async () => {
  const throwing: EntitlementSubjectSource = {
    // deno-lint-ignore require-await
    async resolveUserSubject() { throw new EntitlementSourceError('db down'); },
  };
  const r = await requireModuleAccess(reqWith(), USER, 'knowledge-vault', CORS, throwing);
  assertFalse(r.allowed);
  if (!r.allowed) {
    assertEquals(r.response.status, 503);
    assertEquals((await r.response.json()).error, 'ENTITLEMENT_UNAVAILABLE');
  }
  const nonError: EntitlementSubjectSource = {
    // deno-lint-ignore require-await
    async resolveUserSubject() { throw 'string thrown'; },
  };
  assertFalse((await requireModuleAccess(reqWith(), USER, 'knowledge-vault', CORS, nonError)).allowed);
});

Deno.test('EN-25 client alters module id to an unknown one → denied, not allowed-by-default', async () => {
  const r = await requireModuleAccess(reqWith(), USER, 'knowledge-vault-premium', CORS, fakeSource('premium'));
  assertFalse(r.allowed);
});

Deno.test('EN-26 client tries beta/admin-only real modules as free/pro/premium → denied', async () => {
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    for (const m of ['admin-panel', 'intelligence-debug', 'decision-simulator', 'ive-quant', 'campaigns', 'improve-post']) {
      const r = await requireModuleAccess(reqWith(), USER, m, CORS, fakeSource(role));
      assertFalse(r.allowed, `${role}/${m}`);
    }
  }
});

Deno.test('EN-27 correlation id: valid header echoed, invalid/injected replaced', async () => {
  const ok = await requireModuleAccess(reqWith({ 'x-correlation-id': 'abc12345-ok' }), USER, 'campaigns', CORS, fakeSource('free'));
  if (!ok.allowed) assertEquals((await ok.response.json()).correlation_id, 'abc12345-ok');
  const bad = await requireModuleAccess(reqWith({ 'x-correlation-id': 'x"},{"allowed":true' }), USER, 'campaigns', CORS, fakeSource('free'));
  if (!bad.allowed) {
    const id = (await bad.response.json()).correlation_id as string;
    assert(/^[0-9a-f-]{36}$/.test(id), id);
  }
});

Deno.test('EN-28 entitlement is not quota: an allowed decision says nothing about usage limits', async () => {
  const r = await requireModuleAccess(reqWith(), USER, 'knowledge-vault', CORS, fakeSource('free'));
  assert(r.allowed);
  // The result carries no quota fields; quota stays in _shared/quota.ts.
  for (const k of ['used', 'limit', 'remaining', 'quota']) assertEquals((r as unknown as Record<string, unknown>)[k], undefined);
});

// ── Codex Gate 1 remediation: subject binding (CX1-04) ───────────────────

function returning(subject: unknown): EntitlementSubjectSource {
  // deno-lint-ignore require-await
  return { async resolveUserSubject() { return subject as EntitlementSubject; } };
}

Deno.test('EN-30 a source returning ANOTHER principal is rejected (fail closed, 503)', async () => {
  const other = { type: 'user', id: 'someone-else', plan: 'premium', roles: new Set(['admin']), source: 'legacy_profiles_role' };
  const r = await requireModuleAccess(reqWith(), USER, 'knowledge-vault', CORS, returning(other));
  assertFalse(r.allowed);
  if (!r.allowed) assertEquals(r.response.status, 503);
});

Deno.test('EN-31 non-user subject types, unknown sources, bad plans or roles are rejected', async () => {
  const base = { type: 'user', id: 'u1', plan: 'free', roles: new Set<string>(), source: 'legacy_profiles_role' };
  const bad: unknown[] = [
    { ...base, type: 'organization' },
    { ...base, type: 'workspace' },
    { ...base, source: 'client_claim' },
    { ...base, plan: 'enterprise' },
    { ...base, plan: undefined },
    { ...base, roles: new Set(['superuser']) },
    { ...base, roles: ['admin'] },
    null,
    'u1',
  ];
  for (const s of bad) {
    const r = await requireModuleAccess(reqWith(), USER, 'knowledge-vault', CORS, returning(s));
    assertFalse(r.allowed, JSON.stringify(s, (_k, v) => (v instanceof Set ? [...v] : v)));
  }
  assert((await requireModuleAccess(reqWith(), USER, 'knowledge-vault', CORS, returning(base))).allowed);
});

// ── Role ≠ plan storage (subject_roles) ──────────────────────────────────

Deno.test('EN-32 paid beta tester: plan from profiles.role, beta role from subject_roles (CX1-02)', () => {
  const s = subjectFromPlanAndRoleRows('u1', 'pro', [{ role: 'beta_tester' }]);
  assertEquals(s.plan, 'pro');
  assert(s.roles.has('beta_tester'));
  assert(decideModuleAccess(s, 'm-beta-pro', POLICY).allowed, 'paid beta tester reaches a pro beta module');
});

Deno.test('EN-33 admin keeps the admin ROLE when billing rewrites profiles.role to a plan', () => {
  const s = subjectFromPlanAndRoleRows('u1', 'free', [{ role: 'admin' }]);
  assertEquals(s.plan, 'free');
  assert(decideModuleAccess(s, 'm-internal', POLICY).allowed);
});

Deno.test('EN-34 unknown role rows are ignored, never promoted; legacy role still honoured (union)', () => {
  const s = subjectFromPlanAndRoleRows('u1', 'beta_tester', [{ role: 'superadmin' }, { role: 42 }, {}]);
  assertEquals([...s.roles], ['beta_tester']);
  assertEquals(s.plan, 'free');
  assertEquals(subjectFromPlanAndRoleRows('u1', 'garbage', [{ role: 'admin' }]).plan, null, 'unknown plan stays unknown');
});

Deno.test('EN-35 audit log never carries the raw user id, the token or the body', async () => {
  const lines: string[] = [];
  const orig = console.log;
  console.log = (...a: unknown[]) => { lines.push(a.map(String).join(' ')); };
  try {
    await requireModuleAccess(
      reqWith({}, { prompt: 'secret business plan', email: 'a@b.c' }),
      { id: '11111111-2222-3333-4444-555555555555' },
      'campaigns',
      CORS,
      fakeSource('free'),
    );
  } finally {
    console.log = orig;
  }
  assertEquals(lines.length, 1);
  const line = lines[0];
  for (const leak of ['11111111-2222-3333-4444-555555555555', 'user-jwt', 'secret business plan', 'a@b.c']) {
    assertFalse(line.includes(leak), `log leaked ${leak}`);
  }
  assert(/"subject_ref":"[0-9a-f]{16}"/.test(line));
});
