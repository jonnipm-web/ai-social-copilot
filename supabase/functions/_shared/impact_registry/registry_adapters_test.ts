// IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01 — registry adapters and transport,
// OFFLINE (no real network: every response is a local fixture shaped like the
// documented official format; synthetic organizations only).
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { normalizeRegistryRecord } from '../impact/provider.ts';
import { trustedProviderRefs } from '../impact/provider_registry.ts';
import { safeFetch, UnsafeUrlError } from '../safe_fetch.ts';
import { REAL_REGISTRY_CATALOG } from './catalog.ts';
import { CHARITY_COMMISSION, CharityCommissionProvider, mapCharity } from './charity_commission.ts';
import { COMPANIES_HOUSE, CompaniesHouseProvider, mapCompanyProfile } from './companies_house.ts';
import { parseCsvLine } from './csv.ts';
import { EO_BMF_HEADER, IRS_EO_BMF, IrsEoBmfProvider } from './irs_eo_bmf.ts';
import { type Fetcher, RegistryTransport } from './transport.ts';

const T0 = Date.UTC(2026, 8, 23, 12, 0, 0);
function clock() {
  let t = T0;
  return { nowMs: () => (t += 10_000) };
}
function stub(responses: Record<string, () => Response>) {
  const calls: string[] = [];
  const fetcher: Fetcher = (url, init) => {
    calls.push(url);
    assert(init.allowedHosts.size > 0, 'allowlist always passed to safe_fetch');
    const path = new URL(url).pathname + new URL(url).search;
    const f = responses[path] ?? responses['*'];
    return Promise.resolve(f ? f() : new Response('nope', { status: 404 }));
  };
  return { fetcher, calls };
}
const json = (body: unknown, status = 200, ct = 'application/json') => () => new Response(JSON.stringify(body), { status, headers: { 'content-type': ct } });

const CH_PROFILE = {
  company_number: 'SC000001', company_name: 'Example Widgets Limited', company_status: 'active', date_of_creation: '2010-04-01',
  type: 'ltd', previous_company_names: [{ name: 'Example Gadgets Limited', effective_from: '2010-04-01', ceased_on: '2015-02-01' }],
  registered_office_address: { address_line_1: '1 Synthetic Street' },
  officers: [{ name: 'Synthetic Person Two' }], links: { self: '/company/SC000001' },
};

// ── transport ───────────────────────────────────────────────────────────────

const cfg = { providerId: 'p', hosts: ['registry.example.gov'], contentTypes: ['application/json'], maxBytes: 1_000, minIntervalMs: 0 };

Deno.test('RT-01 only https URLs on the exact allowlisted host (no userinfo, no port) ever reach the network', async () => {
  const s = stub({ '*': json({}) });
  const t = new RegistryTransport(cfg, { fetcher: s.fetcher, ...clock() });
  for (const u of ['http://registry.example.gov/x', 'https://evil.example/x', 'https://registry.example.gov.evil.example/x',
    'https://user@registry.example.gov/x', 'https://registry.example.gov:8443/x', 'https://169.254.169.254/latest/meta-data', 'not a url']) {
    const r = await t.get(u);
    assertEquals(r.ok ? 'OK' : r.error.code, 'UNSAFE_REFERENCE', u);
  }
  assertEquals(s.calls, []);
});

