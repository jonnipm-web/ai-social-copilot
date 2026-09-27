/**
 * Action Engine action table (INSIGHTVALUES-PRODUCTIZATION-MACRO-03).
 *
 * Action Engine's action_queue is, today, overwhelmingly a self-attested
 * task tracker: an item's "action_type" (tarefa/conteudo/campanha/produto/
 * analise) names real-world work the USER does themselves -- there is no
 * digital tool anywhere in this codebase that actually posts content or
 * sends a message on the user's behalf. Calling that transition "execute"
 * while it was a bare, ungoverned Supabase status write was the real risk
 * this macro's own brief named: not an active bypass (nothing was being
 * executed to bypass), but an architecture that would silently bypass AEF
 * the moment a real tool got bolted onto the existing update-status call.
 *
 * This table adds exactly ONE LAB mock tool, `internal.mock_complete_action`
 * (see lab_tools.ts for its definition), representing that self-attestation
 * as a real, governed, receipted, Human-Gate-approved transition instead of
 * an ungoverned client write. It reuses the SAME shared LAB tool registry
 * (createLabToolRegistry) as the IVE runtime -- one registry, two action
 * tables, each scoped to what its own calling surface may request.
 */
import { defineIveActionTable, type IveActionTable } from "../persistence/ive_intent_mapping.ts";

/**
 * Action Engine may request exactly one action: self-attested completion.
 * Every other requestedAction (including anything that happens to share a
 * name with an IVE action, e.g. publish_content) is absent here ->
 * INTENT_ACTION_UNKNOWN -- this table does not inherit IVE's vocabulary.
 */
export const ACTION_ENGINE_TABLE: IveActionTable = defineIveActionTable({
  complete_action: { domain: "internal", action: "internal.mock_complete_action" },
});
