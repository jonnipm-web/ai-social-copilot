// IV-IMPACT-FOUNDATION-01 — boundary tripwires: purity, isolation from the
// other Labs, entitlement (reuses the Entitlement Core), AEF action classes,
// no execution surface, no score/verdict surface, error contract.
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { ActionClassification } from '../../../../aef/types.ts';
import { decideModuleAccess, type EntitlementSubject, type Role } from '../entitlement.ts';
import { MODULE_POLICY } from '../module_policy.ts';
import {
  type AefActionClassification,
  classifyImpactAction,
  EDITORIAL_INDEPENDENCE,
  IMPACT_MODULE_ID,
  requestImpactAction,
  toAefClassification,
} from './boundaries.ts';
import { IMPACT_ERROR_CODES } from './errors.ts';

const DIR = new URL('.', import.meta.url);

async function sourceFiles(): Promise<{ name: string; text: string }[]> {
  const out: { name: string; text: string }[] = [];
  for await (const e of Deno.readDir(DIR)) {
    if (e.isFile && e.name.endsWith('.ts') && !e.name.endsWith('_test.ts')) {
      out.push({ name: e.name, text: await Deno.readTextFile(new URL(e.name, DIR)) });
    }
  }
  for await (const e of Deno.readDir(new URL('fixtures/', DIR))) {
    if (e.isFile && e.name.endsWith('.ts')) out.push({ name: `fixtures/${e.name}`, text: await Deno.readTextFile(new URL(`fixtures/${e.name}`, DIR)) });
  }
  return out;
}

function code(text: string): string {
  // strip block and line comments so documentation can mention forbidden words
  return text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
}

