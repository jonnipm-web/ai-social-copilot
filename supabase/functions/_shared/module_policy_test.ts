/**
 * Server module policy invariants — INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02.
 * These are the Promotion Gate checks that are enforced by CI rather than
 * only documented (MODULE_PROMOTION_GATE.md §3).
 *
 * Execução:
 *   deno test --allow-read supabase/functions/_shared/module_policy_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { AEF_PERSISTENCE_AVAILABLE, effectiveActionClass, MODULE_POLICY } from './module_policy.ts';

const FUNCTIONS_DIR = new URL('../', import.meta.url);
const LIFECYCLES = new Set(['EXPERIMENTAL', 'INTERNAL', 'ALPHA', 'BETA', 'RELEASE_CANDIDATE', 'COMMERCIAL', 'DEPRECATED']);
const PLANS = new Set(['free', 'pro', 'premium']);
const ACTION_CLASSES = new Set(['READ_ONLY', 'REVERSIBLE', 'CONSEQUENTIAL']);

/**
 * Codex final audit (round 4, INTELLIGENCE-AUTOMATION-MACRO-04) — extracted
 * so MP-09 and MP-12's adversarial test share the exact same detection
 * logic (never duplicated, never allowed to drift): a whole-file
 * regex.test() would be satisfied by a COMMENTED-OUT `if` line (or one
 * whose `deny` call was commented out while the `if` survived), since the
 * text is still "in the file" either way. This checks per-line instead:
 * the `if [ "$FUNCTION_NAME" = "<fn>" ]` line and an uncommented `deny`
 * call within the next few lines must BOTH be real, executable shell.
 */
