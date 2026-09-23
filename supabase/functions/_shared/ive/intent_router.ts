/**
 * IVE intent → capability routing (IVE-INTELLIGENCE-CORE-01).
 *
 * Deterministic keyword routing (PT/EN). It IDENTIFIES and SUGGESTS; it
 * never executes. Risk comes from the AEF taxonomy already stored per
 * module (module_policy.ts `actionClass`) plus a fixed set of consequential
 * verbs: anything that would publish, send, pay, trade, transfer or delete
 * on the user's behalf is CONSEQUENTIAL and must go through AEF — IVE
 * answers ACTION_REQUIRES_AEF and prepares an IveActionIntent instead.
 *
 * Deliberately conservative: a false "requires AEF" costs one extra step;
 * a false "safe" could skip a Human Gate.
 *
 * NOT the security boundary on its own (Codex Gate 1 IG1-03): IVE has no
 * execution tool at all, so an unrecognized consequential request can only
 * ever produce text. This router exists so IVE can say "this needs AEF"
 * and hand over an IveActionIntent. It is hardened anyway: matching runs
 * on a canonical form (NFKC, invisible characters removed, look-alike
 * letters folded, accents stripped) and again with punctuation removed,
 * and it scans the latest user turns of the conversation, not only the
 * current message.
 */
import { MODULE_POLICY, type ActionClass, type ModulePolicyDoc } from '../module_policy.ts';
import { canonicalize, squash } from './text_normalize.ts';

export interface RoutedIntent {
  intent: 'analyze' | 'open_capability' | 'consequential_action' | 'general';
  capabilityId: string | null;
  actionClass: ActionClass;
  requiresAef: boolean;
  requestedAction: string | null;
}

/** Consequential verbs (imperative / infinitive / "please do X" forms),
 * PT and EN, matched on the canonical form with word boundaries. Nouns
 * ("posts", "publicação", "resposta") are deliberately not matched. */
const CONSEQUENTIAL: readonly { re: RegExp; action: string }[] = [
  { re: /\b(publique|publiquem|publicar|publica|poste|postem|postar|posta|divulgue|divulgar|tuite|tuitar|publish|tweet|post (?:it|this|that|now|on|to|the)|share (?:it |this |that )?(?:on|to) (?:instagram|facebook|linkedin|twitter|x|tiktok|social))\b/, action: 'publish_content' },
  { re: /\b(agende|agendar|schedule)\b.{0,30}\b(post|posts|publicacao|publicacoes|tweet|campanha|campaign)\b/, action: 'publish_content' },
  { re: /\b(compartilhe|compartilhar)\b.{0,30}\b(redes|instagram|facebook|linkedin|twitter|tiktok)\b/, action: 'publish_content' },
  { re: /\b(envie|enviar|mande|mandar|dispare|disparar|send|email)\b.{0,40}\b(e-?mail|mensagem|message|campanha|campaign|newsletter|sms|whatsapp|clientes|customers|leads)\b/, action: 'send_message' },
  { re: /\b(pague|pagar|pay|cobre|cobrar|charge|reembolse|reembolsar|refund|cancele (?:a |minha )?assinatura|cancel (?:my |the )?subscription)\b/, action: 'payment' },
  { re: /\b(compre|comprar|venda|vender|buy|sell|invista|investir|invest|opere|operar|execute (?:a |the )?(?:ordem|order|trade)|executar (?:a )?ordem|place (?:an |the )?order)\b/, action: 'trade_order' },
  { re: /\b(transfira|transferir|transfer|saque|sacar|withdraw|pix)\b.{0,30}\b(dinheiro|money|fundos|funds|saldo|balance|reais|dolares|dollars|conta|account)\b/, action: 'transfer_funds' },
  { re: /\b(delete|deletar|apague|apagar|exclua|excluir|remova|remover|remove|wipe)\b/, action: 'delete_data' },
  // Codex Final IF-03 — indirect / pronoun forms.
  { re: /\b(envie|enviar|mande|mandar|send)\s+(isso|isto|ele|ela|eles|elas|it|this|that|them|agora|now)\b/, action: 'send_message' },
  { re: /\b(execute|executar|execute o|rode|rodar|run|dispare|disparar|trigger|acione|acionar)\b.{0,20}\b(workflow|workflows|fluxo|fluxos|automacao|automacoes|automation|automations|script|job|rotina|pipeline)\b/, action: 'execute_workflow' },
];

