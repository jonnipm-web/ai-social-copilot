/**
 * UK Companies House adapter — IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01.
 *
 * Official API (https://developer.company-information.service.gov.uk/),
 * HTTP Basic with an API key (Owner credential — none is configured in the
 * Lab, so this adapter is NOT composed into the Lab registry;
 * IMPACT_REGISTRY_SOURCE_DOSSIER.md). Endpoints used — and ONLY these:
 *   GET /company/{company_number}            company profile
 *   GET /search/companies?q=…&items_per_page  name search (candidates)
 * Officers, persons with significant control, addresses and filings are
 * never requested, never parsed, never stored (PII minimization).
 *
 * The adapter only translates the registry's own format into the canonical
 * payload that provider.ts normalizeRegistryRecord() validates; it decides
 * nothing about status, authority or identity beyond that mapping.
 */
import { fail, ok, type ImpactResult } from '../impact/errors.ts';
import type { ImpactSourceProvider, OrganizationQuery, ProviderDescriptor, RawRegistryRecord, RegistryStatus } from '../impact/provider.ts';
import { RegistryTransport, TRANSPORT_LIMITS, type TransportDeps } from './transport.ts';

export const COMPANIES_HOUSE_HOST = 'api.company-information.service.gov.uk';

export const COMPANIES_HOUSE: ProviderDescriptor = Object.freeze({
  id: 'gb-companies-house',
  sourceType: 'OFFICIAL_REGISTRY',
  capabilities: Object.freeze(['SEARCH_ORGANIZATION', 'FETCH_REGISTRY_RECORD']) as ProviderDescriptor['capabilities'],
  jurisdictions: Object.freeze(['GB']) as readonly string[],
  authorityScope: Object.freeze(['LEGAL_REGISTRATION', 'OPERATING_HISTORY']) as readonly string[],
  freshnessDays: 2,
  retrievalMethod: 'OFFICIAL_API',
  official: true,
  authorityClass: 'STATUTORY_REGISTER',
  primaryPublisher: true,
  dataScope: 'UK register of companies: number, name, status, incorporation/cessation dates, previous names (no officers, PSC or addresses)',
  adapterVersion: 'gb-companies-house/1',
  termsStatus: 'REQUIRES_CONFIRMATION',
  synthetic: false,
});

/** Companies House numbers: 8 characters, digits or a 2-letter prefix (SC, NI, OC, …). */
const NUMBER_RE = /^[A-Z0-9]{8}$/;
const RECORD_PREFIX = 'gb-ch-';
const MAX_SEARCH_ITEMS = 10;

function mapStatus(s: unknown): { status: RegistryStatus; detail: string } {
  const raw = typeof s === 'string' ? s.toLowerCase().replace(/[^a-z0-9-]/g, '-').slice(0, 40) : 'unknown';
  if (raw === 'active') return { status: 'REGISTERED', detail: raw };
  if (raw === 'dissolved') return { status: 'DISSOLVED', detail: raw };
  if (raw === 'converted-closed' || raw === 'closed' || raw === 'removed') return { status: 'REMOVED', detail: raw };
  // liquidation, administration, receivership, voluntary-arrangement,
  // insolvency-proceedings, open, … : kept verbatim, never mapped to a judgement.
  return { status: 'UNKNOWN', detail: raw || 'unknown' };
}

const date = (v: unknown) => (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v) ? v : undefined);

