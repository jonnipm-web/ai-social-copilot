// aef-runtime — LAB ONLY (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
//
// NOT DEPLOYABLE: hard-blocked by scripts/ci/resolve_deploy_selection.sh and
// absent from .github/deploy-allowlist.tsv. The handler's kill switch
// (aef/runtime/runtime_guard.ts) also answers 503 unless AEF_RUNTIME_MODE=LAB,
// AEF_TOOLS=MOCK_ONLY and SUPABASE_URL points to a LOCAL Supabase stack —
// never a hosted project, never production. Mock tools only.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import type { AuthClient } from '../_shared/auth.ts';
import type { EntitlementSubjectSource } from '../_shared/entitlement.ts';
import type { QuotaClient } from '../_shared/quota.ts';
import { type AefRuntimeEndpointDeps, handleAefRuntime } from '../_shared/aef_runtime_endpoint.ts';
import { createServiceClient } from '../_shared/service_client.ts';
import { AefIdentityResolver } from '../../../aef/identity_resolver.ts';
import { SupabaseUserVerifier } from '../../../aef/adapters/supabase_identity_resolver.ts';
import { AefGovernance } from '../../../aef/persistence/governance.ts';
import { PostgresAefStore, SupabaseRpcTransport } from '../../../aef/persistence/store.ts';
import { IveAefRuntime } from '../../../aef/runtime/ive_aef_runtime.ts';
import { createLabToolRegistry } from '../../../aef/runtime/lab_tools.ts';

let runtime: IveAefRuntime | null = null;

/** Built on first use, only after auth, entitlement and the kill switch passed. */
function labRuntime(): IveAefRuntime {
  if (runtime) return runtime;
  const { registry } = createLabToolRegistry();
  const governance = new AefGovernance({
    identityResolver: new AefIdentityResolver(new SupabaseUserVerifier()),
    toolRegistry: registry,
    store: new PostgresAefStore(new SupabaseRpcTransport(createServiceClient())),
    requireInputSchema: true,
  });
  runtime = new IveAefRuntime({ governance });
  return runtime;
}

// Positional parity with every other MODULE-kind handler (test harness).
// This function consumes no quota; the quota client is accepted and unused.
export async function handler(
  req: Request,
  authClient?: AuthClient,
  _quotaClient?: QuotaClient,
  subjectSource?: EntitlementSubjectSource,
  deps: Partial<Omit<AefRuntimeEndpointDeps, 'authClient' | 'subjectSource'>> = {},
): Promise<Response> {
  // resolveAuthenticatedUser + requireModuleAccess(req, user, 'aef-runtime-lab', ...)
  // run inside handleAefRuntime (_shared/aef_runtime_endpoint.ts), before the
  // LAB kill switch and before the runtime is built — see MP-06.
  return await handleAefRuntime(req, { runtime: labRuntime, ...deps, authClient, subjectSource });
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
