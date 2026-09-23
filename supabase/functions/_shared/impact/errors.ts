/**
 * Impact error contract — IV-IMPACT-FOUNDATION-01.
 *
 * `code` is the logical contract (stable, machine-readable). `message` is a
 * human-readable hint for logs only and is NOT part of the contract: callers
 * branch on `code`, never on text. `details` carries structured context only
 * (ids, codes, counts) — never document content, personal data or secrets.
 */

export type ImpactErrorCode =
  | 'ORGANIZATION_NOT_FOUND'
  | 'ENTITY_MATCH_UNCERTAIN'
  | 'REGISTRY_UNAVAILABLE'
  | 'SOURCE_UNAVAILABLE'
  | 'SOURCE_STALE'
  | 'EVIDENCE_INSUFFICIENT'
  | 'EVIDENCE_CONFLICT'
  | 'CLAIM_UNVERIFIED'
  | 'INVALID_EVIDENCE'
  | 'INVALID_SOURCE'
  | 'INVALID_CLAIM'
  | 'CROSS_INVESTIGATION_DENIED'
  | 'SENSITIVE_DATA_REJECTED'
  | 'UNSAFE_REFERENCE'
  | 'CAPABILITY_NOT_SUPPORTED'
  | 'ACTION_BLOCKED'
  | 'ENTITLEMENT_DENIED'
  | 'REVIEW_REQUIRED'
  | 'INVALID_REQUEST'
  | 'INVESTIGATION_NOT_FOUND'
  | 'INVESTIGATION_NOT_ACTIVE'
  | 'ALREADY_EXISTS'
  | 'LIMIT_EXCEEDED'
  | 'PAYLOAD_TOO_LARGE'
  // I2 Registry Intelligence — operational states, never a finding about an organization.
  | 'REGISTRY_RATE_LIMITED'
  | 'REGISTRY_RESPONSE_INVALID'
  | 'ORGANIZATION_AMBIGUOUS'
  // I3 Evidence Collection — operational / validation states, never a signal about an organization.
  | 'UNSUPPORTED_FILE_TYPE'
  | 'FILE_TOO_LARGE'
  | 'FILE_SIGNATURE_INVALID'
  | 'LOCATOR_INVALID'
  | 'EVIDENCE_REVIEW_REQUIRED'
  | 'INTERNAL_ERROR';

export const IMPACT_ERROR_CODES: readonly ImpactErrorCode[] = Object.freeze([
  'ORGANIZATION_NOT_FOUND',
  'ENTITY_MATCH_UNCERTAIN',
  'REGISTRY_UNAVAILABLE',
  'SOURCE_UNAVAILABLE',
  'SOURCE_STALE',
  'EVIDENCE_INSUFFICIENT',
  'EVIDENCE_CONFLICT',
  'CLAIM_UNVERIFIED',
  'INVALID_EVIDENCE',
  'INVALID_SOURCE',
  'INVALID_CLAIM',
  'CROSS_INVESTIGATION_DENIED',
  'SENSITIVE_DATA_REJECTED',
  'UNSAFE_REFERENCE',
  'CAPABILITY_NOT_SUPPORTED',
  'ACTION_BLOCKED',
  'ENTITLEMENT_DENIED',
  'REVIEW_REQUIRED',
  'INVALID_REQUEST',
  'INVESTIGATION_NOT_FOUND',
  'INVESTIGATION_NOT_ACTIVE',
  'ALREADY_EXISTS',
  'LIMIT_EXCEEDED',
  'PAYLOAD_TOO_LARGE',
  'REGISTRY_RATE_LIMITED',
  'REGISTRY_RESPONSE_INVALID',
  'ORGANIZATION_AMBIGUOUS',
  'UNSUPPORTED_FILE_TYPE',
  'FILE_TOO_LARGE',
  'FILE_SIGNATURE_INVALID',
  'LOCATOR_INVALID',
  'EVIDENCE_REVIEW_REQUIRED',
  'INTERNAL_ERROR',
]);

export type ImpactErrorDetails = Record<string, string | number | boolean | null>;

export interface ImpactError {
  readonly code: ImpactErrorCode;
  readonly message: string;
  readonly details?: ImpactErrorDetails;
}

/** Every fallible Impact operation returns this instead of throwing, so a
 * caller can never mistake a rejected input for a verified one. */
export type ImpactResult<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: ImpactError };

export function ok<T>(value: T): ImpactResult<T> {
  return { ok: true, value };
}

export function fail<T = never>(
  code: ImpactErrorCode,
  message: string,
  details?: ImpactErrorDetails,
): ImpactResult<T> {
  return { ok: false, error: Object.freeze({ code, message, ...(details ? { details } : {}) }) };
}
