/**
 * Server-side provider registry — IV-IMPACT-I1 (CF-06) + I2 (Registry Intelligence).
 *
 * The ONLY place that decides which providers are trusted. It is composed
 * here, in server code, from fixed descriptors; no request field, header or
 * stored row can add, remove or re-scope a provider or its authority
 * metadata (official, authority class, primary publisher, jurisdictions,
 * adapter version). The Verification Engine receives `trustedRefs()` from the
 * server composition, never from a caller.
 *
 * A source becomes acquisition=PROVIDER only through `ingestProviderRecord()`,
 * which fetches the record from the registered provider itself and builds the
 * Source (type, publisher, jurisdiction, content hash) from the provider's own
 * declaration. Client-submitted sources are forced to ANALYST_ENTRY /
 * USER_UPLOAD by the Lab contract, so a caller cannot claim "a government
 * provider fetched this".
 *
 * Lab scope: SYNTHETIC fixture registries only (retrievalMethod FIXTURE,
 * network NONE, fictitious jurisdictions XA / XB — never real organizations).
 * Real registry adapters (Companies House, Charity Commission, IRS EO BMF)
 * live in _shared/impact_registry/, go through safe_fetch.ts, and are NOT
 * composed into the Lab registry until their terms are confirmed and the
 * Owner enables them (IMPACT_REGISTRY_SOURCE_DOSSIER.md). Every provider
 * here must be mirrored by public.impact_trusted_provider (drift-tested).
 */
import { fail, ok, type ImpactResult } from './errors.ts';
import {
  type CanonicalRegistryRecord,
  FixtureProvider,
  type ImpactSourceProvider,
  normalizeRegistryRecord,
  type OrganizationQuery,
  type ProviderDescriptor,
  type RawRegistryRecord,
  searchVia,
} from './provider.ts';
import { isValidId } from './provenance.ts';
import type { Source, TrustedProviderRef } from './types.ts';

export const PROVIDER_REGISTRY_VERSION = 'impact-provider-registry/2';

export type ProviderNetwork = 'NONE' | 'HTTPS_VIA_SAFE_FETCH';

export interface RegisteredProvider {
  readonly descriptor: ProviderDescriptor;
  /** Publisher name written on every source this provider produces. */
  readonly publisher: string;
  readonly network: ProviderNetwork;
  readonly provider: ImpactSourceProvider;
}

export const REGISTRY_LIMITS = Object.freeze({
  /** Records a search may return before normalization (algorithmic DoS bound). */
  maxSearchRecords: 50,
});

// ── SYNTHETIC fixtures (XA / XB are fictitious jurisdictions) ──────────────

const XA_CHARITY_RECORDS: readonly RawRegistryRecord[] = Object.freeze([
  {
    providerId: 'fixture-xa-charity-registry', recordId: 'xa-1234567', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'charity-number', registration_number: 'XA-1234567', name: 'HopeBridge Foundation',
      organization_type: 'FOUNDATION', status: 'REGISTERED', status_as_of: '2026-08-31', registered_on: '2012-03-01',
      source_as_of: '2026-08-31', domains: ['hopebridge.example'], trading_names: ['HopeBridge'],
      former_names: [{ name: 'HopeBridge Trust', from: '2012-03-01', to: '2018-06-01' }],
      cross_references: [{ country: 'XA', scheme: 'company-number', value: 'XA-C-778899' }],
      // Officers / trustees are NEVER part of a canonical record (dropped by normalization).
      trustees: [{ name: 'Synthetic Person One' }],
    },
  },
  {
    providerId: 'fixture-xa-charity-registry', recordId: 'xa-7654321', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'charity-number', registration_number: 'XA-7654321', name: 'Northstar Relief Initiative',
      organization_type: 'NGO', status: 'REGISTERED', status_as_of: '2026-08-31', registered_on: '2015-01-01',
      domains: ['northstar-relief.example'], former_names: [{ name: 'Northstar Aid', from: '2015-01-01', to: '2020-05-01' }],
    },
  },
  {
    providerId: 'fixture-xa-charity-registry', recordId: 'xa-9990001', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'charity-number', registration_number: 'XA-9990001', name: 'Northstar Relief',
      organization_type: 'COMMUNITY_PROJECT', status: 'REMOVED', status_as_of: '2025-01-15', dissolved_on: '2025-01-15',
      domains: ['northstar-relief-appeal.example'], cross_references: [{ country: 'XA', scheme: 'company-number', value: 'XA-C-990001' }],
    },
  },
  {
    providerId: 'fixture-xa-charity-registry', recordId: 'xa-5550001', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'charity-number', registration_number: 'XA-5550001', name: 'Example Aid Trust',
      organization_type: 'CHARITY', status: 'REGISTERED', status_as_of: '2026-08-31', domains: ['example-aid.example'],
    },
  },
  {
    // Same legal name, same jurisdiction, DIFFERENT organization.
    providerId: 'fixture-xa-charity-registry', recordId: 'xa-5550002', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'charity-number', registration_number: 'XA-5550002', name: 'Example Aid Trust',
      organization_type: 'COMMUNITY_PROJECT', status: 'REGISTERED', status_as_of: '2026-08-31', domains: ['exampleaid-local.example'],
    },
  },
]);

