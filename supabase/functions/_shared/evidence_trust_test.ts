/**
 * Cross-domain evidence-trust invariants — INSIGHTVALUES-INTELLIGENCE-
 * AUTOMATION-MACRO-04 §10-11. Each test states one invariant §11 names
 * explicitly and proves it holds for EVERY domain's real adapter
 * (evidence_trust.ts), not just one -- the whole point of a shared
 * vocabulary is that these properties hold everywhere it applies.
 *   deno test --allow-read supabase/functions/_shared/evidence_trust_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  type EvidenceConfidenceTier,
  impactClaimConfidenceTier,
  impactSourceConfidenceTier,
  isHigherConfidence,
  learningConfidenceTier,
  quantDataConfidenceTier,
} from './evidence_trust.ts';

Deno.test('EV-01 low-confidence evidence is never silently upgraded to HIGH', () => {
  // Impact: anything short of fully SUPPORTED stays below HIGH.
  for (const status of ['PARTIALLY_SUPPORTED', 'INCONCLUSIVE', 'OUTDATED', 'UNVERIFIED', 'CONTRADICTED', 'DISPUTED'] as const) {
    assert(impactClaimConfidenceTier(status) !== 'HIGH', status);
  }
  // Quant: weak strength never reaches HIGH, regardless of trust level.
  for (const trust of ['SYNTHETIC_FIXTURE', 'USER_SUPPLIED', 'PROVIDER_REPORTED'] as const) {
    assert(quantDataConfidenceTier(trust, 'WEAK') !== 'HIGH', trust);
  }
  // Learning: an unverified (non-SUCCESS) receipted result never reaches HIGH.
  assert(learningConfidenceTier('unverified') !== 'HIGH');
});

Deno.test('EV-02 conflicting/contested evidence remains at NONE, never merely "low" -- it is not the same as unchecked, but it is never positive either', () => {
  assertEquals(impactClaimConfidenceTier('CONTRADICTED'), 'NONE');
  assertEquals(impactClaimConfidenceTier('DISPUTED'), 'NONE');
  // Contested must not rank ABOVE genuinely unresolved/weak evidence --
  // there is nothing "better" about a contested claim than an inconclusive one.
  assert(!isHigherConfidence(impactClaimConfidenceTier('CONTRADICTED'), impactClaimConfidenceTier('INCONCLUSIVE')));
});

Deno.test('EV-03 unknown/absent authority remains unknown -- NONE-scope sources and never-submitted evidence carry no confidence', () => {
  assertEquals(impactSourceConfidenceTier('NONE'), 'NONE');
  assertEquals(impactSourceConfidenceTier('USER_SUBMITTED'), 'NONE');
  // Quant: synthetic/fixture data (no real authority behind it at all)
  // never reaches even MEDIUM, regardless of computational "strength".
  assertEquals(quantDataConfidenceTier('SYNTHETIC_FIXTURE', 'WEAK'), 'NONE');
  assert(quantDataConfidenceTier('SYNTHETIC_FIXTURE', 'STANDARD') !== 'HIGH');
  assert(quantDataConfidenceTier('SYNTHETIC_FIXTURE', 'STANDARD') !== 'MEDIUM');
});

Deno.test('EV-04 missing provenance does not become trusted provenance', () => {
  // Learning: a memory row with no AEF receipt at all (verificationState
  // null -- never went through governance) gets NO confidence from this
  // adapter, the same floor as an explicitly failed/contested one.
  assertEquals(learningConfidenceTier(null), 'NONE');
  assert(!isHigherConfidence(learningConfidenceTier(null), learningConfidenceTier('unverified')));
});

Deno.test('EV-05 inference/partial evidence remains distinguishable from fully verified evidence, in every domain', () => {
  // Impact: a partial claim must rank strictly below a fully supported one.
  assert(isHigherConfidence(impactClaimConfidenceTier('SUPPORTED'), impactClaimConfidenceTier('PARTIALLY_SUPPORTED')));
  assert(isHigherConfidence(impactClaimConfidenceTier('PARTIALLY_SUPPORTED'), impactClaimConfidenceTier('INCONCLUSIVE')));
  // Quant: user-supplied (real but not provider-verified) ranks strictly
  // below provider-reported, at the same (standard) strength.
  assert(isHigherConfidence(quantDataConfidenceTier('PROVIDER_REPORTED', 'STANDARD'), quantDataConfidenceTier('USER_SUPPLIED', 'STANDARD')));
  // Learning: verified (a real SUCCESS receipt) strictly outranks
  // unverified (a real receipt, but not SUCCESS) -- the execution FACT
  // being real in both cases must never blur this distinction.
  assert(isHigherConfidence(learningConfidenceTier('verified'), learningConfidenceTier('unverified')));
});

Deno.test('EV-06 every adapter is total -- no real domain value is left unmapped (fails closed, not silently undefined)', () => {
  const claimStatuses = ['UNVERIFIED', 'SUPPORTED', 'PARTIALLY_SUPPORTED', 'CONTRADICTED', 'INCONCLUSIVE', 'OUTDATED', 'DISPUTED'] as const;
  const authorityScopes = ['AUTHORITATIVE', 'INDEPENDENT', 'SELF_REPORTED', 'USER_SUBMITTED', 'ATTRIBUTION_ONLY', 'CONTEXTUAL', 'NONE'] as const;
  const trustLevels = ['SYNTHETIC_FIXTURE', 'USER_SUPPLIED', 'PROVIDER_REPORTED'] as const;
  const strengths = ['STANDARD', 'WEAK'] as const;
  const valid: readonly EvidenceConfidenceTier[] = ['HIGH', 'MEDIUM', 'LOW', 'NONE'];
  for (const s of claimStatuses) assert(valid.includes(impactClaimConfidenceTier(s)), s);
  for (const s of authorityScopes) assert(valid.includes(impactSourceConfidenceTier(s)), s);
  for (const t of trustLevels) for (const st of strengths) assert(valid.includes(quantDataConfidenceTier(t, st)), `${t}/${st}`);
  for (const v of ['verified', 'unverified', null] as const) assert(valid.includes(learningConfidenceTier(v)), String(v));
});
