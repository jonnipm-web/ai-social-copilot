// strategy-simulation-runtime — LAB ONLY (INSIGHTVALUES-STRATEGY-
// INTELLIGENCE-MACRO-07 §24-27).
//
// The governed bridge for Strategy Simulation's one safe consequential
// action: a human approving/acknowledging a simulation result that
// strategy-builder's own `run_simulation` op already computed safely,
// deterministically and in-process (see
// aef/runtime/strategy_simulation_tools.ts). Clones quant-runtime/
// index.ts's exact shape: same shared HTTP boundary as aef-runtime,
// action-engine-runtime and quant-runtime (_shared/aef_runtime_endpoint.ts),
// same shared LAB tool registry (mock tools only, real tools structurally
// unreachable), but its OWN action table
// (STRATEGY_SIMULATION_ACTION_TABLE -- one action,
// approve_simulation_result) and its OWN entitlement gate
// ('ive-strategy-simulation', EXPERIMENTAL/admin-only per
// module_policy.ts -- this module stays exactly as gated as
// strategy-builder itself).
//
// NOT DEPLOYABLE: hard-blocked by scripts/ci/resolve_deploy_selection.sh
// and absent from .github/deploy-allowlist.tsv. The handler's kill switch
// (aef/runtime/runtime_guard.ts) also answers 503 unless
// AEF_RUNTIME_MODE=LAB, AEF_TOOLS=MOCK_ONLY and SUPABASE_URL points to a
// LOCAL Supabase stack -- never a hosted project, never production. Mock
// tools only. No broker, no order, no real money (TRADING_BOUNDARY, §49).
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import type { AuthClient } from '../_shared/auth.ts';
import type { EntitlementSubjectSource } from '../_shared/entitlement.ts';
import type { QuotaClient } from '../_shared/quota.ts';
import { type AefRuntimeEndpointDeps, handleAefRuntime } from '../_shared/aef_runtime_endpoint.ts';
import { createServiceClient } from '../_shared/service_client.ts';
import { writeLearningEntry } from '../_shared/result_learning.ts';
import { AefIdentityResolver } from '../../../aef/identity_resolver.ts';
import { SupabaseUserVerifier } from '../../../aef/adapters/supabase_identity_resolver.ts';
import { AefGovernance } from '../../../aef/persistence/governance.ts';
import { PostgresAefStore, SupabaseRpcTransport } from '../../../aef/persistence/store.ts';
import { IveAefRuntime } from '../../../aef/runtime/ive_aef_runtime.ts';
import { createLabToolRegistry } from '../../../aef/runtime/lab_tools.ts';
import { STRATEGY_SIMULATION_ACTION_TABLE } from '../../../aef/runtime/strategy_simulation_tools.ts';

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
  runtime = new IveAefRuntime({
    governance,
    table: STRATEGY_SIMULATION_ACTION_TABLE,
    source: 'strategy_simulation',
    learningWriter: writeLearningEntry(createServiceClient()),
  });
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
  // resolveAuthenticatedUser + requireModuleAccess(req, user,
  // 'ive-strategy-simulation', ...) run inside handleAefRuntime
  // (_shared/aef_runtime_endpoint.ts), before the LAB kill switch and
  // before the runtime is built.
  //
  // `deps` spreads FIRST so a caller-supplied deps.moduleId can never
  // override the literal 'ive-strategy-simulation' binding (same fix as
  // quant-runtime/aef-runtime/action-engine-runtime, which share this
  // exact call shape).
  return await handleAefRuntime(req, { ...deps, runtime: labRuntime, moduleId: 'ive-strategy-simulation', authClient, subjectSource });
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