Deno.test('RT-02 HTTP outcomes map to operational states, never to "not registered"', async () => {
  const cases: [number, string][] = [[429, 'REGISTRY_RATE_LIMITED'], [503, 'REGISTRY_UNAVAILABLE'], [500, 'REGISTRY_UNAVAILABLE'], [401, 'REGISTRY_UNAVAILABLE'],
    [403, 'REGISTRY_UNAVAILABLE'], [404, 'ORGANIZATION_NOT_FOUND'], [302, 'REGISTRY_RESPONSE_INVALID'], [206, 'REGISTRY_RESPONSE_INVALID']];
  for (const [status, code] of cases) {
    const t = new RegistryTransport(cfg, { fetcher: stub({ '*': json({}, status) }).fetcher, ...clock() });
    const r = await t.get('https://registry.example.gov/x');
    assertEquals(r.ok ? 'OK' : r.error.code, code, String(status));
  }
  const down = new RegistryTransport(cfg, { fetcher: () => Promise.reject(new TypeError('network down')), ...clock() });
  assertEquals((await down.get('https://registry.example.gov/x') as { error: { code: string } }).error.code, 'REGISTRY_UNAVAILABLE');
  const ssrf = new RegistryTransport(cfg, { fetcher: () => Promise.reject(new UnsafeUrlError()), ...clock() });
  assertEquals((await ssrf.get('https://registry.example.gov/x') as { error: { code: string } }).error.code, 'UNSAFE_REFERENCE');
});

Deno.test('RT-03 wrong content type, malformed JSON and oversized bodies are rejected', async () => {
  const wrongCt = new RegistryTransport(cfg, { fetcher: stub({ '*': json({}, 200, 'text/html') }).fetcher, ...clock() });
  assertEquals((await wrongCt.get('https://registry.example.gov/x') as { error: { code: string } }).error.code, 'REGISTRY_RESPONSE_INVALID');
  const bad = new RegistryTransport(cfg, { fetcher: stub({ '*': () => new Response('{not json', { headers: { 'content-type': 'application/json' } }) }).fetcher, ...clock() });
  assertEquals((await bad.getJson('https://registry.example.gov/x') as { error: { code: string } }).error.code, 'REGISTRY_RESPONSE_INVALID');
  const big = new RegistryTransport(cfg, { fetcher: stub({ '*': () => new Response('x'.repeat(5_000), { headers: { 'content-type': 'application/json' } }) }).fetcher, ...clock() });
  assertEquals((await big.get('https://registry.example.gov/x') as { error: { code: string } }).error.code, 'REGISTRY_RESPONSE_INVALID');
});

Deno.test('RT-04 polite local rate limit, no automatic retry', async () => {
  const s = stub({ '*': json({}) });
  const fixed = { nowMs: () => T0 };
  const t = new RegistryTransport({ ...cfg, minIntervalMs: 1_000 }, { fetcher: s.fetcher, ...fixed });
  assert((await t.get('https://registry.example.gov/a')).ok);
  assertEquals((await t.get('https://registry.example.gov/b') as { error: { code: string } }).error.code, 'REGISTRY_RATE_LIMITED');
  const r429 = stub({ '*': json({}, 429) });
  const t2 = new RegistryTransport(cfg, { fetcher: r429.fetcher, ...clock() });
  await t2.get('https://registry.example.gov/a');
  assertEquals(r429.calls.length, 1); // a 429 is reported, never hammered
});

Deno.test('RT-05 safe_fetch allowlist: a redirect to another host or to a private/metadata address is refused', async () => {
  const original = globalThis.fetch;
  try {
    for (const location of ['https://evil.example/x', 'http://169.254.169.254/latest/meta-data', 'https://127.0.0.1/admin']) {
      let calls = 0;
      globalThis.fetch = ((_u: string | URL | Request) => {
        calls++;
        return Promise.resolve(new Response(null, { status: 302, headers: { location } }));
      }) as typeof fetch;
      let blocked = false;
      try {
        // A public IPv4 literal needs no DNS, so the test is fully offline.
        await safeFetch('https://93.184.216.34/start', { allowedHosts: new Set(['93.184.216.34']) });
      } catch (e) {
        blocked = e instanceof UnsafeUrlError;
      }
      assert(blocked, location);
      assertEquals(calls, 1, location); // the redirect target was never fetched
    }
    let reached = false;
    globalThis.fetch = (() => { reached = true; return Promise.resolve(new Response('x')); }) as typeof fetch;
    let refused = false;
    try {
      await safeFetch('https://93.184.216.34/start', { allowedHosts: new Set(['registry.example.gov']) });
    } catch (e) {
      refused = e instanceof UnsafeUrlError;
    }
    assert(refused && !reached, 'a non-allowlisted first host is refused before DNS or fetch');
  } finally {
    globalThis.fetch = original;
  }
});

