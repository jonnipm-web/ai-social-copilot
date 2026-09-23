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
import type { Jurisdiction, OrganizationIdentity, OrganizationType, SourceType } from './types.ts';

export type ProviderCapability = 'SEARCH_ORGANIZATION' | 'FETCH_REGISTRY_RECORD' | 'FETCH_EVIDENCE';
export type RetrievalMethod = 'FIXTURE' | 'OFFICIAL_API' | 'BULK_DATASET' | 'LICENSED_API' | 'MANUAL_UPLOAD';

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
}

export interface OrganizationQuery {
  readonly name?: string;
  readonly registration?: string;
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
  readonly retrievedAt: string;
  readonly jurisdiction: Jurisdiction;
  readonly scheme: string;
  readonly registrationNumber: string;
  readonly name: string;
  readonly organizationType: OrganizationType;
  readonly status: RegistryStatus;
  readonly registeredOn?: string;
  readonly statusAsOf?: string;
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
  for (const d of ['registered_on', 'status_as_of'] as const) {
    if (p[d] !== undefined && parseIsoMs(p[d]) === null) return fail('INVALID_SOURCE', `invalid ${d}`, { recordId: raw.recordId });
  }
  const domains = (Array.isArray(p.domains) ? p.domains : [])
    .map((d) => (typeof d === 'string' ? normalizeDomain(d) : null))
    .filter((d): d is string => !!d);
  const jurisdiction: Jurisdiction = { country, registry: provider.id };
  const registrationNumber = normalizeRegistration(number);
  return ok(Object.freeze({
    providerId: provider.id,
    recordId: raw.recordId,
    rawRecordHash: await sha256Hex(JSON.stringify([raw.providerId, raw.recordId, raw.retrievedAt, p])),
    retrievedAt: raw.retrievedAt,
    jurisdiction,
    scheme,
    registrationNumber,
    name,
    organizationType: type as OrganizationType,
    status: status as RegistryStatus,
    ...(p.registered_on ? { registeredOn: p.registered_on as string } : {}),
    ...(p.status_as_of ? { statusAsOf: p.status_as_of as string } : {}),
    domains: Object.freeze(domains),
    identity: Object.freeze({
      legalName: name,
      registrations: [{ jurisdiction, scheme, value: registrationNumber }],
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
    const hits = this.records.filter((r) => {
      const p = r.payload;
      if (q.country && String(p.country).toUpperCase() !== q.country.toUpperCase()) return false;
      if (reg && normalizeRegistration(String(p.registration_number ?? '')) !== reg) return false;
      if (dom && !(Array.isArray(p.domains) && p.domains.some((d) => typeof d === 'string' && normalizeDomain(d) === dom))) return false;
      if (name && !String(p.name ?? '').toLowerCase().includes(name)) return false;
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
