import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  analyzeSegmentStability, directionalBalance, executionAmbiguityRate, sampleSizeSufficiency,
} from './robustness.ts';
import { buildCanonicalBacktestResult, type CanonicalBacktestResult, type CanonicalBacktestResultInput } from './backtest_result.ts';
import { SMALL_SAMPLE_THRESHOLD } from './ive_strategy_analyst.ts';

function baseInput(overrides: Partial<CanonicalBacktestResultInput> = {}): CanonicalBacktestResultInput {
  return {
    strategyId: 's1', strategyVersion: 1, strategySpecHash: 'h1', datasetId: 'd1', datasetHash: 'dh1',
    instrumentSymbol: 'SYNTH1', periodStart: '2026-01-01T00:00:00Z', periodEnd: '2026-01-02T00:00:00Z',
    timeframes: ['5min'], tradeCount: 10, longCount: 10, shortCount: 0, wins: 5, losses: 5,
    grossPnl: 10, grossProfit: 60, grossLoss: 50, totalCost: 0, netPnl: 10, maxDrawdown: -20,
    targetTouches: 5, stopTouches: 5, executionAmbiguityCount: 2, methodologyStatus: 'ZERO_COST_RESEARCH',
    costAssumptions: null, limitations: [], provenance: 'test', ...overrides,
  };
}

async function build(overrides: Partial<CanonicalBacktestResultInput> = {}): Promise<CanonicalBacktestResult> {
  const r = await buildCanonicalBacktestResult(baseInput(overrides));
  assert(r.ok);
  if (!r.ok) throw new Error('unreachable');
  return r.value;
}

Deno.test('RB-01 sampleSizeSufficiency uses the shared SMALL_SAMPLE_THRESHOLD, not a private duplicate', async () => {
  const small = await build({ tradeCount: 5, longCount: 5, wins: 3, losses: 2 });
  const big = await build({ tradeCount: SMALL_SAMPLE_THRESHOLD, longCount: SMALL_SAMPLE_THRESHOLD, wins: 20, losses: 10 });
  assertEquals(sampleSizeSufficiency(small), { tradeCount: 5, threshold: SMALL_SAMPLE_THRESHOLD, sufficient: false });
  assertEquals(sampleSizeSufficiency(big).sufficient, true);
});

Deno.test('RB-02 executionAmbiguityRate divides real fields, and reports null rather than NaN with zero trades', async () => {
  const r = await build({ tradeCount: 10, executionAmbiguityCount: 2 });
  assertEquals(executionAmbiguityRate(r), { ambiguousCount: 2, tradeCount: 10, rate: 0.2 });
  const zero = await build({ tradeCount: 0, longCount: 0, shortCount: 0, wins: 0, losses: 0, grossPnl: 0, grossProfit: 0, grossLoss: 0, netPnl: 0, targetTouches: 0, stopTouches: 0, executionAmbiguityCount: 0 });
  assertEquals(executionAmbiguityRate(zero).rate, null);
});

Deno.test('RB-03 directionalBalance flags the untested side when a strategy only ever traded one direction', async () => {
  const longOnly = await build({ longCount: 10, shortCount: 0 });
  const finding = directionalBalance(longOnly);
  assertEquals(finding.untested, 'SHORT');
  assertEquals(finding.longFraction, 1);
});

Deno.test('RB-04 directionalBalance reports no untested side once both directions have real trades', async () => {
  const both = await build({ tradeCount: 10, longCount: 6, shortCount: 4 });
  const finding = directionalBalance(both);
  assertEquals(finding.untested, null);
  assertEquals(finding.longFraction, 0.6);
});

Deno.test('RB-05 analyzeSegmentStability: STABLE when research and holdout net P&L share the same sign', async () => {
  const research = await build({ strategyId: 's1', strategyVersion: 1, datasetId: 'seg-research', netPnl: 10, grossPnl: 10 });
  const holdout = await build({ strategyId: 's1', strategyVersion: 1, datasetId: 'seg-holdout', periodStart: '2026-02-01T00:00:00Z', periodEnd: '2026-02-02T00:00:00Z', netPnl: 5, grossPnl: 5 });
  const finding = analyzeSegmentStability(research, holdout);
  assertEquals(finding.status, 'STABLE');
  assertEquals(finding.netPnlSignConsistent, true);
});

Deno.test('RB-06 analyzeSegmentStability: SIGN_FLIP when research was profitable and holdout was not (the documented synthetic-fixture case)', async () => {
  const research = await build({ strategyId: 's1', strategyVersion: 1, datasetId: 'seg-research', netPnl: 10, grossPnl: 10 });
  const holdout = await build({ strategyId: 's1', strategyVersion: 1, datasetId: 'seg-holdout', periodStart: '2026-02-01T00:00:00Z', periodEnd: '2026-02-02T00:00:00Z', netPnl: -5, grossPnl: -5 });
  const finding = analyzeSegmentStability(research, holdout);
  assertEquals(finding.status, 'SIGN_FLIP');
  assertEquals(finding.netPnlSignConsistent, false);
});

Deno.test('RB-07 analyzeSegmentStability: NOT_COMPARABLE across different strategies -- never silently compared', async () => {
  const research = await build({ strategyId: 's1' });
  const holdout = await build({ strategyId: 's2' });
  const finding = analyzeSegmentStability(research, holdout);
  assertEquals(finding.status, 'NOT_COMPARABLE');
  assert(finding.incomparabilityReasons.length > 0);
  assertEquals(finding.researchNetPnl, null);
});

Deno.test('RB-08 analyzeSegmentStability tolerates different datasetId/period between segments -- that is the whole point of a holdout split', async () => {
  const research = await build({ datasetId: 'seg-research', periodStart: '2026-01-01T00:00:00Z', periodEnd: '2026-01-01T01:00:00Z' });
  const holdout = await build({ datasetId: 'seg-holdout', periodStart: '2026-02-01T00:00:00Z', periodEnd: '2026-02-01T01:00:00Z' });
  const finding = analyzeSegmentStability(research, holdout);
  assert(finding.status !== 'NOT_COMPARABLE');
});