// ── Companies House ─────────────────────────────────────────────────────────

Deno.test('CH-01 profile → canonical record; officers, PSC and addresses never requested nor kept', async () => {
  const s = stub({ '/company/SC000001': json(CH_PROFILE) });
  const p = new CompaniesHouseProvider('synthetic-key', { fetcher: s.fetcher, ...clock() });
  const raw = await p.fetchRegistryRecord('gb-ch-sc000001');
  assert(raw.ok, raw.ok ? '' : raw.error.message);
  const c = await normalizeRegistryRecord(raw.value, COMPANIES_HOUSE);
  assert(c.ok, c.ok ? '' : c.error.message);
  assertEquals([c.value.canonicalOrgId, c.value.status, c.value.statusDetail, c.value.registeredOn], ['GB:company-number:SC000001', 'REGISTERED', 'active', '2010-04-01']);
  assertEquals(c.value.formerNames, [{ name: 'Example Gadgets Limited', from: '2010-04-01', to: '2015-02-01' }]);
  const blob = JSON.stringify([raw.value, c.value]);
  for (const k of ['Synthetic Person Two', 'Synthetic Street', 'officers', 'registered_office_address']) assertEquals(blob.includes(k), false, k);
  assert(s.calls.every((u) => /\/company\/SC000001$/.test(u)), s.calls.join());
});

Deno.test('CH-02 insolvency-type statuses are kept verbatim, never turned into a judgement', () => {
  for (const st of ['liquidation', 'administration', 'receivership', 'voluntary-arrangement', 'insolvency-proceedings']) {
    const r = mapCompanyProfile({ ...CH_PROFILE, company_status: st }, '2026-09-23T12:00:00Z');
    assert(r.ok);
    assertEquals([r.value.payload.status, r.value.payload.status_detail], ['UNKNOWN', st]);
  }
  const d = mapCompanyProfile({ ...CH_PROFILE, company_status: 'dissolved', date_of_cessation: '2020-01-01' }, '2026-09-23T12:00:00Z');
  assert(d.ok);
  assertEquals([d.value.payload.status, d.value.payload.dissolved_on], ['DISSOLVED', '2020-01-01']);
});

Deno.test('CH-03 the registry must answer for the record asked for; malformed payloads are refused', async () => {
  const s = stub({ '/company/SC000001': json({ ...CH_PROFILE, company_number: 'SC999999' }) });
  const p = new CompaniesHouseProvider('synthetic-key', { fetcher: s.fetcher, ...clock() });
  assertEquals((await p.fetchRegistryRecord('gb-ch-sc000001') as { error: { code: string } }).error.code, 'REGISTRY_RESPONSE_INVALID');
  for (const bad of [null, [], { company_number: 'SC000001' }, { company_name: 'x' }, { company_number: '../etc', company_name: 'x' }]) {
    assertEquals(mapCompanyProfile(bad, '2026-09-23T12:00:00Z').ok, false, JSON.stringify(bad));
  }
  assertEquals((await p.fetchRegistryRecord('gb-ch-../../x') as { error: { code: string } }).error.code, 'INVALID_REQUEST');
  assertEquals(s.calls.length, 1);
});

Deno.test('CH-04 search is bounded, skips malformed items and never answers for another country', async () => {
  const items = Array.from({ length: 25 }, (_, i) => ({ ...CH_PROFILE, company_number: `SC${String(i).padStart(6, '0')}`, title: 'Example Widgets Limited' }));
  items[3] = { bad: true } as never;
  const s = stub({ '*': json({ items }) });
  const p = new CompaniesHouseProvider('synthetic-key', { fetcher: s.fetcher, ...clock() });
  const r = await p.searchOrganization({ name: 'Example Widgets', country: 'GB' });
  assert(r.ok);
  assertEquals(r.value.length, 9); // 10 inspected, 1 malformed skipped
  assert(s.calls[0].includes('items_per_page=10'));
  assertEquals(await p.searchOrganization({ name: 'x', country: 'US' }), { ok: true, value: [] });
});

