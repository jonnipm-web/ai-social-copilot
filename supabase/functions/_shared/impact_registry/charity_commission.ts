/**
 * Charity Commission for England and Wales adapter — IV-IMPACT-I2.
 *
 * Official Register of Charities API (https://api-portal.charitycommission.gov.uk/),
 * subscription key header `Ocp-Apim-Subscription-Key` (Owner credential —
 * none configured; NOT composed into the Lab registry). Content is published
 * under the Open Government Licence v3.0 (IMPACT_REGISTRY_SOURCE_DOSSIER.md).
 * Endpoints used — and ONLY these:
 *   GET /register/api/allcharitydetailsV2/{regno}/0   main charity record
 *   GET /register/api/searchCharityName/{name}         name search
 * Trustee, contact and address endpoints are never called; person fields are
 * never parsed (PII minimization). The field mapping REQUIRES CONFIRMATION
 * against live responses once a credential exists (fixture-tested only).
 */
import { normalizeDomain } from '../impact/entity_resolution.ts';
import { fail, ok, type ImpactResult } from '../impact/errors.ts';
import type { ImpactSourceProvider, OrganizationQuery, ProviderDescriptor, RawRegistryRecord } from '../impact/provider.ts';
import { RegistryTransport, TRANSPORT_LIMITS, type TransportDeps } from './transport.ts';

export const CHARITY_COMMISSION_HOST = 'api.charitycommission.gov.uk';

export const CHARITY_COMMISSION: ProviderDescriptor = Object.freeze({
  id: 'gb-charity-commission',
  sourceType: 'OFFICIAL_REGISTRY',
  capabilities: Object.freeze(['SEARCH_ORGANIZATION', 'FETCH_REGISTRY_RECORD']) as ProviderDescriptor['capabilities'],
  jurisdictions: Object.freeze(['GB']) as readonly string[],
  authorityScope: Object.freeze(['LEGAL_REGISTRATION', 'REGULATORY_STATUS', 'OPERATING_HISTORY']) as readonly string[],
  freshnessDays: 2,
  retrievalMethod: 'OFFICIAL_API',
  official: true,
  authorityClass: 'STATUTORY_REGISTER',
  primaryPublisher: true,
  dataScope: 'Register of charities (England and Wales): number, name, registration/removal, linked company number, website (no trustees, contacts or addresses)',
  adapterVersion: 'gb-charity-commission/1',
  termsStatus: 'REQUIRES_CONFIRMATION',
  synthetic: false,
});

const RECORD_PREFIX = 'gb-cc-';
const REGNO_RE = /^\d{6,8}$/;
const MAX_SEARCH_ITEMS = 10;
const date = (v: unknown) => (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}/.test(v) ? v.slice(0, 10) : undefined);

export function mapCharity(json: unknown, retrievedAt: string): ImpactResult<RawRegistryRecord> {
  if (typeof json !== 'object' || json === null || Array.isArray(json)) return fail('REGISTRY_RESPONSE_INVALID', 'charity is not an object');
  const j = json as Record<string, unknown>;
  const regno = String(j.reg_charity_number ?? '');
  const name = typeof j.charity_name === 'string' ? j.charity_name : '';
  if (!REGNO_RE.test(regno) || !name.trim()) return fail('REGISTRY_RESPONSE_INVALID', 'charity misses number or name');
  const removed = j.reg_status === 'RM';
  const registered = j.reg_status === 'R';
  const company = typeof j.charity_company_registration_number === 'string' ? j.charity_company_registration_number.trim().toUpperCase() : '';
  const web = typeof j.charity_contact_web === 'string' ? normalizeDomain(j.charity_contact_web) : null;
  return ok({
    providerId: CHARITY_COMMISSION.id,
    recordId: `${RECORD_PREFIX}${regno}`,
    retrievedAt,
    payload: {
      country: 'GB',
      scheme: 'charity-number',
      registration_number: regno,
      name,
      organization_type: 'CHARITY',
      status: registered ? 'REGISTERED' : removed ? 'REMOVED' : 'UNKNOWN',
      status_detail: registered ? 'registered' : removed ? 'removed' : 'unknown',
      ...(date(j.date_of_registration) ? { registered_on: date(j.date_of_registration) } : {}),
      ...(removed && date(j.date_of_removal) ? { dissolved_on: date(j.date_of_removal) } : {}),
      ...(/^[A-Z0-9]{8}$/.test(company) ? { cross_references: [{ country: 'GB', scheme: 'company-number', value: company }] } : {}),
      ...(web ? { domains: [web] } : {}),
      // trustees / contact e-mail / phone / address deliberately dropped
    },
  });
}

export class CharityCommissionProvider implements ImpactSourceProvider {
  readonly descriptor = CHARITY_COMMISSION;
  private readonly transport: RegistryTransport;
  constructor(subscriptionKey: string, deps: TransportDeps = {}) {
    if (!subscriptionKey || subscriptionKey.length > 200) throw new Error('Charity Commission subscription key required');
    this.transport = new RegistryTransport({
      providerId: CHARITY_COMMISSION.id,
      hosts: [CHARITY_COMMISSION_HOST],
      contentTypes: ['application/json'],
      maxBytes: TRANSPORT_LIMITS.maxJsonBytes,
      minIntervalMs: 1_000, // no published figure found: conservative 1 req/s (dossier)
      headers: { 'Ocp-Apim-Subscription-Key': subscriptionKey },
    }, deps);
  }

  async fetchRegistryRecord(recordId: string): Promise<ImpactResult<RawRegistryRecord>> {
    if (!recordId.startsWith(RECORD_PREFIX)) return fail('INVALID_REQUEST', 'not a Charity Commission record id');
    const regno = recordId.slice(RECORD_PREFIX.length);
    if (!REGNO_RE.test(regno)) return fail('INVALID_REQUEST', 'invalid charity number');
    const r = await this.transport.getJson(`https://${CHARITY_COMMISSION_HOST}/register/api/allcharitydetailsV2/${regno}/0`);
    if (!r.ok) return r;
    const m = mapCharity(r.value.json, r.value.retrievedAt);
    if (!m.ok) return m;
    return m.value.recordId === recordId ? m : fail('REGISTRY_RESPONSE_INVALID', 'registry answered for another charity');
  }

  async searchOrganization(q: OrganizationQuery): Promise<ImpactResult<readonly RawRegistryRecord[]>> {
    if (q.country && q.country.toUpperCase() !== 'GB') return ok([]);
    if (q.registration) {
      const one = await this.fetchRegistryRecord(`${RECORD_PREFIX}${q.registration.replace(/\D/g, '')}`);
      if (!one.ok) return one.error.code === 'ORGANIZATION_NOT_FOUND' || one.error.code === 'INVALID_REQUEST' ? ok([]) : one;
      return ok([one.value]);
    }
    if (!q.name || q.name.length > 200) return ok([]);
    const r = await this.transport.getJson(`https://${CHARITY_COMMISSION_HOST}/register/api/searchCharityName/${encodeURIComponent(q.name)}`);
    if (!r.ok) return r;
    if (!Array.isArray(r.value.json)) return fail('REGISTRY_RESPONSE_INVALID', 'search result is not a list');
    const out: RawRegistryRecord[] = [];
    for (const it of r.value.json.slice(0, MAX_SEARCH_ITEMS)) {
      const m = mapCharity(it, r.value.retrievedAt);
      if (m.ok) out.push(m.value);
    }
    return ok(out);
  }
}
