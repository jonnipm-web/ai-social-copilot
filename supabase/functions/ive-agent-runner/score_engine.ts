/**
 * ive-agent-runner — Score Engine
 *
 * Tradução fiel das fórmulas do EcosystemIntelligenceService (Dart) para TypeScript.
 * Fonte canônica: lib/data/services/ecosystem_intelligence_service.dart
 *
 * REGRA: Ausência de dados NUNCA vira zero calculado.
 * Use status 'insufficient_data' para diferenciar zero real de dado ausente.
 *
 * Inputs identicos aos queries do context-copilot + roi_metrics adicionais.
 */

import type { DbAction, DbAsset, DbKbItem, DbOpportunity, DbProject, DbRoiMetric, ScoreFactors, ScoreResult } from './types.ts';

// ── Clamp helper ───────────────────────────────────────────────────────────────

function clamp(v: number, min = 0, max = 100): number {
  return Math.min(max, Math.max(min, Math.round(v)));
}

// ── Market Score ──────────────────────────────────────────────────────────────

function marketScore(opportunities: DbOpportunity[]): { score: number; factor: string } {
  if (opportunities.length === 0) {
    return { score: 0, factor: 'insufficient_data: nenhuma oportunidade registrada' };
  }
  const avgMarket  = opportunities.reduce((s, o) => s + (o.market_score  ?? 0), 0) / opportunities.length;
  const avgRevenue = opportunities.reduce((s, o) => s + (o.revenue_score ?? 0), 0) / opportunities.length;
  const avgFit     = opportunities.reduce((s, o) => s + (o.strategic_fit ?? 0), 0) / opportunities.length;
  const score      = clamp(avgMarket * 0.45 + avgRevenue * 0.30 + avgFit * 0.25);
  return {
    score,
    factor: `derived from ${opportunities.length} opportunities: market=${avgMarket.toFixed(0)}, revenue=${avgRevenue.toFixed(0)}, fit=${avgFit.toFixed(0)}`,
  };
}

// ── Execution Score ───────────────────────────────────────────────────────────

function executionScore(
  actions:       DbAction[],
  opportunities: DbOpportunity[],
): { score: number; factor: string } {
  if (actions.length === 0 && opportunities.length === 0) {
    return { score: 0, factor: 'insufficient_data: sem ações e sem oportunidades' };
  }
  const completed = actions.filter(a => a.status === 'completed').length;
  const approved  = opportunities.filter(o => o.status === 'approved').length;
  const compRate  = actions.length > 0 ? completed / actions.length : 0;
  const compPts   = clamp(compRate * 50);
  const appPts    = Math.min(30, approved * 10);
  const score     = clamp(compPts + appPts);
  return {
    score,
    factor: `${completed}/${actions.length} ações concluídas → ${compPts}pts; ${approved} oportunidades aprovadas → ${appPts}pts`,
  };
}

// ── Opportunity Score ─────────────────────────────────────────────────────────

function opportunityScore(
  project:       DbProject,
  opportunities: DbOpportunity[],
): { score: number; factor: string } {
  if (opportunities.length > 0) {
    const avg   = opportunities.reduce((s, o) => s + o.final_score, 0) / opportunities.length;
    const bonus = Math.min(10, opportunities.length * 2);
    const score = clamp(avg + bonus);
    return { score, factor: `média final_score ${avg.toFixed(0)} + bônus volume ${bonus}pts (${opportunities.length} oportunidades)` };
  }
  // Fallback: campos do projeto
  const revScore = Math.min(50, Math.round((project.revenue_potential ?? 0) / 2000));
  const priScore = Math.round((project.priority_score ?? 0) * 0.30);
  const timeBns  = (project.time_to_revenue_days ?? 0) > 0 && (project.time_to_revenue_days ?? 999) <= 90 ? 10 : 0;
  const score    = clamp(revScore + priScore + timeBns);
  return { score, factor: `derived from project fields: revenue=${revScore}pts, priority=${priScore}pts, time_to_revenue=${timeBns}pts` };
}

// ── ROI Score ─────────────────────────────────────────────────────────────────

function roiScore(roiMetrics: DbRoiMetric[]): { score: number; hasData: boolean; factor: string } {
  if (roiMetrics.length > 0) {
    const total = roiMetrics.reduce((s, r) => s + r.metric_value, 0);
    const score = clamp(Math.round(total / 2000 * 100));
    return { score, hasData: true, factor: `total ROI R$${total.toFixed(0)} → ${score}/100 (meta R$2.000)` };
  }
  return { score: 0, hasData: false, factor: 'insufficient_data: nenhuma métrica de ROI registrada' };
}

