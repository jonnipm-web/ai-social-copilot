/**
 * Extra authority-shaped names refused inside the bound payload of the
 * persistent AEF (Codex Gate 3 G3-02). The shared contract list
 * (contracts/aef/prohibited_fields.ts) is versioned and left unchanged; this
 * list adds the names the persistence layer itself uses for authority, so a
 * future tool can never be handed e.g. `owner_id` or `risk` that looks
 * authoritative. Same normalization as the contract scanner (lowercase,
 * non-alphanumerics stripped): `owner_id`, `ownerId`, `OWNER-ID` all match.
 *
 * Defense in depth only: AEF never reads authority from the payload, with
 * or without this list.
 */
const ALIASES = [
  "owner_id", "user_id", "subject_id", "actor_id", "approver_id", "approved_by",
  "risk", "risk_class", "risk_level", "risk_version", "policy_version",
  "tool_allowed", "allowed_tools", "tool_id", "requires_human_gate", "human_gate_ref",
  "execution_token",
] as const;

function normalize(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, "");
}

const ALIAS_SET: ReadonlySet<string> = new Set(ALIASES.map(normalize));

/** Returns the first authority-shaped key found at any depth, or null. */
export function findAuthorityAlias(value: unknown): string | null {
  if (value === null || typeof value !== "object") return null;
  if (Array.isArray(value)) {
    for (const item of value) {
      const hit = findAuthorityAlias(item);
      if (hit) return hit;
    }
    return null;
  }
  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    if (ALIAS_SET.has(normalize(key))) return key;
    const hit = findAuthorityAlias(child);
    if (hit) return hit;
  }
  return null;
}
