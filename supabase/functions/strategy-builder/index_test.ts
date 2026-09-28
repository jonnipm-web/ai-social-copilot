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
  ResultKind, StrategyBacktestJobRow, StrategyBacktestResultRow, StrategyExperimentRow, StrategyRow, StrategyStore, StrategyVersionRow,
} from '../_shared/strategy_server.ts';
import type { StrategySpecification } from '../_shared/strategy/strategy_spec.ts';
import type { CanonicalBacktestResult } from '../_shared/strategy/backtest_result.ts';
import { V10_REFERENCE_SPEC_INPUT } from '../_shared/strategy/v10_reference.ts';
import { GENERIC_REFERENCE_SPEC_INPUT } from '../_shared/strategy/generic_reference_strategy.ts';
import { StrategyLimitReachedError } from '../_shared/strategy_server.ts';
import { handler, planAllowsResearchOp, type StrategyBuilderDeps } from './index.ts';

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
  experiments: (StrategyExperimentRow & { userId: string })[] = [];
  private n = 0;
  private id() {
    return `cccccccc-0000-4000-8000-${String(++this.n).padStart(12, '0')}`;
  }
  // deno-lint-ignore require-await
  async list(u: string) {
    return this.strategies.filter((s) => s.userId === u).map(({ userId: _u, ...s }) => s);
  }
  // deno-lint-ignore require-await
  /** Mirrors migration 20261004000000's strategies_enforce_plan_limit
   * trigger: the store itself is the race-safe authority, re-checked
   * at insert time regardless of what the caller's own pre-check saw
   * (Codex final audit, P1 fix). */
  storeLevelLimit = 3;
  async create(u: string, spec: StrategySpecification) {
    if (this.strategies.filter((s) => s.userId === u).length >= this.storeLevelLimit) {
      throw new StrategyLimitReachedError();
    }
    const strategy: StrategyRow & { userId: string } = {
      id: this.id(), userId: u, name: spec.name, status: 'DRAFT', currentVersion: 1, createdAt: 't', updatedAt: 't', holdoutFirstViewedAt: null,
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
  async insertBacktestResult(u: string, strategyVersionId: string, result: CanonicalBacktestResult, resultKind: ResultKind) {
    const row: StrategyBacktestResultRow & { userId: string } = {
      id: this.id(), userId: u, strategyVersionId, datasetId: result.datasetId, datasetHash: result.datasetHash,
      methodologyStatus: result.methodologyStatus, netPnl: result.netPnl, tradeCount: result.tradeCount,
      resultHash: result.resultHash, canonicalResult: result, resultKind, createdAt: 't',
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
  // deno-lint-ignore require-await
  async insertExperiment(u: string, input: Omit<StrategyExperimentRow, 'id' | 'createdAt'>) {
    // A REAL timestamp, unlike the 't' placeholder used elsewhere in this
    // store -- computeContamination compares createdAt values as actual
    // dates, and Date.parse('t') is NaN, which silently broke every
    // comparison against it.
    const row: StrategyExperimentRow & { userId: string } = { id: this.id(), userId: u, createdAt: new Date().toISOString(), ...input };
    this.experiments.push(row);
    // Mirrors 20261005000000's strategy_experiments_mark_holdout_viewed
    // trigger: first HOLDOUT experiment sets the strategy's timestamp,
    // COALESCE-guarded (first-write-wins) -- never overwritten later.
    if (input.segment === 'HOLDOUT') {
      const idx = this.strategies.findIndex((x) => x.id === input.strategyId && x.userId === u);
      if (idx >= 0 && this.strategies[idx].holdoutFirstViewedAt === null) {
        this.strategies[idx] = { ...this.strategies[idx], holdoutFirstViewedAt: row.createdAt };
      }
    }
    const { userId: _u, ...e } = row;
    return e;
  }
  // deno-lint-ignore require-await
  async listExperiments(u: string, strategyId: string) {
    return this.experiments.filter((e) => e.strategyId === strategyId && e.userId === u)
      .map(({ userId: _u, ...e }) => e);
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

Deno.test('SB-33 (§21) compare_versions surfaces independent robustness/score for each side, reweighted by the given objective', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const strategyId = created.json.strategy.id;
  const versionAId = created.json.version.id;
  const v2 = await call({ op: 'create_version', strategyId, spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionBId = v2.json.version.id;
  await call({ op: 'run_backtest', strategyVersionId: versionAId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  await call({ op: 'run_backtest', strategyVersionId: versionBId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });

  const noObjective = await call({ op: 'compare_versions', versionAId, versionBId });
  assertEquals(noObjective.status, 200);
  assert(noObjective.json.robustnessA.sampleSize.threshold > 0);
  assert(['MORE_ROBUST_UNDER_TESTED_ASSUMPTIONS', 'REQUIRES_MORE_EVIDENCE'].includes(noObjective.json.scoreA.language));

  const withObjective = await call({ op: 'compare_versions', versionAId, versionBId, objective: 'CAPITAL_PRESERVATION' });
  // The generic engine never measures maxDrawdown (always null), so
  // (Codex final audit, P2-01 fix) DRAWDOWN_CONTROL is excluded --
  // weight 0 -- under EITHER objective here; that exclusion itself is
  // exactly the fix, so assert it holds under reweighting too, and use
  // PROFITABILITY (never excluded) to prove the objective genuinely
  // changed the weighting.
  const weightOf = (s: { components: { name: string; weight: number }[] }, name: string) => s.components.find((c) => c.name === name)!.weight;
  assertEquals(weightOf(withObjective.json.scoreA, 'DRAWDOWN_CONTROL'), 0);
  assertEquals(weightOf(noObjective.json.scoreA, 'DRAWDOWN_CONTROL'), 0);
  assert(weightOf(withObjective.json.scoreA, 'PROFITABILITY') < weightOf(noObjective.json.scoreA, 'PROFITABILITY'));
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

Deno.test('SB-19 (Codex final audit, P1 fix) the store-level limit still blocks creation even when the app-level pre-check races and wrongly passes', async () => {
  store = new MemoryStore();
  for (let i = 0; i < 3; i++) {
    await call({ op: 'create', spec: { ...GENERIC_REFERENCE_SPEC_INPUT, name: `Racer ${i}` } });
  }
  assertEquals(store.strategies.length, 3);
  // Simulate the exact race Codex found: the app's own list()-based
  // pre-check observes a stale/incorrect (empty) count -- as it could
  // under real concurrency -- and lets the request through anyway.
  const originalList = store.list.bind(store);
  store.list = (u: string) => Promise.resolve([]);
  const raced = await call({ op: 'create', spec: { ...GENERIC_REFERENCE_SPEC_INPUT, name: 'Racer 4' } });
  store.list = originalList;
  // The app-level pre-check was fooled (it would have said "0 < 3, go
  // ahead"), but the store/database-level check still refuses -- this is
  // the race-safety property the migration's trigger provides in
  // production.
  assertEquals(raced.status, 403);
  assertEquals(raced.json.error, 'STRATEGY_LIMIT_REACHED');
  assertEquals(store.strategies.length, 3);
});

Deno.test('SB-37 (Codex final audit, Macro-06 deferred P3, closed) the same race-safety property holds for clone_reference, not just create', async () => {
  store = new MemoryStore();
  for (let i = 0; i < 3; i++) {
    await call({ op: 'create', spec: { ...GENERIC_REFERENCE_SPEC_INPUT, name: `Racer ${i}` } });
  }
  assertEquals(store.strategies.length, 3);
  const originalList = store.list.bind(store);
  store.list = (u: string) => Promise.resolve([]);
  const raced = await call({ op: 'clone_reference', reference: 'GENERIC' });
  store.list = originalList;
  assertEquals(raced.status, 403);
  assertEquals(raced.json.error, 'STRATEGY_LIMIT_REACHED');
  assertEquals(store.strategies.length, 3);
});

Deno.test('SB-20 (Codex final audit, P2 fix) a job-row write failure AFTER a real result is saved never reports the backtest as failed', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const originalInsertSucceeded = store.insertSucceededBacktestJob.bind(store);
  store.insertSucceededBacktestJob = () => {
    throw new Error('simulated job-row write failure');
  };
  const r = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  store.insertSucceededBacktestJob = originalInsertSucceeded;
  // The backtest genuinely succeeded and its canonical result is durably
  // saved -- the caller must see that real success (200, a real result),
  // not a 500 or a fabricated FAILED job, even though the job-row
  // bookkeeping itself failed.
  assertEquals(r.status, 200);
  assertEquals(r.json.result.tradeCount, 2);
  assertEquals(r.json.job, null);
  assertEquals(store.results.length, 1);
  assert(store.jobs.every((j) => j.status !== 'FAILED'));
});

Deno.test('SB-21 (§5) engine_status reports the in-process engine always available and the external one unavailable when the bridge is unreachable', async () => {
  store = new MemoryStore();
  const r = await call({ op: 'engine_status' });
  assertEquals(r.status, 200);
  const byId = new Map(r.json.engines.map((e: { engineId: string }) => [e.engineId, e]));
  assertEquals(byId.get('GENERIC_RULE_ENGINE'), { engineId: 'GENERIC_RULE_ENGINE', available: true, reason: null });
  const v10 = byId.get('PAULO_TREND_FIBONACCI_V10') as { available: boolean; reason: string | null };
  assertEquals(v10.available, false);
  assert(typeof v10.reason === 'string' && v10.reason.length > 0);
});

Deno.test('SB-22 (§14) run_backtest against the research and holdout segment datasets reproduces the documented sign-flip end to end', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const research = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1-research', engineId: 'GENERIC_RULE_ENGINE' });
  const holdout = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1-holdout', engineId: 'GENERIC_RULE_ENGINE' });
  assertEquals(research.status, 200);
  assertEquals(holdout.status, 200);
  assertEquals(research.json.result.tradeCount, 1);
  assertEquals(holdout.json.result.tradeCount, 1);
  // Documented fixture behavior (generic_engine_fixtures.ts): session 1
  // (research) hits its +10 target; session 2 (holdout) hits its -5
  // stop -- a real, measured sign flip out of sample, not a fabricated one.
  assertEquals(research.json.result.netPnl, 10);
  assertEquals(holdout.json.result.netPnl, -5);
  assertEquals(Math.sign(research.json.result.netPnl), 1);
  assertEquals(Math.sign(holdout.json.result.netPnl), -1);
});

Deno.test('SB-23 (§33-35) planAllowsResearchOp: pure gate logic -- admin bypasses, pro/premium pass, free is denied', () => {
  assertEquals(planAllowsResearchOp('propose_variants', 'free', 'ADMIN_ROLE'), true);
  assertEquals(planAllowsResearchOp('propose_variants', 'free', 'PLAN_ENTITLED'), false);
  assertEquals(planAllowsResearchOp('propose_variants', 'pro', 'PLAN_ENTITLED'), true);
  assertEquals(planAllowsResearchOp('propose_variants', 'premium', 'PLAN_ENTITLED'), true);
  // Non-research ops are never gated by this function -- validation/
  // security stay ungated (§35).
  assertEquals(planAllowsResearchOp('validate', 'free', 'PLAN_ENTITLED'), true);
});

Deno.test('SB-24 (§10/§19) propose_variants returns fit evidence and bounded proposals when the stop is flagged tight', async () => {
  store = new MemoryStore();
  const tightStopSpec = { ...GENERIC_REFERENCE_SPEC_INPUT, stop: { ruleId: 'STOP.FIXED_DISTANCE', distance: 1 } };
  const created = await call({ op: 'create', spec: tightStopSpec });
  const versionId = created.json.version.id;
  const r = await call({ op: 'propose_variants', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' });
  assertEquals(r.status, 200);
  const stopFinding = r.json.fitEvidence.items.find((i: { dimension: string }) => i.dimension === 'STOP_VS_MOVEMENT');
  assertEquals(stopFinding.flagged, true);
  assert(r.json.proposals.length > 0);
  assert(r.json.proposals.length <= 5);
});

Deno.test('SB-25 propose_variants against an unknown dataset is a structured 400, never a 500', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const r = await call({ op: 'propose_variants', strategyVersionId: created.json.version.id, datasetId: 'not-a-real-dataset' });
  assertEquals(r.status, 400);
  assertEquals(r.json.error, 'UNKNOWN_DATASET');
});

Deno.test('SB-26 (§15) record_experiment persists a BACKTEST-category experiment linked to a real result, uncontaminated', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const bt = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  const resultId = bt.json.result.id;
  const r = await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'BACKTEST', datasetId: 'synthetic-fixture-5min-v1',
    segment: 'FULL', parametersChanged: null, reason: 'baseline run', resultId, source: 'USER',
  });
  assertEquals(r.status, 200);
  assertEquals(r.json.experiment.contaminated, false);
  assertEquals(r.json.experiment.resultId, resultId);
  assertEquals(store.experiments.length, 1);
});

Deno.test('SB-27 record_experiment refuses a segment label that does not match the datasets own segmentKind', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const r = await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'BACKTEST', datasetId: 'synthetic-fixture-5min-v1',
    segment: 'HOLDOUT', parametersChanged: null, reason: 'lying about the segment', resultId: null, source: 'USER',
  });
  assertEquals(r.status, 400);
  assertEquals(store.experiments.length, 0);
});

Deno.test('SB-28 record_experiment refuses a resultId that belongs to a different dataset than the one claimed', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const bt = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1-research', engineId: 'GENERIC_RULE_ENGINE' });
  const r = await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'BACKTEST', datasetId: 'synthetic-fixture-5min-v1',
    segment: 'FULL', parametersChanged: null, reason: 'mismatched dataset', resultId: bt.json.result.id, source: 'USER',
  });
  assertEquals(r.status, 400);
});

