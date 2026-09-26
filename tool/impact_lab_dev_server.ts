/**
 * Impact Lab LOCAL dev server — IV-IMPACT-I6-PHYSICAL-CLOSURE (physical
 * Android validation). NOT a deployment artifact.
 *
 * Runs the REAL `impact-lab` handler on the PC so a DEBUG build on a
 * USB-connected phone (`--dart-define=IMPACT_API_BASE_URL=http://127.0.0.1:<port>`)
 * can exercise the full Impact flow through `adb reverse tcp:<port> tcp:<port>`
 * without deploying anything (same contract as tool/quant_lab_dev_server.ts):
 *   - authentication: the real Supabase Auth (the caller's own JWT verified by
 *     `auth.getUser`; read-only);
 *   - entitlement: the real server-side admin gate, reading the caller's OWN
 *     profile row with the caller's JWT (read-only, RLS);
 *   - data: an IN-MEMORY store seeded per caller with SYNTHETIC XA fixtures
 *     only (nothing is written to any database; lost on exit);
 *   - rate limits: the in-memory twin of the SQL limiter (same rule shape).
 *
 * Dev controls (PC only, need the random token printed at start-up):
 *   POST /__dev/ratelimit?build=3&export=2&verify=3   real limiter, lower Lab limits
 *   POST /__dev/stale                                 material change ⇒ issued snapshots become STALE
 *   POST /__dev/fault?mode=none|401|404|500|mismatch  LABELLED fault injection for failure-UX checks
 *
 * FAKE-AUTH mode (the DEFAULT; real Supabase only with the explicit opt-in
 * IMPACT_DEV_REAL_SUPABASE=1): NO contact with
 * any real Supabase project. The server also emulates the minimum of Supabase
 * Auth + REST the app needs, for ONE synthetic admin
 * (lab-admin@impact.lab.invalid): the app is built with SUPABASE_URL pointing
 * at this server, and the real impact-lab handler verifies the synthetic JWT
 * and reads the synthetic admin profile through the same emulation. Every
 * other table answers empty; every other Edge Function answers LAB_UNAVAILABLE.
 *
 * Binds to 127.0.0.1 only. In fake-auth mode SUPABASE_URL defaults to this
 * server and MUST be loopback http (anything else is refused); the real-auth
 * opt-in needs SUPABASE_URL and SUPABASE_ANON_KEY in the environment.
 *
 *   deno run --allow-net=127.0.0.1,<project>.supabase.co --allow-env tool/impact_lab_dev_server.ts
 */
import { resolveAuthenticatedUser } from '../supabase/functions/_shared/auth.ts';
import { parseLabRequest } from '../supabase/functions/_shared/impact/lab_contract.ts';
import { handleLabRequest } from '../supabase/functions/_shared/impact/lab_service.ts';
import { InMemoryImpactDatabase, InMemoryImpactLabStore } from '../supabase/functions/_shared/impact/lab_store.ts';
import { DEFAULT_RATE_LIMITS, InMemoryRateLimiter, RATE_WINDOW_SECONDS, type RateBucket, type RateRule } from '../supabase/functions/_shared/impact/rate_limit.ts';

const PORT = Number(Deno.env.get('IMPACT_DEV_PORT') ?? '54322');
// Must happen BEFORE the handler module is loaded: it only calls serve() when not testing.
Deno.env.set('DENO_TESTING', '1');
const { handler } = await import('../supabase/functions/impact-lab/index.ts');
// Fail closed: synthetic fake auth unless real Supabase is explicitly requested.
const FAKE = Deno.env.get('IMPACT_DEV_REAL_SUPABASE') !== '1';
if (Deno.env.get('IMPACT_DEV_SELFTEST') !== '1') {
  if (FAKE) {
    if (!Deno.env.get('SUPABASE_URL')) Deno.env.set('SUPABASE_URL', `http://127.0.0.1:${PORT}`);
    if (!Deno.env.get('SUPABASE_ANON_KEY')) Deno.env.set('SUPABASE_ANON_KEY', 'lab-anon-key');
    const u = new URL(Deno.env.get('SUPABASE_URL')!);
    if (u.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(u.hostname)) {
      console.error('fake-auth mode refuses a non-loopback SUPABASE_URL (set IMPACT_DEV_REAL_SUPABASE=1 to opt in to real Supabase).');
      Deno.exit(2);
    }
  } else if (!Deno.env.get('SUPABASE_URL') || !Deno.env.get('SUPABASE_ANON_KEY')) {
    console.error('SUPABASE_URL and SUPABASE_ANON_KEY must be set (runtime only; never commit them).');
    Deno.exit(2);
  }
}

