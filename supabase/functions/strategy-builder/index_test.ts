/**
 * strategy-builder API tests — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05.
 * Real handler + an in-memory store that mimics RLS (rows keyed by owner).
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env --allow-read --allow-net=deno.land,esm.sh supabase/functions/strategy-builder/index_test.ts
 */
import { assert, assertEquals, assertFalse } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { AuthClient } from '../_shared/auth.ts';
import { fakeSubjectSource } from '../_shared/entitlement_test_support.ts';
import { MODULE_POLICY } from '../_shared/module_policy.ts';
import type {
  ResultKind, StrategyBacktestJobRow, StrategyBacktestResultRow, StrategyExperimentRow, StrategyRow, StrategyStore, StrategyVersionRow,
} from '../_shared/strategy_server.ts';
import type { StrategySpecification } from '../_shared/strategy/strategy_spec.ts';
import type { CanonicalBacktestResult } from '../_shared/strategy/backtest_result.ts';
import { V10_REFERENCE_SPEC_INPUT } from '../_shared/strategy/v10_reference.ts';
import { GENERIC_REFERENCE_SPEC_INPUT } from '../_shared/strategy/generic_reference_strategy.ts';
import { IdempotencyKeyConflictError, StrategyLimitReachedError } from '../_shared/strategy_server.ts';
import { handler, planAllowsOp, STRATEGY_LIMIT_BY_PLAN, type StrategyBuilderDeps } from './index.ts';

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
  // Mirrors strategies_create_with_version's own idempotency-key dedup
  // (20261008000000, 2nd Codex re-verification): keyed by (user, key) ->
  // (strategyId, the spec it was created with).
  idempotencyIndex = new Map<string, { strategyId: string; specJson: string }>();
  async create(u: string, spec: StrategySpecification, idempotencyKey?: string | null) {
    if (idempotencyKey) {
      const existing = this.idempotencyIndex.get(`${u}:${idempotencyKey}`);
      if (existing) {
        if (existing.specJson !== JSON.stringify(spec)) throw new IdempotencyKeyConflictError();
        const strategy = this.strategies.find((s) => s.id === existing.strategyId && s.userId === u)!;
        const version = this.versions.find((v) => v.strategyId === existing.strategyId && v.versionNumber === 1)!;
        const { userId: _u1, ...s } = strategy;
        const { userId: _u2, ...v } = version;
        return { strategy: s, version: v };
      }
    }
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
    if (idempotencyKey) this.idempotencyIndex.set(`${u}:${idempotencyKey}`, { strategyId: strategy.id, specJson: JSON.stringify(spec) });
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

Deno.test('SB-07 anonymous, forged token and an unrecognized plan are denied before the store is touched', async () => {
  store = new MemoryStore();
  assertEquals((await call({ op: 'list' }, null)).status, 401);
  assertEquals((await call({ op: 'list' }, 'forged')).status, 401);
  // 'enterprise' is not a real legacy profiles.role value -- fails closed,
  // never guessed at a plan (mapLegacyProfileRole -> plan: null).
  const r = await call({ op: 'create', spec: V10_REFERENCE_SPEC_INPUT }, 'jwt-a', 'enterprise');
  assertEquals(r.status, 503);
  assertEquals(store.strategies.length, 0);
});

Deno.test('SB-43 (Macro-08 §5-6) strategy-builder is COMMERCIAL/free -- a real free/pro/premium/beta_tester user (no admin role) can now create a strategy directly', async () => {
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    store = new MemoryStore();
    const r = await call({ op: 'create', spec: V10_REFERENCE_SPEC_INPUT }, 'jwt-a', role);
    assertEquals(r.status, 200, role);
    assertEquals(store.strategies.length, 1, role);
  }
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

Deno.test('SB-47 (Macro-08 §37) Premium is a high FINITE fair-use cap (200), never unlimited -- a Premium user can exceed the free/pro limits but is still a real, bounded number', () => {
  assertEquals(Number.isFinite(STRATEGY_LIMIT_BY_PLAN.premium), true);
  assertEquals(STRATEGY_LIMIT_BY_PLAN.premium, 200);
  assert(STRATEGY_LIMIT_BY_PLAN.premium > STRATEGY_LIMIT_BY_PLAN.pro);
  assert(STRATEGY_LIMIT_BY_PLAN.pro > STRATEGY_LIMIT_BY_PLAN.free);
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

Deno.test('SB-23 (§33-35) planAllowsOp: pure gate logic -- admin bypasses, pro/premium pass research ops, free is denied', () => {
  assertEquals(planAllowsOp('propose_variants', 'free', 'ADMIN_ROLE'), true);
  assertEquals(planAllowsOp('propose_variants', 'free', 'PLAN_ENTITLED'), false);
  assertEquals(planAllowsOp('propose_variants', 'pro', 'PLAN_ENTITLED'), true);
  assertEquals(planAllowsOp('propose_variants', 'premium', 'PLAN_ENTITLED'), true);
  // Non-research ops are never gated by this function -- validation/
  // security stay ungated (§35).
  assertEquals(planAllowsOp('validate', 'free', 'PLAN_ENTITLED'), true);
});

Deno.test('SB-42 (Macro-08 §10) run_simulation specifically requires Premium -- Pro alone is not enough', () => {
  assertEquals(planAllowsOp('run_simulation', 'pro', 'PLAN_ENTITLED'), false);
  assertEquals(planAllowsOp('run_simulation', 'premium', 'PLAN_ENTITLED'), true);
  assertEquals(planAllowsOp('run_simulation', 'free', 'ADMIN_ROLE'), true);
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

Deno.test('SB-58 (Macro-08 continuation §11) propose_variants generalizes bounded exploration to target -- proposes NARROWER target variants when TARGET_VS_MOVEMENT is flagged, and reports breakEven as UNSUPPORTED_BY_CURRENT_ENGINE when configured', async () => {
  store = new MemoryStore();
  const farTargetSpec = {
    ...GENERIC_REFERENCE_SPEC_INPUT,
    target: { ruleId: 'TARGET.FIXED_DISTANCE', distance: 100000 },
    breakEven: { ruleId: 'BREAK_EVEN.STEPPED', triggerDistance: 50, initialProtectedDistance: 10, stepDistance: 10 },
  };
  const created = await call({ op: 'create', spec: farTargetSpec });
  const versionId = created.json.version.id;
  const r = await call({ op: 'propose_variants', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' });
  assertEquals(r.status, 200);
  const targetFinding = r.json.fitEvidence.items.find((i: { dimension: string }) => i.dimension === 'TARGET_VS_MOVEMENT');
  assertEquals(targetFinding.flagged, true);
  const targetProposals = (r.json.proposals as Array<{ parametersChanged: Record<string, { from: number; to: number }> }>)
    .filter((p) => 'target.distance' in p.parametersChanged);
  assert(targetProposals.length > 0, 'expected at least one narrower-target proposal');
  for (const p of targetProposals) assert(p.parametersChanged['target.distance'].to < p.parametersChanged['target.distance'].from);
  assertEquals(r.json.unsupportedParameters.length, 1);
  assertEquals(r.json.unsupportedParameters[0].parameter, 'breakEven');
  assert((r.json.unsupportedParameters[0].reason as string).startsWith('UNSUPPORTED_BY_CURRENT_ENGINE'));
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

Deno.test('SB-59 (Macro-08 continuation §11) run_research_loop generalizes candidate-building to target: a far-target strategy produces real candidates with a narrower target.distance, not a crash on the old stop-only assumption', async () => {
  store = new MemoryStore();
  const farTargetSpec = { ...GENERIC_REFERENCE_SPEC_INPUT, target: { ruleId: 'TARGET.FIXED_DISTANCE', distance: 100000 } };
  const created = await call({ op: 'create', spec: farTargetSpec });
  const versionId = created.json.version.id;
  const r = await call({ op: 'run_research_loop', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' });
  assertEquals(r.status, 200);
  assert(r.json.candidates.length > 0);
  for (const c of r.json.candidates) {
    assertEquals(c.error, null);
    assert(c.versionId !== null && c.versionId !== versionId);
  }
  const versions = await call({ op: 'list_versions', strategyId: created.json.strategy.id });
  // Every candidate version's target must be strictly narrower than the original 100000 -- proves
  // the generalized apply-loop actually wrote target.distance, not a silently-unchanged spec.
  const targets = (versions.json.versions as Array<{ id: string; spec: { target: { distance: number } } }>)
    .filter((v) => v.id !== versionId).map((v) => v.spec.target.distance);
  for (const t of targets) assert(t < 100000, `expected a narrower target, got ${t}`);
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

Deno.test('SB-16 (Macro-08 §5-7) a real free user reaches every SAFE_USER_CAPABILITY op -- never MODULE_NOT_AVAILABLE, never PLAN_UPGRADE_REQUIRED', async () => {
  store = new MemoryStore();
  for (const payload of [
    { op: 'clone_reference', reference: 'V10' },
    { op: 'create_version', strategyId: 'cccccccc-0000-4000-8000-000000000001', spec: GENERIC_REFERENCE_SPEC_INPUT },
    { op: 'list_versions', strategyId: 'cccccccc-0000-4000-8000-000000000001' },
    { op: 'run_backtest', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' },
    { op: 'compare_versions', versionAId: 'cccccccc-0000-4000-8000-000000000001', versionBId: 'cccccccc-0000-4000-8000-000000000002' },
    { op: 'analyze_backtest_result', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001' },
    { op: 'engine_status' },
  ]) {
    const r = await call(payload, 'jwt-a', 'free');
    assert(r.status !== 403 || !['MODULE_NOT_AVAILABLE', 'PLAN_UPGRADE_REQUIRED'].includes(r.json.error), JSON.stringify(payload) + ' -> ' + JSON.stringify(r.json));
  }
});

Deno.test('SB-44 (Macro-08 §7, §10) a real free user is refused PLAN_UPGRADE_REQUIRED (not MODULE_NOT_AVAILABLE) on every research/simulation op, with the correct requiredPlan', async () => {
  store = new MemoryStore();
  for (const [payload, expectedPlan] of [
    [{ op: 'propose_variants', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', datasetId: 'synthetic-fixture-5min-v1' }, 'pro'],
    [{
      op: 'record_experiment', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', category: 'BACKTEST',
      datasetId: 'synthetic-fixture-5min-v1', segment: 'FULL', parametersChanged: null, reason: 'x', resultId: null, source: 'USER',
    }, 'pro'],
    [{ op: 'list_experiments', strategyId: 'cccccccc-0000-4000-8000-000000000001' }, 'pro'],
    [{ op: 'run_research_loop', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', datasetId: 'synthetic-fixture-5min-v1' }, 'pro'],
    [{ op: 'run_simulation', strategyVersionId: 'cccccccc-0000-4000-8000-000000000001', datasetId: 'synthetic-fixture-5min-v1' }, 'premium'],
  ] as const) {
    const r = await call(payload, 'jwt-a', 'free');
    assertEquals(r.status, 403, JSON.stringify(payload));
    assertEquals(r.json.error, 'PLAN_UPGRADE_REQUIRED', JSON.stringify(payload));
    assertEquals(r.json.requiredPlan, expectedPlan, JSON.stringify(payload));
    assertEquals(r.json.currentPlan, 'free', JSON.stringify(payload));
  }
  assertEquals(store.strategies.length, 0);
  assertEquals(store.jobs.length, 0);
});

Deno.test('SB-45 (Macro-08 §7) a real Pro user passes every research op but is still refused run_simulation (Premium-only)', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-a', 'pro');
  const versionId = created.json.version.id;
  const proposeResult = await call({ op: 'propose_variants', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' }, 'jwt-a', 'pro');
  assertEquals(proposeResult.status, 200);
  const simResult = await call({ op: 'run_simulation', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' }, 'jwt-a', 'pro');
  assertEquals(simResult.status, 403);
  assertEquals(simResult.json.error, 'PLAN_UPGRADE_REQUIRED');
  assertEquals(simResult.json.requiredPlan, 'premium');
});

Deno.test('SB-46 (Macro-08 §7) a real Premium user passes run_simulation', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-a', 'premium');
  const versionId = created.json.version.id;
  const simResult = await call({ op: 'run_simulation', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' }, 'jwt-a', 'premium');
  assertEquals(simResult.status, 200);
  assertEquals(simResult.json.label, 'SIMULATION');
});

Deno.test('SB-48 drift: the DB entitlement predicate of strategy-builder matches its server COMMERCIAL/free lifecycle (Codex adversarial review, Macro-08 diff vs 15d4177)', async () => {
  // Codex found: module_policy.ts promotes strategy-builder to COMMERCIAL/
  // free (real non-admin users pass the Edge Function's entitlement gate),
  // but the migration's own DB predicate was still hardcoded to
  // role='admin' -- every RLS policy on strategies/strategy_versions/
  // strategy_backtest_results depends on it, so a real free/pro/premium
  // user would pass the handler gate and then get a bare RLS failure on
  // every read/write. This test pins BOTH sides of that contract so they
  // cannot silently diverge again: mirrors QB-16
  // (_shared/quant/boundary_test.ts) for quant-watchlists's own
  // INTERNAL/EXPERIMENTAL predicate, inverted for a COMMERCIAL module.
  const lifecycle = MODULE_POLICY.modules['strategy-builder'].lifecycle;
  assertEquals(lifecycle, 'COMMERCIAL', `lifecycle changed to ${lifecycle} -- update this test's expected predicate before re-pinning`);
  const sql = await Deno.readTextFile(new URL('../../migrations/20261002000000_strategy_builder.sql', import.meta.url));
  const fn = sql.slice(sql.indexOf('FUNCTION public.strategy_builder_access_allowed()'), sql.indexOf('-- ── RLS'));
  assert(/p\.role IN \([^)]*'free'[^)]*\)/.test(fn), 'predicate must admit free');
  for (const role of ['free', 'pro', 'premium', 'beta_tester', 'admin']) {
    assert(fn.includes(`'${role}'`), `predicate must admit ${role} (mapLegacyProfileRole's five resolvable-plan roles)`);
  }
  assert(/SECURITY INVOKER/.test(fn) && !/SECURITY DEFINER/.test(fn), 'predicate must not expand privilege');
  const policies = [...sql.matchAll(/CREATE POLICY (\w+)[\s\S]*?;/g)];
  assertEquals(policies.length, 8, 'strategies(4) + strategy_versions(2) + strategy_backtest_results(2)');
  for (const p of policies) assert(p[0].includes('strategy_builder_access_allowed()'), `${p[1]} lacks the entitlement predicate`);
});

Deno.test('SB-49 (Codex adversarial review re-verification) strategy creation is atomic: one SECURITY DEFINER RPC does both inserts, direct INSERT on strategies is revoked, an idempotency unique index exists', async () => {
  const sql = await Deno.readTextFile(new URL('../../migrations/20261008000000_strategy_create_atomic.sql', import.meta.url));
  const fn = sql.slice(sql.indexOf('FUNCTION public.strategies_create_with_version'), sql.indexOf('REVOKE ALL ON FUNCTION public.strategies_create_with_version'));
  assert(/SECURITY DEFINER/.test(fn), 'must be SECURITY DEFINER to insert past the revoked direct-insert grant');
  assert(/auth\.uid\(\)/.test(fn), 'must re-derive identity server-side, never trust a parameter');
  assert(/strategy_builder_access_allowed\(\)/.test(fn), 'must re-check the same entitlement predicate the RLS policies use');
  assert(/INSERT INTO public\.strategies/.test(fn) && /INSERT INTO public\.strategy_versions/.test(fn), 'both inserts must happen inside this one function body (one transaction)');
  assert(/idempotency_key/.test(fn), 'must support a caller-supplied idempotency key');
  assert(/CREATE UNIQUE INDEX[^;]*strategies_user_idempotency_key_uq[^;]*\(user_id, idempotency_key\)/.test(sql), 'idempotency key must be unique per user');
  assert(/REVOKE INSERT ON public\.strategies FROM authenticated/.test(sql), 'direct INSERT bypass of the atomic RPC must be closed, mirroring 20261006000000/20261007000000');
  assert(/IDEMPOTENCY_KEY_CONFLICT/.test(fn), 'a key reused with a different spec must be rejected, never silently return the wrong row');
});

Deno.test('SB-50 (2nd Codex re-verification) the same idempotency key + the same spec on retry returns the ORIGINAL strategy, never a duplicate', async () => {
  store = new MemoryStore();
  const first = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT, idempotencyKey: 'retry-key-1' }, 'jwt-a', 'free');
  assertEquals(first.status, 200);
  const retry = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT, idempotencyKey: 'retry-key-1' }, 'jwt-a', 'free');
  assertEquals(retry.status, 200);
  assertEquals(retry.json.strategy.id, first.json.strategy.id);
  const list = await call({ op: 'list' }, 'jwt-a', 'free');
  assertEquals((list.json.strategies as unknown[]).length, 1, 'a genuine retry must never create a second strategy');
});

Deno.test('SB-51 (2nd Codex re-verification) the same idempotency key reused with a DIFFERENT spec is rejected, never silently satisfied with the wrong strategy', async () => {
  store = new MemoryStore();
  const first = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT, idempotencyKey: 'reused-key' }, 'jwt-a', 'free');
  assertEquals(first.status, 200);
  const differentSpec = { ...GENERIC_REFERENCE_SPEC_INPUT, name: 'A totally different strategy name' };
  const conflict = await call({ op: 'create', spec: differentSpec, idempotencyKey: 'reused-key' }, 'jwt-a', 'free');
  assertEquals(conflict.status, 409);
  assertEquals(conflict.json.error, 'IDEMPOTENCY_KEY_CONFLICT');
});

Deno.test('SB-52 a malformed idempotencyKey (empty or oversized) is a 400, and clone_reference honors the same key end-to-end', async () => {
  store = new MemoryStore();
  const empty = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT, idempotencyKey: '' }, 'jwt-a', 'free');
  assertEquals(empty.status, 400);
  const oversized = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT, idempotencyKey: 'x'.repeat(201) }, 'jwt-a', 'free');
  assertEquals(oversized.status, 400);
  const firstClone = await call({ op: 'clone_reference', reference: 'GENERIC', idempotencyKey: 'clone-retry-1' }, 'jwt-a', 'free');
  assertEquals(firstClone.status, 200);
  const retryClone = await call({ op: 'clone_reference', reference: 'GENERIC', idempotencyKey: 'clone-retry-1' }, 'jwt-a', 'free');
  assertEquals(retryClone.status, 200);
  assertEquals(retryClone.json.strategy.id, firstClone.json.strategy.id);
});

// ── Adversarial entitlement re-validation (Macro-08 continuation §29-30) ──
// After removing the global admin-only shield, every one of these must
// fail closed for a REAL non-admin persona, not just admin (the earlier
// forgery tests SB-38/39 used the implicit admin default).

Deno.test('SB-53 a real (non-admin) free user still cannot forge record_experiment category vs the actual result_kind', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-a', 'pro');
  const versionId = created.json.version.id;
  const bt = await call({ op: 'run_backtest', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' }, 'jwt-a', 'pro');
  const forged = await call({
    op: 'record_experiment', strategyVersionId: versionId, category: 'SIMULATION', datasetId: 'synthetic-fixture-5min-v1',
    segment: 'FULL', parametersChanged: null, reason: 'lying about the result kind as a real paying user', resultId: bt.json.result.id, source: 'USER',
  }, 'jwt-a', 'pro');
  assertEquals(forged.status, 400);
  assertEquals(store.experiments.length, 0);
});

Deno.test('SB-54 a real (non-admin) user cannot run any pro/premium research op against a strategy version owned by another user', async () => {
  store = new MemoryStore();
  const created = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-a', 'free');
  const versionId = created.json.version.id;
  const asOtherPro = await call({ op: 'propose_variants', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' }, 'jwt-b', 'pro');
  assertEquals(asOtherPro.status, 404, 'foreign ownership must be checked before/independently of the plan gate');
  const otherResearchLoop = await call({ op: 'run_research_loop', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' }, 'jwt-b', 'pro');
  assertEquals(otherResearchLoop.status, 404);
  const otherSimulation = await call({ op: 'run_simulation', strategyVersionId: versionId, datasetId: 'synthetic-fixture-5min-v1' }, 'jwt-b', 'premium');
  assertEquals(otherSimulation.status, 404);
});

Deno.test('SB-55 compare_versions and analyze_backtest_result refuse a version that belongs to another user, even for a real paying persona', async () => {
  store = new MemoryStore();
  const mine = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-a', 'pro');
  const myVersionId = mine.json.version.id;
  await call({ op: 'run_backtest', strategyVersionId: myVersionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' }, 'jwt-a', 'pro');
  const theirs = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT }, 'jwt-b', 'pro');
  const theirVersionId = theirs.json.version.id;
  await call({ op: 'run_backtest', strategyVersionId: theirVersionId, datasetId: 'synthetic-fixture-5min-v1', engineId: 'GENERIC_RULE_ENGINE' }, 'jwt-b', 'pro');

  const crossCompare = await call({ op: 'compare_versions', versionAId: myVersionId, versionBId: theirVersionId }, 'jwt-a', 'pro');
  assert(crossCompare.status === 404 || crossCompare.status === 400, `expected a fail-closed status, got ${crossCompare.status}`);

  const crossAnalyze = await call({ op: 'analyze_backtest_result', strategyVersionId: theirVersionId }, 'jwt-a', 'pro');
  assertEquals(crossAnalyze.status, 404);
});

Deno.test('SB-56 two different users reusing the IDENTICAL idempotency key string get independent strategies, never a cross-user collision', async () => {
  store = new MemoryStore();
  const mine = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT, idempotencyKey: 'shared-string-both-users-typed' }, 'jwt-a', 'free');
  const theirs = await call({ op: 'create', spec: GENERIC_REFERENCE_SPEC_INPUT, idempotencyKey: 'shared-string-both-users-typed' }, 'jwt-b', 'free');
  assertEquals(mine.status, 200);
  assertEquals(theirs.status, 200);
  assert(mine.json.strategy.id !== theirs.json.strategy.id, 'the idempotency key must be scoped per-user, never global');
});

Deno.test('SB-57 (§29: immutable version mutation, lifecycle self-promotion) the DB grants structurally forbid both, independent of any application logic bug', async () => {
  const base = await Deno.readTextFile(new URL('../../migrations/20261002000000_strategy_builder.sql', import.meta.url));
  assert(/GRANT UPDATE \(name\) ON public\.strategies TO authenticated/.test(base), 'strategies must only allow updating name -- never status/current_version (no self-promotion)');
  assertFalse(/GRANT UPDATE[^;]*ON public\.strategy_versions/.test(base), 'strategy_versions must never be updatable by authenticated -- a version is immutable once created');
  assertFalse(/GRANT[^;]*DELETE[^;]*ON public\.strategy_versions/.test(base), 'strategy_versions must never be deletable by authenticated');
  const create = await Deno.readTextFile(new URL('../../migrations/20261008000000_strategy_create_atomic.sql', import.meta.url));
  assert(/REVOKE INSERT ON public\.strategies FROM authenticated/.test(create), 'direct strategies INSERT must stay revoked -- creation only through the atomic RPC');
  const hardening = await Deno.readTextFile(new URL('../../migrations/20261007000000_strategy_backtest_results_hardening.sql', import.meta.url));
  assert(/REVOKE INSERT ON public\.strategy_backtest_results FROM authenticated/.test(hardening), 'direct strategy_backtest_results INSERT must stay revoked -- results only through the hardened RPC');
});
