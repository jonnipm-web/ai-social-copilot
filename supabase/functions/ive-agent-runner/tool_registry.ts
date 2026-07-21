/**
 * ive-agent-runner — Tool Registry V1
 *
 * 11 ferramentas disponíveis para o agente IVE.
 * Cada tool é um adapter seguro sobre queries Supabase com RLS enforced.
 *
 * Regras de segurança:
 *   - user_id: SEMPRE do JWT (passado via ToolExecutionContext)
 *   - project_id: SEMPRE do contexto verificado server-side (não do LLM)
 *   - write tools: somente PROPOSE — EXECUTE requer confirmação do usuário no Flutter
 */

import { SupabaseClient } from 'npm:@supabase/supabase-js@2';
import {
  computeEcosystemScores,
  compareScores,
  summarizeAssets,
  summarizeKb,
  scoreStatus,
} from './score_engine.ts';
import { fetchUserProjects, isValidUuid } from './permission_engine.ts';
import type {
  AIToolDefinition,
  DbAction,
  DbAsset,
  DbKbItem,
  DbOpportunity,
  DbProject,
  DbRoiMetric,
  PermissionLevel,
  ServerContext,
  ToolDefinition,
  ToolExecutionContext,
  ToolResult,
} from './types.ts';

// ── Tool execution type ────────────────────────────────────────────────────────

type ToolExecutor = (
  args:    Record<string, unknown>,
  ctx:     ToolExecutionContext,
) => Promise<ToolResult>;

interface RegisteredTool extends ToolDefinition {
  execute: ToolExecutor;
}

// ── Tool Registry ──────────────────────────────────────────────────────────────

const TOOLS = new Map<string, RegisteredTool>();

