/**
 * Organization identity — IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01.
 *
 * "WHICH organization is this?" answered from registry records, never from a
 * name. Pure: no network, no clock (evaluatedAt is injected), no LLM.
 *
 *  - Canonical id: `COUNTRY:scheme:NUMBER` (jurisdiction + registry scheme +
 *    registry identifier). Stable across renames, websites and slugs.
 *  - Resolution is conservative (docs/impact/IMPACT_ORGANIZATION_IDENTITY.md):
 *      EXACT      one canonical organization holds the queried registration
 *      STRONG     no registration queried; exactly one organization matches
 *                 BOTH an official domain and a registry name — shown as
 *                 probable, never merged automatically
 *      AMBIGUOUS  more than one plausible organization, or name-only /
 *                 domain-only evidence — candidates for human review;
 *                 nothing is chosen, nothing migrates between candidates
 *      NO_MATCH   nothing matches (≠ "the organization does not exist":
 *                 absence in one registry is never a negative signal)
 *  - A name never resolves identity by itself; the same name in another
 *    jurisdiction is another organization until a registration says otherwise.
 *  - A former name is part of the timeline of ONE organization: it helps
 *    search, it never merges two organizations that shared an old name.
 */
import { nameSimilarity, normalizeDomain, normalizeName, normalizeRegistration } from './entity_resolution.ts';
import { parseIsoMs } from './provenance.ts';
import type { CanonicalRegistryRecord, OrganizationQuery, RegistryStatus } from './provider.ts';

export const IDENTITY_POLICY_VERSION = 'impact-identity/1';

export const IDENTITY_LIMITS = Object.freeze({ maxCandidates: 10, nameSimilarityThreshold: 0.5 });

/** `COUNTRY:scheme:NUMBER` — mirrored exactly by SQL (impact_canonical_org_id). */
export function canonicalOrgId(country: string, scheme: string, number: string): string {
  return `${country.trim().toUpperCase()}:${scheme.trim().toLowerCase().replace(/[^a-z0-9-]+/g, '-')}:${normalizeRegistration(number)}`;
}

/** Name key for search/conflict comparison (legal forms canonicalized, never dropped). */
export function legalNameKey(name: string): string {
  return normalizeName(name);
}

export type IdentityOutcome = 'EXACT' | 'STRONG' | 'AMBIGUOUS' | 'NO_MATCH';

export type IdentitySignal =
  | 'REGISTRATION_EQUAL'
  | 'CROSS_REFERENCE_EQUAL'
  | 'DOMAIN_EQUAL'
  | 'NAME_EQUAL'
  | 'TRADING_NAME_EQUAL'
  | 'FORMER_NAME_EQUAL'
  | 'NAME_SIMILAR'
  | 'NAME_DIFFERENT'
  | 'DISSOLVED_OR_REMOVED'
  | 'STALE_SNAPSHOT'
  | 'SYNTHETIC_FIXTURE';

export type IdentityReason =
  | 'REGISTRATION_NOT_FOUND'
  | 'MULTIPLE_ORGANIZATIONS'
  | 'NAME_ONLY'
  | 'DOMAIN_ONLY'
  | 'NAME_DIFFERS_FROM_REGISTRY'
  | 'OTHER_JURISDICTION_IGNORED'
  | 'NO_IDENTIFIERS'
  | 'CANDIDATES_TRUNCATED';

export interface IdentityCandidate {
  readonly canonicalOrgId: string;
  readonly providerId: string;
  readonly recordId: string;
  readonly legalName: string;
  readonly country: string;
  readonly status: RegistryStatus;
  readonly signals: readonly IdentitySignal[];
  readonly snapshotFresh: boolean;
  readonly retrievedAt: string;
  readonly sourceAsOf?: string;
  readonly synthetic: boolean;
}

export interface IdentityResolution {
  readonly outcome: IdentityOutcome;
  readonly candidates: readonly IdentityCandidate[];
  readonly reasons: readonly IdentityReason[];
  /** A human must look before anything is attached to a candidate. */
  readonly requiresReview: boolean;
  readonly identityStatus: 'CONFIRMED' | 'PROBABLE' | 'UNCERTAIN' | 'UNRESOLVED';
  readonly policyVersion: string;
}

