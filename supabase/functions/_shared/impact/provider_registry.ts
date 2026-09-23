/**
 * Server-side provider registry — IV-IMPACT-I1-PERSISTENCE-RLS-01 (closes CF-06).
 *
 * The ONLY place that decides which providers are trusted. It is composed
 * here, in server code, from fixed descriptors; no request field, header or
 * stored row can add, remove or re-scope a provider. The Verification Engine
 * receives `trustedProviderRefs()` from the server composition, never from a
 * caller.
 *
 * A source becomes acquisition=PROVIDER only through
 * `ingestProviderRecord()`, which fetches the record from the registered
 * provider itself and builds the Source (type, publisher, jurisdiction,
 * content hash) from the provider's own declaration. Client-submitted sources
 * are forced to ANALYST_ENTRY / USER_UPLOAD by the Lab contract, so a caller
 * cannot claim "a government provider fetched this".
 *
 * Lab scope: fixture providers only (retrievalMethod FIXTURE, network NONE),
 * fictitious jurisdiction XA. Real registry adapters are gate I2 and must use
 * _shared/safe_fetch.ts.
 */
import { fail, ok, type ImpactResult } from './errors.ts';
import { type CanonicalRegistryRecord, FixtureProvider, type ImpactSourceProvider, normalizeRegistryRecord, type ProviderDescriptor, type RawRegistryRecord } from './provider.ts';
import { isValidId } from './provenance.ts';
import type { Source, TrustedProviderRef } from './types.ts';

export const PROVIDER_REGISTRY_VERSION = 'impact-provider-registry/1';

export type ProviderNetwork = 'NONE' | 'HTTPS_VIA_SAFE_FETCH';

export interface RegisteredProvider {
  readonly descriptor: ProviderDescriptor;
  /** Publisher name written on every source this provider produces. */
  readonly publisher: string;
  readonly network: ProviderNetwork;
  readonly provider: ImpactSourceProvider;
}

/** Fictitious registry records (jurisdiction XA). Never real organizations. */
const XA_REGISTRY_RECORDS: readonly RawRegistryRecord[] = Object.freeze([
  {
    providerId: 'fixture-xa-charity-registry', recordId: 'xa-1234567', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'charity-number', registration_number: 'XA-1234567', name: 'HopeBridge Foundation',
      organization_type: 'FOUNDATION', status: 'REGISTERED', status_as_of: '2026-08-31', registered_on: '2012-03-01',
      domains: ['hopebridge.example'],
    },
  },
  {
    providerId: 'fixture-xa-charity-registry', recordId: 'xa-7654321', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'charity-number', registration_number: 'XA-7654321', name: 'Northstar Relief Initiative',
      organization_type: 'NGO', status: 'REGISTERED', status_as_of: '2026-08-31', domains: ['northstar-relief.example'],
    },
  },
  {
    providerId: 'fixture-xa-charity-registry', recordId: 'xa-9990001', retrievedAt: '2026-09-01T00:00:00Z',
    payload: {
      country: 'XA', scheme: 'charity-number', registration_number: 'XA-9990001', name: 'Northstar Relief',
      organization_type: 'COMMUNITY_PROJECT', status: 'REMOVED', status_as_of: '2025-01-15', domains: ['northstar-relief-appeal.example'],
    },
  },
]);

const XA_REGISTRY: ProviderDescriptor = Object.freeze({
  id: 'fixture-xa-charity-registry',
  sourceType: 'OFFICIAL_REGISTRY',
  capabilities: Object.freeze(['SEARCH_ORGANIZATION', 'FETCH_REGISTRY_RECORD']) as ProviderDescriptor['capabilities'],
  jurisdictions: Object.freeze(['XA']) as readonly string[],
  authorityScope: Object.freeze(['LEGAL_REGISTRATION', 'REGULATORY_STATUS', 'GOVERNANCE', 'OPERATING_HISTORY']) as readonly string[],
  freshnessDays: 7,
  retrievalMethod: 'FIXTURE',
});

const REGISTRY: ReadonlyMap<string, RegisteredProvider> = new Map(
  [
    Object.freeze({
      descriptor: XA_REGISTRY,
      publisher: 'Exampleland Charity Registry (fixture)',
      network: 'NONE' as const,
      provider: new FixtureProvider(XA_REGISTRY, XA_REGISTRY_RECORDS),
    }),
  ].map((p) => [p.descriptor.id, p]),
);

export function registeredProviders(): readonly RegisteredProvider[] {
  return Object.freeze([...REGISTRY.values()]);
}

/** Map lookup only — prototype keys ("__proto__", "constructor") never resolve. */
export function getRegisteredProvider(id: unknown): RegisteredProvider | undefined {
  return typeof id === 'string' ? REGISTRY.get(id) : undefined;
}

/** The trusted set handed to the Verification Engine by the server. */
export function trustedProviderRefs(): readonly TrustedProviderRef[] {
  return Object.freeze([...REGISTRY.values()].map((p) =>
    Object.freeze({ id: p.descriptor.id, sourceType: p.descriptor.sourceType, jurisdictions: p.descriptor.jurisdictions })
  ));
}

export interface IngestedRecord {
  readonly source: Source;
  readonly record: CanonicalRegistryRecord;
}

/** Server-side ingestion: the provider fetches, the server builds the Source. */
export async function ingestProviderRecord(providerId: unknown, recordId: unknown, ref: string): Promise<ImpactResult<IngestedRecord>> {
  const reg = getRegisteredProvider(providerId);
  if (!reg) return fail('CAPABILITY_NOT_SUPPORTED', 'unknown provider');
  if (!isValidId(recordId) || !isValidId(ref)) return fail('INVALID_REQUEST', 'invalid record id or ref');
  if (!reg.descriptor.capabilities.includes('FETCH_REGISTRY_RECORD') || !reg.provider.fetchRegistryRecord) {
    return fail('CAPABILITY_NOT_SUPPORTED', 'provider cannot fetch records', { providerId: reg.descriptor.id });
  }
  const raw = await reg.provider.fetchRegistryRecord(recordId);
  if (!raw.ok) return raw;
  const canon = await normalizeRegistryRecord(raw.value, reg.descriptor);
  if (!canon.ok) return canon;
  const r = canon.value;
  const source: Source = Object.freeze({
    id: ref,
    type: reg.descriptor.sourceType,
    publisher: reg.publisher,
    retrievedAt: r.retrievedAt,
    jurisdiction: Object.freeze({ country: r.jurisdiction.country, registry: reg.descriptor.id }),
    status: 'ACTIVE' as const,
    retention: 'SNAPSHOT' as const,
    contentHash: r.rawRecordHash,
    acquisition: Object.freeze({ method: 'PROVIDER' as const, providerId: reg.descriptor.id }),
  });
  return ok(Object.freeze({ source, record: r }));
}
