/**
 * Server-owned versions and limits for the persistent AEF (IV-AEF-PERSISTENCE-01).
 *
 * Nothing here is ever read from a request. A change to the policy or the
 * risk taxonomy MUST bump the matching version: every pending approval is
 * bound to the policy version it was requested under, and the database
 * invalidates it (POLICY_VERSION_CHANGED) instead of honoring an approval
 * given under different rules.
 */
export const AEF_POLICY_VERSION = "aef-policy/2026-09-25.1";
export const AEF_RISK_VERSION = "aef-risk/2026-09-25.1";

/** Canonical JSON of the bound payload. Mirrors the DB CHECK (payload_bytes <= 16384). */
export const MAX_PAYLOAD_BYTES = 16_384;
export const MAX_PAYLOAD_DEPTH = 8;
export const MAX_PAYLOAD_NODES = 1_000;

/** Operation lifetime and approval window (DB bounds: 60..86400 and 60..3600). */
export const OPERATION_TTL_SECONDS = 3_600;
export const GATE_TTL_SECONDS = 900;

/** The tool must finish well inside the lease; a lease that runs out means UNKNOWN_OUTCOME. */
export const EXECUTION_LEASE_SECONDS = 60;
export const TOOL_TIMEOUT_MS = 10_000;
