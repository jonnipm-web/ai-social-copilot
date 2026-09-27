/**
 * Financial data provenance + freshness — IV-QUANT-FOUNDATION-01
 * (QUANT_DATA_MODEL.md §3–§4).
 *
 * Every dataset the engine analyzes carries a DataProvenance. An analysis
 * built on incomplete provenance is still computed (the math does not
 * change) but its evidence strength is downgraded to WEAK and a
 * PROVENANCE_WEAK warning is attached — it must never be presented as
 * strong evidence.
 *
 * Freshness is a pure function of (data as-of time, injected `now`, policy).
 * The engine never reads the wall clock itself, so results are reproducible
 * and tests are deterministic. No state here ever means "live price": the
 * best a daily series can be is FRESH relative to the policy for its
 * frequency.
 */
import { fail, ok, type QuantResult } from './errors.ts';

export type Frequency = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'INTRADAY_1M' | 'INTRADAY_5M' | 'INTRADAY_1H';
export const ALL_FREQUENCIES: readonly Frequency[] = ['DAILY', 'WEEKLY', 'MONTHLY', 'INTRADAY_1M', 'INTRADAY_5M', 'INTRADAY_1H'];

export type ProviderKind = 'FIXTURE' | 'USER_UPLOAD' | 'EXTERNAL_PROVIDER';
export type AdjustmentPolicy = 'UNADJUSTED' | 'SPLIT_ADJUSTED' | 'SPLIT_AND_DIVIDEND_ADJUSTED' | 'UNKNOWN';
export type TrustLevel = 'SYNTHETIC_FIXTURE' | 'USER_SUPPLIED' | 'PROVIDER_REPORTED';
export type EvidenceStrength = 'STANDARD' | 'WEAK';

export interface DataProvenance {
  /** Stable provider id (e.g. 'fixture-golden', 'user-csv'). */
  readonly providerId: string;
  readonly providerKind: ProviderKind;
  /** Market time the newest datum refers to (ISO 8601 UTC), when known. */
  readonly sourceAsOf?: string;
  /** When the system obtained the data (ISO 8601 UTC). Required. */
  readonly retrievedAt: string;
  readonly frequency: Frequency;
  readonly currency: string;
  readonly adjustment: AdjustmentPolicy;
  readonly trust: TrustLevel;
  /** Free-form, non-authoritative label (e.g. uploaded file name). Never parsed. */
  readonly sourceLabel?: string;
}

const ISO_UTC_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$/;
const PROVIDER_ID_RE = /^[a-z0-9][a-z0-9_-]{0,63}$/;

export function parseIsoUtc(s: unknown): number | null {
  if (typeof s !== 'string' || !ISO_UTC_RE.test(s)) return null;
  const t = Date.parse(s);
  return Number.isFinite(t) ? t : null;
}

export function validateProvenance(p: DataProvenance): QuantResult<DataProvenance> {
  if (!p || typeof p !== 'object') return fail('INVALID_DATASET', 'provenance required');
  if (!PROVIDER_ID_RE.test(p.providerId ?? '')) return fail('INVALID_DATASET', 'invalid providerId', { field: 'providerId' });
  if (!['FIXTURE', 'USER_UPLOAD', 'EXTERNAL_PROVIDER'].includes(p.providerKind)) {
    return fail('INVALID_DATASET', 'invalid providerKind', { field: 'providerKind' });
  }
  if (parseIsoUtc(p.retrievedAt) === null) return fail('INVALID_DATASET', 'retrievedAt must be ISO 8601 UTC', { field: 'retrievedAt' });
  if (p.sourceAsOf !== undefined) {
    const asOf = parseIsoUtc(p.sourceAsOf);
    if (asOf === null) return fail('INVALID_DATASET', 'sourceAsOf must be ISO 8601 UTC', { field: 'sourceAsOf' });
    // Data cannot be retrieved before the moment it describes (5 min clock-skew allowance).
    if (asOf > (parseIsoUtc(p.retrievedAt) as number) + 5 * 60_000) {
      return fail('INVALID_DATASET', 'sourceAsOf is later than retrievedAt', { field: 'sourceAsOf' });
    }
  }
  if (!ALL_FREQUENCIES.includes(p.frequency)) return fail('INVALID_DATASET', 'invalid frequency', { field: 'frequency' });
  if (!/^[A-Z]{3}$/.test(p.currency ?? '')) return fail('INVALID_DATASET', 'currency must be ISO 4217', { field: 'currency' });
  if (!['UNADJUSTED', 'SPLIT_ADJUSTED', 'SPLIT_AND_DIVIDEND_ADJUSTED', 'UNKNOWN'].includes(p.adjustment)) {
    return fail('INVALID_DATASET', 'invalid adjustment', { field: 'adjustment' });
  }
  if (!['SYNTHETIC_FIXTURE', 'USER_SUPPLIED', 'PROVIDER_REPORTED'].includes(p.trust)) {
    return fail('INVALID_DATASET', 'invalid trust', { field: 'trust' });
  }
  // Trust must be consistent with where the data came from: a user upload can
  // never claim to be provider-reported, and a fixture is always synthetic.
  const expectedTrust: Record<ProviderKind, TrustLevel> = {
    FIXTURE: 'SYNTHETIC_FIXTURE',
    USER_UPLOAD: 'USER_SUPPLIED',
    EXTERNAL_PROVIDER: 'PROVIDER_REPORTED',
  };
  if (expectedTrust[p.providerKind] !== p.trust) {
    return fail('INVALID_DATASET', 'trust level inconsistent with providerKind', { field: 'trust' });
  }
  return ok(p);
}