const DAY_MS = 86_400_000;

export function snapshotFresh(r: Pick<CanonicalRegistryRecord, 'retrievedAt' | 'sourceAsOf'>, freshnessDays: number, evaluatedAtMs: number): boolean {
  // The registry's own "as of" is what the data describes; retrieval cannot make it newer.
  const asOf = Math.min(parseIsoMs(r.retrievedAt) ?? -Infinity, parseIsoMs(r.sourceAsOf) ?? Infinity);
  return evaluatedAtMs - asOf <= freshnessDays * DAY_MS;
}

function nameSignals(queryName: string | undefined, r: CanonicalRegistryRecord): IdentitySignal[] {
  if (!queryName) return [];
  const q = legalNameKey(queryName);
  if (!q) return [];
  if (legalNameKey(r.name) === q) return ['NAME_EQUAL'];
  if (r.tradingNames.some((t) => legalNameKey(t) === q)) return ['TRADING_NAME_EQUAL'];
  if (r.formerNames.some((f) => legalNameKey(f.name) === q)) return ['FORMER_NAME_EQUAL'];
  const all = [r.name, ...r.tradingNames, ...r.formerNames.map((f) => f.name)].map(legalNameKey);
  if (all.some((n) => nameSimilarity(n, q) >= IDENTITY_LIMITS.nameSimilarityThreshold)) return ['NAME_SIMILAR'];
  return ['NAME_DIFFERENT'];
}

const nameMatches = (s: IdentitySignal[]) => s.some((x) => x !== 'NAME_DIFFERENT');

/**
 * Resolves a query against registry records (already normalized, from
 * trusted providers). `freshnessDays(providerId)` comes from the SERVER
 * registry. Deterministic for the same inputs.
 */