// ── Strategic Fit ─────────────────────────────────────────────────────────────

function strategicFit(
  market:    number,
  roi:       number,
  execution: number,
  project:   DbProject,
): { score: number; factor: string } {
  const mkt  = market    * 0.35;
  const pri  = Math.min(100, project.priority_score ?? 0) * 0.20;
  const roiP = roi       * 0.25;
  const exec = execution * 0.20;
  const score = clamp(mkt + pri + roiP + exec);
  return {
    score,
    factor: `market×0.35=${mkt.toFixed(0)} + priority×0.20=${pri.toFixed(0)} + roi×0.25=${roiP.toFixed(0)} + execution×0.20=${exec.toFixed(0)}`,
  };
}

// ── Synergy Score ─────────────────────────────────────────────────────────────

function synergyScore(
  opportunities: DbOpportunity[],
  actions:       DbAction[],
): { score: number; factor: string } {
  const approved = opportunities.filter(o => o.status === 'approved').length;
  const labPts   = Math.min(30, opportunities.length * 8);
  const appPts   = Math.min(20, approved * 10);
  const actPts   = Math.min(15, actions.length * 3);
  const score    = clamp(labPts + appPts + actPts);
  return {
    score,
    factor: `oportunidades×8=${labPts}pts + aprovadas×10=${appPts}pts + ações×3=${actPts}pts`,
  };
}

// ── Momentum Score ────────────────────────────────────────────────────────────

function momentumScore(
  actions:       DbAction[],
  opportunities: DbOpportunity[],
  cutoffIso:     string,
): { score: number; factor: string } {
  const baseline  = (actions.length > 0 || opportunities.length > 0) ? 15 : 0;
  const recentA   = actions.filter(a => (a.created_at ?? '') >= cutoffIso).length;
  const recentO   = opportunities.filter(o => (o.created_at ?? '') >= cutoffIso).length;
  const completed = actions.filter(a => a.status === 'completed').length;
  const score     = clamp(baseline + recentA * 12 + recentO * 8 + completed * 5);
  return {
    score,
    factor: `baseline=${baseline} + ${recentA} ações recentes×12 + ${recentO} oportunidades recentes×8 + ${completed} concluídas×5`,
  };
}

// ── Weighted Ecosystem Score ───────────────────────────────────────────────────

function weightedEcosystem(opp: number, fit: number, syn: number, roi: number, mom: number): number {
  return clamp(opp * 0.25 + fit * 0.25 + syn * 0.20 + roi * 0.20 + mom * 0.10);
}

// ── Recommendation Engine ─────────────────────────────────────────────────────

function recommend(score: number, hasEnoughData: boolean): string {
  if (!hasEnoughData) return 'ANÁLISE INCOMPLETA';
  if (score >= 80) return 'ESCALAR';
  if (score >= 60) return 'ACELERAR';
  if (score >= 40) return 'MANTER';
  if (score >= 20) return 'VALIDAR';
  return 'PAUSAR';
}

// ── Public API ─────────────────────────────────────────────────────────────────

/**
 * Computa todos os scores de ecossistema para um projeto.
 *
 * Portagem fiel do EcosystemIntelligenceService.computeProjectScores() (Dart).
 * Usa os mesmos inputs e as mesmas fórmulas para garantir valores idênticos à UI.
 */
export function computeEcosystemScores(
  project:       DbProject,
  opportunities: DbOpportunity[],
  actions:       DbAction[],
  roiMetrics:    DbRoiMetric[],
): ScoreResult {
  // 30-day cutoff for momentum (ISO 8601 prefix comparison)
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

  const oppResult  = opportunityScore(project, opportunities);
  const mktResult  = marketScore(opportunities);
  const execResult = executionScore(actions, opportunities);
  const roiResult  = roiScore(roiMetrics);
  const fitResult  = strategicFit(mktResult.score, roiResult.score, execResult.score, project);
  const synResult  = synergyScore(opportunities, actions);
  const momResult  = momentumScore(actions, opportunities, cutoff);
  const ecosystem  = weightedEcosystem(
    oppResult.score, fitResult.score, synResult.score, roiResult.score, momResult.score,
  );

  const hasEnoughData = opportunities.length > 0 || actions.length > 0;

  const factors: ScoreFactors = {
    opportunity:  oppResult.factor,
    market:       mktResult.factor,
    execution:    execResult.factor,
    strategicFit: fitResult.factor,
    synergy:      synResult.factor,
    roi:          roiResult.factor,
    momentum:     momResult.factor,
    ecosystem:    `opp×0.25 + fit×0.25 + syn×0.20 + roi×0.20 + mom×0.10 = ${ecosystem}`,
  };

  return {
    ecosystemScore:   ecosystem,
    opportunityScore: oppResult.score,
    marketScore:      mktResult.score,
    executionScore:   execResult.score,
    strategicFit:     fitResult.score,
    synergyScore:     synResult.score,
    roiScore:         roiResult.score,
    momentumScore:    momResult.score,
    hasRoiData:       roiResult.hasData,
    hasEnoughData,
    recommendation:   recommend(ecosystem, hasEnoughData),
    scoreFactors:     factors,
  };
}

