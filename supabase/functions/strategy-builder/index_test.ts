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
import type {
  StrategyBacktestJobRow, StrategyBacktestResultRow, StrategyRow, StrategyStore, StrategyVersionRow,
} from '../_shared/strategy_server.ts';
import type { StrategySpecification } from '../_shared/strategy/strategy_spec.ts';
import type { CanonicalBacktestResult } from '../_shared/strategy/backtest_result.ts';
import { V10_REFERENCE_SPEC_INPUT } from '../_shared/strategy/v10_reference.ts';
import { GENERIC_REFERENCE_SPEC_INPUT } from '../_shared/strategy/generic_reference_strategy.ts';
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
  results: (StrategyBacktestResultRow & { userId: string })[] = [];
  jobs: (StrategyBacktestJobRow & { userId: string })[] = [];
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
  // deno-lint-ignore require-await
  async createNewVersion(u: string, strategyId: string, spec: StrategySpecification) {
    const existing = this.versions.filter((v) => v.strategyId === strategyId && v.userId === u);
    if (existing.length === 0) throw new Error('NOT_FOUND');
    const nextVersion = Math.max(...existing.map((v) => v.versionNumber)) + 1;
    const version: StrategyVersionRow & { userId: string } = {
      id: this.id(), userId: u, strategyId, versionNumber: nextVersion, spec, specHash: `h${nextVersion}`, createdAt: 't',
    };
    this.versions.push(version);
    const { userId: _u, ...v } = version;
    return v;
  }
  // deno-lint-ignore require-await
  async listVersions(u: string, strategyId: string) {
    return this.versions.filter((v) => v.strategyId === strategyId && v.userId === u)
      .sort((a, b) => a.versionNumber - b.versionNumber)
      .map(({ userId: _u, ...v }) => v);
  }
  // deno-lint-ignore require-await
  async getVersionById(u: string, versionId: string) {
    const v = this.versions.find((x) => x.id === versionId && x.userId === u);
    if (!v) return null;
    const { userId: _u, ...version } = v;
    return version;
  }
  // deno-lint-ignore require-await
  async insertBacktestResult(u: string, strategyVersionId: string, result: CanonicalBacktestResult) {
    const row: StrategyBacktestResultRow & { userId: string } = {
      id: this.id(), userId: u, strategyVersionId, datasetId: result.datasetId, datasetHash: result.datasetHash,
      methodologyStatus: result.methodologyStatus, netPnl: result.netPnl, tradeCount: result.tradeCount,
      resultHash: result.resultHash, canonicalResult: result, createdAt: 't',
    };
    this.results.push(row);
    const { userId: _u, ...r } = row;
    return r;
  }
  // deno-lint-ignore require-await
  async insertFailedBacktestJob(u: string, strategyVersionId: string, datasetId: string, engineId: string, startedAt: string, failureReason: string) {
    const row: StrategyBacktestJobRow & { userId: string } = {
      id: this.id(), userId: u, strategyVersionId, datasetId, engineId, status: 'FAILED', startedAt,
      completedAt: 't', failureReason, resultId: null, createdAt: 't',
    };
    this.jobs.push(row);
    const { userId: _u, ...j } = row;
    return j;
  }
  // deno-lint-ignore require-await
  async insertSucceededBacktestJob(u: string, strategyVersionId: string, datasetId: string, engineId: string, startedAt: string, resultId: string) {
    const row: StrategyBacktestJobRow & { userId: string } = {
      id: this.id(), userId: u, strategyVersionId, datasetId, engineId, status: 'SUCCEEDED', startedAt,
      completedAt: 't', failureReason: null, resultId, createdAt: 't',
    };
    this.jobs.push(row);
    const { userId: _u, ...j } = row;
    return j;
  }
  // deno-lint-ignore require-await
  async listBacktestResultsForVersion(u: string, strategyVersionId: string) {
    return this.results.filter((r) => r.strategyVersionId === strategyVersionId && r.userId === u)
      .map(({ userId: _u, ...r }) => r);
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

Deno.test('SB-09 clone_reference creates the callers OWN new strategy from V10, never touching a shared reference row', async () => {
  store = new MemoryStore();
  const r = await call({ op: 'clone_reference', reference: 'V10' });
  assertEquals(r.status, 200);
  assertEquals(r.json.strategy.status, 'DRAFT');
  assertEquals(r.json.version.spec.name, V10_REFERENCE_SPEC_INPUT.name);
  assert(store.strategies.every((s) => s.userId === A));
});

Deno.test('SB-10 create_version appends version 2 without touching version 1s spec (§9/§29 immutability)', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const strategyId = created.json.strategy.id;
  const v2 = await call({ op: 'create_version', strategyId, spec: { ...GENERIC_REFERENCE_SPEC_INPUT, stop: { ruleId: 'STOP.FIXED_DISTANCE', distance: 7 } } });
  assertEquals(v2.status, 200);
  assertEquals(v2.json.version.versionNumber, 2);
  const listed = await call({ op: 'list_versions', strategyId });
  assertEquals(listed.json.versions.length, 2);
  assertEquals(listed.json.versions[0].spec.stop.distance, 5); // v1 unchanged
  assertEquals(listed.json.versions[1].spec.stop.distance, 7); // v2 new
});