// ── Charity Commission ──────────────────────────────────────────────────────

Deno.test('CC-01 charity record → canonical record with company cross-reference; trustees and contacts dropped', async () => {
  const body = {
    reg_charity_number: 1000001, charity_name: 'Example Hope Trust', reg_status: 'R', date_of_registration: '2011-05-01T00:00:00',
    charity_company_registration_number: 'SC000001', charity_contact_web: 'https://www.example-hope.example/',
    charity_contact_email: 'someone@example.invalid', trustees: [{ trustee_name: 'Synthetic Person Three' }],
  };
  const s = stub({ '/register/api/allcharitydetailsV2/1000001/0': json(body) });
  const p = new CharityCommissionProvider('synthetic-key', { fetcher: s.fetcher, ...clock() });
  const raw = await p.fetchRegistryRecord('gb-cc-1000001');
  assert(raw.ok, raw.ok ? '' : raw.error.message);
  const c = await normalizeRegistryRecord(raw.value, CHARITY_COMMISSION);
  assert(c.ok, c.ok ? '' : c.error.message);
  assertEquals(c.value.canonicalIds, ['GB:charity-number:1000001', 'GB:company-number:SC000001']);
  assertEquals(c.value.domains, ['example-hope.example']);
  const blob = JSON.stringify(c.value);
  for (const k of ['Synthetic Person Three', 'someone@example.invalid', 'trustee']) assertEquals(blob.includes(k), false, k);
  const removed = mapCharity({ ...body, reg_status: 'RM', date_of_removal: '2024-02-01' }, '2026-09-23T12:00:00Z');
  assert(removed.ok);
  assertEquals([removed.value.payload.status, removed.value.payload.dissolved_on], ['REMOVED', '2024-02-01']);
});

// ── IRS EO BMF ──────────────────────────────────────────────────────────────

const csvRow = (ein: string, name: string, ico = 'SYNTHETIC PERSON FOUR') =>
  [ein, name, ico, '1 SYNTHETIC RD', 'EXAMPLETOWN', 'WY', '82001', '0000', '03', '3', '1000', '201305', '1', '15', '000000000', '1', '01',
    '202312', '0', '0', '01', '0', '12', '0', '0', '0', 'P20', 'EXAMPLE SORT'].map((v) => (v.includes(',') ? `"${v}"` : v)).join(',');
