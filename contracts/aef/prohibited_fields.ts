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
  "trusted",
  "verified",

  // Tenant / organization (Section 10 -- no tenant model exists; ANY such
  // field is rejected unconditionally in v1, never merely ignored)
  "tenant_id",
  "tenant",
  "organization_id",
  "organization_role",
  "org_id",
  "org",

  // Entitlement / billing (Section 11 -- IVE may describe/request a
  // capability, never grant one)
  "plan",
  "subscription_tier",
  "entitlement",
  "entitlements",
  "billing_status",
  "quota_override",

  // Policy / approval bypass (Section 12/13)
  "policy_override",
  "approved",
  "human_approved",
  "skip_checks",
  "force_execute",
  "bypass",
  "permissions",
  "scope", // legitimate `scope` lives only on DelegationEnvelope, never on ExecutionRequest
] as const;

const PROHIBITED_SET: ReadonlySet<string> = new Set(
  PROHIBITED_AUTHORITY_FIELDS.map((f) => f.toLowerCase()),
);

export interface ProhibitedFieldFinding {
  /** Dot-path to the offending field, e.g. "parameters.role" or "metadata.is_admin". */
  path: string;
  field: string;
}

/**
 * Recursively scans a value (object/array/primitive) for any key matching
 * PROHIBITED_AUTHORITY_FIELDS, case-insensitively (a caller trying
 * `Role` or `ROLE` to dodge a naive exact-match check is still caught).
 * Returns every finding, not just the first, so a single reject can report
 * everything that needs fixing.
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
    if (PROHIBITED_SET.has(key.toLowerCase())) {
      findings.push({ path: childPath, field: key });
    }
    findings.push(...scanForProhibitedFields(val, childPath));
  }

  return findings;
}
