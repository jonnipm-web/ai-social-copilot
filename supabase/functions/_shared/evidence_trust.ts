/**
 * Shared evidence-trust semantics — INSIGHTVALUES-INTELLIGENCE-AUTOMATION-
 * MACRO-04 §10-11.
 *
 * Impact (impact/source_authority.ts's AuthorityScope, impact/types.ts's
 * ClaimStatus), Quant (quant/provenance.ts's TrustLevel/EvidenceStrength)
 * and Result -> Learning (business_memory.verification_state, this
 * mission's own §7-9 work) each independently arrived at the same
 * underlying principle: evidence carries an explicit trust grading, and
 * weak/absent/contested evidence must never be silently presented as
 * confirmed. This module does NOT merge their concrete models -- Impact's
 * seven-value ClaimStatus lifecycle and Quant's provider/strength pair
 * encode real, different, domain-specific distinctions that a shared type
 * would flatten and lose. §10 is explicit: "Do NOT force Impact and Quant
 * to share one concrete evidence object."
 *
 * What genuinely IS shared, and is worth a shared type for, is the one
 * question IVE's context assembly needs answered identically regardless of
 * which domain a piece of injected context came from: how much weight can
 * this be given, at all. [EvidenceConfidenceTier] is that answer, and the
 * adapters below are the ONLY place each domain's real status is
 * translated into it -- never reinterpreted, never upgraded.
 */
import type { AuthorityScope } from './impact/source_authority.ts';
import type { ClaimStatus } from './impact/types.ts';
import type { EvidenceStrength, TrustLevel } from './quant/provenance.ts';

/**
 * HIGH    a real, positively confirmed fact (Impact: SUPPORTED by
 *         independent/authoritative sources; Quant: standard-strength,
 *         provider-reported data; Learning: a real AEF SUCCESS receipt).
 * MEDIUM  a real signal, not yet fully confirmed (Impact:
 *         PARTIALLY_SUPPORTED; Quant: standard-strength, user-supplied
 *         data).
 * LOW     real but weak or unresolved (Impact: INCONCLUSIVE/OUTDATED;
 *         Quant: weak-strength, non-synthetic data; Learning: a receipted
 *         but non-SUCCESS outcome).
 * NONE    no positive confidence at all -- includes actively CONTESTED
 *         evidence (Impact: CONTRADICTED/DISPUTED), never-verified claims
 *         (UNVERIFIED), synthetic/fixture data presented as real (Quant),
 *         and anything with no governed provenance at all (Learning: not
 *         AEF-derived). Contested is NOT "low positive confidence" --
 *         it is the same absence of confidence as never having been
 *         checked, by design (see EV-* invariant tests).
 */
export type EvidenceConfidenceTier = 'HIGH' | 'MEDIUM' | 'LOW' | 'NONE';

const TIER_ORDER: Readonly<Record<EvidenceConfidenceTier, number>> = { NONE: 0, LOW: 1, MEDIUM: 2, HIGH: 3 };

/** True when `a` is a strictly higher confidence tier than `b`. */
export function isHigherConfidence(a: EvidenceConfidenceTier, b: EvidenceConfidenceTier): boolean {
  return TIER_ORDER[a] > TIER_ORDER[b];
}

/**
 * Impact (impact/types.ts ClaimStatus). Authority (who may even move a
 * claim off UNVERIFIED) is already enforced inside Impact's own domain
 * logic (source_authority.ts's isIndependentScope) before a ClaimStatus is
 * ever produced -- this adapter only translates the resulting status, it
 * does not re-derive or second-guess Impact's own promotion decision.
 */
export function impactClaimConfidenceTier(status: ClaimStatus): EvidenceConfidenceTier {
  switch (status) {
    case 'SUPPORTED':
      return 'HIGH';
    case 'PARTIALLY_SUPPORTED':
      return 'MEDIUM';
    case 'INCONCLUSIVE':
    case 'OUTDATED':
      return 'LOW';
    case 'UNVERIFIED':
    case 'CONTRADICTED':
    case 'DISPUTED':
      return 'NONE';
  }
}

/** Impact (impact/source_authority.ts AuthorityScope) on its own, for a
 * single source's weight independent of any claim it was used in. */
export function impactSourceConfidenceTier(scope: AuthorityScope): EvidenceConfidenceTier {
  switch (scope) {
    case 'AUTHORITATIVE':
      return 'HIGH';
    case 'INDEPENDENT':
      return 'MEDIUM';
    case 'SELF_REPORTED':
    case 'ATTRIBUTION_ONLY':
    case 'CONTEXTUAL':
      return 'LOW';
    case 'USER_SUBMITTED':
    case 'NONE':
      return 'NONE';
  }
}

/**
 * Quant (quant/provenance.ts DataProvenance's trust + strength pair).
 * Synthetic/fixture data is NEVER promoted above LOW regardless of
 * "strength" -- strength describes statistical confidence in a
 * computation, not whether the underlying data was ever real.
 */
export function quantDataConfidenceTier(trust: TrustLevel, strength: EvidenceStrength): EvidenceConfidenceTier {
  if (trust === 'SYNTHETIC_FIXTURE') return strength === 'STANDARD' ? 'LOW' : 'NONE';
  if (strength === 'WEAK') return 'LOW';
  return trust === 'PROVIDER_REPORTED' ? 'HIGH' : 'MEDIUM';
}

/**
 * Result -> Learning (business_memory.verification_state, §7-9 of this
 * mission). `null` means the row is not AEF-derived at all -- there is no
 * governed claim here to weigh, so it gets NO confidence from this adapter
 * (a caller wanting to trust plain user-authored memory does so through a
 * different signal entirely, not this one).
 */
export function learningConfidenceTier(verificationState: 'verified' | 'unverified' | null): EvidenceConfidenceTier {
  if (verificationState === 'verified') return 'HIGH';
  if (verificationState === 'unverified') return 'LOW';
  return 'NONE';
}
