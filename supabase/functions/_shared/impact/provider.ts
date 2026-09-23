/**
 * Source providers and normalization — IV-IMPACT-FOUNDATION-01.
 *
 * ImpactSourceProvider is the ONLY way external data will enter Impact.
 * Providers declare what they can do (capabilities), where they are
 * authoritative (jurisdictions + scope), how fresh they are and how they
 * retrieve. Not every provider supports every operation; calling an
 * undeclared capability fails with CAPABILITY_NOT_SUPPORTED.
 *
 * The Foundation ships ONLY FixtureProvider (in-memory, deterministic). No
 * crawler, no scraping, no search engine. A future network provider must
 * use _shared/safe_fetch.ts, respect robots/terms/authentication, and is a
 * separate gate (IMPACT_ROADMAP.md, I1).
 *
 * Pipeline: RAW SOURCE RECORD → validate → normalize → (link → verify →
 * analyze elsewhere). The raw record is never mutated and stays referenced
 * from the canonical record (rawRecordHash).
 */
import { fail, ok, type ImpactResult } from './errors.ts';
import { normalizeDomain, normalizeRegistration } from './entity_resolution.ts';
import { isValidId, parseIsoMs, sha256Hex } from './provenance.ts';
import { canonicalOrgId, legalNameKey } from './organization_identity.ts';
import type { FormerName, Jurisdiction, OrganizationIdentity, OrganizationType, SourceType } from './types.ts';

export type ProviderCapability = 'SEARCH_ORGANIZATION' | 'FETCH_REGISTRY_RECORD' | 'FETCH_EVIDENCE';
export type RetrievalMethod = 'FIXTURE' | 'OFFICIAL_API' | 'BULK_DATASET' | 'LICENSED_API' | 'MANUAL_UPLOAD';

/** Server-owned class of authority a registry holds (I2). A caller never sets it. */
export type RegistryAuthorityClass =
  | 'STATUTORY_REGISTER' //   the legal register itself (company / charity register)
  | 'REGULATOR' //            a regulator's own records
  | 'TAX_AUTHORITY'; //       exemption / tax status records

/** Terms / licence review state (docs/impact/IMPACT_REGISTRY_SOURCE_DOSSIER.md). */
export type TermsStatus = 'CONFIRMED' | 'REQUIRES_CONFIRMATION' | 'NOT_SUPPORTED' | 'UNKNOWN' | 'SYNTHETIC';

export interface ProviderDescriptor {
  readonly id: string;
  readonly sourceType: SourceType;
  readonly capabilities: readonly ProviderCapability[];
  /** ISO 3166-1 alpha-2 codes where this provider has any authority. */
  readonly jurisdictions: readonly string[];
  /** What the provider can speak to — e.g. ['LEGAL_REGISTRATION']. */
  readonly authorityScope: readonly string[];
  /** Typical lag between reality and the data (days). */
  readonly freshnessDays: number;
  readonly retrievalMethod: RetrievalMethod;
  // ── I2 registry metadata (server-owned) ──
  /** Official (government / statutory) source, not a third-party database. */
  readonly official: boolean;
  readonly authorityClass: RegistryAuthorityClass;
  /** Serves its OWN primary records (lineage ORIGINAL by provenance). */
  readonly primaryPublisher: boolean;
  /** What the data covers, in words (dossier + UI). */
  readonly dataScope: string;
  /** Version of the adapter that produced a record (kept in snapshots). */
  readonly adapterVersion: string;
  readonly termsStatus: TermsStatus;
  /** Marked in every record and response: fixture data is never real. */
  readonly synthetic: boolean;
}

export interface OrganizationQuery {
  readonly name?: string;
  readonly registration?: string;
  /** Registration scheme (e.g. charity-number) — narrows a registration query. */
  readonly scheme?: string;
  readonly domain?: string;
  readonly country?: string;
}

export interface RawRegistryRecord {
  readonly providerId: string;
  readonly recordId: string;
  readonly retrievedAt: string;
  /** As delivered by the provider — untrusted, arbitrary shape. */
  readonly payload: Readonly<Record<string, unknown>>;
}

export type RegistryStatus = 'REGISTERED' | 'REMOVED' | 'DISSOLVED' | 'SUSPENDED' | 'UNKNOWN';

