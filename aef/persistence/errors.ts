/**
 * Structured error codes of the persistent AEF. Callers branch on the code,
 * never on message text. Codes that the database returns are listed in
 * STORE_CODES so a store reply carrying anything else is a protocol error
 * (fail closed), not an unknown-but-accepted value.
 */
export const STORE_CODES = [
  "ARGUMENT_REJECTED",
  "POLICY_DENIED",
  "RESOURCE_TYPE_UNSUPPORTED",
  "RESOURCE_FORBIDDEN",
  "REQUEST_REPLAYED",
  "IDEMPOTENCY_CONFLICT",
  "GATE_NOT_FOUND",
  "GATE_EXPIRED",
  "GATE_NOT_PENDING",
  "APPROVAL_BINDING_MISMATCH",
  "POLICY_VERSION_CHANGED",
  "OPERATION_NOT_FOUND",
  "OPERATION_EXPIRED",
  "NOT_CLAIMABLE",
  "BINDING_MISMATCH",
  "GATE_NOT_AUTHORIZED",
  "EXECUTION_TOKEN_INVALID",
  "CANCEL_NOT_ALLOWED_IN_FLIGHT",
  "OPERATION_TERMINAL",
] as const;
export type StoreCode = typeof STORE_CODES[number];

export type AefErrorCode =
  | StoreCode
  | "AUTH_FAILED"
  | "INVALID_REQUEST"
  | "INPUT_REJECTED"
  | "DELEGATION_UNSUPPORTED"
  | "CLIENT_APPROVAL_REJECTED"
  | "IDEMPOTENCY_KEY_REQUIRED"
  | "UNKNOWN_TOOL"
  | "PAYLOAD_INVALID"
  | "PAYLOAD_TOO_LARGE"
  | "STORE_UNAVAILABLE"
  | "STORE_PROTOCOL_ERROR"
  | "INTENT_INVALID"
  | "INTENT_ACTION_UNKNOWN";

export function isStoreCode(v: unknown): v is StoreCode {
  return typeof v === "string" && (STORE_CODES as readonly string[]).includes(v);
}