export function resolveOrganization(
  q: OrganizationQuery,
  records: readonly CanonicalRegistryRecord[],
  evaluatedAt: string,
  freshnessDays: (providerId: string) => number,
): IdentityResolution {
  const evaluatedAtMs = parseIsoMs(evaluatedAt) ?? 0;
  const reasons = new Set<IdentityReason>();
  const country = q.country?.trim().toUpperCase();
  const scheme = q.scheme?.trim().toLowerCase();
  const inJurisdiction = records.filter((r) => !country || r.jurisdiction.country === country);
  if (country && inJurisdiction.length < records.length) reasons.add('OTHER_JURISDICTION_IGNORED');

  // One entry per canonical organization (newest snapshot represents it).
  const byOrg = new Map<string, CanonicalRegistryRecord>();
  const pick = (rs: readonly CanonicalRegistryRecord[]) => {
    const m = new Map<string, CanonicalRegistryRecord>();
    for (const r of rs) {
      const cur = m.get(r.canonicalOrgId);
      if (!cur || r.retrievedAt > cur.retrievedAt || (r.retrievedAt === cur.retrievedAt && r.recordId < cur.recordId)) m.set(r.canonicalOrgId, r);
    }
    return m;
  };

  let outcome: IdentityOutcome;
  const extra = new Map<string, IdentitySignal[]>();
  if (q.registration) {
    const reg = normalizeRegistration(q.registration);
    const hits = inJurisdiction.filter((r) =>
      (r.registrationNumber === reg && (!scheme || r.scheme.toLowerCase() === scheme)) ||
      r.crossReferences.some((x) => x.value === reg && (!scheme || x.scheme.toLowerCase() === scheme))
    );
    for (const [k, v] of pick(hits)) {
      byOrg.set(k, v);
      extra.set(k, [v.registrationNumber === reg ? 'REGISTRATION_EQUAL' : 'CROSS_REFERENCE_EQUAL']);
    }
    if (byOrg.size === 0) { outcome = 'NO_MATCH'; reasons.add('REGISTRATION_NOT_FOUND'); } // never falls back to a name
    else if (byOrg.size > 1) { outcome = 'AMBIGUOUS'; reasons.add('MULTIPLE_ORGANIZATIONS'); }
    else {
      outcome = 'EXACT';
      const only = [...byOrg.values()][0];
      if (nameSignals(q.name, only).includes('NAME_DIFFERENT')) reasons.add('NAME_DIFFERS_FROM_REGISTRY');
    }
  } else if (q.domain || q.name) {
    const dom = q.domain ? normalizeDomain(q.domain) : null;
    const domainHits = dom ? pick(inJurisdiction.filter((r) => r.domains.includes(dom))) : new Map();
    if (dom && domainHits.size > 0) {
      for (const [k, v] of domainHits) { byOrg.set(k, v); extra.set(k, ['DOMAIN_EQUAL']); }
      if (byOrg.size > 1) { outcome = 'AMBIGUOUS'; reasons.add('MULTIPLE_ORGANIZATIONS'); }
      else if (nameMatches(nameSignals(q.name, [...byOrg.values()][0])) && q.name) outcome = 'STRONG';
      else { outcome = 'AMBIGUOUS'; reasons.add('DOMAIN_ONLY'); }
    } else if (q.name) {
      const hits = inJurisdiction.filter((r) => nameMatches(nameSignals(q.name, r)));
      for (const [k, v] of pick(hits)) byOrg.set(k, v);
      if (byOrg.size === 0) outcome = 'NO_MATCH';
      else {
        outcome = 'AMBIGUOUS';
        reasons.add(byOrg.size > 1 ? 'MULTIPLE_ORGANIZATIONS' : 'NAME_ONLY');
      }
    } else outcome = 'NO_MATCH';
  } else {
    outcome = 'NO_MATCH';
    reasons.add('NO_IDENTIFIERS');
  }

  const all = [...byOrg.values()].sort((a, b) => (a.canonicalOrgId < b.canonicalOrgId ? -1 : 1));
  if (all.length > IDENTITY_LIMITS.maxCandidates) reasons.add('CANDIDATES_TRUNCATED');
  const candidates = all.slice(0, IDENTITY_LIMITS.maxCandidates).map((r) => {
    const fresh = snapshotFresh(r, freshnessDays(r.providerId), evaluatedAtMs);
    const signals = [...new Set<IdentitySignal>([
      ...(extra.get(r.canonicalOrgId) ?? []),
      ...nameSignals(q.name, r),
      ...(r.status === 'DISSOLVED' || r.status === 'REMOVED' ? ['DISSOLVED_OR_REMOVED' as const] : []),
      ...(fresh ? [] : ['STALE_SNAPSHOT' as const]),
      ...(r.synthetic ? ['SYNTHETIC_FIXTURE' as const] : []),
    ])].sort();
    return Object.freeze({
      canonicalOrgId: r.canonicalOrgId, providerId: r.providerId, recordId: r.recordId, legalName: r.name,
      country: r.jurisdiction.country, status: r.status, signals: Object.freeze(signals), snapshotFresh: fresh,
      retrievedAt: r.retrievedAt, ...(r.sourceAsOf ? { sourceAsOf: r.sourceAsOf } : {}), synthetic: r.synthetic,
    });
  });

  const identityStatus = outcome === 'EXACT' ? 'CONFIRMED' : outcome === 'STRONG' ? 'PROBABLE' : outcome === 'AMBIGUOUS' ? 'UNCERTAIN' : 'UNRESOLVED';
  return Object.freeze({
    outcome,
    candidates: Object.freeze(candidates),
    reasons: Object.freeze([...reasons].sort()),
    requiresReview: outcome !== 'EXACT' || reasons.has('NAME_DIFFERS_FROM_REGISTRY'),
    identityStatus,
    policyVersion: IDENTITY_POLICY_VERSION,
  });
}

// ── temporal identity ──────────────────────────────────────────────────────

export type NameValidity = 'CURRENT_NAME' | 'FORMER_NAME_AT_DATE' | 'NOT_THE_NAME_AT_DATE' | 'UNKNOWN_NAME';

