/**
 * PROHIBITED_AUTHORITY_FIELDS (Section 5).
 *
 * A closed, hardcoded list of field names that must NEVER appear anywhere
 * in an ExecutionRequest -- not at the top level, and not nested inside
 * `parameters`, `constraints`, or `metadata` at any depth. Presence of any
 * of these anywhere in the object is an unconditional REJECT, regardless
 * of the field's value (even `role: null` or `role: "none"` is rejected --
 * the field's mere presence is the signal of a mass-assignment attempt or
 * a confused caller, and this contract does not try to guess intent).
 *
 * This exists because JSON Schema's `additionalProperties: false` only
 * protects object shapes it fully controls. `parameters` is deliberately
 * open (domain/action-specific data must be extensible), so schema-level
 * protection cannot cover it. This scanner is the actual security boundary
 * for that object -- schema permissiveness there is not one.
 *
 * IMPORTANT, non-negotiable caveat (Codex adversarial review, Finding
 * F-01): a name-based blocklist can NEVER be a complete enumeration of
 * every authority-shaped field a careless implementer might invent
 * (`workspace_id`, `subscriptionLevel`, `execution_mode`, and others were
 * all found missing from an earlier version of this list). This list is
 * DEFENSE IN DEPTH, not the primary security boundary. The primary rule,
 * stated in README.md and repeated here, is:
 *
 *   A future AEF MUST NEVER treat ANY field inside `parameters`,
 *   `constraints`, or `metadata` as authoritative for identity, tenancy,
 *   entitlement, approval, or privilege -- REGARDLESS of whether that
 *   field's name happens to appear on this list. Authority may only ever
 *   come from independently-resolved sources: a verified auth_ref, a
 *   resolved DelegationEnvelope, a resolved HumanGateRecord, or a
 *   resolved entitlement lookup -- never from request payload content.
 *
 * To narrow (not eliminate) the alias-enumeration problem, field names
 * are compared after NORMALIZATION (lowercased, with every non-alphanumeric
 * character stripped) rather than by exact/lowercase string match alone --
 * this means `tenant_id`, `tenantId`, `TENANT-ID`, and `Tenant Id` all
 * collide to the same canonical form and are caught by a single list
 * entry, instead of requiring every casing/separator variant to be
 * enumerated by hand.
 */
export const PROHIBITED_AUTHORITY_FIELDS: readonly string[] = [
  // Identity / privilege escalation
  "role",
  "is_admin",
  "admin",
  "superuser",
  "service_role",
  "authorization_level",
  "privilege",
  "privileged",
  "trusted",
  "verified",
  "elevated",

  // Tenant / organization (Section 10 -- no tenant model exists; ANY such
  // field is rejected unconditionally in v1, never merely ignored)
  "tenant_id",
  "tenant",
  "organization_id",
  "organization_role",
  "org_id",
  "org",
  "organization",
  "workspace_id",
  "workspace",
  "org_ref",
  "tenant_ref",

  // Entitlement / billing (Section 11 -- IVE may describe/request a
  // capability, never grant one)
  "plan",
  "subscription_tier",
  "subscription_level",
  "tier",
  "entitlement",
  "entitlements",
  "entitled",
  "billing_status",
  "quota_override",
  "paid",
  "premium",
  "is_paid",
  "is_premium",

  // Policy / approval / execution-mode bypass (Section 12/13/16)
  "policy_override",
  "approved",
  "human_approved",
  "skip_checks",
  "force_execute",
  "bypass",
  "permissions",
  "scope", // legitimate `scope` lives only on DelegationEnvelope, never on ExecutionRequest
  "execution_mode",
  "live_mode",
  "real_money",
  "override",
  "unsafe",
] as const;

/** Normalizes a field name for comparison: lowercase, non-alphanumeric characters stripped. `tenant_id`, `tenantId`, `TENANT-ID`, and `Tenant Id` all normalize to `tenantid`. */
function normalizeFieldName(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, "");
}

/**
 * A field name (anywhere in an ExecutionRequest, including nested inside
 * `parameters`/`metadata`/`constraints`) must be a plain ASCII identifier.
 * Codex adversarial review (2nd round, still-open F-01) demonstrated that
 * a Cyrillic homoglyph -- 'раid' using U+0430 CYRILLIC SMALL LETTER A
 * in place of Latin 'a' -- is a visually indistinguishable but distinct
 * key that PROHIBITED_SET's normalization (which only folds case and
 * strips separators, not confusable Unicode) does not catch. Rather than
 * attempt a full Unicode confusable-skeleton normalization (UTS #39,
 * genuinely complex and disproportionate for this contract foundation),
 * this closes the entire class at the root: NO non-ASCII-identifier key
 * is permitted anywhere in these fields at all, regardless of what it
 * says. A legitimate parameter name is always a plain ASCII identifier in
 * this codebase's own conventions (see every real field in the schemas);
 * anything else is rejected outright as malformed, not merely as a
 * suspected authority field.
 */
const ASCII_IDENTIFIER_RE = /^[A-Za-z_][A-Za-z0-9_]*$/;

const PROHIBITED_SET: ReadonlySet<string> = new Set(
  PROHIBITED_AUTHORITY_FIELDS.map(normalizeFieldName),
);

export interface ProhibitedFieldFinding {
  /** Dot-path to the offending field, e.g. "parameters.role" or "metadata.is_admin". */
  path: string;
  field: string;
  /** Why this was flagged: an exact/normalized match against the prohibited list, or a non-ASCII-identifier key shape (which closes the homoglyph bypass class entirely, per the ASCII_IDENTIFIER_RE comment above). */
  reason: "prohibited_name" | "non_ascii_identifier_key";
}

/**
 * Recursively scans a value (object/array/primitive) for:
 *  (a) any key matching PROHIBITED_AUTHORITY_FIELDS after normalization
 *      (case- and separator-insensitive -- `Role`, `ROLE`, `is-admin`,
 *      and `IsAdmin` are all caught, not just an exact/lowercase match);
 *  (b) any key that is not a plain ASCII identifier at all (closes the
 *      Unicode homoglyph bypass class -- see ASCII_IDENTIFIER_RE above).
 * Returns every finding, not just the first, so a single reject can
 * report everything that needs fixing.
 */
export function scanForProhibitedFields(
  value: unknown,
  path = "$",
): ProhibitedFieldFinding[] {
  const findings: ProhibitedFieldFinding[] = [];

  if (value === null || typeof value !== "object") {
    return findings;
  }

  if (Array.isArray(value)) {
    value.forEach((item, i) => {
      findings.push(...scanForProhibitedFields(item, `${path}[${i}]`));
    });
    return findings;
  }

  for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
    const childPath = path === "$" ? key : `${path}.${key}`;
    if (!ASCII_IDENTIFIER_RE.test(key)) {
      findings.push({ path: childPath, field: key, reason: "non_ascii_identifier_key" });
    } else if (PROHIBITED_SET.has(normalizeFieldName(key))) {
      findings.push({ path: childPath, field: key, reason: "prohibited_name" });
    }
    findings.push(...scanForProhibitedFields(val, childPath));
  }

  return findings;
}