export interface CanonicalRegistryRecord {
  readonly providerId: string;
  readonly recordId: string;
  readonly rawRecordHash: string;
  /** Hash of the canonical DATA only (no retrieval time): same registry data
   * = same dataHash, which is what idempotent re-ingestion keys on (I2). */
  readonly dataHash: string;
  /** Stable internal identity: country:scheme:number (organization_identity.ts). */
  readonly canonicalOrgId: string;
  /** canonicalOrgId + cross-referenced registrations declared by the registry. */
  readonly canonicalIds: readonly string[];
  /** Normalized legal-name key (conflict detection; search only). */
  readonly nameKey: string;
  readonly retrievedAt: string;
  /** When the REGISTRY says its data was current (≤ retrievedAt). */
  readonly sourceAsOf?: string;
  readonly adapterVersion: string;
  readonly synthetic: boolean;
  readonly jurisdiction: Jurisdiction;
  readonly scheme: string;
  readonly registrationNumber: string;
  readonly name: string;
  readonly organizationType: OrganizationType;
  readonly status: RegistryStatus;
  readonly registeredOn?: string;
  readonly statusAsOf?: string;
  readonly dissolvedOn?: string;
  readonly formerNames: readonly FormerName[];
  readonly tradingNames: readonly string[];
  /** Other registrations the registry itself declares (e.g. a charity's company number). */
  readonly crossReferences: readonly { readonly country: string; readonly scheme: string; readonly value: string }[];
  readonly domains: readonly string[];
  readonly identity: OrganizationIdentity;
}

export interface ImpactSourceProvider {
  readonly descriptor: ProviderDescriptor;
  searchOrganization?(q: OrganizationQuery): Promise<ImpactResult<readonly RawRegistryRecord[]>>;
  fetchRegistryRecord?(recordId: string): Promise<ImpactResult<RawRegistryRecord>>;
}

export function supports(p: ImpactSourceProvider, c: ProviderCapability): boolean {
  if (!p.descriptor.capabilities.includes(c)) return false;
  if (c === 'SEARCH_ORGANIZATION') return typeof p.searchOrganization === 'function';
  if (c === 'FETCH_REGISTRY_RECORD') return typeof p.fetchRegistryRecord === 'function';
  return false;
}

export async function searchVia(p: ImpactSourceProvider, q: OrganizationQuery) {
  if (!supports(p, 'SEARCH_ORGANIZATION')) {
    return fail<readonly RawRegistryRecord[]>('CAPABILITY_NOT_SUPPORTED', 'provider cannot search', { providerId: p.descriptor.id });
  }
  return await p.searchOrganization!(q);
}

export async function fetchRegistryVia(p: ImpactSourceProvider, recordId: string) {
  if (!supports(p, 'FETCH_REGISTRY_RECORD')) {
    return fail<RawRegistryRecord>('CAPABILITY_NOT_SUPPORTED', 'provider cannot fetch registry records', { providerId: p.descriptor.id });
  }
  return await p.fetchRegistryRecord!(recordId);
}

const ORG_TYPES: ReadonlySet<string> = new Set([
  'CHARITY', 'NGO', 'NONPROFIT', 'FOUNDATION', 'SOCIAL_ENTERPRISE', 'RELIGIOUS_ORGANIZATION',
  'COMMUNITY_PROJECT', 'CROWDFUNDING_CAMPAIGN', 'INFORMAL_INITIATIVE', 'OTHER',
]);
const REGISTRY_STATUSES: ReadonlySet<string> = new Set(['REGISTERED', 'REMOVED', 'DISSOLVED', 'SUSPENDED', 'UNKNOWN']);

function str(v: unknown, max = 300): string | null {
  return typeof v === 'string' && v.trim() && v.length <= max ? v.trim() : null;
}

/** RAW → CANONICAL. Unknown fields are dropped; anything malformed rejects
 * the whole record (a half-parsed registry record is worse than none). */
