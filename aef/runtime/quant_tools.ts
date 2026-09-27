/**
 * Quant action table (INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §15-17).
 *
 * The safe internal seam for Quant -> Action Intent -> AEF: a strategy
 * engine's structural events (e.g. Strategy001/"Paulo Trend Fibonacci" --
 * see lib/core/quant/strategy001_contracts.dart, and
 * STRATEGY001_SOURCE_FINDING.md for what could and could not be verified
 * about that asset's real source this mission) may propose that a human
 * ACKNOWLEDGE a detected condition. This table adds exactly ONE LAB mock
 * tool, `internal.mock_quant_signal_acknowledgment` (lab_tools.ts) -- never
 * a trade, an order, or anything resembling a live-market action.
 *
 * Reuses the SAME shared LAB tool registry (createLabToolRegistry) as IVE
 * and Action Engine -- one registry, three action tables, each scoped to
 * what its own calling surface may request.
 */
import { defineIveActionTable, type IveActionTable } from "../persistence/ive_intent_mapping.ts";

/**
 * Quant may request exactly one action: acknowledging a structural signal.
 * trade_order, payment, transfer_funds and every other IVE/Action-Engine
 * action are absent here -> INTENT_ACTION_UNKNOWN -- this table does not
 * inherit either surface's vocabulary, and there is categorically no path
 * from it to a trading action (TRADING_BOUNDARY, §17).
 */
export const QUANT_ACTION_TABLE: IveActionTable = defineIveActionTable({
  acknowledge_signal: { domain: "internal", action: "internal.mock_quant_signal_acknowledgment" },
});