const XA_COMPANY_RECORDS: readonly RawRegistryRecord[] = Object.freeze([
  {
    // Same organization as charity XA-1234567 (cross-referenced both ways);
    // the company register spells the name with "Limited" → NAME_MISMATCH conflict.
    providerId: 'fixture-xa-company-registry', recordId: 'xa-c-778899', retrievedAt: '2026-09-02T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'company-number', registration_number: 'XA-C-778899', name: 'HopeBridge Foundation Limited',
      organization_type: 'FOUNDATION', status: 'REGISTERED', status_as_of: '2026-09-01', registered_on: '2012-02-20',
      cross_references: [{ country: 'XA', scheme: 'charity-number', value: 'XA-1234567' }],
    },
  },
  {
    // Company of the REMOVED charity XA-9990001 still listed as registered → STATUS_MISMATCH conflict.
    providerId: 'fixture-xa-company-registry', recordId: 'xa-c-990001', retrievedAt: '2026-09-02T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'company-number', registration_number: 'XA-C-990001', name: 'Northstar Relief',
      organization_type: 'COMMUNITY_PROJECT', status: 'REGISTERED', status_as_of: '2026-09-01',
      cross_references: [{ country: 'XA', scheme: 'charity-number', value: 'XA-9990001' }],
    },
  },
]);

const XB_CHARITY_RECORDS: readonly RawRegistryRecord[] = Object.freeze([
  {
    // Same legal name as XA-1234567, OTHER jurisdiction → another organization.
    providerId: 'fixture-xb-charity-registry', recordId: 'xb-1234567', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XB', scheme: 'charity-number', registration_number: 'XB-1234567', name: 'HopeBridge Foundation',
      organization_type: 'FOUNDATION', status: 'REGISTERED', status_as_of: '2026-08-31', domains: ['hopebridge-xb.example'],
    },
  },
]);

const FIXTURE_BASE = {
  sourceType: 'OFFICIAL_REGISTRY' as const,
  capabilities: Object.freeze(['SEARCH_ORGANIZATION', 'FETCH_REGISTRY_RECORD']) as ProviderDescriptor['capabilities'],
  authorityScope: Object.freeze(['LEGAL_REGISTRATION', 'REGULATORY_STATUS', 'GOVERNANCE', 'OPERATING_HISTORY']) as readonly string[],
  freshnessDays: 7,
  retrievalMethod: 'FIXTURE' as const,
  official: true, // official WITHIN the fiction: a synthetic statutory register
  authorityClass: 'STATUTORY_REGISTER' as const,
  primaryPublisher: true,
  adapterVersion: 'fixture-adapter/2',
  termsStatus: 'SYNTHETIC' as const,
  synthetic: true,
};

const XA_CHARITY: ProviderDescriptor = Object.freeze({
  ...FIXTURE_BASE, id: 'fixture-xa-charity-registry', jurisdictions: Object.freeze(['XA']) as readonly string[],
  dataScope: 'SYNTHETIC charity register of Exampleland (XA): registration, status, names, domains',
});
const XA_COMPANY: ProviderDescriptor = Object.freeze({
  ...FIXTURE_BASE, id: 'fixture-xa-company-registry', jurisdictions: Object.freeze(['XA']) as readonly string[],
  dataScope: 'SYNTHETIC company register of Exampleland (XA): incorporation, status, names',
});
const XB_CHARITY: ProviderDescriptor = Object.freeze({
  ...FIXTURE_BASE, id: 'fixture-xb-charity-registry', jurisdictions: Object.freeze(['XB']) as readonly string[],
  dataScope: 'SYNTHETIC charity register of Otherland (XB): registration, status, names, domains',
});

// ── composition ────────────────────────────────────────────────────────────

export interface ProviderRegistry {
  readonly version: string;
  get(id: unknown): RegisteredProvider | undefined;
  list(): readonly RegisteredProvider[];
  /** The trusted set handed to the Verification Engine. */
  trustedRefs(): readonly TrustedProviderRef[];
}

/** Frozen, server-composed registry. Duplicate ids or malformed descriptors fail closed. */
export function composeProviderRegistry(entries: readonly RegisteredProvider[]): ProviderRegistry {
  const map = new Map<string, RegisteredProvider>();
  for (const e of entries) {
    const d = e.descriptor;
    if (!isValidId(d.id) || map.has(d.id) || e.provider.descriptor !== d) throw new Error(`invalid provider composition: ${d.id}`);
    if (!d.jurisdictions.length || d.jurisdictions.some((j) => !/^[A-Z]{2}$/.test(j))) throw new Error(`invalid jurisdictions: ${d.id}`);
    if ((e.network === 'NONE') !== (d.retrievalMethod === 'FIXTURE')) throw new Error(`network/retrieval mismatch: ${d.id}`);
    map.set(d.id, Object.freeze(e));
  }
  const refs = Object.freeze([...map.values()].map((p) =>
    Object.freeze({
      id: p.descriptor.id, sourceType: p.descriptor.sourceType, jurisdictions: p.descriptor.jurisdictions,
      primaryPublisher: p.descriptor.primaryPublisher,
    })
  ));
  const list = Object.freeze([...map.values()]);
  return Object.freeze({
    version: PROVIDER_REGISTRY_VERSION,
    // Map lookup only — prototype keys ("__proto__", "constructor") never resolve.
    get: (id: unknown) => (typeof id === 'string' ? map.get(id) : undefined),
    list: () => list,
    trustedRefs: () => refs,
  });
}

