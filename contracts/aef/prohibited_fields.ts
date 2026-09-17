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

const PROHIBITED_SET: ReadonlySet<string> = new Set(
  PROHIBITED_AUTHORITY_FIELDS.map(normalizeFieldName),
);

export interface ProhibitedFieldFinding {
  /** Dot-path to the offending field, e.g. "parameters.role" or "metadata.is_admin". */
  path: string;
  field: string;
}

/**
 * Recursively scans a value (object/array/primitive) for any key matching
 * PROHIBITED_AUTHORITY_FIELDS after normalization (case- and
 * separator-insensitive -- `Role`, `ROLE`, `is-admin`, and `IsAdmin` are
 * all caught, not just an exact/lowercase match). Returns every finding,
 * not just the first, so a single reject can report everything that
 * needs fixing.
 *
 * Known, documented limitation: true Unicode homoglyphs (e.g. Cyrillic
 * 'а' U+0430 substituted for Latin 'a') are NOT normalized to their Latin
 * equivalent and would NOT be caught by name alone. This is a deliberate
 * scope boundary, not an oversight -- closing it fully requires Unicode
 * confusable-skeleton normalization (e.g. per UTS #39), which this
 * contract foundation does not implement. It is recorded here, in
 * validators_test.ts's fuzz suite, and in the mission report as a known
 * gap for a future hardening pass, not silently left undocumented.
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
    if (PROHIBITED_SET.has(normalizeFieldName(key))) {
      findings.push({ path: childPath, field: key });
    }
    findings.push(...scanForProhibitedFields(val, childPath));
  }

  return findings;
}
