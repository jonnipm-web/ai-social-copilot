// ive-memory — IVE-INTELLIGENCE-CORE-01.
//
// Governed durable-memory write path (promote / forget). Every write runs
// the server memory policy (_shared/ive/memory_policy.ts) and project
// ownership checks, with the caller's own JWT. No service role, no AI call.
//
// NOT DEPLOYED by this mission (Module Lab). Not on .github/deploy-allowlist.tsv.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import type { AuthClient } from '../_shared/auth.ts';
import type { EntitlementSubjectSource } from '../_shared/entitlement.ts';
import { handleIveMemory, type IveMemoryDeps } from '../_shared/ive/memory_endpoint.ts';

export async function handler(
  req: Request,
  authClient?: AuthClient,
  _quotaClient?: unknown,
  subjectSource?: EntitlementSubjectSource,
  deps: Omit<IveMemoryDeps, 'authClient' | 'subjectSource'> = {},
): Promise<Response> {
  return await handleIveMemory(req, { ...deps, authClient, subjectSource });
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
