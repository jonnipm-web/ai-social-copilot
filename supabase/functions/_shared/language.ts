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
export function normalizeLanguage(rawLanguage: unknown): string {
  if (typeof rawLanguage !== 'string' || rawLanguage.trim().length === 0) return 'pt-BR';
  return rawLanguage.trim();
}

export function withLanguageDirective(language: string, userContent: string): string {
  return `Idioma de resposta: ${language}\n\n${userContent}`;
}
