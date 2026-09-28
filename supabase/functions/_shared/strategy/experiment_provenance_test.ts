import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { computeContamination, validateStrategyExperimentInput, type StrategyExperimentInput } from './experiment_provenance.ts';

function baseInput(overrides: Partial<StrategyExperimentInput> = {}): StrategyExperimentInput {
  return {
    strategyId: 's1', strategyVersionId: 'v1', category: 'BACKTEST', datasetId: 'd1', segment: 'FULL',
    parametersChanged: null, reason: 'baseline run', resultId: null, costAssumptions: null, source: 'USER', ...overrides,
  };
}

Deno.test('EP-01 accepts a well-formed experiment input', () => {
  const r = validateStrategyExperimentInput(baseInput());
  assert(r.ok);
});

Deno.test('EP-02 rejects an unknown category/segment/source', () => {
  assert(!validateStrategyExperimentInput(baseInput({ category: 'NOT_REAL' as never })).ok);
  assert(!validateStrategyExperimentInput(baseInput({ segment: 'NOT_REAL' as never })).ok);
  assert(!validateStrategyExperimentInput(baseInput({ source: 'NOT_REAL' as never })).ok);
});

Deno.test('EP-03 rejects an empty or missing reason -- every experiment must state why it ran', () => {
  assert(!validateStrategyExperimentInput(baseInput({ reason: '' })).ok);
  assert(!validateStrategyExperimentInput(baseInput({ reason: '   ' })).ok);
  assert(!validateStrategyExperimentInput(baseInput({ reason: 'x'.repeat(501) })).ok);
});

Deno.test('EP-04 rejects parametersChanged that is an array instead of a plain object', () => {
  const r = validateStrategyExperimentInput(baseInput({ parametersChanged: [1, 2, 3] as never }));
  assert(!r.ok);
});

Deno.test('EP-05 accepts a real parametersChanged object', () => {
  const r = validateStrategyExperimentInput(baseInput({ parametersChanged: { 'stop.distance': { from: 100, to: 110 } } }));
  assert(r.ok);
});

Deno.test('EP-06 computeContamination: false when the strategy has never had a HOLDOUT experiment', () => {
  assertEquals(computeContamination(null, '2026-01-01T00:00:00Z', false), false);
});

Deno.test('EP-07 computeContamination: a candidate created AFTER the first holdout view is contaminated', () => {
  assertEquals(computeContamination('2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', false), true);
});

Deno.test('EP-08 computeContamination: a candidate created BEFORE the first holdout view is not contaminated', () => {
  assertEquals(computeContamination('2026-01-05T00:00:00Z', '2026-01-01T00:00:00Z', false), false);
});

Deno.test('EP-09 computeContamination: the holdout experiment itself is never contaminated by its own first view', () => {
  assertEquals(computeContamination('2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', true), false);
});

Deno.test('EP-10 computeContamination: a LATER holdout re-run after the first view IS contaminated (it is not the first anymore)', () => {
  assertEquals(computeContamination('2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', true), true);
});
