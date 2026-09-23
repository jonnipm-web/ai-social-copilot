/**
 * Temporal consistency — IV-IMPACT-FOUNDATION-01.
 *
 * A registration valid in 2023 does not prove status in 2026; an old
 * allegation may since have been dismissed. Two rules, both deterministic
 * and driven by an injected `evaluatedAt` (never the wall clock):
 *
 *  1 STATE claims (registration, regulatory status, governance, affiliation)
 *    describe something that can change. Evidence older than the max age
 *    below is STALE: it is kept and shown, but cannot establish the current
 *    state → the claim becomes OUTDATED when only stale evidence exists.
 *  2 PERIOD claims (outputs, outcomes, financial years, beneficiary counts)
 *    are about a period. Evidence whose observed period does not overlap the
 *    claim's period is PERIOD_MISMATCH and is not counted.
 */
import { parseIsoMs } from './provenance.ts';
import type { ClaimKind, Period } from './types.ts';

export const TEMPORAL_POLICY_VERSION = 'impact-temporal/2';

const DAY_MS = 86_400_000;

/** Max evidence age (days) for STATE claims. Absent = not a state claim. */
export const STATE_CLAIM_MAX_AGE_DAYS: Readonly<Partial<Record<ClaimKind, number>>> = Object.freeze({
  LEGAL_REGISTRATION: 365,
  REGULATORY_STATUS: 365,
  GOVERNANCE: 365,
  AFFILIATION: 180,
});

export function isStateClaim(kind: ClaimKind): boolean {
  return STATE_CLAIM_MAX_AGE_DAYS[kind] !== undefined;
}

/** Point in time the evidence speaks about: the EARLIEST of the end of its
 * observed period, the publication date and the retrieval date. A source
 * cannot speak about anything later than when it was published/retrieved,
 * so a future-dated `observedPeriod.to` can never make old evidence look
 * current (Codex G1-02). */
export function evidenceAsOfMs(observed: Period | undefined, publishedAt: string | undefined, retrievedAt: string): number {
  const candidates = [parseIsoMs(observed?.to), parseIsoMs(publishedAt), parseIsoMs(retrievedAt)]
    .filter((v): v is number => v !== null);
  return Math.min(...candidates);
}

export function isStale(kind: ClaimKind, asOfMs: number, evaluatedAtMs: number): boolean {
  const maxDays = STATE_CLAIM_MAX_AGE_DAYS[kind];
  if (maxDays === undefined) return false;
  return evaluatedAtMs - asOfMs > maxDays * DAY_MS;
}

/** Inclusive overlap. Unknown bounds are open (−∞/+∞): missing information
 * never creates a mismatch on its own. */
export function periodsOverlap(a: Period | undefined, b: Period | undefined): boolean {
  if (!a || !b) return true;
  const aFrom = parseIsoMs(a.from) ?? -Infinity;
  const aTo = parseIsoMs(a.to) ?? Infinity;
  const bFrom = parseIsoMs(b.from) ?? -Infinity;
  const bTo = parseIsoMs(b.to) ?? Infinity;
  return aFrom <= bTo && bFrom <= aTo;
}