function register(tool: RegisteredTool): void {
  TOOLS.set(tool.name, tool);
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. project.get_active
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'project_get_active',
  publicName:  'project.get_active',
  description: 'Retorna os dados do projeto atualmente selecionado/ativo na sessão.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {},
    required:   [],
  },
  execute: async (_args, ctx) => {
    const client = ctx.supabase as SupabaseClient;
    const { data, error } = await client
      .from('projects')
      .select('id,name,description,type,status,priority_score,opportunity_score,revenue_potential,created_at')
      .eq('id', ctx.projectId)
      .eq('user_id', ctx.uid)
      .maybeSingle();

    if (error || !data) {
      return { ok: false, error: 'Projeto não encontrado ou não autorizado.' };
    }

    return {
      ok: true,
      data: data as Record<string, unknown>,
      summary: `Projeto ativo: ${(data as DbProject).name} (${ctx.projectId})`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. project.find
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'project_find',
  publicName:  'project.find',
  description: 'Busca projetos do usuário autenticado por nome/query. Retorna candidatos — nunca escolhe silenciosamente quando há ambiguidade.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      query: { type: 'string', description: 'Nome ou parte do nome do projeto a buscar.' },
    },
    required: ['query'],
  },
  execute: async (args, ctx) => {
    const query = (args.query as string ?? '').trim().toLowerCase();
    if (!query) return { ok: false, error: 'query é obrigatório' };

    const projects = await fetchUserProjects(ctx.supabase as SupabaseClient, ctx.uid);
    const matches  = projects.filter(p => p.name.toLowerCase().includes(query));

    if (matches.length === 0) {
      return {
        ok:   true,
        data: { candidates: [], count: 0 },
        summary: `Nenhum projeto encontrado para "${query}".`,
      };
    }

    // Retorna todos os candidatos — o LLM deve perguntar ao usuário se há ambiguidade (>1 match)
    const candidates = matches.map(p => ({
      id:     p.id,
      name:   p.name,
      type:   p.type,
      status: p.status,
      note:   p.id === ctx.projectId ? 'este é o projeto atualmente ativo' : undefined,
    }));

    const summary = matches.length === 1
      ? `Projeto encontrado: ${matches[0].name}`
      : `${matches.length} projetos encontrados para "${query}" — retornando todos os candidatos para evitar escolha ambígua.`;

    return {
      ok:   true,
      data: { candidates, count: candidates.length, ambiguous: matches.length > 1 },
      summary,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. project.get_overview
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'project_get_overview',
  publicName:  'project.get_overview',
  description: 'Produz visão estruturada de um projeto: identidade, status, scores, resumo de ações/oportunidades/assets/kb e dados ausentes.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      project_id: {
        type:        'string',
        description: 'ID do projeto. Se omitido, usa o projeto ativo da sessão.',
      },
    },
    required: [],
  },
  execute: async (args, ctx) => {
    const client    = ctx.supabase as SupabaseClient;
    // SEGURANÇA: verifica ownership — project_id do LLM não é confiável
    let targetId    = ctx.projectId;
    const rawId     = args.project_id;
    if (isValidUuid(rawId) && ctx.allProjectIds.has(rawId)) {
      targetId = rawId;
    }

    const [projRes, oppsRes, actsRes, kbRes, assetRes, roiRes] = await Promise.all([
      client.from('projects').select('id,name,description,type,status,priority_score,opportunity_score,revenue_potential,time_to_revenue_days,created_at').eq('id', targetId).eq('user_id', ctx.uid).maybeSingle(),
      client.from('opportunity_lab').select('id,title,status,final_score,created_at').eq('project_id', targetId).eq('user_id', ctx.uid).order('final_score', { ascending: false }).limit(5),
      client.from('action_queue').select('id,title,status,priority,created_at').eq('project_id', targetId).eq('user_id', ctx.uid).order('priority', { ascending: false }).limit(5),
      client.from('knowledge_items').select('id,title,status').eq('project_id', targetId).eq('user_id', ctx.uid).limit(5),
      client.from('assets').select('id,title,type,status').eq('project_id', targetId).eq('user_id', ctx.uid).limit(5),
      client.from('roi_metrics').select('id,metric_name,metric_value').eq('project_id', targetId).eq('user_id', ctx.uid).limit(5),
    ]);

    const project = projRes.data as DbProject | null;
    if (!project) return { ok: false, error: 'Projeto não encontrado.' };

    const opps   = (oppsRes.data  ?? []) as DbOpportunity[];
    const acts   = (actsRes.data  ?? []) as DbAction[];
    const kbItems= (kbRes.data    ?? []) as DbKbItem[];
    const assets = (assetRes.data ?? []) as DbAsset[];
    const roi    = (roiRes.data   ?? []) as DbRoiMetric[];

    const missingData: string[] = [];
    if (opps.length   === 0) missingData.push('oportunidades (Opportunity Lab vazio)');
    if (acts.length   === 0) missingData.push('ações (Action Engine vazio)');
    if (kbItems.length=== 0) missingData.push('knowledge base (sem documentos)');
    if (assets.length === 0) missingData.push('assets');
    if (roi.length    === 0) missingData.push('métricas de ROI');

    const scores = computeEcosystemScores(project, opps, acts, roi);

    return {
      ok: true,
      data: {
        identity:      { id: project.id, name: project.name, type: project.type, status: project.status },
        description:   project.description ?? null,
        scores: {
          ecosystem:         scores.ecosystemScore,
          opportunity:       scores.opportunityScore,
          market:            scores.marketScore,
          strategic_fit:     scores.strategicFit,
          synergy:           scores.synergyScore,
          roi:               scores.hasRoiData ? scores.roiScore : null,
          has_roi_data:      scores.hasRoiData,
          momentum:          scores.momentumScore,
          execution:         scores.executionScore,
          has_enough_data:   scores.hasEnoughData,
          recommendation:    scores.recommendation,
        },
        actions_summary:      { total: acts.length, top5: acts.map(a => ({ id: a.id, title: a.title, status: a.status, priority: a.priority })) },
        opportunities_summary:{ total: opps.length, top5: opps.map(o => ({ id: o.id, title: o.title, status: o.status, score: o.final_score })) },
        assets_summary:       summarizeAssets(assets),
        knowledge_summary:    summarizeKb(kbItems),
        roi_metrics:          roi.map(r => ({ name: r.metric_name, value: r.metric_value })),
        missing_data:         missingData,
      },
      summary: `Visão geral de "${project.name}": ecosystem=${scores.ecosystemScore}/100, ${missingData.length} dado(s) ausente(s).`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. project.compare
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'project_compare',
  publicName:  'project.compare',
  description: 'Compara dois projetos pertencentes ao usuário autenticado. Nunca compara projetos de outro usuário. Distingue dados known/unknown/insufficient_data.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      project_ids: {
        type:        'array',
        items:       { type: 'string' },
        minItems:    2,
        maxItems:    2,
        description: 'IDs dos dois projetos a comparar. Ambos devem pertencer ao usuário autenticado.',
      },
    },
    required: ['project_ids'],
  },
  execute: async (args, ctx) => {
    const client = ctx.supabase as SupabaseClient;
    const ids    = args.project_ids as string[];

    if (!Array.isArray(ids) || ids.length !== 2) {
      return { ok: false, error: 'project_ids deve conter exatamente 2 IDs.' };
    }

    const [idA, idB] = ids;
    if (!isValidUuid(idA) || !isValidUuid(idB)) {
      return { ok: false, error: 'project_ids inválidos — apenas UUIDs reais são aceitos.' };
    }

    // Verifica que ambos pertencem ao usuário autenticado
    if (!ctx.allProjectIds.has(idA) || !ctx.allProjectIds.has(idB)) {
      return { ok: false, error: 'Um ou ambos os projetos não foram encontrados ou não pertencem ao usuário.' };
    }

    // Carrega dados dos dois projetos em paralelo
    const [resA, resB, oppsA, oppsB, actsA, actsB, roiA, roiB] = await Promise.all([
      client.from('projects').select('id,name,description,type,status,priority_score,opportunity_score,revenue_potential,time_to_revenue_days').eq('id', idA).eq('user_id', ctx.uid).maybeSingle(),
      client.from('projects').select('id,name,description,type,status,priority_score,opportunity_score,revenue_potential,time_to_revenue_days').eq('id', idB).eq('user_id', ctx.uid).maybeSingle(),
      client.from('opportunity_lab').select('id,project_id,final_score,market_score,revenue_score,strategic_fit,status,created_at').eq('project_id', idA).eq('user_id', ctx.uid).limit(25),
      client.from('opportunity_lab').select('id,project_id,final_score,market_score,revenue_score,strategic_fit,status,created_at').eq('project_id', idB).eq('user_id', ctx.uid).limit(25),
      client.from('action_queue').select('id,project_id,status,priority,created_at').eq('project_id', idA).eq('user_id', ctx.uid).limit(25),
      client.from('action_queue').select('id,project_id,status,priority,created_at').eq('project_id', idB).eq('user_id', ctx.uid).limit(25),
      client.from('roi_metrics').select('id,metric_value').eq('project_id', idA).eq('user_id', ctx.uid),
      client.from('roi_metrics').select('id,metric_value').eq('project_id', idB).eq('user_id', ctx.uid),
    ]);

    const projA = resA.data as DbProject | null;
    const projB = resB.data as DbProject | null;
    if (!projA || !projB) return { ok: false, error: 'Um ou ambos os projetos não foram encontrados.' };

    const scoreA = computeEcosystemScores(projA, (oppsA.data ?? []) as DbOpportunity[], (actsA.data ?? []) as DbAction[], (roiA.data ?? []) as DbRoiMetric[]);
    const scoreB = computeEcosystemScores(projB, (oppsB.data ?? []) as DbOpportunity[], (actsB.data ?? []) as DbAction[], (roiB.data ?? []) as DbRoiMetric[]);

    const comparison = compareScores(scoreA, scoreB, projA, projB);

    return {
      ok:      true,
      data:    comparison,
      summary: `Comparação "${projA.name}" vs "${projB.name}": vencedor geral = ${comparison.overall_winner as string}`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. score.get
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'score_get',
  publicName:  'score.get',
  description: 'Retorna os scores de ecossistema do projeto ativo. Usa a mesma fórmula do EcosystemIntelligenceService (fonte canônica) para garantir valores idênticos à UI.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      project_id: { type: 'string', description: 'ID do projeto. Se omitido, usa o projeto ativo.' },
    },
    required: [],
  },
  execute: async (args, ctx) => {
    const client   = ctx.supabase as SupabaseClient;
    const targetId = (isValidUuid(args.project_id) && ctx.allProjectIds.has(args.project_id as string))
      ? args.project_id as string
      : ctx.projectId;

    const [projRes, oppsRes, actsRes, roiRes] = await Promise.all([
      client.from('projects').select('id,name,priority_score,revenue_potential,time_to_revenue_days,opportunity_score').eq('id', targetId).eq('user_id', ctx.uid).maybeSingle(),
      client.from('opportunity_lab').select('id,project_id,final_score,market_score,revenue_score,strategic_fit,status,created_at').eq('project_id', targetId).eq('user_id', ctx.uid).limit(50),
      client.from('action_queue').select('id,project_id,status,created_at').eq('project_id', targetId).eq('user_id', ctx.uid).limit(50),
      client.from('roi_metrics').select('id,metric_value').eq('project_id', targetId).eq('user_id', ctx.uid),
    ]);

    if (!projRes.data) return { ok: false, error: 'Projeto não encontrado.' };

    const scores = computeEcosystemScores(
      projRes.data as DbProject,
      ((oppsRes.data ?? []) as DbOpportunity[]).filter(o => o.project_id === targetId),
      ((actsRes.data ?? []) as DbAction[]).filter(a => a.project_id === targetId),
      (roiRes.data ?? []) as DbRoiMetric[],
    );

    return {
      ok: true,
      data: {
        project_id:        targetId,
        ecosystem_score:   scores.ecosystemScore,
        opportunity_score: scores.opportunityScore,
        market_score:      scores.marketScore,
        strategic_fit:     scores.strategicFit,
        synergy_score:     scores.synergyScore,
        roi_score:         scores.hasRoiData ? scores.roiScore : null,
        has_roi_data:      scores.hasRoiData,
        momentum_score:    scores.momentumScore,
        execution_score:   scores.executionScore,
        has_enough_data:   scores.hasEnoughData,
        recommendation:    scores.recommendation,
        note:              'Scores calculados pela mesma fórmula do EcosystemIntelligenceService.',
      },
      summary: `Scores de "${(projRes.data as DbProject).name}": ecosystem=${scores.ecosystemScore}/100, recomendação=${scores.recommendation}`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 6. score.explain
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'score_explain',
  publicName:  'score.explain',
  description: 'Explica em detalhe como cada score foi calculado: valor, status, fatores, dados ausentes e confiança.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      project_id: { type: 'string', description: 'ID do projeto.' },
      score_name: {
        type:        'string',
        enum:        ['ecosystem', 'opportunity', 'market', 'strategic_fit', 'synergy', 'roi', 'momentum', 'execution', 'all'],
        description: 'Qual score explicar. Use "all" para todos.',
      },
    },
    required: ['score_name'],
  },
  execute: async (args, ctx) => {
    const client   = ctx.supabase as SupabaseClient;
    const targetId = (isValidUuid(args.project_id) && ctx.allProjectIds.has(args.project_id as string))
      ? args.project_id as string
      : ctx.projectId;

    const [projRes, oppsRes, actsRes, roiRes] = await Promise.all([
      client.from('projects').select('id,name,priority_score,revenue_potential,time_to_revenue_days,opportunity_score').eq('id', targetId).eq('user_id', ctx.uid).maybeSingle(),
      client.from('opportunity_lab').select('id,project_id,final_score,market_score,revenue_score,strategic_fit,status,created_at').eq('project_id', targetId).eq('user_id', ctx.uid).limit(50),
      client.from('action_queue').select('id,project_id,status,created_at').eq('project_id', targetId).eq('user_id', ctx.uid).limit(50),
      client.from('roi_metrics').select('id,metric_name,metric_value').eq('project_id', targetId).eq('user_id', ctx.uid),
    ]);

    if (!projRes.data) return { ok: false, error: 'Projeto não encontrado.' };

    const project = projRes.data as DbProject;
    const opps    = ((oppsRes.data ?? []) as DbOpportunity[]).filter(o => o.project_id === targetId);
    const acts    = ((actsRes.data ?? []) as DbAction[]).filter(a => a.project_id === targetId);
    const roi     = (roiRes.data ?? []) as DbRoiMetric[];
    const scores  = computeEcosystemScores(project, opps, acts, roi);

    const scoreMap: Record<string, { value: number | null; factor: string; status: string }> = {
      ecosystem:     { value: scores.ecosystemScore,   factor: scores.scoreFactors.ecosystem,    status: scoreStatus(scores.ecosystemScore,   scores.hasEnoughData, !scores.hasEnoughData) },
      opportunity:   { value: scores.opportunityScore, factor: scores.scoreFactors.opportunity,  status: scoreStatus(scores.opportunityScore, true, false) },
      market:        { value: scores.marketScore,      factor: scores.scoreFactors.market,       status: scoreStatus(scores.marketScore,      opps.length > 0, false) },
      strategic_fit: { value: scores.strategicFit,     factor: scores.scoreFactors.strategicFit, status: 'available' },
      synergy:       { value: scores.synergyScore,     factor: scores.scoreFactors.synergy,      status: 'available' },
      roi:           { value: scores.hasRoiData ? scores.roiScore : null, factor: scores.scoreFactors.roi, status: scores.hasRoiData ? 'available' : 'insufficient_data' },
      momentum:      { value: scores.momentumScore,    factor: scores.scoreFactors.momentum,     status: 'available' },
      execution:     { value: scores.executionScore,   factor: scores.scoreFactors.execution,    status: acts.length > 0 || opps.length > 0 ? 'available' : 'insufficient_data' },
    };

    const requestedScore = args.score_name as string;
    const result = requestedScore === 'all'
      ? { scores: scoreMap, project_name: project.name, formula: 'ecosystem = opp×0.25 + fit×0.25 + syn×0.20 + roi×0.20 + mom×0.10' }
      : { score: scoreMap[requestedScore], project_name: project.name };

    return {
      ok:      true,
      data:    result,
      summary: `Explicação do score ${requestedScore} para "${project.name}".`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 7. action.list
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'action_list',
  publicName:  'action.list',
  description: 'Lista ações do projeto ativo. Filtro opcional por status.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      status: { type: 'string', enum: ['pending', 'in_progress', 'completed', 'cancelled', 'all'] },
      limit:  { type: 'integer', minimum: 1, maximum: 25, default: 10 },
    },
    required: [],
  },
  execute: async (args, ctx) => {
    const client = ctx.supabase as SupabaseClient;
    const status = args.status as string | undefined;
    const limit  = Math.min(25, Math.max(1, (args.limit as number | undefined) ?? 10));

    let query = client
      .from('action_queue')
      .select('id,project_id,title,description,status,priority,impact_score,effort_score,roi_score,market_score,origin,rationale,created_at')
      .eq('project_id', ctx.projectId)
      .eq('user_id', ctx.uid)
      .order('priority', { ascending: false })
      .limit(limit);

    if (status && status !== 'all') {
      query = query.eq('status', status);
    }

    const { data, error } = await query;
    if (error) return { ok: false, error: 'Erro ao carregar ações.' };

    const actions = ((data ?? []) as DbAction[]).filter(a => a.project_id === ctx.projectId);
    return {
      ok:   true,
      data: { actions, total: actions.length },
      summary: `${actions.length} ação(ões) encontrada(s)${status && status !== 'all' ? ` com status=${status}` : ''}.`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 8. action.create (PROPOSE ONLY — requer confirmação do usuário no Flutter)
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'action_create',
  publicName:  'action.create',
  description: 'Propõe a criação de uma ação. A ação NÃO é criada automaticamente — o usuário deve confirmar explicitamente no app. Use apenas quando o usuário claramente pediu para criar uma ação.',
  permission:  'propose',
  requiresUserConfirmation: true,
  parameters: {
    type:       'object',
    properties: {
      title:          { type: 'string',  maxLength: 200, description: 'Título conciso da ação.' },
      description:    { type: 'string',  maxLength: 1000 },
      priority:       { type: 'string',  enum: ['low', 'medium', 'high', 'critical'] },
      impact:         { type: 'string',  enum: ['low', 'medium', 'high'] },
      effort:         { type: 'string',  enum: ['low', 'medium', 'high'] },
      due_date:       { type: 'string',  description: 'ISO 8601 date.' },
      rationale:      { type: 'string',  maxLength: 500 },
      evidence_ids:   { type: 'array',   items: { type: 'string' } },
      opportunity_id: { type: 'string' },
    },
    required: ['title', 'priority', 'impact', 'effort'],
  },
  execute: async (args, ctx) => {
    // Valida campos obrigatórios
    const title = (args.title as string ?? '').trim();
    if (!title || title.length > 200) return { ok: false, error: 'Título inválido (1-200 chars).' };

    const PRIORITIES = ['low', 'medium', 'high', 'critical'];
    const LEVELS     = ['low', 'medium', 'high'];
    if (!PRIORITIES.includes(args.priority as string)) return { ok: false, error: 'priority inválida.' };
    if (!LEVELS.includes(args.impact as string))        return { ok: false, error: 'impact inválido.' };
    if (!LEVELS.includes(args.effort as string))        return { ok: false, error: 'effort inválido.' };

    // Valida evidence_ids — apenas IDs reais do contexto são aceitos
    const rawEvidenceIds = Array.isArray(args.evidence_ids) ? args.evidence_ids as string[] : [];
    const evidence_ids   = rawEvidenceIds.filter(id => ctx.evidenceIds.has(id));

    // Valida opportunity_id (opcional)
    const rawOppId     = args.opportunity_id as string | undefined;
    const opportunity_id = (rawOppId && ctx.evidenceIds.has(rawOppId)) ? rawOppId : undefined;

    // IMPORTANTE: project_id SEMPRE do contexto verificado — nunca do LLM
    return {
      ok: true,
      data: {
        tool_name:      'action.create',
        project_id:     ctx.projectId,   // ← sempre do servidor
        title,
        description:    (args.description as string ?? '').trim().slice(0, 1000) || undefined,
        priority:       args.priority as string,
        impact:         args.impact   as string,
        effort:         args.effort   as string,
        due_date:       args.due_date as string | undefined,
        rationale:      (args.rationale as string ?? '').trim().slice(0, 500) || undefined,
        evidence_ids,
        opportunity_id,
        requires_confirmation: true,  // Flutter processa isso como IveActionProposal
      },
      summary: `Proposta de ação: "${title}" — aguardando confirmação do usuário.`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 9. opportunity.list
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'opportunity_list',
  publicName:  'opportunity.list',
  description: 'Lista oportunidades avaliadas do projeto ativo, ordenadas por final_score.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      status: { type: 'string', enum: ['pending', 'approved', 'rejected', 'all'] },
      limit:  { type: 'integer', minimum: 1, maximum: 25, default: 10 },
    },
    required: [],
  },
  execute: async (args, ctx) => {
    const client = ctx.supabase as SupabaseClient;
    const status = args.status as string | undefined;
    const limit  = Math.min(25, Math.max(1, (args.limit as number | undefined) ?? 10));

    let query = client
      .from('opportunity_lab')
      .select('id,project_id,title,description,status,opportunity_type,final_score,market_score,revenue_score,competition_score,synergy_score,strategic_fit,confidence,rationale,origin,created_at')
      .eq('project_id', ctx.projectId)
      .eq('user_id', ctx.uid)
      .order('final_score', { ascending: false })
      .limit(limit);

    if (status && status !== 'all') {
      query = query.eq('status', status);
    }

    const { data, error } = await query;
    if (error) return { ok: false, error: 'Erro ao carregar oportunidades.' };

    const opps = ((data ?? []) as DbOpportunity[]).filter(o => o.project_id === ctx.projectId);
    return {
      ok:   true,
      data: { opportunities: opps, total: opps.length },
      summary: `${opps.length} oportunidade(s) encontrada(s).`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 10. kb.search
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'kb_search',
  publicName:  'kb.search',
  description: 'Busca itens na Knowledge Base do projeto ativo. Retorna apenas metadados — conteúdo integral dos documentos não está disponível.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      query: { type: 'string', maxLength: 200, description: 'Termo de busca por título ou niche.' },
      limit: { type: 'integer', minimum: 1, maximum: 10, default: 5 },
    },
    required: [],
  },
  execute: async (args, ctx) => {
    const client = ctx.supabase as SupabaseClient;
    const query  = (args.query as string ?? '').trim().toLowerCase();
    const limit  = Math.min(10, Math.max(1, (args.limit as number | undefined) ?? 5));

    const { data, error } = await client
      .from('knowledge_items')
      .select('id,project_id,title,status,niche,created_at')
      .eq('project_id', ctx.projectId)
      .eq('user_id', ctx.uid)
      .order('created_at', { ascending: false })
      .limit(50);  // carrega mais para filtrar em memória

    if (error) return { ok: false, error: 'Erro ao buscar knowledge base.' };

    let items = ((data ?? []) as DbKbItem[]).filter(k => k.project_id === ctx.projectId);
    if (query) {
      items = items.filter(k =>
        k.title?.toLowerCase().includes(query) ||
        k.niche?.toLowerCase().includes(query),
      );
    }
    items = items.slice(0, limit);

    return {
      ok: true,
      data: {
        items: items.map(k => ({ id: k.id, title: k.title, status: k.status, niche: k.niche })),
        total: items.length,
        limitation: 'Apenas metadados retornados. Conteúdo integral dos documentos não está disponível neste contexto.',
      },
      summary: `${items.length} item(ns) de knowledge${query ? ` para "${query}"` : ''}.`,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// 11. asset.list
// ─────────────────────────────────────────────────────────────────────────────

register({
  name:        'asset_list',
  publicName:  'asset.list',
  description: 'Lista assets do projeto ativo com resumo estruturado (tipo, status, score). Respeita RLS e ownership.',
  permission:  'read',
  requiresUserConfirmation: false,
  parameters: {
    type:       'object',
    properties: {
      limit: { type: 'integer', minimum: 1, maximum: 25, default: 10 },
    },
    required: [],
  },
  execute: async (args, ctx) => {
    const client = ctx.supabase as SupabaseClient;
    const limit  = Math.min(25, Math.max(1, (args.limit as number | undefined) ?? 10));

    const { data, error } = await client
      .from('assets')
      .select('id,project_id,title,type,status,score,created_at')
      .eq('project_id', ctx.projectId)
      .eq('user_id', ctx.uid)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) return { ok: false, error: 'Erro ao carregar assets.' };

    const assets = ((data ?? []) as DbAsset[]).filter(a => a.project_id === ctx.projectId);
    return {
      ok:   true,
      data: { assets, summary: summarizeAssets(assets), total: assets.length },
      summary: `${assets.length} asset(s) encontrado(s).`,
    };
  },
});

// ── Public API ─────────────────────────────────────────────────────────────────

/**
 * Retorna as definições de tool no formato OpenAI/Groq para o agent loop.
 */
export function getToolDefinitions(): AIToolDefinition[] {
  return Array.from(TOOLS.values()).map(t => ({
    type: 'function' as const,
    function: {
      name:        t.name,
      description: t.description,
      parameters:  t.parameters,
    },
  }));
}

/**
 * Executa um tool pelo nome (formato underscore).
 * Valida permissões antes de executar.
 * NUNCA usa user_id ou project_id vindo do LLM — apenas do ToolExecutionContext.
 */
export async function executeTool(
  toolName: string,
  rawArgs:  string,
  ctx:      ToolExecutionContext,
): Promise<ToolResult> {
  const tool = TOOLS.get(toolName);
  if (!tool) {
    return { ok: false, error: `Ferramenta "${toolName}" não encontrada no registry.` };
  }

  // Valida permissão
  if (tool.permission === 'execute') {
    return { ok: false, error: `Ferramenta "${toolName}" requer EXECUTE — não disponível no agent loop. Requer confirmação explícita do usuário.` };
  }

  // Parse dos argumentos do LLM
  let args: Record<string, unknown>;
  try {
    args = JSON.parse(rawArgs) as Record<string, unknown>;
  } catch {
    return { ok: false, error: 'Argumentos da ferramenta não são JSON válido.' };
  }

  // Executa
  try {
    return await tool.execute(args, ctx);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Erro desconhecido';
    return { ok: false, error: `Erro ao executar "${toolName}": ${message}` };
  }
}

/** Retorna a lista de todos os tool names registrados. */
export function getRegisteredToolNames(): string[] {
  return Array.from(TOOLS.keys());
}

/** Verifica se um tool name existe e qual a sua permissão. */
export function getToolPermission(toolName: string): PermissionLevel | null {
  return TOOLS.get(toolName)?.permission ?? null;
}
