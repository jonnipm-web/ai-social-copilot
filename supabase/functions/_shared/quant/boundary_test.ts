/**
 * Quant boundary tripwires — IV-QUANT-FOUNDATION-01 (QUANT_SECURITY_MODEL.md).
 *
 * Static + executed checks that the Foundation stays what it claims to be:
 *  - pure: no network, no env/secrets, no wall clock, no I/O in production modules
 *  - isolated: imports only its own modules (no IVE Core, no AEF kernel, no Supabase client)
 *  - no execution surface: nothing exported that names an order/broker/trade path
 *  - entitlement: 'ive-quant' is admin-only (EXPERIMENTAL) server-side and no
 *    Edge Function serves it while AEF persistence is unavailable
 *  - AEF: real-money quant tiers are hard-denied by the existing domain boundary
 *
 * Execução:
 *   deno test --allow-read supabase/functions/_shared/quant/boundary_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { decideModuleAccess, mapLegacyProfileRole } from '../entitlement.ts';
import { AEF_PERSISTENCE_AVAILABLE, MODULE_POLICY } from '../module_policy.ts';
import { checkDomainBoundary } from '../../../../aef/action_classification.ts';
import type { ExecutionRequest } from '../../../../contracts/aef/types.ts';

const QUANT_DIR = new URL('./', import.meta.url);

async function productionModules(): Promise<{ name: string; src: string }[]> {
  const out: { name: string; src: string }[] = [];
  for await (const e of Deno.readDir(QUANT_DIR)) {
    if (!e.isFile || !e.name.endsWith('.ts') || e.name.endsWith('_test.ts')) continue;
    out.push({ name: e.name, src: await Deno.readTextFile(new URL(e.name, QUANT_DIR)) });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

/** Strip comments so documentation that NAMES a forbidden API is not a false positive. */
function code(src: string): string {
  return src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
}

Deno.test('QB-01 production modules exist and are all covered by this tripwire', async () => {
  const names = (await productionModules()).map((m) => m.name);
  assertEquals(names, [
    'analysis.ts', 'api_contract.ts', 'calendar.ts', 'csv.ts', 'display.ts', 'domain_future.ts', 'errors.ts', 'instrument.ts',
    'ive_boundary.ts', 'metrics.ts', 'numeric.ts', 'observability.ts', 'portfolio.ts', 'provenance.ts', 'provider.ts', 'risk.ts',
    'session_freshness.ts', 'signals.ts', 'timeseries.ts', 'watchlist_contract.ts',
  ]);
});