/**
 * Determina o status de um score individual.
 *
 * Segue a regra: ZERO só representa zero calculado; ausência de dados = insufficient_data.
 */
export function scoreStatus(
  value:       number,
  hasData:     boolean,
  isProvisional: boolean,
): 'available' | 'insufficient_data' | 'provisional' {
  if (!hasData && value === 0) return 'insufficient_data';
  if (isProvisional) return 'provisional';
  return 'available';
}

/**
 * Compara scores de dois projetos.
 * Retorna structured diff com distinção entre known/unknown/not_applicable.
 */
export function compareScores(
  scoreA: ScoreResult,
  scoreB: ScoreResult,
  projectA: DbProject,
  projectB: DbProject,
): Record<string, unknown> {
  const fields: Array<{ key: keyof ScoreResult; label: string }> = [
    { key: 'opportunityScore', label: 'Opportunity' },
    { key: 'strategicFit',     label: 'Strategic Fit' },
    { key: 'synergyScore',     label: 'Synergy' },
    { key: 'roiScore',         label: 'ROI' },
    { key: 'momentumScore',    label: 'Momentum' },
    { key: 'marketScore',      label: 'Market' },
    { key: 'executionScore',   label: 'Execution' },
    { key: 'ecosystemScore',   label: 'Ecosystem' },
  ];

  const comparison: Record<string, unknown> = {};
  for (const { key, label } of fields) {
    const valA = scoreA[key] as number;
    const valB = scoreB[key] as number;

    const unknownA = key === 'roiScore' && !scoreA.hasRoiData;
    const unknownB = key === 'roiScore' && !scoreB.hasRoiData;

    comparison[label] = {
      [projectA.name]: unknownA ? 'insufficient_data' : valA,
      [projectB.name]: unknownB ? 'insufficient_data' : valB,
      delta:           (unknownA || unknownB) ? null : (valA - valB),
      winner:          (unknownA || unknownB) ? null : (valA > valB ? projectA.name : valA < valB ? projectB.name : 'tie'),
    };
  }

  return {
    compared_projects: [{ id: projectA.id, name: projectA.name }, { id: projectB.id, name: projectB.name }],
    scores:            comparison,
    overall_winner:    scoreA.ecosystemScore > scoreB.ecosystemScore ? projectA.name
                       : scoreA.ecosystemScore < scoreB.ecosystemScore ? projectB.name
                       : 'tie',
    recommendation: {
      [projectA.name]: scoreA.recommendation,
      [projectB.name]: scoreB.recommendation,
    },
    data_quality: {
      [projectA.name]: { has_enough_data: scoreA.hasEnoughData, has_roi_data: scoreA.hasRoiData },
      [projectB.name]: { has_enough_data: scoreB.hasEnoughData, has_roi_data: scoreB.hasRoiData },
    },
    note: 'Scores calculados pela mesma fórmula que a UI do Ecosystem Intelligence.',
  };
}

// ── Asset scoring helper ───────────────────────────────────────────────────────

export function summarizeAssets(assets: DbAsset[]): Record<string, unknown> {
  if (assets.length === 0) return { count: 0, status: 'no_assets' };
  const byType: Record<string, number> = {};
  for (const a of assets) {
    const t = a.type ?? 'unknown';
    byType[t] = (byType[t] ?? 0) + 1;
  }
  const avgScore = assets.filter(a => a.score != null).length > 0
    ? assets.reduce((s, a) => s + (a.score ?? 0), 0) / assets.length
    : null;
  return { count: assets.length, by_type: byType, avg_score: avgScore };
}

// ── Knowledge summary ──────────────────────────────────────────────────────────

export function summarizeKb(items: DbKbItem[]): Record<string, unknown> {
  if (items.length === 0) return { count: 0, status: 'no_knowledge_items' };
  const byStatus: Record<string, number> = {};
  for (const k of items) {
    const s = k.status ?? 'unknown';
    byStatus[s] = (byStatus[s] ?? 0) + 1;
  }
  return {
    count: items.length,
    by_status: byStatus,
    note: 'Apenas metadados retornados. Conteúdo integral dos documentos não está disponível neste contexto.',
  };
}