Deno.test('SB-29 (§14) the FIRST HOLDOUT experiment is never contaminated; a later experiment after it IS', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const holdoutBt = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1-holdout', engineId: 'GENERIC_RULE_ENGINE' });
  const firstHoldout = await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'ROBUSTNESS_EXPERIMENT', datasetId: 'synthetic-fixture-5min-v1-holdout',
    segment: 'HOLDOUT', parametersChanged: null, reason: 'first holdout look', resultId: holdoutBt.json.result.id, source: 'USER',
  });
  assertEquals(firstHoldout.json.experiment.contaminated, false);

  const fullBt = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  const later = await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'USER_DECISION', datasetId: 'synthetic-fixture-5min-v1',
    segment: 'FULL', parametersChanged: null, reason: 'decided after seeing holdout', resultId: fullBt.json.result.id, source: 'USER',
  });
  assertEquals(later.json.experiment.contaminated, true);
});

Deno.test('SB-30 list_experiments is scoped to the caller -- another users experiments never leak', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-a');
  const strategyId = created.json.strategy.id;
  const versionId = created.json.version.id;
  const bt = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' }, 'jwt-a');
  await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'BACKTEST', datasetId: 'synthetic-fixture-5min-v1',
    segment: 'FULL', parametersChanged: null, reason: 'owner experiment', resultId: bt.json.result.id, source: 'USER',
  }, 'jwt-a');
  const asOwner = await call({ op: 'list_experiments', strategyId }, 'jwt-a');
  assertEquals(asOwner.json.experiments.length, 1);
  const asOther = await call({ op: 'list_experiments', strategyId }, 'jwt-b');
  assertEquals(asOther.json.experiments.length, 0);
});