const CSV = [EO_BMF_HEADER.join(','), csvRow('000000001', 'EXAMPLE WATER FUND'), csvRow('000000002', 'EXAMPLE, "QUOTED" TRUST'.replace(/"/g, '""'))].join('\r\n');

Deno.test('IRS-01 EO BMF row → canonical record; the in-care-of PERSON, address and amounts are dropped', async () => {
  const s = stub({ '/pub/irs-soi/eo_wy.csv': () => new Response(CSV, { headers: { 'content-type': 'text/csv' } }) });
  const p = new IrsEoBmfProvider({ fetcher: s.fetcher, ...clock() });
  const raw = await p.fetchRegistryRecord('us-irs:wy:000000001');
  assert(raw.ok, raw.ok ? '' : raw.error.message);
  const c = await normalizeRegistryRecord(raw.value, IRS_EO_BMF);
  assert(c.ok, c.ok ? '' : c.error.message);
  assertEquals([c.value.canonicalOrgId, c.value.statusDetail, c.value.registeredOn, c.value.tradingNames], ['US:ein:000000001', 'irs-status-01', '2013-05-01', ['EXAMPLE SORT']]);
  const blob = JSON.stringify([raw.value, c.value]);
  for (const k of ['SYNTHETIC PERSON FOUR', 'SYNTHETIC RD', 'EXAMPLETOWN', '82001']) assertEquals(blob.includes(k), false, k);
});

Deno.test('IRS-02 layout drift, unknown state or missing state fail closed; absence is NOT_FOUND, never negative', async () => {
  const drift = stub({ '*': () => new Response('EIN,NAME\n1,X', { headers: { 'content-type': 'text/csv' } }) });
  const p1 = new IrsEoBmfProvider({ fetcher: drift.fetcher, ...clock() });
  assertEquals((await p1.fetchRegistryRecord('us-irs:wy:000000001') as { error: { code: string } }).error.code, 'REGISTRY_RESPONSE_INVALID');
  const s = stub({ '*': () => new Response(CSV, { headers: { 'content-type': 'text/csv' } }) });
  const p = new IrsEoBmfProvider({ fetcher: s.fetcher, ...clock() });
  assertEquals((await p.fetchRegistryRecord('us-irs:zz:000000001') as { error: { code: string } }).error.code, 'INVALID_REQUEST');
  assertEquals((await p.fetchRegistryRecord('us-irs:wy:999999999') as { error: { code: string } }).error.code, 'ORGANIZATION_NOT_FOUND');
  assertEquals((await p.searchOrganization({ name: 'EXAMPLE' }) as { error: { code: string } }).error.code, 'INVALID_REQUEST');
  const found = await p.searchOrganization({ name: 'quoted', subdivision: 'US-WY' });
  assert(found.ok);
  assertEquals(found.value.map((r) => r.payload.name), ['EXAMPLE, "QUOTED" TRUST']);
});

Deno.test('CSV-01 parser: quotes, escaped quotes, commas; malformed lines rejected', () => {
  assertEquals(parseCsvLine('a,"b,c","d ""e""",'), { ok: true, value: ['a', 'b,c', 'd "e"', ''] });
  for (const bad of ['"open', 'a,b"c', '"x"y']) assertEquals(parseCsvLine(bad).ok, false, bad);
});

// ── catalog ─────────────────────────────────────────────────────────────────

Deno.test('CAT-01 no real registry is enabled in the Lab (not in the server registry, not trusted by the engine)', () => {
  const trusted = new Set(trustedProviderRefs().map((p) => p.id));
  for (const e of REAL_REGISTRY_CATALOG) {
    assertEquals(e.enabledInLab, false);
    assert(!trusted.has(e.descriptor.id), e.descriptor.id);
    assertEquals([e.descriptor.synthetic, e.descriptor.official, e.descriptor.termsStatus], [false, true, 'REQUIRES_CONFIRMATION']);
    assert(e.blockers.includes('EGRESS_PINNING_REQUIRED'), `${e.descriptor.id}: DNS-rebinding residual must block enablement`);
  }
});

Deno.test('BT-R1 network layer tripwire: only safe_fetch reaches the network; no env, DB client, LLM or clock-free bypass', async () => {
  const dir = new URL('.', import.meta.url);
  let files = 0;
  for await (const e of Deno.readDir(dir)) {
    if (!e.isFile || !e.name.endsWith('.ts') || e.name.endsWith('_test.ts')) continue;
    files++;
    const text = (await Deno.readTextFile(new URL(e.name, dir))).replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
    assert(!/(^|[^.\w])fetch\s*\(/.test(text), `${e.name}: raw fetch()`);
    assert(!/Deno\.(env|readTextFile|writeTextFile|open|Command|run)/.test(text), `${e.name}: env / file / process access`);
    for (const m of text.matchAll(/from\s+'([^']+)'/g)) {
      assert(m[1].startsWith('./') || m[1].startsWith('../impact/') || m[1] === '../safe_fetch.ts', `${e.name} imports ${m[1]}`);
      assert(!/supabase-js|groq|openai|anthropic|aef/i.test(m[1]), `${e.name} imports ${m[1]}`);
    }
  }
  assert(files >= 6, `expected the whole network layer, got ${files}`);
});