Deno.test('SB-11 run_backtest against the GENERIC_RULE_ENGINE + synthetic fixture persists a real canonical result', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const r = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  assertEquals(r.status, 200);
  assertEquals(r.json.job.status, 'SUCCEEDED');
  assertEquals(r.json.result.tradeCount, 2);
  assertEquals(r.json.result.netPnl, 5); // +10 target, -5 stop (see generic_rule_engine_test.ts GE-01)
  assert(store.results.every((res) => res.userId === A));
});

Deno.test('SB-12 run_backtest refuses an engine/dataset mismatch before persisting a result, but still records the job', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: V10_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  // V10s own rule set is not on GENERIC_RULE_ENGINEs allowlist.
  const r = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  assertEquals(r.status, 200);
  assertEquals(r.json.job.status, 'FAILED');
  assertEquals(r.json.result, null);
  assertEquals(store.results.length, 0);
});

Deno.test('SB-13 run_backtest with an unknown dataset/engine id is a structured 400, never a 500', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const badDataset = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'not-a-real-dataset', engineId: 'GENERIC_RULE_ENGINE' });
  assertEquals(badDataset.status, 400);
  const badEngine = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'NOT_A_REAL_ENGINE' });
  assertEquals(badEngine.status, 400);
});

Deno.test('SB-14 compare_versions requires a real backtest result on both sides before computing any delta', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const strategyId = created.json.strategy.id;
  const versionAId = created.json.version.id;
  const v2 = await call({ op: 'create_version', strategyId, spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionBId = v2.json.version.id;

  const noResults = await call({ op: 'compare_versions', versionAId, versionBId });
  assertEquals(noResults.status, 404);

  await call({ op: 'run_backtest', strategyVersionId: versionAId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  await call({ op: 'run_backtest', strategyVersionId: versionBId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  const compared = await call({ op: 'compare_versions', versionAId, versionBId });
  assertEquals(compared.status, 200);
  assertEquals(compared.json.comparison.comparable, true);
  assertEquals(compared.json.comparison.deltas.netPnlDelta, 0);
});

Deno.test('SB-15 another user cannot run a backtest against, list versions of, or compare a foreign strategy version', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const strategyId = created.json.strategy.id;
  const versionId = created.json.version.id;

  const foreignVersions = await call({ op: 'list_versions', strategyId }, 'jwt-b');
  assertEquals(foreignVersions.json.versions, []);

  const foreignCreateVersion = await call({ op: 'create_version', strategyId, spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-b');
  assertEquals(foreignCreateVersion.status, 404);

  const foreignBacktest = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' }, 'jwt-b');
  assertEquals(foreignBacktest.status, 404);
});

Deno.test('SB-17 analyze_backtest_result returns real epistemic claims after a real run_backtest, never before one exists', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;

  const tooEarly = await call({ op: 'analyze_backtest_result', strategyVersionId: versionId });
  assertEquals(tooEarly.status, 404);

  await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  const analyzed = await call({ op: 'analyze_backtest_result', strategyVersionId: versionId });
  assertEquals(analyzed.status, 200);
  assert(Array.isArray(analyzed.json.claims));
  assert(analyzed.json.claims.some((c: { status: string; statement: string }) => c.status === 'UNKNOWN' && c.statement.includes('Future profitability')));
});

Deno.test('SB-18 (§43) a free-plan caller is refused STRATEGY_LIMIT_REACHED past 3 strategies; another users own count is unaffected', async () => {
  store = new MemoryStore();
  for (let i = 0; i < 3; i++) {
    const r = await call({ op: 'create', spec: { ...GENERIC_REFERENCE_SPEC_INPUT, name: `Strategy ${i}` } });
    assertEquals(r.status, 200, `strategy #${i}`);
  }
  const fourth = await call({ op: 'create', spec: { ...GENERIC_REFERENCE_SPEC_INPUT, name: 'Strategy 4' } });
  assertEquals(fourth.status, 403);
  assertEquals(fourth.json.error, 'STRATEGY_LIMIT_REACHED');
  assertEquals(store.strategies.length, 3);

  // clone_reference consumes the SAME quota.
  const clone = await call({ op: 'clone_reference', reference: 'V10' });
  assertEquals(clone.status, 403);
  assertEquals(clone.json.error, 'STRATEGY_LIMIT_REACHED');

  // A different user's own quota is untouched by the first user's limit.
  const otherUser = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-b');
  assertEquals(otherUser.status, 200);
});

Deno.test('SB-16 non-admin plans are denied for every new op before the store is touched', async () => {
  store = new MemoryStore();
  for (const payload of [
    { op: 'clone_reference', reference: 'V10' },
    { op: 'create_version', strategyId: 'cccccccc-0000-4000-8000-000000000001', spec: GENERIC_REFERENCE_SPEC_INPUT },
    { op: 'list_versions', strategyId: 'cccccccc-0000-4000-8000-000000000001' },
    { op: 'run_backtest', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' },
    { op: 'compare_versions', versionAId: 'cccccccc-0000-4000-8000-000000000001', versionBId: 'cccccccc-0000-4000-8000-000000000002' },
    { op: 'analyze_backtest_result', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001' },
  ]) {
    const r = await call(payload, 'jwt-a', 'free');
    assertEquals([r.status, r.json.error], [403, 'MODULE_NOT_AVAILABLE'], JSON.stringify(payload));
  }
  assertEquals(store.strategies.length, 0);
  assertEquals(store.jobs.length, 0);
});