Deno.test('SB-31 (§16/§30) run_research_loop produces bounded candidates, each a real new version with a real persisted result', async () => {
  store = new MemoryStore();
  const tightStopSpec = { ...GENERIC_REFERENCE_SPEC_INPUT, stop: { ruleId: 'STOP.FIXED_DISTANCE', distance: 1 } };
  const created = await call({ op: 'create', spec: tightStopSpec });
  const versionId = created.json.version.id;
  const r = await call({ op: 'run_research_loop', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' });
  assertEquals(r.status, 200);
  assert(r.json.candidates.length > 0);
  assert(r.json.candidates.length <= 5);
  for (const c of r.json.candidates) {
    assertEquals(c.error, null);
    assert(c.versionId !== null && c.versionId !== versionId);
    assert(c.result !== null);
    assert(c.experimentId !== null);
  }
  // Every candidate became a real, persisted new version -- listVersions
  // must see them (never a throwaway/ephemeral version).
  const versions = await call({ op: 'list_versions', strategyId: created.json.strategy.id });
  assertEquals(versions.json.versions.length, 1 + r.json.candidates.length);
  assertEquals(store.experiments.length, r.json.candidates.length);
});

Deno.test('SB-32 run_research_loop returns an empty, non-error candidate list when no evidence-based proposal exists', async () => {
  store = new MemoryStore();
  const wideStopSpec = { ...GENERIC_REFERENCE_SPEC_INPUT, stop: { ruleId: 'STOP.FIXED_DISTANCE', distance: 1000 } };
  const created = await call({ op: 'create', spec: wideStopSpec });
  const r = await call({ op: 'run_research_loop', strategyVersionId: created.json.version.id, datasetId: 'synthetic-fixture-5min-v1' });
  assertEquals(r.status, 200);
  assertEquals(r.json.candidates, []);
  assertEquals(r.json.proposals, []);
});

Deno.test('SB-34 (§24-25) run_simulation persists a real result tagged SIMULATION, never BACKTEST', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const r = await call({ op: 'run_simulation', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' });
  assertEquals(r.status, 200);
  assertEquals(r.json.label, 'SIMULATION');
  assertEquals(r.json.experiment.category, 'SIMULATION');
  assertEquals(r.json.experiment.resultId, r.json.result.id);
  assertEquals(r.json.result.tradeCount, 2); // same deterministic fixture as SB-11
  assertEquals(store.experiments.length, 1);
  assertEquals(store.experiments[0].category, 'SIMULATION');
});

Deno.test('SB-35 run_simulation refuses the external V10 engine implicitly -- only GENERIC_RULE_ENGINE datasets are usable', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: V10_REFERENCE_SPEC_INPUT });
  const r = await call({ op: 'run_simulation', strategyVersionId: created.json.version.id, datasetId: 'win1-5min-qt01c3' });
  assertEquals(r.status, 400);
  assertEquals(r.json.error, 'DATA_REQUIREMENT_UNMET');
});

