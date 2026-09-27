/**
 * Epistemic status & Estimates — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 §20,
 * §24.
 *
 * IVE Strategy Analyst output must never blur "this is what the backtest
 * measured" with "this is what I think might happen." Every claim IVE
 * makes about a strategy carries one of these statuses, and every
 * ESTIMATE/INFERENCE/HYPOTHESIS carries the provenance §24 requires
 * (source period, sample size, assumptions, limitations) -- a bare number
 * with no EpistemicStatus attached is not a valid IVE Strategy Analyst
 * output.
 */
import { fail, ok, type StrategyResult } from './errors.ts';

/**
 * MEASURED       a value read directly off a CanonicalBacktestResult --
 *                no interpretation applied.
 * ESTIMATE       a numeric projection derived from measured evidence with
 *                stated assumptions (e.g. "if costs rose 20%...").
 * INFERENCE      a qualitative conclusion drawn from measured evidence
 *                (e.g. "this sample is too small to judge robustness").
 * HYPOTHESIS     an untested idea for further research, not yet backed by
 *                any backtest.
 * RECOMMENDATION a suggested next action -- never a promise of outcome.
 * UNKNOWN        IVE explicitly has insufficient evidence to say anything
 *                on this question -- the honest alternative to silence or
 *                fabrication.
 */
export type EpistemicStatus = 'MEASURED' | 'ESTIMATE' | 'INFERENCE' | 'HYPOTHESIS' | 'RECOMMENDATION' | 'UNKNOWN';

export interface EstimateProvenance {
  readonly sourcePeriodStart: string; // ISO 8601
  readonly sourcePeriodEnd: string; // ISO 8601
  readonly sampleSize: number;
  readonly dataSource: string;
  readonly assumptions: readonly string[];
  readonly costModelDescription: string | null;
  /** Free-text confidence/uncertainty note. Deliberately a string, not a
   * fabricated numeric confidence interval this codebase cannot actually
   * compute yet (§21: "Do not invent metrics unsupported by current Quant
   * implementation"). */
  readonly confidenceNote: string | null;
  readonly limitations: readonly string[];
}

export interface EpistemicClaim<T> {
  readonly status: EpistemicStatus;
  readonly value: T;
  readonly statement: string;
  /** Required for ESTIMATE/INFERENCE/HYPOTHESIS; optional (and typically
   * absent) for MEASURED, whose provenance is the CanonicalBacktestResult
   * itself; never present for RECOMMENDATION/UNKNOWN. */
  readonly provenance: EstimateProvenance | null;
}

const PROVENANCE_REQUIRED: ReadonlySet<EpistemicStatus> = new Set(['ESTIMATE', 'INFERENCE', 'HYPOTHESIS']);

/** Constructs a claim, refusing to build an ESTIMATE/INFERENCE/HYPOTHESIS
 * with no stated provenance -- fabricated financial expertise (§23) most
 * often looks exactly like a confident number with nothing behind it. */
export function buildEpistemicClaim<T>(
  status: EpistemicStatus,
  value: T,
  statement: string,
  provenance: EstimateProvenance | null,
): StrategyResult<EpistemicClaim<T>> {
  if (PROVENANCE_REQUIRED.has(status) && !provenance) {
    return fail('INVALID_STRATEGY_SPEC', `EpistemicStatus ${status} requires provenance`, { status });
  }
  return ok(Object.freeze({ status, value, statement, provenance: provenance ? Object.freeze({ ...provenance }) : null }));
}
