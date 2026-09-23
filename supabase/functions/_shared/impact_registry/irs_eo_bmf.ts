/**
 * US IRS Exempt Organizations Business Master File (EO BMF) adapter — IV-IMPACT-I2.
 *
 * Official downloadable dataset (no key): per-state CSV files at
 *   https://www.irs.gov/pub/irs-soi/eo_{state}.csv
 * documented at irs.gov "Exempt Organizations Business Master File Extract".
 * It lists organizations the IRS currently recognizes as tax-exempt; it is
 * NOT an incorporation register (sourceType GOVERNMENT_RECORD, authority
 * class TAX_AUTHORITY), and ABSENCE from it proves nothing (small
 * organizations, churches and group members may not appear).
 *
 * Bulk file, not a lookup API: a state file is fetched (size-capped) and
 * scanned. Large states exceed the Lab cap and fail closed with
 * REGISTRY_RESPONSE_INVALID — production use needs a scheduled ingestion
 * pipeline (future gate, dossier). Only organization columns are read: the
 * "ICO" (in care of — a PERSON's name), street, city and ZIP are dropped and
 * never stored.
 */
import { fail, ok, type ImpactResult } from '../impact/errors.ts';
import type { ImpactSourceProvider, OrganizationQuery, ProviderDescriptor, RawRegistryRecord } from '../impact/provider.ts';
import { parseCsvLine } from './csv.ts';
import { RegistryTransport, TRANSPORT_LIMITS, type TransportDeps } from './transport.ts';

export const IRS_HOST = 'www.irs.gov';

export const IRS_EO_BMF: ProviderDescriptor = Object.freeze({
  id: 'us-irs-eo-bmf',
  sourceType: 'GOVERNMENT_RECORD',
  capabilities: Object.freeze(['SEARCH_ORGANIZATION', 'FETCH_REGISTRY_RECORD']) as ProviderDescriptor['capabilities'],
  jurisdictions: Object.freeze(['US']) as readonly string[],
  authorityScope: Object.freeze(['REGULATORY_STATUS']) as readonly string[],
  freshnessDays: 45, // monthly extract
  retrievalMethod: 'BULK_DATASET',
  official: true,
  authorityClass: 'TAX_AUTHORITY',
  primaryPublisher: true,
  dataScope: 'IRS-recognized tax-exempt organizations: EIN, name, subsection, ruling date, status code (no persons, no addresses)',
  adapterVersion: 'us-irs-eo-bmf/1',
  termsStatus: 'REQUIRES_CONFIRMATION',
  synthetic: false,
});

/** Documented EO BMF header (information sheet). The adapter refuses any other layout. */
export const EO_BMF_HEADER = [
  'EIN', 'NAME', 'ICO', 'STREET', 'CITY', 'STATE', 'ZIP', 'GROUP', 'SUBSECTION', 'AFFILIATION', 'CLASSIFICATION', 'RULING',
  'DEDUCTIBILITY', 'FOUNDATION', 'ACTIVITY', 'ORGANIZATION', 'STATUS', 'TAX_PERIOD', 'ASSET_CD', 'INCOME_CD', 'FILING_REQ_CD',
  'PF_FILING_REQ_CD', 'ACCT_PD', 'ASSET_AMT', 'INCOME_AMT', 'REVENUE_AMT', 'NTEE_CD', 'SORT_NAME',
] as const;

const STATES = new Set(('al ak az ar ca co ct de dc fl ga hi id il in ia ks ky la me md ma mi mn ms mo mt ne nv nh nj nm ny nc nd oh ok or pa ri sc sd tn tx ut vt va wa wv wi wy pr').split(' '));
const RECORD_RE = /^us-irs:([a-z]{2}):(\d{9})$/;
const MAX_ROWS = 200_000;
const MAX_CANDIDATES = 10;

export function mapEoBmfRow(cols: readonly string[], idx: Readonly<Record<string, number>>, state: string, retrievedAt: string): ImpactResult<RawRegistryRecord> {
  const get = (k: string) => (cols[idx[k]] ?? '').trim();
  const ein = get('EIN');
  const name = get('NAME');
  if (!/^\d{9}$/.test(ein) || !name) return fail('REGISTRY_RESPONSE_INVALID', 'row misses EIN or name');
  const ruling = get('RULING');
  const rulingDate = /^(19|20)\d{2}(0[1-9]|1[0-2])$/.test(ruling) ? `${ruling.slice(0, 4)}-${ruling.slice(4, 6)}-01` : undefined;
  const statusCode = get('STATUS');
  const sort = get('SORT_NAME');
  return ok({
    providerId: IRS_EO_BMF.id,
    recordId: `us-irs:${state}:${ein}`,
    retrievedAt,
    payload: {
      country: 'US',
      scheme: 'ein',
      registration_number: ein,
      name,
      organization_type: 'NONPROFIT',
      // Listed = currently recognized as exempt; the IRS status code is kept verbatim.
      status: 'REGISTERED',
      status_detail: /^\d{2}$/.test(statusCode) ? `irs-status-${statusCode}` : 'irs-status-unknown',
      ...(rulingDate && rulingDate.slice(0, 10) <= retrievedAt.slice(0, 10) ? { registered_on: rulingDate } : {}),
      ...(sort ? { trading_names: [sort] } : {}),
      // ICO (a person), STREET, CITY, ZIP and financial amounts are dropped.
    },
  });
}