/** WEAK when the provenance cannot support a strong claim: user-supplied or
 * synthetic data, unknown adjustment, or unknown market as-of. */
export function evidenceStrength(p: DataProvenance): EvidenceStrength {
  if (p.trust !== 'PROVIDER_REPORTED') return 'WEAK';
  if (p.adjustment === 'UNKNOWN') return 'WEAK';
  if (p.sourceAsOf === undefined) return 'WEAK';
  return 'STANDARD';
}

// ---------------------------------------------------------------------------
// Freshness
// ---------------------------------------------------------------------------

export type FreshnessState = 'FRESH' | 'DELAYED' | 'STALE' | 'UNKNOWN';

export interface FreshnessPolicy {
  /** age <= freshMaxMs → FRESH */
  readonly freshMaxMs: number;
  /** freshMaxMs < age <= delayedMaxMs → DELAYED; beyond → STALE */
  readonly delayedMaxMs: number;
  /** A data time further than this in the future is a clock/provider error → UNKNOWN. */
  readonly futureToleranceMs: number;
}

const MIN = 60_000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

/**
 * Default policies. CALENDAR-NAIVE: there is no exchange calendar in the
 * Foundation, so daily thresholds are wide enough to span a weekend plus one
 * holiday (the last daily bar on a Tuesday morning after a Monday holiday is
 * Friday's — ~4 days old). Documented in QUANT_DATA_MODEL.md §4.
 */
export const DEFAULT_FRESHNESS_POLICIES: Readonly<Record<Frequency, FreshnessPolicy>> = {
  INTRADAY_1M: { freshMaxMs: 2 * MIN, delayedMaxMs: 20 * MIN, futureToleranceMs: MIN },
  INTRADAY_5M: { freshMaxMs: 10 * MIN, delayedMaxMs: 30 * MIN, futureToleranceMs: MIN },
  INTRADAY_1H: { freshMaxMs: 2 * HOUR, delayedMaxMs: 6 * HOUR, futureToleranceMs: MIN },
  DAILY: { freshMaxMs: 4 * DAY, delayedMaxMs: 7 * DAY, futureToleranceMs: DAY },
  WEEKLY: { freshMaxMs: 10 * DAY, delayedMaxMs: 21 * DAY, futureToleranceMs: DAY },
  MONTHLY: { freshMaxMs: 35 * DAY, delayedMaxMs: 70 * DAY, futureToleranceMs: DAY },
};

export interface FreshnessAssessment {
  readonly state: FreshnessState;
  /** Age in ms of the newest datum relative to `now`; null when unknown. */
  readonly ageMs: number | null;
  readonly asOf: string | null;
  /** null only when the injected clock itself is unusable. */
  readonly evaluatedAt: string | null;
}

/** ECMAScript Date range limit (±8.64e15 ms). */
export const MAX_DATE_MS = 8.64e15;

export function assessFreshness(
  asOfMs: number | null,
  nowMs: number,
  policy: FreshnessPolicy,
): FreshnessAssessment {
  // Claude finding CL-02: toISOString() throws RangeError outside the Date
  // range, so every conversion is guarded — an unusable clock or timestamp
  // yields UNKNOWN, never an exception.
  const iso = (ms: number | null): string | null =>
    ms !== null && Number.isFinite(ms) && Math.abs(ms) <= MAX_DATE_MS ? new Date(ms).toISOString() : null;
  const evaluatedAt = iso(nowMs);
  const asOf = iso(asOfMs);
  if (asOf === null || evaluatedAt === null) return { state: 'UNKNOWN', ageMs: null, asOf, evaluatedAt };
  asOfMs = asOfMs as number;
  const age = nowMs - asOfMs;
  if (age < -policy.futureToleranceMs) return { state: 'UNKNOWN', ageMs: age, asOf, evaluatedAt };
  const ageMs = Math.max(0, age);
  const state: FreshnessState = ageMs <= policy.freshMaxMs ? 'FRESH' : ageMs <= policy.delayedMaxMs ? 'DELAYED' : 'STALE';
  return { state, ageMs, asOf, evaluatedAt };
}
