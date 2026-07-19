export function buildOpportunityContextSection(
  opportunities: Record<string, unknown>[],
  hasActiveProject: boolean,
): string {
  if (opportunities.length) {
    const rows = opportunities
      .slice(0, 5)
      .map((o) => `• [${o.id}] ${o.title}
  Status: ${o.status} | Score final: ${o.final_score}/100 | Mercado: ${o.market_score}/100 | Receita/ROI: ${o.revenue_score}/100
  Fit estratégico: ${o.strategic_fit}/100 | Sinergia: ${o.synergy_score}/100 | Competição: ${o.competition_score}/100 | Confiança: ${o.confidence}/100
  Justificativa: ${o.rationale || o.description || '—'}
  Riscos: ${Array.isArray(o.risks) && o.risks.length ? o.risks.join('; ') : '—'}
  Próximos passos: ${Array.isArray(o.action_steps) && o.action_steps.length ? o.action_steps.join('; ') : '—'}`)
      .join('\n');
    return `## OPORTUNIDADES DO PROJETO (${opportunities.length} total, fonte: servidor)\n${rows}`;
  }

  if (!hasActiveProject) return '';
  return '## OPORTUNIDADES DO PROJETO (0 total, fonte: servidor)\nEste projeto ainda não possui oportunidades registradas no Opportunity Lab. Ao responder perguntas sobre oportunidades, declare exatamente essa ausência e ofereça gerar/analisar oportunidades. Não use a frase genérica "dados insuficientes".';
}
