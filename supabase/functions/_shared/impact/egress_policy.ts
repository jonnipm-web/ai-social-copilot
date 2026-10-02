/**
 * Impact egress policy — IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01.
 *
 * All outbound requests from the Impact module MUST use safeFetch with an
 * explicit allowedHosts set derived from this policy. No arbitrary URL fetch
 * is permitted. Every external call is classified by purpose, and only the
 * hosts appropriate to that purpose are allowed.
 *
 * SSRF protection is provided by safeFetch (safe_fetch.ts). This module adds
 * the host-level allowlist on top: even a public, non-private IP is blocked
 * if its hostname is not in the allowlist for the declared purpose.
 *
 * Fetch success ≠ evidence credibility. A retrieved document must go through
 * the evidence ingestion pipeline before any claim can cite it.
 */
import type { SafeFetchOptions } from '../safe_fetch.ts';

// ── Purpose taxonomy ─────────────────────────────────────────────────────────

/**
 * Every outbound request must declare its purpose. The purpose determines
 * which host allowlist applies and what gets logged.
 *
 * PUBLIC_SOURCE_FETCH   — fetching a URL submitted by a user as a source
 * REGISTRY_QUERY        — querying a known registry provider (companies_house, etc.)
 * INTERNAL              — internal Supabase service (storage, database via REST)
 * EXTERNAL_SIDE_EFFECT  — a consequential external call (requires AEF authorization)
 */
export type EgressPurpose =
  | 'PUBLIC_SOURCE_FETCH'
  | 'REGISTRY_QUERY'
  | 'INTERNAL'
  | 'EXTERNAL_SIDE_EFFECT';

// ── Registry host allowlists (per provider) ──────────────────────────────────

const REGISTRY_HOSTS: ReadonlySet<string> = new Set([
  // UK Companies House API
  'api.company-information.service.gov.uk',
  // UK Charity Commission API
  'api.charitycommission.gov.uk',
  // IRS EO Business Master File (static CSV download)
  'apps.irs.gov',
  'www.irs.gov',
]);

// ── Public source fetch — no host allowlist (any public host) ────────────────
// safeFetch still enforces SSRF protection (private IPs, loopback, link-local).
// A user-submitted URL may point to any legitimate public web host.
// Content-type and size limits are enforced by safeFetch options below.

// ── Timeout and size limits by purpose ───────────────────────────────────────

const LIMITS: Readonly<Record<EgressPurpose, { timeoutMs: number; maxResponseBytes: number }>> = {
  PUBLIC_SOURCE_FETCH: { timeoutMs: 15_000, maxResponseBytes: 2_000_000 },
  REGISTRY_QUERY: { timeoutMs: 20_000, maxResponseBytes: 5_000_000 },
  INTERNAL: { timeoutMs: 10_000, maxResponseBytes: 10_000_000 },
  EXTERNAL_SIDE_EFFECT: { timeoutMs: 30_000, maxResponseBytes: 1_000_000 },
};

// ── Policy builder ────────────────────────────────────────────────────────────

/**
 * Return SafeFetchOptions for the given purpose. Always call this before
 * safeFetch — never call safeFetch without options derived from here.
 *
 * For REGISTRY_QUERY: pass the provider's specific host(s) via `hosts`
 * override (the registry adapters already do this via their `allowedHosts`).
 * The `hosts` parameter narrows further, never broadens.
 */
export function buildEgressOptions(
  purpose: EgressPurpose,
  hosts?: ReadonlySet<string>,
): SafeFetchOptions {
  const limits = LIMITS[purpose];
  let allowedHosts: ReadonlySet<string> | undefined;

  if (purpose === 'REGISTRY_QUERY') {
    // Caller-provided hosts must be a subset of the known registry set.
    if (hosts) {
      for (const h of hosts) {
        if (!REGISTRY_HOSTS.has(h)) {
          throw new Error(`EGRESS_POLICY_VIOLATION: host "${h}" not in REGISTRY_QUERY allowlist`);
        }
      }
      allowedHosts = hosts;
    } else {
      allowedHosts = REGISTRY_HOSTS;
    }
  } else if (purpose === 'INTERNAL') {
    // Internal calls use Supabase's own URL (resolved from env) — no wildcard.
    // The caller must provide the specific host.
    if (!hosts || hosts.size === 0) {
      throw new Error('EGRESS_POLICY: INTERNAL purpose requires explicit hosts');
    }
    allowedHosts = hosts;
  } else if (purpose === 'EXTERNAL_SIDE_EFFECT') {
    // External side effects require AEF authorization AND explicit hosts.
    if (!hosts || hosts.size === 0) {
      throw new Error('EGRESS_POLICY: EXTERNAL_SIDE_EFFECT purpose requires explicit hosts');
    }
    allowedHosts = hosts;
  }
  // PUBLIC_SOURCE_FETCH: no host restriction (any public host, SSRF-checked by safeFetch)

  return {
    timeoutMs: limits.timeoutMs,
    maxResponseBytes: limits.maxResponseBytes,
    ...(allowedHosts ? { allowedHosts } : {}),
  };
}

// ── Content validation helper ─────────────────────────────────────────────────

const ALLOWED_SOURCE_CONTENT_TYPES: ReadonlySet<string> = new Set([
  'text/html',
  'text/plain',
  'application/json',
  'application/pdf',
  'application/xml',
  'text/xml',
  'application/atom+xml',
  'application/rss+xml',
  'text/csv',
]);

/**
 * Validate the Content-Type of an egress response.
 * Returns null if valid, or an error string if not acceptable.
 */
export function validateEgressContentType(contentType: string | null, purpose: EgressPurpose): string | null {
  if (!contentType) return 'missing Content-Type';
  const base = contentType.split(';')[0].trim().toLowerCase();
  if (purpose === 'PUBLIC_SOURCE_FETCH' || purpose === 'REGISTRY_QUERY') {
    if (!ALLOWED_SOURCE_CONTENT_TYPES.has(base)) {
      return `content type "${base}" not allowed for ${purpose}`;
    }
  }
  return null;
}

// ── Egress event metadata ────────────────────────────────────────────────────

export interface EgressEventMeta {
  readonly purpose: EgressPurpose;
  readonly correlationId: string;
  /** Hostname only — never the full URL (may contain path params with PII). */
  readonly hostname: string;
  readonly outcome: 'STARTED' | 'COMPLETED' | 'DENIED' | 'TIMEOUT' | 'TOO_LARGE' | 'CONTENT_TYPE_REJECTED';
  readonly statusCode: number | null;
  readonly durationMs: number | null;
}
