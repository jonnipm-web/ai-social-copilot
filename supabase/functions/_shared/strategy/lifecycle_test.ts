import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { canPromote, type PromotionEvidence } from './lifecycle.ts';

const NO_EVIDENCE: PromotionEvidence = {
  hasValidSpec: false,
  hasBacktestResult: false,
  ownerAuthorizedSimulationOrAbove: false,
};

Deno.test('LC-01 DRAFT -> VALIDATED requires hasValidSpec evidence', () => {
  const denied = canPromote('DRAFT', 'VALIDATED', NO_EVIDENCE);
  assert(!denied.ok);
  assertEquals(denied.ok ? null : denied.error.code, 'PROMOTION_DENIED');

  const allowed = canPromote('DRAFT', 'VALIDATED', { ...NO_EVIDENCE, hasValidSpec: true });
  assert(allowed.ok);
});

Deno.test('LC-02 VALIDATED -> BACKTESTED requires hasBacktestResult evidence', () => {
  const denied = canPromote('VALIDATED', 'BACKTESTED', { ...NO_EVIDENCE, hasValidSpec: true });
  assert(!denied.ok);

  const allowed = canPromote('VALIDATED', 'BACKTESTED', { ...NO_EVIDENCE, hasValidSpec: true, hasBacktestResult: true });
  assert(allowed.ok);
});

Deno.test('LC-03 BACKTESTED -> RESEARCH is automatic once backtested', () => {
  const result = canPromote('BACKTESTED', 'RESEARCH', { ...NO_EVIDENCE, hasValidSpec: true, hasBacktestResult: true });
  assert(result.ok);
});

Deno.test('LC-04 RESEARCH -> SIMULATION_ELIGIBLE/PAPER_ELIGIBLE/LIVE_ELIGIBLE are ALWAYS denied this macro, even with every other evidence flag true', () => {
  const fullEvidenceButNoOwnerAuth: PromotionEvidence = {
    hasValidSpec: true,
    hasBacktestResult: true,
    ownerAuthorizedSimulationOrAbove: false,
  };
  for (const target of ['SIMULATION_ELIGIBLE', 'PAPER_ELIGIBLE', 'LIVE_ELIGIBLE'] as const) {
    const result = canPromote('RESEARCH', target, fullEvidenceButNoOwnerAuth);
    assert(!result.ok, target);
    assertEquals(result.ok ? null : result.error.code, 'PROMOTION_DENIED');
  }
});

Deno.test('LC-05 a gated promotion still requires RESEARCH as the current status even if ownerAuthorized were somehow true', () => {
  const hypotheticallyAuthorized: PromotionEvidence = {
    hasValidSpec: true,
    hasBacktestResult: true,
    ownerAuthorizedSimulationOrAbove: true,
  };
  const fromDraft = canPromote('DRAFT', 'SIMULATION_ELIGIBLE', hypotheticallyAuthorized);
  assert(!fromDraft.ok);
});

Deno.test('LC-06 RETIRED has no automatic outgoing transitions', () => {
  const result = canPromote('RETIRED', 'RESEARCH', { ...NO_EVIDENCE, hasValidSpec: true, hasBacktestResult: true });
  assert(!result.ok);
});

Deno.test('LC-07 a no-op transition (current === target) is denied', () => {
  const result = canPromote('RESEARCH', 'RESEARCH', NO_EVIDENCE);
  assert(!result.ok);
});