export async function normalizeRegistryRecord(
  raw: RawRegistryRecord,
  provider: ProviderDescriptor,
): Promise<ImpactResult<CanonicalRegistryRecord>> {
  if (raw.providerId !== provider.id) return fail('INVALID_SOURCE', 'record from another provider');
  if (!isValidId(raw.recordId) || parseIsoMs(raw.retrievedAt) === null) return fail('INVALID_SOURCE', 'bad record envelope');
  const p = raw.payload;
  const country = str(p.country, 2)?.toUpperCase();
  const scheme = str(p.scheme, 60);
  const number = str(p.registration_number, 60);
  const name = str(p.name);
  if (!country || !/^[A-Z]{2}$/.test(country) || !scheme || !number || !name) {
    return fail('INVALID_SOURCE', 'registry record missing country/scheme/number/name', { recordId: raw.recordId });
  }
  if (!provider.jurisdictions.includes(country)) {
    return fail('INVALID_SOURCE', 'record outside the provider jurisdiction', { recordId: raw.recordId, country });
  }
  // Absent → OTHER/UNKNOWN; present but not an exact known value → reject
  // (a forged or overlong value must never degrade silently into a default).
  const type = p.organization_type === undefined ? 'OTHER' : str(p.organization_type, 40);
  const status = p.status === undefined ? 'UNKNOWN' : str(p.status, 40);
  if (!type || !status || !ORG_TYPES.has(type) || !REGISTRY_STATUSES.has(status)) {
    return fail('INVALID_SOURCE', 'unknown organization type or status', { recordId: raw.recordId });
  }
  const retrievedMs = parseIsoMs(raw.retrievedAt)!;
  for (const d of ['registered_on', 'status_as_of', 'dissolved_on', 'source_as_of'] as const) {
    if (p[d] === undefined) continue;
    const ms = parseIsoMs(p[d]);
    // Temporal integrity: the registry cannot describe a state after it was retrieved.
    if (ms === null || ms > retrievedMs) return fail('INVALID_SOURCE', `invalid or future ${d}`, { recordId: raw.recordId });
  }
  if (p.registered_on && p.dissolved_on && (parseIsoMs(p.dissolved_on) as number) < (parseIsoMs(p.registered_on) as number)) {
    return fail('INVALID_SOURCE', 'dissolved before registered', { recordId: raw.recordId });
  }
  if (p.dissolved_on !== undefined && status !== 'DISSOLVED' && status !== 'REMOVED') {
    return fail('INVALID_SOURCE', 'dissolved_on only with a DISSOLVED/REMOVED status', { recordId: raw.recordId });
  }
  const formerNames: FormerName[] = [];
  if (p.former_names !== undefined) {
    if (!Array.isArray(p.former_names) || p.former_names.length > 20) return fail('INVALID_SOURCE', 'former_names invalid', { recordId: raw.recordId });
    for (const f of p.former_names) {
      const fo = (f ?? {}) as Record<string, unknown>;
      const fname = str(fo.name);
      const from = fo.from === undefined ? undefined : fo.from;
      const to = fo.to === undefined ? undefined : fo.to;
      if (!fname || (from !== undefined && parseIsoMs(from) === null) || (to !== undefined && parseIsoMs(to) === null)
          || (from !== undefined && to !== undefined && (parseIsoMs(from) as number) > (parseIsoMs(to) as number))) {
        return fail('INVALID_SOURCE', 'former name invalid', { recordId: raw.recordId });
      }
      formerNames.push(Object.freeze({ name: fname, ...(from ? { from: from as string } : {}), ...(to ? { to: to as string } : {}) }));
    }
  }
  const tradingNames: string[] = [];
  if (p.trading_names !== undefined) {
    if (!Array.isArray(p.trading_names) || p.trading_names.length > 20) return fail('INVALID_SOURCE', 'trading_names invalid', { recordId: raw.recordId });
    for (const t of p.trading_names) {
      const tn = str(t);
      if (!tn) return fail('INVALID_SOURCE', 'trading name invalid', { recordId: raw.recordId });
      tradingNames.push(tn);
    }
  }
  const crossReferences: { country: string; scheme: string; value: string }[] = [];
  if (p.cross_references !== undefined) {
    if (!Array.isArray(p.cross_references) || p.cross_references.length > 10) return fail('INVALID_SOURCE', 'cross_references invalid', { recordId: raw.recordId });
    for (const x of p.cross_references) {
      const xo = (x ?? {}) as Record<string, unknown>;
      const xc = str(xo.country, 2)?.toUpperCase();
      const xs = str(xo.scheme, 60);
      const xv = str(xo.value, 60);
      // A cross-reference is only accepted inside the provider's own jurisdiction.
      if (!xc || xc !== country || !xs || !xv) return fail('INVALID_SOURCE', 'cross reference invalid', { recordId: raw.recordId });
      crossReferences.push(Object.freeze({ country: xc, scheme: xs, value: normalizeRegistration(xv) }));
    }
  }
  const domains = (Array.isArray(p.domains) ? p.domains : [])
    .map((d) => (typeof d === 'string' ? normalizeDomain(d) : null))
    .filter((d): d is string => !!d);
  const jurisdiction: Jurisdiction = { country, registry: provider.id };
  const registrationNumber = normalizeRegistration(number);
  const own = canonicalOrgId(country, scheme, registrationNumber);
  if (!isValidId(own)) return fail('INVALID_SOURCE', 'registration does not form a valid canonical id', { recordId: raw.recordId });
  const canonicalIds = [own, ...crossReferences.map((x) => canonicalOrgId(x.country, x.scheme, x.value))];
  const data = {
    country, scheme, registrationNumber, name, type, status, registeredOn: p.registered_on ?? null, statusAsOf: p.status_as_of ?? null,
    dissolvedOn: p.dissolved_on ?? null, sourceAsOf: p.source_as_of ?? null, formerNames, tradingNames, crossReferences, domains,
  };
  return ok(Object.freeze({
    providerId: provider.id,
    recordId: raw.recordId,
    rawRecordHash: await sha256Hex(JSON.stringify([raw.providerId, raw.recordId, raw.retrievedAt, p])),
    dataHash: await sha256Hex(JSON.stringify([raw.providerId, raw.recordId, data])),
    canonicalOrgId: own,
    canonicalIds: Object.freeze([...new Set(canonicalIds)]),
    nameKey: legalNameKey(name),
    retrievedAt: raw.retrievedAt,
    ...(p.source_as_of ? { sourceAsOf: p.source_as_of as string } : {}),
    adapterVersion: provider.adapterVersion,
    synthetic: provider.synthetic,
    jurisdiction,
    scheme,
    registrationNumber,
    name,
    organizationType: type as OrganizationType,
    status: status as RegistryStatus,
    ...(p.registered_on ? { registeredOn: p.registered_on as string } : {}),
    ...(p.status_as_of ? { statusAsOf: p.status_as_of as string } : {}),
    ...(p.dissolved_on ? { dissolvedOn: p.dissolved_on as string } : {}),
    formerNames: Object.freeze(formerNames),
    tradingNames: Object.freeze(tradingNames),
    crossReferences: Object.freeze(crossReferences),
    domains: Object.freeze(domains),
    identity: Object.freeze({
      legalName: name,
      ...(tradingNames.length ? { tradingNames } : {}),
      ...(formerNames.length ? { formerNames } : {}),
      registrations: [
        { jurisdiction, scheme, value: registrationNumber },
        ...crossReferences.map((x) => ({ jurisdiction: { country: x.country }, scheme: x.scheme, value: x.value })),
      ],
      domains,
      jurisdictions: [jurisdiction],
    }),
  }));
}

