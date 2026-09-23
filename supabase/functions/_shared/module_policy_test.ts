/**
 * Server module policy invariants — INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02.
 * These are the Promotion Gate checks that are enforced by CI rather than
 * only documented (MODULE_PROMOTION_GATE.md §3).
 *
 * Execução:
 *   deno test --allow-read supabase/functions/_shared/module_policy_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { AEF_PERSISTENCE_AVAILABLE, MODULE_POLICY } from './module_policy.ts';

const FUNCTIONS_DIR = new URL('../', import.meta.url);
const LIFECYCLES = new Set(['EXPERIMENTAL', 'INTERNAL', 'ALPHA', 'BETA', 'RELEASE_CANDIDATE', 'COMMERCIAL', 'DEPRECATED']);
const PLANS = new Set(['free', 'pro', 'premium']);
const ACTION_CLASSES = new Set(['READ_ONLY', 'REVERSIBLE', 'CONSEQUENTIAL']);

async function edgeFunctionDirs(): Promise<string[]> {
  const out: string[] = [];
  for await (const e of Deno.readDir(FUNCTIONS_DIR)) {
    if (e.isDirectory && !e.name.startsWith('_')) out.push(e.name);
  }
  return out.sort();
}

Deno.test('MP-01 the JSON block between the markers is strict JSON and equals MODULE_POLICY', async () => {
  const src = await Deno.readTextFile(new URL('./module_policy.ts', import.meta.url));
  const start = src.indexOf('// BEGIN_MODULE_POLICY_JSON');
  const end = src.indexOf('// END_MODULE_POLICY_JSON');
  assert(start > 0 && end > start);
  const json = JSON.parse(src.slice(src.indexOf('\n', start) + 1, end));
  assertEquals(json, MODULE_POLICY);
});

Deno.test('MP-02 every module has a valid lifecycle, plan and AEF action class', () => {
  for (const [id, m] of Object.entries(MODULE_POLICY.modules)) {
    assert(LIFECYCLES.has(m.lifecycle), `${id}.lifecycle=${m.lifecycle}`);
    assert(PLANS.has(m.minimumPlan), `${id}.minimumPlan=${m.minimumPlan}`);
    assert(ACTION_CLASSES.has(m.actionClass), `${id}.actionClass=${m.actionClass}`);
  }
});

Deno.test('MP-03 PROMOTION GATE: no CONSEQUENTIAL module at RC/COMMERCIAL while AEF persistence is unavailable', () => {
  if (AEF_PERSISTENCE_AVAILABLE) return;
  const violations = Object.entries(MODULE_POLICY.modules)
    .filter(([, m]) => m.actionClass === 'CONSEQUENTIAL' && (m.lifecycle === 'RELEASE_CANDIDATE' || m.lifecycle === 'COMMERCIAL'))
    .map(([id]) => id);
  assertEquals(violations, [], 'class C modules cannot be promoted outside AEF');
});

Deno.test('MP-04 every Edge Function directory is classified, and every classified function exists', async () => {
  const dirs = await edgeFunctionDirs();
  assertEquals(Object.keys(MODULE_POLICY.edgeFunctions).sort(), dirs);
});

Deno.test('MP-05 every MODULE-kind function maps to a known module', () => {
  for (const [fn, p] of Object.entries(MODULE_POLICY.edgeFunctions)) {
    if (p.kind !== 'MODULE') continue;
    assert(p.moduleId && p.moduleId in MODULE_POLICY.modules, `${fn} → ${p.moduleId}`);
  }
});

Deno.test('MP-06 PROMOTION GATE: every MODULE-kind function enforces its own module server-side, after auth and before quota', async () => {
  for (const [fn, p] of Object.entries(MODULE_POLICY.edgeFunctions)) {
    if (p.kind !== 'MODULE') continue;
    const gatePath = p.gateFile ? `../${p.gateFile}` : `../${fn}/index.ts`;
    const src = await Deno.readTextFile(new URL(gatePath, import.meta.url));
    if (p.gateFile) {
      // The delegating index.ts must actually route through that shared handler.
      const index = await Deno.readTextFile(new URL(`../${fn}/index.ts`, import.meta.url));
      const base = p.gateFile.split('/').pop()!;
      assert(index.includes(base.replace(/\.ts$/, '')), `${fn}/index.ts must delegate to ${p.gateFile}`);
    }
    const call = new RegExp(`requireModuleAccess\\(\\s*req,\\s*\\w+,\\s*'${p.moduleId}'`);
    const m = call.exec(src);
    assert(m, `${fn} must call requireModuleAccess(req, <user>, '${p.moduleId}', ...)`);
    assert(/if \(!access\.allowed\) return access\.response;/.test(src), `${fn} must return the denial response`);
    const authAt = src.indexOf('resolveAuthenticatedUser(req');
    const quotaAt = src.indexOf('reserveQuota(');
    assert(authAt >= 0 && authAt < m.index, `${fn}: entitlement must run after authentication`);
    if (quotaAt >= 0) assert(m.index < quotaAt, `${fn}: entitlement must run before quota reservation`);
  }
});

Deno.test('MP-07 non-MODULE functions carry no module id (their boundary is documented, not implied)', () => {
  for (const [fn, p] of Object.entries(MODULE_POLICY.edgeFunctions)) {
    if (p.kind !== 'MODULE') assertEquals(p.moduleId, undefined, fn);
  }
});

Deno.test('MP-08 production code never imports the test-only entitlement helpers', async () => {
  const offenders: string[] = [];
  for (const fn of await edgeFunctionDirs()) {
    const src = await Deno.readTextFile(new URL(`../${fn}/index.ts`, import.meta.url));
    if (src.includes('entitlement_test_support')) offenders.push(fn);
  }
  for await (const e of Deno.readDir(new URL('./', import.meta.url))) {
    if (!e.isFile || e.name.endsWith('_test.ts') || e.name === 'entitlement_test_support.ts') continue;
    const src = await Deno.readTextFile(new URL(`./${e.name}`, import.meta.url));
    if (src.includes('entitlement_test_support')) offenders.push(`_shared/${e.name}`);
  }
  assertEquals(offenders, []);
});

Deno.test('MP-09 PROMOTION GATE: no Edge Function of ANY kind serves a CONSEQUENTIAL module while AEF persistence is unavailable (Codex CXF-02)', () => {
  if (AEF_PERSISTENCE_AVAILABLE) return;
  const consequential = new Set(
    Object.entries(MODULE_POLICY.modules).filter(([, m]) => m.actionClass === 'CONSEQUENTIAL').map(([id]) => id),
  );
  const paths = Object.entries(MODULE_POLICY.edgeFunctions)
    .filter(([, p]) => p.moduleId !== undefined && consequential.has(p.moduleId))
    .map(([fn]) => fn);
  assertEquals(paths, [], 'a class C capability may only execute through AEF (Human Gate + receipt)');
});

Deno.test('MP-10 non-MODULE kinds are a closed, reviewed allowlist — a new function cannot dodge the gate by picking another kind', () => {
  const nonModule = Object.entries(MODULE_POLICY.edgeFunctions)
    .filter(([, p]) => p.kind !== 'MODULE')
    .map(([fn, p]) => `${fn}:${p.kind}`)
    .sort();
  assertEquals(nonModule, [
    'create-checkout-session:BILLING',
    'ive-agent-runner:RETIRED',
    'module-access:ENTITLEMENT',
    'stripe-webhook:PUBLIC_WEBHOOK',
  ]);
});
