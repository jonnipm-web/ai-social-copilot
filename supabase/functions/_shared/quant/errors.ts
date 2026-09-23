/**
 * Quant error contract — IV-QUANT-FOUNDATION-01.
 *
 * `code` is the logical contract (stable, machine-readable). `message` is a
 * human-readable hint for logs/debugging and is NOT part of the contract:
 * callers must branch on `code` only. `details` carries structured context
 * (never secrets, never raw user documents, never full portfolios).
 */

export type QuantErrorCode =
  | 'INVALID_INSTRUMENT'
  | 'INVALID_DATASET'
  | 'DATASET_TOO_LARGE'
  | 'INSUFFICIENT_DATA'
  | 'STALE_DATA'
  | 'PROVIDER_UNAVAILABLE'
  | 'UNSUPPORTED_ASSET_CLASS'
  | 'CURRENCY_MISMATCH'
  | 'ENTITLEMENT_DENIED'
  | 'CALCULATION_ERROR'
  | 'DATA_QUALITY_ERROR'
  | 'INVALID_PORTFOLIO'
  | 'INVALID_PARAMETER'
  | 'PROJECT_ACCESS_DENIED';

export type QuantErrorDetails = Record<string, string | number | boolean | null>;

export interface QuantError {
  readonly code: QuantErrorCode;
  readonly message: string;
  readonly details?: QuantErrorDetails;
}

/** Every fallible Quant operation returns this instead of throwing, so a
 * caller can never mistake a failed calculation for a number. */
export type QuantResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: QuantError };

export function ok<T>(value: T): QuantResult<T> {
  return { ok: true, value };
}

export function fail<T = never>(code: QuantErrorCode, message: string, details?: QuantErrorDetails): QuantResult<T> {
  return { ok: false, error: details ? { code, message, details } : { code, message } };
}

/** Non-fatal data/calculation caveat attached to results. Same rule as
 * errors: `code` is the contract. */
export type QuantWarningCode =
  | 'ROWS_REORDERED'
  | 'EXACT_DUPLICATES_COLLAPSED'
  | 'UNKNOWN_COLUMNS_IGNORED'
  | 'TIME_GAPS_DETECTED'
  | 'DATA_DELAYED'
  | 'DATA_STALE'
  | 'FRESHNESS_UNKNOWN'
  | 'PROVENANCE_WEAK'
  | 'ADJUSTMENT_UNKNOWN'
  | 'ADJUSTED_CLOSE_PROVIDER_DEFINED'
  | 'ADJUSTMENT_UNVERIFIED'
  | 'CALENDAR_NAIVE'
  | 'MISSING_SESSIONS'
  | 'NON_SESSION_BARS'
  | 'PARTIAL_SESSION_BAR'
  | 'INSUFFICIENT_DATA_FOR_METRIC'
  | 'ZERO_VARIANCE';

export interface QuantWarning {
  readonly code: QuantWarningCode;
  readonly message: string;
  readonly details?: QuantErrorDetails;
}
