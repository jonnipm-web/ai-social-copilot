/**
 * Strategy Builder error contract — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05.
 *
 * Same shape/discipline as quant/errors.ts (`code` is the stable contract,
 * `message` is a debug hint, `details` never carries secrets or raw user
 * documents) but kept as its own closed union: Strategy Builder concerns
 * (unsupported rule, contradictory configuration, promotion denied) are not
 * Quant Foundation concerns, and merging the two error unions would let an
 * unrelated domain's callers see codes they can never actually receive.
 */

export type StrategyErrorCode =
  | 'INVALID_STRATEGY_SPEC'
  | 'UNSUPPORTED_RULE'
  | 'UNSUPPORTED_TIMEFRAME'
  | 'MISSING_REQUIRED_RULE'
  | 'CONTRADICTORY_CONFIGURATION'
  | 'INVALID_MARKET_PROFILE'
  | 'INVALID_SESSION_WINDOW'
  | 'INVALID_POSITION_SIZE'
  | 'INVALID_RISK_PARAMETER'
  | 'DATA_REQUIREMENT_UNMET'
  | 'PROMOTION_DENIED'
  | 'NOT_COMPARABLE'
  | 'AMBIGUOUS_NATURAL_LANGUAGE';

export type StrategyErrorDetails = Record<string, string | number | boolean | null>;

export interface StrategyError {
  readonly code: StrategyErrorCode;
  readonly message: string;
  readonly details?: StrategyErrorDetails;
}

/** Every fallible Strategy Builder operation returns this instead of
 * throwing, so a caller can never mistake a rejected/ambiguous
 * configuration for a valid one. */
export type StrategyResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: StrategyError };

export function ok<T>(value: T): StrategyResult<T> {
  return { ok: true, value };
}

export function fail<T = never>(
  code: StrategyErrorCode,
  message: string,
  details?: StrategyErrorDetails,
): StrategyResult<T> {
  return { ok: false, error: details ? { code, message, details } : { code, message } };
}