/** Deterministic in-memory provider for tests and the Lab. No I/O. */
export class FixtureProvider implements ImpactSourceProvider {
  constructor(
    readonly descriptor: ProviderDescriptor,
    private readonly records: readonly RawRegistryRecord[],
    private readonly available = true,
  ) {}

  searchOrganization(q: OrganizationQuery): Promise<ImpactResult<readonly RawRegistryRecord[]>> {
    if (!this.available) return Promise.resolve(fail('REGISTRY_UNAVAILABLE', 'fixture registry offline'));
    const name = q.name?.toLowerCase();
    const reg = q.registration ? normalizeRegistration(q.registration) : undefined;
    const dom = q.domain ? normalizeDomain(q.domain) : undefined;
    const scheme = q.scheme?.trim().toLowerCase();
    const hits = this.records.filter((r) => {
      const p = r.payload;
      if (q.country && String(p.country).toUpperCase() !== q.country.toUpperCase()) return false;
      if (scheme && String(p.scheme ?? '').trim().toLowerCase() !== scheme) return false;
      if (reg && normalizeRegistration(String(p.registration_number ?? '')) !== reg) return false;
      if (dom && !(Array.isArray(p.domains) && p.domains.some((d) => typeof d === 'string' && normalizeDomain(d) === dom))) return false;
      if (name) {
        // Search (not identity): current, trading and former names, loosely.
        const all = [p.name, ...(Array.isArray(p.trading_names) ? p.trading_names : []),
          ...(Array.isArray(p.former_names) ? p.former_names.map((f) => (f as { name?: unknown })?.name) : [])];
        if (!all.some((n) => typeof n === 'string' && legalNameKey(n).includes(legalNameKey(name)))) return false;
      }
      return true;
    });
    return Promise.resolve(ok(Object.freeze(hits)));
  }

  fetchRegistryRecord(recordId: string): Promise<ImpactResult<RawRegistryRecord>> {
    if (!this.available) return Promise.resolve(fail('REGISTRY_UNAVAILABLE', 'fixture registry offline'));
    const r = this.records.find((x) => x.recordId === recordId);
    return Promise.resolve(r ? ok(r) : fail('ORGANIZATION_NOT_FOUND', 'no such record', { recordId }));
  }
}
