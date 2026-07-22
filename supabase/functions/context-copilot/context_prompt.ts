export function buildOpportunityContextSection(
  opportunities: Record<string, unknown>[],
  hasActiveProject: boolean,
): string {
  if (opportunities.length) {
    const rows = opportunities
      .slice(0, 5)
      .map((o) => `• ${o.title} [referência interna=${o.id}]
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

export function buildProjectContextSection(
  project: Record<string, unknown> | null,
  scores: Record<string, unknown> | null,
): string {
  if (!project) return '';

  const id = project.id ?? '—';
  const name = project.name ?? '—';
  const lines = [
    '## PROJECT (validado pelo servidor)',
    `id: ${id}`,
    `name: ${name}`,
    `description: ${project.description || '—'}`,
    `type: ${project.type || '—'}`,
    `status: ${project.status || '—'}`,
  ];

  if (scores) {
    lines.push(
      '',
      '## INDICADORES ESTRATÉGICOS (hint do cliente vinculado ao projeto acima)',
      `${name} — Ecosystem Score: ${scores.ecosystem ?? 0}/100`,
      `${name} — Opportunity Score: ${scores.opportunity ?? 0}/100`,
      `${name} — Strategic Fit: ${scores.strategic_fit ?? 0}/100`,
      `${name} — Synergy: ${scores.synergy ?? 0}/100`,
      (scores.roi_data_available === false || scores.roi === null)
        ? `${name} — ROI: Dados indisponíveis (sem métricas registradas)`
        : `${name} — ROI: ${scores.roi ?? 0}/100`,
      `${name} — Momentum: ${scores.momentum ?? 0}/100`,
      `${name} — Market Score: ${scores.market ?? 0}/100`,
      `${name} — Execution Score: ${scores.execution ?? 0}/100`,
    );
  }

  return lines.join('\n');
}