Deno.test('QB-02 pure engine: no network, env/secrets, wall clock, file/process I/O, randomness or eval', async () => {
  const forbidden: [string, RegExp][] = [
    ['fetch', /\bfetch\s*\(/],
    ['Deno.env', /Deno\.env/],
    ['Deno I/O', /Deno\.(readFile|readTextFile|writeFile|writeTextFile|open|connect|listen|run|Command|serve)/],
    ['WebSocket', /\bWebSocket\b/],
    ['XMLHttpRequest', /\bXMLHttpRequest\b/],
    ['wall clock Date.now', /Date\.now\s*\(/],
    ['wall clock new Date()', /new Date\(\s*\)/],
    ['performance.now', /performance\.now/],
    ['Math.random', /Math\.random/],
    ['eval', /\beval\s*\(|new Function\s*\(/],
  ];
  const hits: string[] = [];
  for (const m of await productionModules()) {
    const c = code(m.src);
    for (const [label, re] of forbidden) if (re.test(c)) hits.push(`${m.name}: ${label}`);
  }
  assertEquals(hits, []);
});

Deno.test('QB-03 isolation: production modules import only sibling Quant modules', async () => {
  const bad: string[] = [];
  for (const m of await productionModules()) {
    for (const imp of m.src.matchAll(/from\s+['"]([^'"]+)['"]/g)) {
      if (!/^\.\/[a-z_]+\.ts$/.test(imp[1])) bad.push(`${m.name} → ${imp[1]}`);
    }
  }
  assertEquals(bad, [], 'Quant core must not import IVE Core, AEF kernel, Supabase clients or remote code');
});

Deno.test('QB-04 no execution surface: no exported order/broker/trade/execute symbol', async () => {
  const bad: string[] = [];
  for (const m of await productionModules()) {
    const mod = await import(new URL(m.name, QUANT_DIR).href);
    for (const k of Object.keys(mod)) if (/order|broker|trade|execut|submit|rebalanc|transfer/i.test(k)) bad.push(`${m.name}: ${k}`);
    // Type-level exports are erased at runtime; check the declared names too.
    for (const d of code(m.src).matchAll(/export\s+(?:interface|type|class|function|const)\s+(\w+)/g)) {
      if (/order|broker|trade|execut|submit|rebalanc|transfer|recommendation/i.test(d[1])) bad.push(`${m.name}: ${d[1]}`);
    }
  }
  assertEquals(bad, []);
});

// ------------------------------------------------------------ entitlement

function subject(legacyRole: string) {
  const { plan, roles } = mapLegacyProfileRole(legacyRole);
  return { type: 'user' as const, id: 'u-quant', plan, roles, source: 'legacy_profiles_role' as const };
}

Deno.test('QB-10 server policy: ive-quant is EXPERIMENTAL, CONSEQUENTIAL, never commercial', () => {
  const p = MODULE_POLICY.modules['ive-quant'];
  assert(p, 'ive-quant must be registered server-side');
  assertEquals(p.lifecycle, 'EXPERIMENTAL');
  assertEquals(p.actionClass, 'CONSEQUENTIAL');
  assert(p.lifecycle !== 'COMMERCIAL' && p.lifecycle !== 'RELEASE_CANDIDATE');
});

Deno.test('QB-11 entitlement deny: every paying plan and beta testers are denied ive-quant; only admin passes (audited)', () => {
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    const d = decideModuleAccess(subject(role), 'ive-quant');
    assertEquals([d.allowed, d.code], [false, 'MODULE_NOT_AVAILABLE'], role);
  }
  assertEquals(decideModuleAccess(null, 'ive-quant').code, 'AUTH_REQUIRED');
  assertEquals(decideModuleAccess(subject('enterprise'), 'ive-quant').allowed, false);
  const admin = decideModuleAccess(subject('admin'), 'ive-quant');
  assertEquals([admin.allowed, admin.reason], [true, 'ADMIN_ROLE']);
});

Deno.test('QB-12 no Edge Function serves ive-quant while AEF persistence is unavailable (MP-09 restated for Quant)', () => {
  const served = Object.entries(MODULE_POLICY.edgeFunctions).filter(([, p]) => p.moduleId === 'ive-quant').map(([fn]) => fn);
  if (!AEF_PERSISTENCE_AVAILABLE) assertEquals(served, []);
});

// ------------------------------------------------------------ AEF / broker boundary

Deno.test('QB-20 AEF hard-denies real-money quant tiers even with a human gate reference', () => {
  for (const tier of ['controlled_live', 'expanded_live'] as const) {
    const req = {
      contract_version: '1.0',
      request_id: 'c0000000-0000-4000-8000-000000000099',
      requested_at: '2026-09-23T00:00:00.000Z',
      expires_at: '2026-09-23T01:00:00.000Z',
      actor: { type: 'user', id: 'u', auth_ref: 'usr:x' },
      intent: 'test',
      domain: 'quant',
      action: `quant.${tier}.submit_order`,
      quant_execution_tier: tier,
      human_gate_ref: 'hg-1',
    } as unknown as ExecutionRequest;
    const d = checkDomainBoundary(req, 'CONSEQUENTIAL');
    assert(d !== null && d.decision === 'DENY', tier);
  }
});

// ------------------------------------------------------------ IV-QUANT-DATA-PLANE-AND-API-02: module split

Deno.test('QB-13 split: quant-analytics is READ_ONLY + INTERNAL and owns the Quant APIs; ive-quant stays CONSEQUENTIAL with none', () => {
  const qa = MODULE_POLICY.modules['quant-analytics'];
  assert(qa, 'quant-analytics must be registered server-side');
  assertEquals([qa.lifecycle, qa.actionClass], ['INTERNAL', 'READ_ONLY']);
  assertEquals([MODULE_POLICY.modules['ive-quant'].lifecycle, MODULE_POLICY.modules['ive-quant'].actionClass], ['EXPERIMENTAL', 'CONSEQUENTIAL']);
  const byModule = (m: string) => Object.entries(MODULE_POLICY.edgeFunctions).filter(([, p]) => p.moduleId === m).map(([fn]) => fn).sort();
  assertEquals(byModule('quant-analytics'), ['quant-analyze', 'quant-watchlists']);
  assertEquals(byModule('ive-quant'), []);
  for (const role of ['free', 'pro', 'premium', 'beta_tester']) {
    assertEquals(decideModuleAccess(subject(role), 'quant-analytics').code, 'MODULE_NOT_AVAILABLE', role);
  }
  assertEquals(decideModuleAccess(subject('admin'), 'quant-analytics').allowed, true);
});

Deno.test('QB-14 Quant Edge Functions: no AEF/IVE/LLM import, no raw fetch, no service role, gate on quant-analytics', async () => {
  for (const f of ['../../quant-analyze/index.ts', '../../quant-watchlists/index.ts', '../quant_server.ts']) {
    const src = code(await Deno.readTextFile(new URL(f, import.meta.url)));
    assert(!/\bfetch\s*\(/.test(src), `${f}: raw fetch`);
    assert(!/aef\/|contracts\/aef|_shared\/ive\/|context-copilot|groq|openai|anthropic/i.test(src), `${f}: forbidden dependency`);
    assert(!/SERVICE_ROLE|createServiceClient/.test(src), `${f}: service role`);
    if (f.endsWith('index.ts')) {
      assert(/requireModuleAccess\(req, authUser, 'quant-analytics'/.test(src), `${f}: must gate on quant-analytics`);
      assert(!/'ive-quant'/.test(src.replace(/\/\/.*$/gm, '')), `${f}: must not serve ive-quant`);
    }
  }
});

Deno.test('QB-15 CXR-01 accepted residual is pinned: "first"/"primeiro" pass grounding until the Q6 gate', async () => {
  const { checkNarrativeGrounding } = await import('./ive_boundary.ts');
  const req = { facts: [], period: { start: '', end: '', bars: 0 } } as unknown as Parameters<typeof checkNarrativeGrounding>[1];
  assertEquals(checkNarrativeGrounding({ template: 'first result' }, req).grounded, true);
  assertEquals(checkNarrativeGrounding({ template: 'primeiro resultado' }, req).grounded, true);
  const doc = await Deno.readTextFile(new URL('../../../../docs/quant/QUANT_SECURITY_MODEL.md', import.meta.url));
  assert(/"first", "primeiro"/.test(doc), 'residual must stay documented');
});