const fixture = (d: ProviderDescriptor, publisher: string, records: readonly RawRegistryRecord[]): RegisteredProvider => ({
  descriptor: d, publisher, network: 'NONE', provider: new FixtureProvider(d, records),
});

/** The Lab composition: synthetic registries only. */
export const SERVER_PROVIDER_REGISTRY: ProviderRegistry = composeProviderRegistry([
  fixture(XA_CHARITY, 'Exampleland Charity Registry (fixture)', XA_CHARITY_RECORDS),
  fixture(XA_COMPANY, 'Exampleland Company Registry (fixture)', XA_COMPANY_RECORDS),
  fixture(XB_CHARITY, 'Otherland Charity Registry (fixture)', XB_CHARITY_RECORDS),
]);

export function registeredProviders(): readonly RegisteredProvider[] {
  return SERVER_PROVIDER_REGISTRY.list();
}

export function getRegisteredProvider(id: unknown): RegisteredProvider | undefined {
  return SERVER_PROVIDER_REGISTRY.get(id);
}

export function trustedProviderRefs(): readonly TrustedProviderRef[] {
  return SERVER_PROVIDER_REGISTRY.trustedRefs();
}

export interface IngestedRecord {
  readonly source: Source;
  readonly record: CanonicalRegistryRecord;
}

/** Server-side ingestion: the provider fetches, the server builds the Source. */
export async function ingestProviderRecord(
  providerId: unknown,
  recordId: unknown,
  ref: string,
  registry: ProviderRegistry = SERVER_PROVIDER_REGISTRY,
): Promise<ImpactResult<IngestedRecord>> {
  const reg = registry.get(providerId);
  if (!reg) return fail('CAPABILITY_NOT_SUPPORTED', 'unknown provider');
  if (!isValidId(recordId) || !isValidId(ref)) return fail('INVALID_REQUEST', 'invalid record id or ref');
  if (!reg.descriptor.capabilities.includes('FETCH_REGISTRY_RECORD') || !reg.provider.fetchRegistryRecord) {
    return fail('CAPABILITY_NOT_SUPPORTED', 'provider cannot fetch records', { providerId: reg.descriptor.id });
  }
  const raw = await reg.provider.fetchRegistryRecord(recordId);
  if (!raw.ok) return raw;
  // The record must be the one asked for, from this provider (no substitution).
  if (raw.value.recordId !== recordId || raw.value.providerId !== reg.descriptor.id) {
    return fail('REGISTRY_RESPONSE_INVALID', 'provider returned another record', { providerId: reg.descriptor.id });
  }
  const canon = await normalizeRegistryRecord(raw.value, reg.descriptor);
  if (!canon.ok) return canon;
  const r = canon.value;
  const source: Source = Object.freeze({
    id: ref,
    type: reg.descriptor.sourceType,
    publisher: reg.publisher,
    retrievedAt: r.retrievedAt,
    ...(r.sourceAsOf ? { publishedAt: r.sourceAsOf } : {}),
    jurisdiction: Object.freeze({ country: r.jurisdiction.country, registry: reg.descriptor.id }),
    status: 'ACTIVE' as const,
    retention: 'SNAPSHOT' as const,
    contentHash: r.rawRecordHash,
    acquisition: Object.freeze({ method: 'PROVIDER' as const, providerId: reg.descriptor.id }),
  });
  return ok(Object.freeze({ source, record: r }));
}

/** Server-side search: raw provider hits → normalized canonical records (bounded). */
export async function searchProvider(
  providerId: unknown,
  q: OrganizationQuery,
  registry: ProviderRegistry = SERVER_PROVIDER_REGISTRY,
): Promise<ImpactResult<readonly CanonicalRegistryRecord[]>> {
  const reg = registry.get(providerId);
  if (!reg) return fail('CAPABILITY_NOT_SUPPORTED', 'unknown provider');
  const raw = await searchVia(reg.provider, q);
  if (!raw.ok) return raw;
  const out: CanonicalRegistryRecord[] = [];
  for (const r of raw.value.slice(0, REGISTRY_LIMITS.maxSearchRecords)) {
    if (r.providerId !== reg.descriptor.id) return fail('REGISTRY_RESPONSE_INVALID', 'record from another provider');
    const c = await normalizeRegistryRecord(r, reg.descriptor);
    if (!c.ok) return fail('REGISTRY_RESPONSE_INVALID', 'provider returned a malformed record', { recordId: r.recordId });
    out.push(c.value);
  }
  return ok(Object.freeze(out));
}