function isHardBlockedInDenyScript(script: string, fn: string): boolean {
  const lines = script.split('\n');
  const isCommented = (line: string) => line.trim().startsWith('#');
  const hardBlock = new RegExp(`if\\s*\\[\\s*"\\$FUNCTION_NAME"\\s*=\\s*"${fn}"\\s*\\]`);
  const ifIndex = lines.findIndex((l) => hardBlock.test(l) && !isCommented(l));
  return ifIndex >= 0 && lines.slice(ifIndex + 1, ifIndex + 4).some((l) => /\bdeny\s+"/.test(l) && !isCommented(l));
}

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

Deno.test('MP-05b a function\'s actionClassOverride, when present, is itself a valid AEF action class', () => {
  for (const [fn, p] of Object.entries(MODULE_POLICY.edgeFunctions)) {
    if (p.actionClassOverride === undefined) continue;
    assert(ACTION_CLASSES.has(p.actionClassOverride), `${fn}.actionClassOverride=${p.actionClassOverride}`);
  }
});

Deno.test('MP-06 PROMOTION GATE: every MODULE-kind function enforces its own module server-side, after auth and before quota', async () => {
  for (const [fn, p] of Object.entries(MODULE_POLICY.edgeFunctions)) {
    if (p.kind !== 'MODULE') continue;
    const gatePath = p.gateFile ? `../${p.gateFile}` : `../${fn}/index.ts`;
    const src = await Deno.readTextFile(new URL(gatePath, import.meta.url));
    const index = p.gateFile ? await Deno.readTextFile(new URL(`../${fn}/index.ts`, import.meta.url)) : src;
    if (p.gateFile) {
      // The delegating index.ts must actually route through that shared handler.
      const base = p.gateFile.split('/').pop()!;
      assert(index.includes(base.replace(/\.ts$/, '')), `${fn}/index.ts must delegate to ${p.gateFile}`);
    }
    const literalCall = new RegExp(`requireModuleAccess\\(\\s*req,\\s*\\w+,\\s*'${p.moduleId}'`);
    const m = literalCall.exec(src);
    if (m) {
      assert(/if \(!access\.allowed\) return access\.response;/.test(src), `${fn} must return the denial response`);
      const authAt = src.indexOf('resolveAuthenticatedUser(req');
      const quotaAt = src.indexOf('reserveQuota(');
      assert(authAt >= 0 && authAt < m.index, `${fn}: entitlement must run after authentication`);
      if (quotaAt >= 0) assert(m.index < quotaAt, `${fn}: entitlement must run before quota reservation`);
      continue;
    }
    // INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — a shared gateFile (e.g.
    // aef_runtime_endpoint.ts, now serving both aef-runtime and
    // action-engine-runtime with different moduleIds) can no longer
    // hold the moduleId as a literal in the requireModuleAccess call —
    // it's the caller-supplied deps.moduleId. This is only as safe as
    // proving BOTH: (a) the gateFile calls requireModuleAccess with the
    // parameterized field, and (b) THIS function's own index.ts binds
    // that field to exactly the module id the registry declares for it —
    // the same guarantee, checked across two files instead of one.
    const parameterizedCall = /requireModuleAccess\(\s*req,\s*\w+,\s*deps\.moduleId/;
    assert(parameterizedCall.test(src), `${fn} must call requireModuleAccess(req, <user>, '${p.moduleId}', ...) directly, or via a gateFile using deps.moduleId`);
    const boundLiteral = new RegExp(`moduleId:\\s*'${p.moduleId}'`);
    assert(boundLiteral.test(index), `${fn}/index.ts must bind moduleId: '${p.moduleId}' when delegating to a parameterized gateFile`);
    assert(/if \(!access\.allowed\) return access\.response;/.test(src), `${fn} must return the denial response`);
    const authAt = src.indexOf('resolveAuthenticatedUser(req');
    const entitlementAt = src.search(parameterizedCall);
    const quotaAt = src.indexOf('reserveQuota(');
    assert(authAt >= 0 && authAt < entitlementAt, `${fn}: entitlement must run after authentication`);
    if (quotaAt >= 0) assert(entitlementAt < quotaAt, `${fn}: entitlement must run before quota reservation`);
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

Deno.test('MP-09 PROMOTION GATE: every function whose EFFECTIVE actionClass is CONSEQUENTIAL is independently fail-closed while AEF persistence is unavailable (Codex CXF-02, evolved INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04)', async () => {
  if (AEF_PERSISTENCE_AVAILABLE) return;
  // MACRO-04 §4-6: a module's actionClass is now a default, not a ceiling
  // (see effectiveActionClass()) -- a commercially-available module may
  // legitimately own one narrow CONSEQUENTIAL function (action-engine ->
  // action-engine-runtime, aef-runtime-lab -> aef-runtime) without the
  // whole module needing to stay uncommercial. What MUST still be true,
  // for every function whose EFFECTIVE class is CONSEQUENTIAL, is that it
  // is independently, structurally unreachable while AEF persistence is
  // unavailable -- proven here by requiring it be hard-blocked in the
  // deploy allowlist script itself (scripts/ci/resolve_deploy_selection.sh),
  // not merely documented as LAB-only.
  const denyScript = await Deno.readTextFile(new URL('../../../scripts/ci/resolve_deploy_selection.sh', import.meta.url));
  const notContained = Object.keys(MODULE_POLICY.edgeFunctions)
    .filter((fn) => effectiveActionClass(fn) === 'CONSEQUENTIAL')
    .filter((fn) => !isHardBlockedInDenyScript(denyScript, fn));
  assertEquals(notContained, [], 'a CONSEQUENTIAL-effective function must be hard-blocked in resolve_deploy_selection.sh (an UNCOMMENTED if/deny pair, not merely matching text anywhere in the file) while AEF persistence is unavailable -- a class C capability may only ever execute through AEF (Human Gate + receipt)');
});

Deno.test('MP-12 (Codex final audit, round 4) isHardBlockedInDenyScript rejects commented-out if/deny pairs and similarly-named functions -- a false positive here would silently defeat MP-09', () => {
  // A commented-out `if` line: not executable, must not count.
  assert(!isHardBlockedInDenyScript('# if [ "$FUNCTION_NAME" = "quant-runtime" ]; then\n  deny "x"\nfi\n', 'quant-runtime'));
  // A real `if` whose `deny` call was itself commented out: still not a
  // real block -- the function falls through to the allowlist check.
  assert(!isHardBlockedInDenyScript('if [ "$FUNCTION_NAME" = "quant-runtime" ]; then\n  # deny "x"\n  :\nfi\n', 'quant-runtime'));
  // A deny for a DIFFERENT, merely similarly-named function must never
  // satisfy a check for the real one (exact match only, no prefix/substring).
  assert(!isHardBlockedInDenyScript('if [ "$FUNCTION_NAME" = "quant-runtime-v2" ]; then\n  deny "x"\nfi\n', 'quant-runtime'));
  assert(!isHardBlockedInDenyScript('if [ "$FUNCTION_NAME" = "my-quant-runtime" ]; then\n  deny "x"\nfi\n', 'quant-runtime'));
  // The genuine, real pattern this codebase actually uses must still pass.
  assert(isHardBlockedInDenyScript('if [ "$FUNCTION_NAME" = "quant-runtime" ]; then\n  deny "quant-runtime is LAB ONLY"\nfi\n', 'quant-runtime'));
});

Deno.test('MP-11 an actionClassOverride may only RAISE a function\'s effective risk above its module default, never lower it', () => {
  const order = { READ_ONLY: 0, REVERSIBLE: 1, CONSEQUENTIAL: 2 } as const;
  for (const [fn, p] of Object.entries(MODULE_POLICY.edgeFunctions)) {
    if (p.actionClassOverride === undefined) continue;
    assert(p.moduleId && p.moduleId in MODULE_POLICY.modules, `${fn}: actionClassOverride requires a valid moduleId`);
    const moduleClass = MODULE_POLICY.modules[p.moduleId!].actionClass;
    assert(
      order[p.actionClassOverride] >= order[moduleClass],
      `${fn}: actionClassOverride ${p.actionClassOverride} must not be lower than module ${p.moduleId}'s own ${moduleClass} -- a function can never use this field to opt out of its module's protections`,
    );
  }
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