const CONTROL_TOKEN = crypto.randomUUID();
const db = new InMemoryImpactDatabase();
const limiter = new InMemoryRateLimiter();
const rules: Record<RateBucket, RateRule> = { ...DEFAULT_RATE_LIMITS };
const deps = {
  store: (_req: Request, user: { id: string }) => new InMemoryImpactLabStore(db, user.id),
  rateLimiter: () => limiter,
  rateLimits: rules,
  log: (line: string) => console.log(line), // allowlisted Impact events only (codes / ids / counts)
};
let fault: 'none' | '401' | '404' | '500' | 'mismatch' = 'none';
const seeded = new Map<string, string[]>(); // user → investigation ids

// ── synthetic seeding (XA organizations, placeholder people; never real data) ──
async function seed(userId: string): Promise<string[]> {
  let clock = Date.UTC(2026, 8, 25, 9, 0, 0);
  const call = async (body: Record<string, unknown>) => {
    const p = parseLabRequest(body);
    if (!p.ok) throw new Error(`${String(body.action)}: ${p.error.code}`);
    clock += 60_000;
    const r = await handleLabRequest(new InMemoryImpactLabStore(db, userId), { userId }, p.value, new Date(clock).toISOString());
    if (!r.ok) throw new Error(`${String(body.action)}: ${r.error.code} ${r.error.message}`);
    return r.value.data as Record<string, unknown>;
  };
  const subject = (ref: string, legalName: string) => ({
    ref, type: 'FOUNDATION',
    identity: { legalName, registrations: [{ country: 'XA', scheme: 'charity-number', value: 'XA-1234567' }], domains: ['hopebridge.example'] },
  });
  const web = (inv: string) => call({ action: 'add_source', investigation_id: inv, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'HopeBridge Foundation', publisherOrgRef: cur, retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'b'.repeat(64) } });
  const registry = (inv: string) => call({ action: 'ingest_provider_record', investigation_id: inv, provider_id: 'fixture-xa-charity-registry', record_id: 'xa-1234567', ref: 'src-reg' });
  // Evidence must be ABOUT the investigated subject: the engine rightly excludes
  // evidence about another organization (found on the device: all-UNVERIFIED seed).
  let cur = '';
  const create = async (ref: string, name: string) => {
    cur = ref;
    return (await call({ action: 'create_investigation', subject: subject(ref, name) })).investigationId as string;
  };
  const ids: string[] = [];

  // 1 — confirmed identity, official record, uploaded document with locator.
  {
    const inv = await create('org-lab-1-confirmed', 'HopeBridge Foundation');
    await registry(inv);
    await web(inv);
    await call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-reg', kind: 'LEGAL_REGISTRATION', text: 'HopeBridge Foundation is a registered charity.', sourceRef: 'src-web', origin: 'MANUAL' } });
    await call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-reg', claimRef: 'c-reg', sourceRef: 'src-reg', aboutOrgRef: cur, relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', observedPeriod: { to: '2026-09-01' }, personalData: 'NONE' } });
    await call({ action: 'run_verification', investigation_id: inv, claim_ref: 'c-reg' });
    await call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-wells', kind: 'IMPACT_OUTPUT', text: 'HopeBridge Foundation built 20 wells.', quantity: { metric: 'wells_built', value: 20, unit: 'count' }, sourceRef: 'src-web', origin: 'MANUAL' } });
    const doc = ['HopeBridge Foundation annual report (synthetic)', 'HopeBridge Foundation built 20 wells in 2025.', ''].join('\n');
    await call({ action: 'ingest_artifact', investigation_id: inv, artifact: { ref: 'art-report', filename: 'report.txt', contentBase64: btoa(doc), origin: 'CLOUD_IMPORT', cloud: { provider: 'GOOGLE_DRIVE', fileRef: 'drive-file-1' } } });
    await call({ action: 'review_candidate', investigation_id: inv, candidate_ref: 'art-report.auto1', decision: 'ACCEPTED', relationship: 'SUPPORTS', claim_ref: 'c-wells', about_org_ref: cur, personal_data: 'NONE' });
    await call({ action: 'run_verification', investigation_id: inv, claim_ref: 'c-wells' });
    ids.push(inv);
  }
  // 2 — conflicting registries, contradicting news, redacted e-mail / phone, withheld official role.
  {
    const inv = await create('org-lab-2-conflict', 'HopeBridge Foundation');
    await registry(inv);
    await web(inv);
    await call({ action: 'ingest_provider_record', investigation_id: inv, provider_id: 'fixture-xa-company-registry', record_id: 'xa-c-778899', ref: 'src-co' });
    await call({ action: 'add_source', investigation_id: inv, source: { ref: 'src-news', type: 'NEWS', newsGenre: 'REPORTING', publisher: 'Daily Fixture', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'c'.repeat(64) } });
    await call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-wells', kind: 'IMPACT_OUTPUT', text: 'We built 20 wells. Contact office@hopebridge.example.', sourceRef: 'src-web', origin: 'MANUAL' } });
    await call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-self', claimRef: 'c-wells', sourceRef: 'src-web', aboutOrgRef: cur, relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', personalData: 'NONE' } });
    await call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-news', claimRef: 'c-wells', sourceRef: 'src-news', aboutOrgRef: cur, relationship: 'CONTRADICTS', basis: 'HUMAN_ASSESSED', personalData: 'NONE', excerpt: 'A reporter counted 12 wells; call +44 20 7946 0958.' } });
    await call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-board', claimRef: 'c-wells', sourceRef: 'src-web', aboutOrgRef: cur, relationship: 'CONTEXTUALIZES', basis: 'HUMAN_ASSESSED', personalData: 'PUBLIC_OFFICIAL_ROLE', excerpt: 'Trustee Jane Example signed the report.' } });
    await call({ action: 'run_verification', investigation_id: inv, claim_ref: 'c-wells' });
    ids.push(inv);
  }
  // 3 — I6 privacy: private name / address, minor, social publisher, personal URL.
  {
    const inv = await create('org-lab-3-privacy', 'HopeBridge Foundation');
    await registry(inv);
    await web(inv);
    await call({ action: 'add_source', investigation_id: inv, source: { ref: 'src-social', type: 'SOCIAL_MEDIA', publisher: 'Jane Placeholder (@jane.placeholder)', uri: 'https://social.example/jane.placeholder/posts/1', retrievedAt: '2026-09-01T00:00:00Z', retention: 'REFERENCE_ONLY' } });
    await call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-private', kind: 'OTHER', text: 'Volunteer Maria Placeholder lives at 12 Example Road.', sourceRef: 'src-web', origin: 'MANUAL' } });
    await call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-minor', kind: 'OTHER', text: 'Ana, a girl aged 9, lives near the well.', sourceRef: 'src-web', origin: 'MANUAL' } });
    await call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-org', kind: 'OTHER', text: 'HopeBridge Foundation operates in two districts.', sourceRef: 'src-web', origin: 'MANUAL' } });
    await call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-private', claimRef: 'c-org', sourceRef: 'src-web', aboutOrgRef: cur, relationship: 'CONTEXTUALIZES', basis: 'HUMAN_ASSESSED', personalData: 'NONE', excerpt: 'Our treasurer Mr Placeholder confirmed the two districts.' } });
    ids.push(inv);
  }
  // 4 — open dispute.
  {
    const inv = await create('org-lab-4-disputed', 'HopeBridge Foundation');
    await registry(inv);
    await web(inv);
    await call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-reg', kind: 'LEGAL_REGISTRATION', text: 'HopeBridge Foundation is a registered charity.', sourceRef: 'src-web', origin: 'MANUAL' } });
    await call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-reg', claimRef: 'c-reg', sourceRef: 'src-reg', aboutOrgRef: cur, relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', observedPeriod: { to: '2026-09-01' }, personalData: 'NONE' } });
    await call({ action: 'run_verification', investigation_id: inv, claim_ref: 'c-reg' });
    await call({ action: 'open_dispute', investigation_id: inv, ref: 'd1', claim_ref: 'c-reg', kind: 'ORGANIZATION_RESPONSE', submitted_evidence_refs: ['e-reg'] });
    ids.push(inv);
  }
  // 5 — unresolved identity (no registry), claim never verified.
  {
    const inv = await create('org-lab-5-unresolved', 'HopeBridge Foundation');
    await web(inv);
    await call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c1', kind: 'OTHER', text: 'HopeBridge Foundation operates in two districts.', sourceRef: 'src-web', origin: 'MANUAL' } });
    ids.push(inv);
  }
  // 6 — empty.
  {
    const inv = await create('org-lab-6-empty', 'HopeBridge Foundation');
    await web(inv);
    ids.push(inv);
  }
  // 7 — large (45 claims ⇒ "show more").
  {
    const inv = await create('org-lab-7-large', 'HopeBridge Foundation');
    await web(inv);
    for (let i = 0; i < 45; i++) {
      await call({ action: 'add_claim', investigation_id: inv, claim: { ref: `c-${String(i).padStart(2, '0')}`, kind: 'IMPACT_OUTPUT', text: `HopeBridge Foundation completed project phase ${i + 1}.`, sourceRef: 'src-web', origin: 'MANUAL' } });
    }
    ids.push(inv);
  }
  return ids;
}

