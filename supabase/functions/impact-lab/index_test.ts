// IV-IMPACT-I1-PERSISTENCE-RLS-01 — impact-lab Edge Function handler tests.
// Real handler, real auth helper, real Entitlement Core decision; injected
// session client, subject source and in-memory store. Outbound fetch is
// trapped: the Lab must never call the network.
//   DENO_TESTING=1 deno test --allow-env --allow-read supabase/functions/impact-lab/
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { AuthClient } from '../_shared/auth.ts';
import { failingSubjectSource, fakeSubjectSource } from '../_shared/entitlement_test_support.ts';
import { InMemoryImpactDatabase, InMemoryImpactLabStore } from '../_shared/impact/lab_store.ts';
import { handler, type ImpactLabDeps } from './index.ts';

let fetchCalls = 0;
globalThis.fetch = () => {
  fetchCalls++;
  return Promise.resolve(new Response('blocked by test', { status: 599 }));
};

const USERS: Record<string, string> = {
  'jwt-admin-a': 'aaaaaaaa-0000-4000-8000-00000000000a',
  'jwt-admin-b': 'bbbbbbbb-0000-4000-8000-00000000000b',
  'jwt-free': 'cccccccc-0000-4000-8000-00000000000c',
};
const auth: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(token: string) {
      const id = USERS[token];
      return id ? { data: { user: { id } }, error: null } : { data: { user: null }, error: { message: 'invalid' } };
    },
  },
};

function env() {
  const db = new InMemoryImpactDatabase();
  const logs: string[] = [];
  const deps: ImpactLabDeps = {
    store: (_req, user) => new InMemoryImpactLabStore(db, user.id),
    now: () => '2026-09-23T12:00:00Z',
    log: (l) => logs.push(l),
  };
  const send = async (token: string | null, body: unknown, role = 'admin', extraHeaders: Record<string, string> = {}, method = 'POST') => {
    const headers: Record<string, string> = { 'Content-Type': 'application/json', ...extraHeaders };
    if (token) headers.Authorization = `Bearer ${token}`;
    const req = new Request('http://localhost/', { method, headers, body: method === 'POST' ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined });
    const res = await handler(req, auth, undefined, fakeSubjectSource(role), deps);
    return { status: res.status, body: await res.json().catch(() => ({})) as Record<string, unknown> };
  };
  return { db, logs, send };
}

const SUBJECT = { ref: 'org-hopebridge', type: 'FOUNDATION', identity: { legalName: 'HopeBridge Foundation', registrations: [{ country: 'XA', scheme: 'charity-number', value: 'XA-1234567' }] } };

Deno.test('EF-01 no session → 401; anon key → 401; nothing persisted', async () => {
  const e = env();
  assertEquals((await e.send(null, { action: 'list_investigations' })).status, 401);
  assertEquals((await e.send('anon-public-key', { action: 'list_investigations' })).status, 401);
  assertEquals(e.db.investigations.size, 0);
});

Deno.test('EF-02 entitlement: free/pro/premium/beta denied (forged plan/role/module fields and headers ignored); admin allowed', async () => {
  const e = env();
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    const r = await e.send('jwt-free', { action: 'create_investigation', subject: SUBJECT, plan: 'premium', role: 'admin', impact_access: true }, role,
      { 'x-role': 'admin', 'x-plan': 'premium', 'x-impact-access': 'true' });
    assertEquals([r.status, r.body.error], [403, 'MODULE_NOT_AVAILABLE'], role);
  }
  assertEquals(e.db.investigations.size, 0);
  const ok = await e.send('jwt-admin-a', { action: 'create_investigation', subject: SUBJECT });
  assertEquals(ok.status, 200);
});

Deno.test('EF-03 entitlement outage → 503 fail closed', async () => {
  const e = env();
  const req = new Request('http://localhost/', { method: 'POST', headers: { Authorization: 'Bearer jwt-admin-a' }, body: '{}' });
  const res = await handler(req, auth, undefined, failingSubjectSource, { store: () => { throw new Error('must not be reached'); } });
  assertEquals(res.status, 503);
  assertEquals(e.db.investigations.size, 0);
});

Deno.test('EF-04 input contract: POST only, JSON only, size limit, unknown action, mass assignment', async () => {
  const e = env();
  assertEquals((await e.send('jwt-admin-a', null, 'admin', {}, 'GET')).body.error, 'INVALID_REQUEST');
  assertEquals((await e.send('jwt-admin-a', '{not json')).status, 400);
  const big = await e.send('jwt-admin-a', { action: 'create_investigation', subject: { ...SUBJECT, identity: { legalName: 'x'.repeat(70_000) } } });
  assertEquals([big.status, big.body.error], [413, 'PAYLOAD_TOO_LARGE']);
  assertEquals((await e.send('jwt-admin-a', { action: 'drop_tables' })).body.error, 'INVALID_REQUEST');
  const mass = await e.send('jwt-admin-a', { action: 'create_investigation', subject: SUBJECT, owner_id: USERS['jwt-admin-b'] });
  assertEquals([mass.status, mass.body.error], [400, 'INVALID_REQUEST']);
});

