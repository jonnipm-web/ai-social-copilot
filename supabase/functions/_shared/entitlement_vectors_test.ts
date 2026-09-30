/**
 * Server side of the shared entitlement decision vectors —
 * INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02. The Flutter route
 * guard must satisfy the same file (test/core/modules/entitlement_parity_test.dart),
 * so client UX and server authority cannot silently disagree.
 *
 * Execução:
 *   deno test --allow-read supabase/functions/_shared/entitlement_vectors_test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { decideModuleAccess, mapLegacyProfileRole } from './entitlement.ts';
import type { ModuleLifecycle, ModulePolicyDoc, Plan } from './module_policy.ts';

interface VectorCase {
  legacyRole: string;
  lifecycle: ModuleLifecycle;
  minimumPlan: Plan;
  expected: string;
}

const vectors = JSON.parse(
  await Deno.readTextFile(new URL('../../../contracts/entitlements/decision_vectors.v1.json', import.meta.url)),
) as { cases: VectorCase[] };

Deno.test('EV-01 vectors cover every legacy role × lifecycle × plan (5×7×3)', () => {
  assertEquals(vectors.cases.length, 105);
});

Deno.test('EV-02 server decision matches every shared vector', () => {
  for (const c of vectors.cases) {
    const policy: ModulePolicyDoc = {
      version: 1,
      modules: { m: { lifecycle: c.lifecycle, minimumPlan: c.minimumPlan, actionClass: 'READ_ONLY' } },
      edgeFunctions: {},
    };
    const { plan, roles } = mapLegacyProfileRole(c.legacyRole);
    const d = decideModuleAccess({ type: 'user', id: 'u', plan, roles, source: 'legacy_profiles_role' }, 'm', policy);
    assertEquals(d.allowed ? 'ALLOW' : d.code, c.expected, JSON.stringify(c));
  }
});