const STALE_REF = 'org-lab-1-confirmed'; // scenario 1 carries the exportable c-reg claim
async function stale(userId: string) {
  for (const inv of seeded.get(userId) ?? []) {
    const p = parseLabRequest({ action: 'add_evidence', investigation_id: inv, evidence: { ref: `e-stale-${Date.now()}`, claimRef: 'c-reg', sourceRef: 'src-web', aboutOrgRef: STALE_REF, relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', personalData: 'NONE' } });
    if (p.ok) await handleLabRequest(new InMemoryImpactLabStore(db, userId), { userId }, p.value, new Date().toISOString());
  }
}

// Offline self-test: seed a synthetic user and exercise every scenario through
// get_dossier / export_dossier, then exit (no network, no Supabase).
if (Deno.env.get('IMPACT_DEV_SELFTEST') === '1') {
  const u = 'aaaaaaaa-0000-4000-8000-00000000d0e0';
  const ids = await seed(u);
  for (const inv of ids) {
    for (const action of ['get_dossier', 'export_dossier']) {
      const p = parseLabRequest({ action, investigation_id: inv, lang: 'en' });
      if (!p.ok) throw new Error(p.error.code);
      const r = await handleLabRequest(new InMemoryImpactLabStore(db, u), { userId: u }, p.value, new Date().toISOString());
      if (!r.ok) throw new Error(`${action} ${inv}: ${r.error.code}`);
      const all = JSON.stringify(r.value.data);
      if (Deno.env.get('IMPACT_DEV_SELFTEST_VERBOSE') === '1' && action === 'get_dossier') {
        const c = (r.value.data as { dossier: { content: { claims: { ref: string; verification: { status: string } | null; reverificationReasons: string[] }[] } } }).dossier.content;
        console.log(inv, c.claims.slice(0, 3).map((x) => `${x.ref}:${x.verification?.status ?? '-'}:${x.reverificationReasons.join('+')}`).join(' '));
      }
      for (const leak of ['Maria Placeholder', '12 Example Road', 'aged 9', 'jane.placeholder', 'Jane Example', '7946', 'office@']) {
        if (all.includes(leak)) throw new Error(`${action} ${inv} leaked ${leak}`);
      }
    }
  }
  console.log(`SELFTEST PASS: ${ids.length} synthetic investigations, dossier + export clean`);
  Deno.exit(0);
}

// ── fake Supabase Auth + REST (default; see FAKE above): synthetic admin only ──
const LAB_EMAIL = 'lab-admin@impact.lab.invalid';
const LAB_USER_ID = 'bbbbbbbb-0000-4000-8000-00000000fab1';
const b64u = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
const issued = new Set<string>();
const labUser = () => ({
  id: LAB_USER_ID, aud: 'authenticated', role: 'authenticated', email: LAB_EMAIL, phone: '',
  email_confirmed_at: '2026-09-25T00:00:00Z', confirmed_at: '2026-09-25T00:00:00Z', last_sign_in_at: new Date().toISOString(),
  app_metadata: { provider: 'email', providers: ['email'] }, user_metadata: {}, identities: [],
  created_at: '2026-09-25T00:00:00Z', updated_at: new Date().toISOString(),
});
function labSession() {
  const now = Math.floor(Date.now() / 1000);
  const token = `${b64u({ alg: 'HS256', typ: 'JWT' })}.${b64u({ sub: LAB_USER_ID, email: LAB_EMAIL, role: 'authenticated', aud: 'authenticated', iat: now, exp: now + 86_400, session_id: crypto.randomUUID() })}.bGFi`;
  issued.add(token);
  return { access_token: token, token_type: 'bearer', expires_in: 86_400, expires_at: now + 86_400, refresh_token: `lab-refresh-${crypto.randomUUID()}`, user: labUser() };
}
const labProfile = () => ({
  id: LAB_USER_ID, email: LAB_EMAIL, full_name: 'Lab Admin (synthetic)', role: 'admin', monthly_limit: 99999, is_active: true,
  created_at: '2026-09-25T00:00:00Z', updated_at: '2026-09-25T00:00:00Z',
});
const bearer = (req: Request) => req.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() ?? '';

async function fakeSupabase(req: Request, url: URL): Promise<Response | null> {
  const p = url.pathname;
  if (p === '/auth/v1/token') {
    const body = await req.json().catch(() => ({})) as { email?: string; password?: string };
    const grant = url.searchParams.get('grant_type');
    if (grant === 'refresh_token' || (grant === 'password' && body.email === LAB_EMAIL && (body.password ?? '').length > 0)) return json(200, labSession());
    return json(400, { error: 'invalid_grant', error_description: 'Invalid login credentials (Lab: synthetic admin only)' });
  }
  if (p === '/auth/v1/user') return issued.has(bearer(req)) ? json(200, labUser()) : json(401, { msg: 'invalid JWT' });
  if (p === '/auth/v1/logout') {
    issued.delete(bearer(req));
    return new Response(null, { status: 204 });
  }
  if (p.startsWith('/auth/v1/')) return json(404, { msg: 'not emulated in the Lab' });
  if (p.startsWith('/rest/v1/')) {
    if (!issued.has(bearer(req))) return json(401, { message: 'JWT required' });
    const table = p.slice('/rest/v1/'.length);
    const single = (req.headers.get('Accept') ?? '').includes('vnd.pgrst.object');
    if (table === 'profiles') return req.method === 'GET' || req.method === 'HEAD' ? json(200, single ? labProfile() : [labProfile()]) : json(200, [labProfile()]);
    if (req.method === 'GET') return single ? json(406, { code: 'PGRST116', message: 'no rows (Lab)' }) : json(200, []);
    return json(200, table.startsWith('rpc/') ? null : []);
  }
  if (p.startsWith('/functions/v1/')) return json(503, { error: 'LAB_UNAVAILABLE' });
  if (p.startsWith('/storage/v1/') || p.startsWith('/realtime/v1/')) return json(404, { error: 'not emulated in the Lab' });
  return null;
}

const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

async function devControl(req: Request, url: URL): Promise<Response> {
  if (req.headers.get('X-Dev-Control') !== CONTROL_TOKEN) return json(403, { error: 'control token required' });
  if (url.pathname === '/__dev/ratelimit') {
    for (const [q, b] of [['build', 'dossier_build'], ['export', 'dossier_export'], ['verify', 'dossier_verify']] as const) {
      const n = Number(url.searchParams.get(q));
      if (Number.isInteger(n) && n >= 1 && n <= 1000) rules[b] = { limit: n, windowSeconds: RATE_WINDOW_SECONDS };
    }
    return json(200, { rules });
  }
  if (url.pathname === '/__dev/fault') {
    const m = url.searchParams.get('mode');
    if (m === 'none' || m === '401' || m === '404' || m === '500' || m === 'mismatch') fault = m;
    console.log(`[dev] fault injection = ${fault}`);
    return json(200, { fault });
  }
  if (url.pathname === '/__dev/stale') {
    for (const u of seeded.keys()) await stale(u);
    return json(200, { stale: true });
  }
  return json(404, { error: 'unknown control' });
}

Deno.serve({ hostname: '127.0.0.1', port: PORT }, async (req) => {
  const url = new URL(req.url);
  if (url.pathname.startsWith('/__dev/')) return devControl(req, url);
  if (FAKE) {
    const r = await fakeSupabase(req, url);
    if (r) return r;
  }
  if (url.pathname !== '/impact-lab') return new Response('not found', { status: 404 });
  // Seed synthetic data for the (real, read-only verified) caller on first use.
  try {
    const user = await resolveAuthenticatedUser(req.clone());
    if (!seeded.has(user.id)) seeded.set(user.id, await seed(user.id));
  } catch {
    // unauthenticated: the real handler answers 401 below
  }
  const body = await req.clone().json().catch(() => ({})) as { action?: string };
  if (fault === '401') return json(401, { ok: false, error: 'AUTH_REQUIRED' });
  if (fault === '404' && body.action === 'get_dossier') return json(404, { ok: false, error: 'INVESTIGATION_NOT_FOUND', message: 'investigation not found' });
  if (fault === '500' && body.action === 'get_dossier') return json(500, { ok: false, error: 'INTERNAL_ERROR' });
  const res = await handler(req, undefined, undefined, undefined, deps);
  if (fault === 'mismatch' && body.action === 'verify_dossier' && res.ok) {
    const out = await res.json() as { data: { envelopeState: string } };
    out.data.envelopeState = 'MISMATCH'; // LABELLED fault injection (UI check only)
    return json(200, out);
  }
  return res;
});
console.log(`impact-lab dev server on http://127.0.0.1:${PORT} (in-memory, synthetic XA fixtures, no writes${FAKE ? ', FAKE AUTH: no real Supabase' : ''})`);
console.log(`dev control token: ${CONTROL_TOKEN}`);