/**
 * Was `name` this organization's name at `at`? Former-name periods are
 * [from, to); the current name holds from the end of the latest former name.
 * Never applies today's name to the past or an old name to today.
 */
export function nameValidAt(r: Pick<CanonicalRegistryRecord, 'name' | 'formerNames'>, name: string, at: string): NameValidity {
  const k = legalNameKey(name);
  const t = parseIsoMs(at);
  if (t === null) return 'UNKNOWN_NAME';
  const latestFormerEnd = Math.max(-Infinity, ...r.formerNames.map((f) => parseIsoMs(f.to) ?? -Infinity));
  if (legalNameKey(r.name) === k) return t >= latestFormerEnd ? 'CURRENT_NAME' : 'NOT_THE_NAME_AT_DATE';
  const f = r.formerNames.filter((x) => legalNameKey(x.name) === k);
  if (f.length === 0) return 'UNKNOWN_NAME';
  const inPeriod = f.some((x) => (parseIsoMs(x.from) ?? -Infinity) <= t && t < (parseIsoMs(x.to) ?? Infinity));
  return inPeriod ? 'FORMER_NAME_AT_DATE' : 'NOT_THE_NAME_AT_DATE';
}

// ── registry conflicts (mirrored by SQL impact_registry_conflicts trigger) ─

export type RegistryStatusClass = 'ACTIVE' | 'INACTIVE' | 'SUSPENDED' | 'UNKNOWN';

export function registryStatusClass(s: RegistryStatus): RegistryStatusClass {
  return s === 'REGISTERED' ? 'ACTIVE' : s === 'REMOVED' || s === 'DISSOLVED' ? 'INACTIVE' : s === 'SUSPENDED' ? 'SUSPENDED' : 'UNKNOWN';
}

export type RegistryConflictKind = 'NAME_MISMATCH' | 'STATUS_MISMATCH';

/** Why registries disagree — a conflict is a data question, never wrongdoing. */
export const REGISTRY_CONFLICT_EXPLANATIONS = Object.freeze([
  'TIMING_OR_REGISTRY_LAG', 'NAME_CHANGE', 'DIFFERENT_LEGAL_ENTITY_OR_SCOPE', 'DATA_QUALITY',
] as const);

export interface RegistryConflict {
  readonly kind: RegistryConflictKind;
  readonly canonicalOrgId: string;
  readonly sourceRef: string;
  readonly otherSourceRef: string;
}

export interface SnapshotRef {
  readonly sourceRef: string;
  readonly active: boolean;
  readonly record: CanonicalRegistryRecord;
}

/**
 * Conflicts a NEW snapshot has with the other ACTIVE snapshots of the same
 * organization (shared canonical id, different provider record). A newer
 * snapshot of the SAME record is a registry update, not a conflict. No
 * winner is chosen; both snapshots stay.
 */
export function registryConflicts(next: SnapshotRef, others: readonly SnapshotRef[]): RegistryConflict[] {
  const out: RegistryConflict[] = [];
  for (const o of [...others].sort((a, b) => (a.sourceRef < b.sourceRef ? -1 : 1))) {
    if (!o.active || o.sourceRef === next.sourceRef) continue;
    if (o.record.providerId === next.record.providerId && o.record.recordId === next.record.recordId) continue;
    const shared = next.record.canonicalIds.filter((c) => o.record.canonicalIds.includes(c)).sort();
    if (shared.length === 0) continue;
    if (o.record.nameKey !== next.record.nameKey) {
      out.push({ kind: 'NAME_MISMATCH', canonicalOrgId: shared[0], sourceRef: next.sourceRef, otherSourceRef: o.sourceRef });
    }
    const a = registryStatusClass(next.record.status);
    const b = registryStatusClass(o.record.status);
    if (a !== 'UNKNOWN' && b !== 'UNKNOWN' && a !== b) {
      out.push({ kind: 'STATUS_MISMATCH', canonicalOrgId: shared[0], sourceRef: next.sourceRef, otherSourceRef: o.sourceRef });
    }
  }
  return out;
}