Deno.test('EF-05 full flow is structured, owner-scoped and makes zero network calls', async () => {
  const e = env();
  fetchCalls = 0;
  const inv = (await e.send('jwt-admin-a', { action: 'create_investigation', subject: SUBJECT })).body.data as Record<string, unknown>;
  const id = inv.investigationId as string;
  assertEquals((await e.send('jwt-admin-a', { action: 'ingest_provider_record', investigation_id: id, provider_id: 'fixture-xa-charity-registry', record_id: 'xa-1234567', ref: 'src-reg' })).status, 200);
  assertEquals((await e.send('jwt-admin-a', { action: 'add_source', investigation_id: id, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'HopeBridge Foundation', publisherOrgRef: 'org-hopebridge', retrievedAt: '2026-09-01T00:00:00Z', retention: 'HASH_ONLY', contentHash: 'b'.repeat(64) } })).status, 200);
  assertEquals((await e.send('jwt-admin-a', { action: 'add_claim', investigation_id: id, claim: { ref: 'c1', kind: 'LEGAL_REGISTRATION', text: 'A secret-looking claim sentence XYZ.', sourceRef: 'src-web', origin: 'MANUAL' } })).status, 200);
  assertEquals((await e.send('jwt-admin-a', { action: 'add_evidence', investigation_id: id, evidence: { ref: 'e1', claimRef: 'c1', sourceRef: 'src-reg', aboutOrgRef: 'org-hopebridge', relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', observedPeriod: { to: '2026-09-01' }, personalData: 'NONE' } })).status, 200);
  const run = await e.send('jwt-admin-a', { action: 'run_verification', investigation_id: id, claim_ref: 'c1' });
  assertEquals(run.status, 200);
  const v = (run.body.data as Record<string, unknown>).verification as Record<string, unknown>;
  assertEquals([v.status, v.displayClass, v.version, v.isFindingOfWrongdoing], ['SUPPORTED', 'FACT', 1, false]);
  assert(typeof v.policyVersion === 'string' && typeof v.evidenceSetHash === 'string' && typeof run.body.correlation_id === 'string');
  assertEquals(fetchCalls, 0);

  // user B (also admin) sees nothing of A's investigation — same 404 as a nonexistent id
  const foreign = await e.send('jwt-admin-b', { action: 'get_investigation', investigation_id: id });
  const missing = await e.send('jwt-admin-b', { action: 'get_investigation', investigation_id: '99999999-0000-4000-8000-000000000999' });
  assertEquals([foreign.status, foreign.body.error], [404, 'INVESTIGATION_NOT_FOUND']);
  assertEquals([missing.status, missing.body.error], [404, 'INVESTIGATION_NOT_FOUND']);

  // logs: allowlisted fields only — no claim text, no token
  const all = e.logs.join('\n');
  assertEquals(all.includes('secret-looking claim'), false);
  assertEquals(all.includes('jwt-admin'), false);
  assert(e.logs.every((l) => Object.keys(JSON.parse(l)).every((k) => ['event', 'correlation_id', 'investigation_id', 'latency_ms', 'policy_version', 'claims_count', 'evidence_count', 'conflicts_count', 'verification_status', 'error_code'].includes(k))));
});

Deno.test('EF-06 class C requests → 403 ACTION_BLOCKED requiring AEF_HUMAN_GATE', async () => {
  const e = env();
  for (const kind of ['PUBLIC_ACCUSATION', 'DONATE', 'CONTACT_ORGANIZATION', 'REPORT_TO_AUTHORITY', 'EXTERNAL_PUBLICATION']) {
    const r = await e.send('jwt-admin-a', { action: 'request_external_action', kind });
    assertEquals([r.status, r.body.error, r.body.requires], [403, 'ACTION_BLOCKED', 'AEF_HUMAN_GATE'], kind);
  }
});

Deno.test('EF-07 internal failures return 500 without internal details', async () => {
  const req = new Request('http://localhost/', { method: 'POST', headers: { Authorization: 'Bearer jwt-admin-a' }, body: JSON.stringify({ action: 'list_investigations' }) });
  const res = await handler(req, auth, undefined, fakeSubjectSource('admin'), { store: () => { throw new Error('connection string postgres://secret'); }, log: () => {} });
  const body = await res.json();
  assertEquals([res.status, body.error], [500, 'INTERNAL_ERROR']);
  assertEquals(JSON.stringify(body).includes('secret'), false);
});
