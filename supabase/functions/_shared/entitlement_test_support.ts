/**
 * Test-only helpers for Edge Function handler tests —
 * INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02. Never imported by
 * production code (module_policy_test.ts MP-08 asserts that).
 */
import { type EntitlementSubjectSource, mapLegacyProfileRole } from './entitlement.ts';

/** A subject source that answers as if profiles.role were `legacyRole`,
 * always bound to the authenticated user id it is asked about. */
export function fakeSubjectSource(legacyRole: unknown): EntitlementSubjectSource & { calls: number } {
  const src = {
    calls: 0,
    // deno-lint-ignore require-await
    async resolveUserSubject(userId: string) {
      src.calls++;
      const { plan, roles } = mapLegacyProfileRole(legacyRole);
      return { type: 'user' as const, id: userId, plan, roles, source: 'legacy_profiles_role' as const };
    },
  };
  return src;
}

/** A subject source that fails, as when the profile read errors. */
export const failingSubjectSource: EntitlementSubjectSource = {
  // deno-lint-ignore require-await
  async resolveUserSubject() {
    throw new Error('simulated entitlement source outage');
  },
};

// deno-lint-ignore no-explicit-any
type ModuleHandler = (req: Request, authClient?: any, quotaClient?: any, subjectSource?: EntitlementSubjectSource) => Promise<Response>;

/** Wraps a module handler so pre-existing tests (written before server-side
 * entitlement existed) run as a subject with `legacyRole`, unless a test
 * passes its own source explicitly. */
export function withSubject(handler: ModuleHandler, legacyRole: unknown): ModuleHandler {
  const source = fakeSubjectSource(legacyRole);
  return (req, authClient, quotaClient, subjectSource) => handler(req, authClient, quotaClient, subjectSource ?? source);
}
