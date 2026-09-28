/**
 * Strategy Simulation action table — INSIGHTVALUES-STRATEGY-INTELLIGENCE-
 * MACRO-07 §24-27.
 *
 * The governed acknowledgment step for a Strategy Builder simulation,
 * mirroring quant_tools.ts's `acknowledge_signal` exactly: the actual
 * simulation COMPUTATION already happened, safely, deterministically and
 * in-process, inside strategy-builder's `run_simulation` op (never here --
 * this module imports no engine, no dataset, no strategy logic). This
 * table adds exactly ONE LAB mock tool,
 * `internal.mock_strategy_simulation_approval`, so a human can formally
 * approve/acknowledge a simulation result through the SAME AEF pipeline
 * (policy -> Human Gate -> receipt -> learning) every other governed
 * action in this codebase uses -- never a direct IVE-to-simulation
 * bypass for this consequential step (§26).
 *
 * Categorically absent from this table: any action resembling a trade,
 * an order, a broker connection, or "run this simulation live" -- there
 * is no such action to request. A caller may only ever ask for
 * `approve_simulation_result`; anything else is INTENT_ACTION_UNKNOWN.
 */
import { defineIveActionTable, type IveActionTable } from '../persistence/ive_intent_mapping.ts';

export const STRATEGY_SIMULATION_ACTION_TABLE: IveActionTable = defineIveActionTable({
  approve_simulation_result: { domain: 'internal', action: 'internal.mock_strategy_simulation_approval' },
});