Deno.test('SB-36 (§32) compute telemetry: run_backtest/run_simulation/run_research_loop log real dataset/engine/candidate counts, never billing', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;

  await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  const btLine = JSON.parse(logs[logs.length - 1]);
  assertEquals(btLine.telemetry.engineId, 'GENERIC_RULE_ENGINE');
  assertEquals(btLine.telemetry.datasetId, 'synthetic-fixture-5min-v1');
  assertEquals(btLine.telemetry.barCount, 9);
  assertEquals(btLine.telemetry.tradeCount, 2);
  assert(typeof btLine.latency_ms === 'number');

  await call({ op: 'run_simulation', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' });
  const simLine = JSON.parse(logs[logs.length - 1]);
  assertEquals(simLine.telemetry.simulationRun, true);
  assertEquals(simLine.telemetry.barCount, 9);

  const tightStopSpec = { ...GENERIC_REFERENCE_SPEC_INPUT, stop: { ruleId: 'STOP.FIXED_DISTANCE', distance: 1 } };
  const tightCreated = await call({ op: 'create', spec: tightStopSpec });
  await call({ op: 'run_research_loop', strategyVersionId: tightCreated.json.version.id, datasetId: 'synthetic-fixture-5min-v1' });
  const loopLine = JSON.parse(logs[logs.length - 1]);
  assert(typeof loopLine.telemetry.candidateCount === 'number' && loopLine.telemetry.candidateCount > 0);
  assert(typeof loopLine.telemetry.proposalCount === 'number');
});

Deno.test('SB-38 (Codex final audit, P1-02 fix) record_experiment refuses category=SIMULATION for a resultId that was actually a real backtest', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const bt = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  const r = await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'SIMULATION', datasetId: 'synthetic-fixture-5min-v1',
    segment: 'FULL', parametersChanged: null, reason: 'lying about the result kind', resultId: bt.json.result.id, source: 'USER',
  });
  assertEquals(r.status, 400);
  assertEquals(store.experiments.length, 0);
});

