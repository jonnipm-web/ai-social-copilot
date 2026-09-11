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