export class IrsEoBmfProvider implements ImpactSourceProvider {
  readonly descriptor = IRS_EO_BMF;
  private readonly transport: RegistryTransport;
  constructor(deps: TransportDeps = {}) {
    this.transport = new RegistryTransport({
      providerId: IRS_EO_BMF.id,
      hosts: [IRS_HOST],
      contentTypes: ['text/csv', 'application/csv', 'application/octet-stream', 'text/plain'],
      maxBytes: TRANSPORT_LIMITS.maxCsvBytes,
      minIntervalMs: 5_000, // one bulk file per 5 s at most
    }, deps);
  }

  /** Streams the state file and yields mapped rows matching `keep` (bounded). */
  private async scan(state: string, keep: (cols: readonly string[], idx: Readonly<Record<string, number>>) => boolean, limit: number) {
    if (!STATES.has(state)) return fail<RawRegistryRecord[]>('INVALID_REQUEST', 'unknown US state code');
    const r = await this.transport.get(`https://${IRS_HOST}/pub/irs-soi/eo_${state}.csv`);
    if (!r.ok) return r;
    const lines = r.value.body.split(/\r?\n/);
    const header = parseCsvLine(lines[0] ?? '');
    if (!header.ok || header.value.length !== EO_BMF_HEADER.length || header.value.some((h, i) => h.trim().toUpperCase() !== EO_BMF_HEADER[i])) {
      return fail<RawRegistryRecord[]>('REGISTRY_RESPONSE_INVALID', 'unexpected EO BMF layout');
    }
    const idx = Object.fromEntries(EO_BMF_HEADER.map((h, i) => [h, i])) as Record<string, number>;
    const out: RawRegistryRecord[] = [];
    for (let i = 1; i < lines.length && i <= MAX_ROWS && out.length < limit; i++) {
      if (!lines[i]) continue;
      const cols = parseCsvLine(lines[i]);
      if (!cols.ok || cols.value.length !== EO_BMF_HEADER.length) continue; // malformed row skipped, never guessed
      if (!keep(cols.value, idx)) continue;
      const m = mapEoBmfRow(cols.value, idx, state, r.value.retrievedAt);
      if (m.ok) out.push(m.value);
    }
    return ok(out);
  }

  async fetchRegistryRecord(recordId: string): Promise<ImpactResult<RawRegistryRecord>> {
    const m = RECORD_RE.exec(recordId);
    if (!m) return fail('INVALID_REQUEST', 'not an EO BMF record id (us-irs:<state>:<ein>)');
    const rows = await this.scan(m[1], (c, idx) => c[idx.EIN] === m[2], 1);
    if (!rows.ok) return rows;
    return rows.value.length === 1 ? ok(rows.value[0]) : fail('ORGANIZATION_NOT_FOUND', 'EIN not listed in this state extract');
  }

  /** Needs a state (`subdivision` US-XX). Name matching is a SEARCH hint only. */
  async searchOrganization(q: OrganizationQuery): Promise<ImpactResult<readonly RawRegistryRecord[]>> {
    if (q.country && q.country.toUpperCase() !== 'US') return ok([]);
    const state = /^US-([A-Z]{2})$/.exec(q.subdivision ?? '')?.[1]?.toLowerCase();
    if (!state) return fail('INVALID_REQUEST', 'EO BMF search needs a US state (subdivision US-XX)');
    if (q.registration) {
      const ein = q.registration.replace(/\D/g, '');
      if (!/^\d{9}$/.test(ein)) return ok([]);
      return await this.scan(state, (c, idx) => c[idx.EIN] === ein, 1);
    }
    const needle = (q.name ?? '').trim().toUpperCase();
    if (needle.length < 3 || needle.length > 200) return ok([]);
    return await this.scan(state, (c, idx) => (c[idx.NAME] ?? '').toUpperCase().includes(needle), MAX_CANDIDATES);
  }
}