Deno.test('BT-1 purity: no network, env, wall clock or randomness anywhere in the Impact core', async () => {
  const files = await sourceFiles();
  assert(files.length >= 15, `expected the full core, got ${files.length}`);
  for (const f of files) {
    const c = code(f.text);
    for (const [label, re] of [
      ['fetch', /\bfetch\s*\(/],
      ['safeFetch call', /\bsafeFetch\s*\(/],
      ['Deno.env', /Deno\.env/],
      ['Deno I/O', /Deno\.(readTextFile|writeTextFile|open|connect|run|Command|resolveDns)/],
      ['Date.now', /Date\.now\s*\(/],
      ['new Date()', /new Date\(\s*\)/],
      ['Math.random', /Math\.random/],
      ['crypto.randomUUID', /randomUUID/],
      ['XMLHttpRequest/WebSocket', /XMLHttpRequest|WebSocket/],
    ] as const) {
      assert(!re.test(c), `${f.name}: forbidden ${label}`);
    }
  }
});

Deno.test('BT-2 isolation: imports stay inside impact/ plus the SSRF helpers — no Quant, IVE, AEF runtime, DB client or LLM', async () => {
  for (const f of await sourceFiles()) {
    for (const m of f.text.matchAll(/from\s+'([^']+)'/g)) {
      const spec = m[1];
      const allowed = spec.startsWith('./') || spec === '../safe_fetch.ts' || (f.name.startsWith('fixtures/') && spec.startsWith('../'));
      assert(allowed, `${f.name} imports ${spec}`);
      assert(!/quant|ive|aef|supabase-js|groq|openai|anthropic/i.test(spec), `${f.name} imports ${spec}`);
    }
  }
});

const GUARD_VOCABULARY = new Set(['VerdictCategory', 'findVerdictLanguage']);

Deno.test('BT-3 no verdict/score/ranking/execution surface is exported', async () => {
  for (const f of await sourceFiles()) {
    for (const m of code(f.text).matchAll(/export\s+(?:async\s+)?(?:function|const|class|type|interface)\s+(\w+)/g)) {
      const name = m[1];
      if (GUARD_VOCABULARY.has(name)) continue; // the detector of verdict language, not a verdict
      assert(!/score|rank|fraud|guilt|trustworth|verdict/i.test(name), `${f.name} exports ${name}`);
      assert(!/^(execute|send|donate|pay|publish|notify|contact|transfer|reportTo)/i.test(name), `${f.name} exports executor-like ${name}`);
    }
  }
  assertEquals(Object.values(EDITORIAL_INDEPENDENCE).every((v) => v === false), true);
});

Deno.test('BT-4 module "impact" is EXPERIMENTAL in the server policy (admin-only), highest action class REVERSIBLE', () => {
  const p = MODULE_POLICY.modules[IMPACT_MODULE_ID];
  assert(p, 'impact must be registered');
  assertEquals(p.lifecycle, 'EXPERIMENTAL');
  assertEquals(p.actionClass, 'REVERSIBLE');
  assertEquals(Object.values(MODULE_POLICY.edgeFunctions).some((e) => e.moduleId === IMPACT_MODULE_ID), false, 'no Edge Function in the Foundation');
});

const subject = (plan: EntitlementSubject['plan'], roles: Role[] = []): EntitlementSubject => ({
  type: 'user', id: 'u-1', plan, roles: new Set(roles), source: 'legacy_profiles_role',
});

Deno.test('BT-5 entitlement: every plan and beta testers are denied; only the admin role reaches Impact', () => {
  for (const plan of ['free', 'pro', 'premium'] as const) {
    const d = decideModuleAccess(subject(plan), IMPACT_MODULE_ID);
    assertEquals(d.allowed, false, plan);
    assertEquals(d.code, 'MODULE_NOT_AVAILABLE');
  }
  assertEquals(decideModuleAccess(subject('premium', ['beta_tester']), IMPACT_MODULE_ID).allowed, false);
  assertEquals(decideModuleAccess(subject(null), IMPACT_MODULE_ID).allowed, false);
  assertEquals(decideModuleAccess(null, IMPACT_MODULE_ID).code, 'AUTH_REQUIRED');
  assertEquals(decideModuleAccess(subject('free', ['admin']), IMPACT_MODULE_ID).allowed, true);
});

Deno.test('BT-6 entitlement: client-shaped fields (plan=premium, role=admin, impact_access=true) are not an input', () => {
  // decideModuleAccess only takes a server-resolved subject; a forged object
  // with extra fields and no admin role in `roles` is still denied.
  // deno-lint-ignore no-explicit-any
  const forged: any = { ...subject('free'), plan: 'premium', role: 'admin', impact_access: true, roles: new Set() };
  assertEquals(decideModuleAccess(forged, IMPACT_MODULE_ID).allowed, false);
  // deno-lint-ignore no-explicit-any
  const rolesAsArray: any = { ...subject('premium'), roles: ['admin'] };
  let allowed = false;
  try {
    allowed = decideModuleAccess(rolesAsArray, IMPACT_MODULE_ID).allowed;
  } catch {
    allowed = false; // a malformed subject throws — fails closed, never grants
  }
  assertEquals(allowed, false, 'roles must be a real Set from the server source');
});

Deno.test('BT-7 action classes: C (accusation, contact, authority report, donation, publication) is BLOCKED; unknown fails closed', () => {
  for (const k of ['PUBLISH_FINDING', 'PUBLIC_ACCUSATION', 'CONTACT_ORGANIZATION', 'REPORT_TO_AUTHORITY', 'DONATE', 'TRANSFER_FUNDS', 'EXTERNAL_PUBLICATION']) {
    const d = requestImpactAction(k);
    assertEquals(d.decision, 'BLOCKED', k);
    assertEquals(d.executable, false);
    if (d.decision === 'BLOCKED') assertEquals(d.requires, 'AEF_HUMAN_GATE');
  }
  for (const k of ['', 'donate', 'SEND_EMAIL', '__proto__', 'constructor', 'toString']) {
    assertEquals(classifyImpactAction(k), 'C', `unknown "${k}" must fail closed`);
  }
  assertEquals(requestImpactAction('RUN_VERIFICATION').decision, 'ALLOWED_INTERNAL');
  assertEquals(requestImpactAction('SEARCH_ORGANIZATION').actionClass, 'A');
});

Deno.test('BT-8 A/B/C map exactly onto the AEF ActionClassification union', () => {
  const all: ActionClassification[] = (['A', 'B', 'C'] as const).map(toAefClassification);
  assertEquals(all, ['READ_ONLY', 'REVERSIBLE', 'CONSEQUENTIAL']);
  // compile-time parity both ways
  const a: AefActionClassification = 'READ_ONLY' as ActionClassification;
  const b: ActionClassification = 'CONSEQUENTIAL' as AefActionClassification;
  assert(a && b);
});

Deno.test('BT-9 error contract contains every code the mission requires', () => {
  for (const c of [
    'ORGANIZATION_NOT_FOUND', 'ENTITY_MATCH_UNCERTAIN', 'REGISTRY_UNAVAILABLE', 'SOURCE_UNAVAILABLE', 'SOURCE_STALE',
    'EVIDENCE_INSUFFICIENT', 'EVIDENCE_CONFLICT', 'CLAIM_UNVERIFIED', 'INVALID_EVIDENCE', 'ENTITLEMENT_DENIED',
    'REVIEW_REQUIRED', 'INTERNAL_ERROR',
  ] as const) assert(IMPACT_ERROR_CODES.includes(c), c);
});

Deno.test('BT-10 fixtures use fictitious organizations and the XA jurisdiction only', async () => {
  const f = await Deno.readTextFile(new URL('fixtures/golden.ts', DIR));
  assert(/country: 'XA'/.test(f));
  assert(!/country: '(GB|UK|US|BR)'/.test(f), 'no real jurisdiction in adversarial fixtures');
  for (const m of f.matchAll(/https?:\/\/([^/'"]+)/g)) assert(m[1].endsWith('.example'), `non-example host ${m[1]}`);
});