Deno.test('SB-39 (Codex final audit, P1-02 fix) record_experiment refuses category=BACKTEST for a resultId that was actually a simulation', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  const sim = await call({ op: 'run_simulation', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' });
  const r = await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'BACKTEST', datasetId: 'synthetic-fixture-5min-v1',
    segment: 'FULL', parametersChanged: null, reason: 'disguising a simulation as a real backtest', resultId: sim.json.result.id, source: 'USER',
  });
  assertEquals(r.status, 400);
});

Deno.test('SB-40 (Codex final audit, P1-02 fix) compare_versions never selects a SIMULATION result -- a version with only a simulation result is NOT_FOUND, not silently analyzed', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const strategyId = created.json.strategy.id;
  const versionAId = created.json.version.id;
  const v2 = await call({ op: 'create_version', strategyId, spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionBId = v2.json.version.id;
  await call({ op: 'run_simulation', strategyVersionId: versionAId, datasetId: 'synthetic-fixture-5min-v1' });
  await call({ op: 'run_backtest', strategyVersionId: versionBId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' });
  const r = await call({ op: 'compare_versions', versionAId, versionBId });
  assertEquals(r.status, 404);
});

Deno.test('SB-41 (Codex final audit, P1-02 fix) analyze_backtest_result never selects a SIMULATION result', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT });
  const versionId = created.json.version.id;
  await call({ op: 'run_simulation', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' });
  const r = await call({ op: 'analyze_backtest_result', strategyVersionId: versionId });
  assertEquals(r.status, 404);
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
    { op: 'engine_status' },
    { op: 'propose_variants', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', datasetId: 'synthetic-fixture-5min-v1' },
    {
      op: 'record_experiment', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', category: 'BACKTEST',
      datasetId: 'synthetic-fixture-5min-v1', segment: 'FULL', parametersChanged: null, reason: 'x', resultId: null, source: 'USER',
    },
    { op: 'list_experiments', strategyId: 'cccccccc-0000-4000-8000-000000000001' },
    { op: 'run_research_loop', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', datasetId: 'synthetic-fixture-5min-v1' },
    { op: 'run_simulation', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', datasetId: 'synthetic-fixture-5min-v1' },
  ]) {
    const r = await call(payload, 'jwt-a', 'free');
    assertEquals([r.status, r.json.error], [403, 'MODULE_NOT_AVAILABLE'], JSON.stringify(payload));
  }
  assertEquals(store.strategies.length, 0);
  assertEquals(store.jobs.length, 0);
});
