/**
 * IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — diretiva de idioma para
 * prompts de IA. Antes desta missão, 7 das 16 Edge Functions de IA
 * (competitor-discovery, content-cluster, gap-analysis, market-analysis,
 * niche-discovery, opportunity-discovery, revenue-planner) tinham
 * "Todas as respostas em português brasileiro" fixo no SYSTEM_PROMPT --
 * produziam saída em português mesmo com a UI em inglês. As outras 3
 * funções que já suportavam idioma (generate-strategy, generate-campaign,
 * extract-knowledge) usam o mesmo padrão: aceitar `language` no corpo
 * (default 'pt-BR', preserva o comportamento atual quando o cliente não
 * envia o campo) e injetar a diretiva na mensagem do usuário, nunca no
 * system prompt -- é mais barato (não invalida cache de prompt do
 * provedor) e já era o padrão estabelecido antes desta correção.
 */
// Codex Gate (P3, IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01): a versão
// anterior aceitava QUALQUER string não vazia enviada pelo cliente e a
// interpolava direto no prompt -- baixo risco (só afeta o idioma da
// resposta), mas sem necessidade real: a UI só oferece PT/EN hoje
// (languageProvider), então restringir à allowlist real do produto
// fecha a superfície sem quebrar nada legítimo.
const SUPPORTED_LANGUAGES = new Set(['pt-BR', 'en-US']);

export function normalizeLanguage(rawLanguage: unknown): string {
  if (typeof rawLanguage !== 'string') return 'pt-BR';
  const trimmed = rawLanguage.trim();
  return SUPPORTED_LANGUAGES.has(trimmed) ? trimmed : 'pt-BR';
}

export function withLanguageDirective(language: string, userContent: string): string {
  return `Idioma de resposta: ${language}\n\n${userContent}`;
}

// ---------------------------------------------------------------------------
// R16 — global language consistency.
//
// Regra: o idioma de APRESENTAÇÃO (locale da UI, `languageProvider` no
// cliente) decide o idioma da SAÍDA da IA. O idioma de ORIGEM dos dados do
// usuário (ex.: `knowledge_items.language`, o idioma de um site analisado, o
// histórico da conversa) NUNCA decide o idioma da saída.
//
// O idioma é só uma preferência de apresentação do cliente: nunca usar para
// identidade, plano, papel, quota ou ownership.
// ---------------------------------------------------------------------------

export type OutputLanguage = 'pt-BR' | 'en-US';

/**
 * Resolve o idioma de saída a partir do corpo da requisição.
 * Lê `body.language ?? body.locale`. Strings que começam (case-insensitive)
 * com "en" -> 'en-US'; com "pt" -> 'pt-BR'; qualquer outra coisa (ou
 * ausente, ou tipo inválido) -> 'pt-BR' (preserva o default histórico).
 * Nunca lança.
 */
export function resolveOutputLanguage(body: unknown): OutputLanguage {
  try {
    if (body === null || typeof body !== 'object') return 'pt-BR';
    const record = body as Record<string, unknown>;
    const raw = record.language ?? record.locale;
    if (typeof raw !== 'string') return 'pt-BR';
    const normalized = raw.trim().toLowerCase();
    if (normalized.startsWith('en')) return 'en-US';
    if (normalized.startsWith('pt')) return 'pt-BR';
    return 'pt-BR';
  } catch (_) {
    return 'pt-BR';
  }
}

export interface OutputLanguagePolicyOptions {
  /** Campos cujos valores são códigos fixos (chaves de lógica no cliente). */
  fixedValueFields?: string[];
  /** true quando a saída é texto livre (chat), não JSON. */
  freeText?: boolean;
}

/**
 * Bloco de instrução CONFIÁVEL (escrito pelo servidor, nunca pelo cliente),
 * redigido no próprio idioma de destino. Deve ser enviado como uma mensagem
 * `system` adicional, logo após o system prompt principal e antes de
 * qualquer mensagem de usuário/histórico -- ou seja, fora de qualquer
 * delimitador de conteúdo não confiável.
 */
export function outputLanguagePolicy(
  lang: OutputLanguage,
  opts: OutputLanguagePolicyOptions = {},
): string {
  // Só nomes de campo definidos no código do servidor chegam aqui; mesmo
  // assim, restringe a um formato de identificador para não virar vetor de
  // injeção se alguém um dia passar dado do cliente.
  const fields = (opts.fixedValueFields ?? [])
    .filter((f) => typeof f === 'string' && /^[A-Za-z0-9_.\[\]]+$/.test(f));
  const fieldList = fields.join(', ');

  if (lang === 'en-US') {
    const lines = [
      'OUTPUT LANGUAGE POLICY (mandatory): Respond in English.',
      opts.freeText
        ? 'Your entire reply must be in English.'
        : 'All user-facing generated text — every JSON string value (titles, names, summaries, descriptions, recommendations, actions, rationales, steps, labels, CTAs, explanations) and any free text — must be in English.',
      'The source material, the user\'s question, the conversation history and the examples in the instructions may be in another language (e.g. Portuguese); that must NOT change the output language.',
      'Do not switch languages unless the user explicitly asks for a translation or a different language.',
      'Preserve verbatim: proper nouns, brand/product/company names, URLs, identifiers, SKUs, technical codes/standards, citations and quoted source excerpts.',
      'Do not change numbers, amounts or currencies.',
    ];
    lines.push(opts.freeText
      ? 'If a JSON block is required, its keys must stay exactly as specified.'
      : 'JSON keys must stay exactly as specified.');
    if (fields.length > 0) {
      lines.push(
        `The following fields are fixed codes: copy their values EXACTLY from the allowed values listed in the schema, without translating: ${fieldList}.`,
      );
    }
    return lines.join('\n');
  }

  const lines = [
    'POLÍTICA DE IDIOMA DE SAÍDA (obrigatória): Responda em português do Brasil.',
    opts.freeText
      ? 'Toda a sua resposta deve estar em português do Brasil.'
      : 'Todo texto gerado voltado ao usuário — cada valor string do JSON (títulos, nomes, resumos, descrições, recomendações, ações, justificativas, passos, rótulos, CTAs, explicações) e qualquer texto livre — deve estar em português do Brasil.',
    'O material de origem, a pergunta do usuário, o histórico da conversa e os exemplos das instruções podem estar em outro idioma (ex.: inglês); isso NÃO deve mudar o idioma da saída.',
    'Não troque de idioma a menos que o usuário peça explicitamente uma tradução ou outro idioma.',
    'Preserve literalmente: nomes próprios, nomes de marcas/produtos/empresas, URLs, identificadores, SKUs, códigos/normas técnicas, citações e trechos citados da fonte.',
    'Não altere números, valores ou moedas.',
  ];
  lines.push(opts.freeText
    ? 'Se um bloco JSON for exigido, suas chaves devem permanecer exatamente como especificadas.'
    : 'As chaves do JSON devem permanecer exatamente como especificadas.');
  if (fields.length > 0) {
    lines.push(
      `Os campos a seguir são códigos fixos: copie seus valores EXATAMENTE dos valores permitidos listados no esquema, sem traduzir: ${fieldList}.`,
    );
  }
  return lines.join('\n');
}

/** Mensagem `system` pronta com a política de idioma de saída. */
export function outputLanguageSystemMessage(
  lang: OutputLanguage,
  opts: OutputLanguagePolicyOptions = {},
): { role: 'system'; content: string } {
  return { role: 'system', content: outputLanguagePolicy(lang, opts) };
}