/** Company profile JSON → canonical payload (untrusted input; normalize validates again). */
export function mapCompanyProfile(json: unknown, retrievedAt: string): ImpactResult<RawRegistryRecord> {
  if (typeof json !== 'object' || json === null || Array.isArray(json)) return fail('REGISTRY_RESPONSE_INVALID', 'profile is not an object');
  const j = json as Record<string, unknown>;
  const number = typeof j.company_number === 'string' ? j.company_number.toUpperCase() : '';
  const name = typeof j.company_name === 'string' ? j.company_name : typeof j.title === 'string' ? j.title : '';
  if (!NUMBER_RE.test(number) || !name.trim()) return fail('REGISTRY_RESPONSE_INVALID', 'profile misses number or name');
  const st = mapStatus(j.company_status);
  const previous = Array.isArray(j.previous_company_names) ? j.previous_company_names.slice(0, 20) : [];
  const formerNames = previous
    .map((p) => (typeof p === 'object' && p !== null ? p as Record<string, unknown> : {}))
    .filter((p) => typeof p.name === 'string' && (p.name as string).trim())
    .map((p) => ({ name: p.name as string, ...(date(p.effective_from) ? { from: date(p.effective_from) } : {}), ...(date(p.ceased_on) ? { to: date(p.ceased_on) } : {}) }));
  const cessation = date(j.date_of_cessation);
  return ok({
    providerId: COMPANIES_HOUSE.id,
    recordId: `${RECORD_PREFIX}${number.toLowerCase()}`,
    retrievedAt,
    payload: {
      country: 'GB',
      scheme: 'company-number',
      registration_number: number,
      name,
      organization_type: 'OTHER', // a company type is not evidence of charitable status
      status: st.status,
      status_detail: st.detail,
      ...(date(j.date_of_creation) ? { registered_on: date(j.date_of_creation) } : {}),
      ...(cessation && (st.status === 'DISSOLVED' || st.status === 'REMOVED') ? { dissolved_on: cessation } : {}),
      ...(formerNames.length ? { former_names: formerNames } : {}),
      // officers / PSC / registered_office_address deliberately dropped
    },
  });
}

export class CompaniesHouseProvider implements ImpactSourceProvider {
  readonly descriptor = COMPANIES_HOUSE;
  private readonly transport: RegistryTransport;
  constructor(apiKey: string, deps: TransportDeps = {}) {
    if (!apiKey || apiKey.length > 200) throw new Error('Companies House API key required');
    this.transport = new RegistryTransport({
      providerId: COMPANIES_HOUSE.id,
      hosts: [COMPANIES_HOUSE_HOST],
      contentTypes: ['application/json'],
      maxBytes: TRANSPORT_LIMITS.maxJsonBytes,
      // Published limit: 600 requests / 5 minutes → ≥ 500 ms between requests.
      minIntervalMs: 500,
      headers: { Authorization: `Basic ${btoa(`${apiKey}:`)}` },
    }, deps);
  }

  async fetchRegistryRecord(recordId: string): Promise<ImpactResult<RawRegistryRecord>> {
    if (!recordId.startsWith(RECORD_PREFIX)) return fail('INVALID_REQUEST', 'not a Companies House record id');
    const number = recordId.slice(RECORD_PREFIX.length).toUpperCase();
    if (!NUMBER_RE.test(number)) return fail('INVALID_REQUEST', 'invalid company number');
    const r = await this.transport.getJson(`https://${COMPANIES_HOUSE_HOST}/company/${encodeURIComponent(number)}`);
    if (!r.ok) return r;
    const m = mapCompanyProfile(r.value.json, r.value.retrievedAt);
    if (!m.ok) return m;
    // The registry must answer for the record that was asked for.
    return m.value.recordId === recordId.toLowerCase() ? m : fail('REGISTRY_RESPONSE_INVALID', 'registry answered for another company');
  }

  async searchOrganization(q: OrganizationQuery): Promise<ImpactResult<readonly RawRegistryRecord[]>> {
    if (q.country && q.country.toUpperCase() !== 'GB') return ok([]);
    if (q.registration) {
      const one = await this.fetchRegistryRecord(`${RECORD_PREFIX}${q.registration.replace(/[\s\-./]/g, '').toLowerCase()}`);
      if (!one.ok) return one.error.code === 'ORGANIZATION_NOT_FOUND' ? ok([]) : one;
      return ok([one.value]);
    }
    if (!q.name || q.name.length > 200) return ok([]);
    const r = await this.transport.getJson(
      `https://${COMPANIES_HOUSE_HOST}/search/companies?q=${encodeURIComponent(q.name)}&items_per_page=${MAX_SEARCH_ITEMS}`,
    );
    if (!r.ok) return r;
    const items = (r.value.json as { items?: unknown })?.items;
    if (!Array.isArray(items)) return fail('REGISTRY_RESPONSE_INVALID', 'search result without items');
    const out: RawRegistryRecord[] = [];
    for (const it of items.slice(0, MAX_SEARCH_ITEMS)) {
      const m = mapCompanyProfile(it, r.value.retrievedAt);
      if (m.ok) out.push(m.value); // a malformed item is skipped, never guessed
    }
    return ok(out);
  }
}
