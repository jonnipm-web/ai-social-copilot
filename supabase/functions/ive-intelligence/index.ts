// ive-intelligence — IVE-INTELLIGENCE-CORE-01.
//
// The single server entry point of the IVE Intelligence Core for every
// surface (Android and Web today). The client sends only the question, the
// project it is looking at, surface, locale and the visible conversation;
// the server derives identity, entitlement, project ownership, knowledge,
// memory and provenance itself (_shared/ive/*).
//
// NOT DEPLOYED by this mission (Module Lab). Not on .github/deploy-allowlist.tsv.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import type { AuthClient } from '../_shared/auth.ts';
import type { EntitlementSubjectSource } from '../_shared/entitlement.ts';
import type { QuotaClient } from '../_shared/quota.ts';
import { handleIveIntelligence, type IveCoreDeps } from '../_shared/ive/intelligence.ts';

// Positional parity with every other MODULE-kind handler (test harness);
// `deps` lets tests inject the data source and the model provider.
export async function handler(
  req: Request,
  authClient?: AuthClient,
  quotaClient?: QuotaClient,
  subjectSource?: EntitlementSubjectSource,
  deps: Omit<IveCoreDeps, 'authClient' | 'quotaClient' | 'subjectSource'> = {},
): Promise<Response> {
  // resolveAuthenticatedUser + requireModuleAccess(req, user, 'context-copilot', ...)
  // run inside handleIveIntelligence (_shared/ive/intelligence.ts), after
  // authentication and before any quota reservation — see MP-06b.
  return await handleIveIntelligence(req, { ...deps, authClient, quotaClient, subjectSource });
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
