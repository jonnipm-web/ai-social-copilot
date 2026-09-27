/**
 * strategy-builder API tests — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05.
 * Real handler + an in-memory store that mimics RLS (rows keyed by owner).
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env --allow-read --allow-net=deno.land,esm.sh supabase/functions/strategy-builder/index_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { AuthClient } from '../_shared/auth.ts';
import { fakeSubjectSource } from '../_shared/entitlement_test_support.ts';
import type { StrategyRow, StrategyStore, StrategyVersionRow } from '../_shared/strategy_server.ts';
import type { StrategySpecification } from '../_shared/strategy/strategy_spec.ts';
import { V10_REFERENCE_SPEC_INPUT } from '../_shared/strategy/v10_reference.ts';
import { handler, type StrategyBuilderDeps } from './index.ts';

globalThis.fetch = () => Promise.reject(new Error('network is forbidden in strategy-builder tests'));

const A = 'aaaaaaaa-0000-4000-8000-00000000000a';
const B = 'aaaaaaaa-0000-4000-8000-00000000000b';
const auth: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      const id = token === 'jwt-a' ? A : token === 'jwt-b' ? B : null;
      return id ? { data: { user: { id } }, error: null } : { data: { user: null }, error: { message: 'invalid' } };
    },
  },
};

class MemoryStore implements StrategyStore {
  strategies: (StrategyRow & { userId: string })[] = [];
  versions: (StrategyVersionRow & { userId: string })[] = [];
  private n = 0;
  private id() {
    return `cccccccc-0000-4000-8000-${String(++this.n).padStart(12, '0')}`;
  }
  // deno-lint-ignore require-await
  async list(u: string) {
    return this.strategies.filter((s) => s.userId === u).map(({ userId: _u, ...s }) => s);
  }
  // deno-lint-ignore require-await
  async create(u: string, spec: StrategySpecification) {
    const strategy: StrategyRow & { userId: string } = {
      id: this.id(), userId: u, name: spec.name, status: 'DRAFT', currentVersion: 1, createdAt: 't', updatedAt: 't',
    };
    this.strategies.push(strategy);
    const version: StrategyVersionRow & { userId: string } = {
      id: this.id(), userId: u, strategyId: strategy.id, versionNumber: 1, spec, specHash: 'h', createdAt: 't',
    };
    this.versions.push(version);
    const { userId: _u1, ...s } = strategy;
    const { userId: _u2, ...v } = version;
    return { strategy: s, version: v };
  }
  // deno-lint-ignore require-await
  async getWithLatestVersion(u: string, strategyId: string) {
    const s = this.strategies.find((x) => x.id === strategyId && x.userId === u);
    if (!s) return null;
    const v = this.versions.find((x) => x.strategyId === strategyId && x.userId === u);
    if (!v) return null;
    const { userId: _u1, ...strategy } = s;
    const { userId: _u2, ...version } = v;
    return { strategy, version };
  }
}

let store = new MemoryStore();
const logs: string[] = [];
const deps = (): StrategyBuilderDeps => ({ storeFor: () => store, log: (l) => logs.push(l) });

async function call(payload: Record<string, unknown>, token: string | null = 'jwt-a', role = 'admin') {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await handler(
    new Request('http://localhost/', { method: 'POST', headers, body: JSON.stringify(payload) }),
    auth, undefined, fakeSubjectSource(role), deps(),
  );
  return { status: res.status, json: await res.json() };
}

Deno.test('SB-01 validate returns valid:true for the V10 reference spec', async () => {
  const r = await call({ op: 'validate', spec: V10_REFERENCE_SPEC_INPUT });
  assertEquals(r.status, 200);
  assertEquals(r.json.valid, true);
});

Deno.test('SB-02 validate returns valid:false with a structured error for a bad spec, never a 500', async () => {
  const r = await call({ op: 'validate', spec: { ...V10_REFERENCE_SPEC_INPUT, stop: { ruleId: 'STOP.FIXED_DISTANCE', distance: -1 } } });
  assertEquals(r.status, 200);
  assertEquals(r.json.valid, false);
  assertEquals(r.json.error.code, 'INVALID_RISK_PARAMETER');
});

Deno.test('SB-03 create persists a DRAFT strategy + version 1, owned by the caller', async () => {
  store = new MemoryStore();
  const r = await call({ op: 'create', spec: V10_REFERENCE_SPEC_INPUT });
  assertEquals(r.status, 200);
  assertEquals(r.json.strategy.status, 'DRAFT');
  assertEquals(r.json.version.versionNumber, 1);
  assert(store.strategies.every((s) => s.userId === A));
});

Deno.test('SB-04 create with an invalid spec never reaches the store', async () => {
  store = new MemoryStore();
  const r = await call({ op: 'create', spec: { ...V10_REFERENCE_SPEC_INPUT, positionSize: { ruleId: 'POSITION_SIZE.FIXED_CONTRACTS', quantity: 0 } } });
  assertEquals(r.status, 400);
  assertEquals(store.strategies.length, 0);
});

Deno.test('SB-05 draft_from_text never persists anything and always requires human review', async () => {
  store = new MemoryStore();
  const r = await call({ op: 'draft_from_text', text: 'stop 100, target 250, 5min, pullback, both directions' });
  assertEquals(r.status, 200);
  assertEquals(r.json.draft.requiresHumanReview, true);
  assertEquals(r.json.draft.extracted.stopDistance, 100);
  assertEquals(store.strategies.length, 0);
});

Deno.test('SB-06 another user cannot list or get a foreign strategy', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: V10_REFERENCE_SPEC_INPUT });
  const strategyId = created.json.strategy.id;
  const foreignList = await call({ op: 'list' }, 'jwt-b');
  assertEquals(foreignList.json.strategies, []);
  const foreignGet = await call({ op: 'get', strategyId }, 'jwt-b');
  assertEquals(foreignGet.status, 404);
});

Deno.test('SB-07 anonymous, forged token and non-admin plans are denied before the store is touched', async () => {
  store = new MemoryStore();
  assertEquals((await call({ op: 'list' }, null)).status, 401);
  assertEquals((await call({ op: 'list' }, 'forged')).status, 401);
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    const r = await call({ op: 'create', spec: V10_REFERENCE_SPEC_INPUT }, 'jwt-a', role);
    assertEquals([r.status, r.json.error], [403, 'MODULE_NOT_AVAILABLE'], role);
  }
  assertEquals(store.strategies.length, 0);
});

Deno.test('SB-08 an unknown op / malformed body is a structured 400, never a 500', async () => {
  const r1 = await call({ op: 'not_a_real_op' });
  assertEquals(r1.status, 400);
  const r2 = await call({ op: 'get', strategyId: 'not-a-uuid' });
  assertEquals(r2.status, 400);
});