function consequentialIn(text: string): string | null {
  for (const view of [canonicalize(text), squash(text)]) {
    for (const c of CONSEQUENTIAL) if (c.re.test(view)) return c.action;
  }
  return null;
}

const CAPABILITY_KEYWORDS: readonly { re: RegExp; capabilityId: string; intent: RoutedIntent['intent'] }[] = [
  { re: /\b(oportunidades?|opportunit(y|ies))\b/, capabilityId: 'opportunity-lab', intent: 'open_capability' },
  { re: /\b(acoes|acao|tarefas?|actions?|tasks?|crie (?:uma )?acao|create (?:an )?action)\b/, capabilityId: 'action-engine', intent: 'open_capability' },
  { re: /\b(documentos?|conhecimento|cofre|knowledge|documents?|vault)\b/, capabilityId: 'knowledge-vault', intent: 'analyze' },
  { re: /\b(mercado|concorrentes?|nichos?|market|competitors?|niches?)\b/, capabilityId: 'market-intelligence', intent: 'analyze' },
  { re: /\b(site|website|seo)\b/, capabilityId: 'website-analyzer', intent: 'analyze' },
  { re: /\b(campanhas?|campaigns?)\b/, capabilityId: 'campaigns', intent: 'open_capability' },
  { re: /\b(personas?)\b/, capabilityId: 'personas', intent: 'open_capability' },
  { re: /\b(projetos?|projects?|analise meu projeto|analyze my project)\b/, capabilityId: 'projects', intent: 'analyze' },
];

/** How many of the latest USER turns of the conversation are scanned for
 * a consequential request (assistant turns cannot make the user's request
 * consequential, and are not trusted). */
export const ROUTER_USER_TURNS = 3;

export function routeIntent(
  message: string,
  requestedCapability: string | null,
  policy: ModulePolicyDoc = MODULE_POLICY,
  recentUserTurns: readonly string[] = [],
): RoutedIntent {
  const text = canonicalize(message);

  for (const t of [message, ...recentUserTurns.slice(-ROUTER_USER_TURNS)]) {
    const action = consequentialIn(t);
    if (action) {
      return { intent: 'consequential_action', capabilityId: null, actionClass: 'CONSEQUENTIAL', requiresAef: true, requestedAction: action };
    }
  }

  // A capability hint from the client is only a hint: it must exist in the
  // server policy, and if that module is CONSEQUENTIAL the request is
  // routed to AEF no matter how the message is worded.
  if (requestedCapability && Object.prototype.hasOwnProperty.call(policy.modules, requestedCapability)) {
    const cls = policy.modules[requestedCapability].actionClass;
    if (cls === 'CONSEQUENTIAL') {
      return { intent: 'consequential_action', capabilityId: requestedCapability, actionClass: cls, requiresAef: true, requestedAction: 'module_action' };
    }
  }

  for (const k of CAPABILITY_KEYWORDS) {
    if (k.re.test(text) && Object.prototype.hasOwnProperty.call(policy.modules, k.capabilityId)) {
      return { intent: k.intent, capabilityId: k.capabilityId, actionClass: policy.modules[k.capabilityId].actionClass, requiresAef: false, requestedAction: null };
    }
  }
  return { intent: 'general', capabilityId: null, actionClass: 'READ_ONLY', requiresAef: false, requestedAction: null };
}
