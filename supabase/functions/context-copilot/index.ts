/**
 * context-copilot — Edge Function v2
 *
 * Mudanças da v1:
 *  - Autenticação JWT obrigatória (sem token = 401)
 *  - Contexto de negócio carregado server-side (não confiamos no cliente)
 *  - Validação de project_id: pertence ao usuário autenticado
 *  - action.create é a única ferramenta permitida (schema fechado)
 *  - evidence_ids validados contra dados reais recuperados
 *  - Confidence calculada pelo sistema (não pelo modelo)
 *  - Resposta estruturada com response_id e correlation_id
 *  - Erros não expõem internals
 *  - Secrets e tokens nunca aparecem nos logs
 *  - Limite de payload, mensagem e histórico
 *
 * Compatibilidade com context_copilot_provider.dart:
 *  O provider espera: answer, sources, confidence, entities,
 *  action_suggestion, timestamp. Todos presentes na resposta.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { buildOpportunityContextSection } from './context_prompt.ts';

// ── Constants ─────────────────────────────────────────────────────────────────

const GROQ_URL        = 'https://api.groq.com/openai/v1/chat/completions';
const GROQ_MODEL      = 'llama-3.3-70b-versatile';
const PROMPT_VERSION  = '2.0.0';

const MAX_PAYLOAD_BYTES      = 64_000;   // 64 KB
const MAX_MESSAGE_CHARS      = 2_000;
const MAX_HISTORY_ITEMS      = 10;
const MAX_HISTORY_MSG_CHARS  = 800;
const MAX_CONTEXT_ITEMS      = 10;       // por entidade (opps, actions, kb)
const GROQ_TIMEOUT_MS        = 25_000;   // 25 s (Supabase limit = 60 s)
const GROQ_MAX_TOKENS        = 900;

// Prioridades e tipos válidos para action.create
const VALID_PRIORITIES = ['low', 'medium', 'high', 'critical'];
const VALID_IMPACTS    = ['low', 'medium', 'high'];
const VALID_EFFORTS    = ['low', 'medium', 'high'];

// ── CORS ──────────────────────────────────────────────────────────────────────

const CORS_HEADERS = {
  // Supabase Flutter SDK envia de app mobile/web — sem Origin fixo em mobile.
  // Edge Functions do Supabase são acessadas via proxy autenticado; o token JWT
  // é a barreira real. CORS é camada adicional para acesso web.
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function errorResponse(code: string, message: string, status: number, correlationId?: string): Response {
  return jsonResponse({ error: { code, message, correlation_id: correlationId ?? null } }, status);
}

// ── ID generator (no Date.now / Math.random — use crypto) ────────────────────

function newId(): string {
  return crypto.randomUUID();
}

// ── Request schema ────────────────────────────────────────────────────────────

interface RequestBody {
  message:              string;
  screen_name?:         string;
  route?:               string;
  project_id?:          string;
  selected_entity_type?: string;
  selected_entity_id?:  string;
  context_version?:     string;
  context?:             Record<string, unknown>;   // client hints only
  history?:             Array<{ role: string; content: string }>;
  recent_questions?:    string[];
  client_correlation_id?: string;
}

function validateRequest(body: unknown): { data: RequestBody } | { error: string } {
  if (!body || typeof body !== 'object') return { error: 'payload inválido' };
  const b = body as Record<string, unknown>;

  if (typeof b.message !== 'string' || b.message.trim().length === 0)
    return { error: 'message é obrigatório e não pode ser vazio' };
  if (b.message.length > MAX_MESSAGE_CHARS)
    return { error: `message excede ${MAX_MESSAGE_CHARS} caracteres` };

  if (b.project_id !== undefined && typeof b.project_id !== 'string')
    return { error: 'project_id deve ser string' };

  // Valida UUID simples se presente
  if (b.project_id && !/^[0-9a-f-]{36}$/i.test(b.project_id as string))
    return { error: 'project_id formato inválido' };

  return { data: b as RequestBody };
}

// ── Server-side context loader ────────────────────────────────────────────────

interface ServerContext {
  project:      Record<string, unknown> | null;
  opportunities: Record<string, unknown>[];
  actions:       Record<string, unknown>[];
  kb_items:      Record<string, unknown>[];
  evidence_ids:  Set<string>;
  limitations:   string[];
}

async function loadServerContext(
  client: SupabaseClient,
  uid: string,
  projectId: string | undefined,
): Promise<ServerContext> {
  const ctx: ServerContext = {
    project:       null,
    opportunities: [],
    actions:       [],
    kb_items:      [],
    evidence_ids:  new Set(),
    limitations:   [],
  };

  // ── Projeto ───────────────────────────────────────────────────────────────
  if (projectId) {
    const { data: proj, error: projErr } = await client
      .from('projects')
      .select('id,name,description,type,status,opportunity_score,revenue_potential,priority_score')
      .eq('id', projectId)
      .eq('user_id', uid)   // ownership validation
      .maybeSingle();

    if (projErr) ctx.limitations.push('projeto indisponível');
    else if (!proj) ctx.limitations.push('projeto não encontrado ou não autorizado');
    else {
      ctx.project = proj as Record<string, unknown>;
      ctx.evidence_ids.add(proj.id as string);
    }
  }

  // ── Oportunidades ────────────────────────────────────────────────────────
  const oppQuery = client
    .from('opportunity_lab')
    .select('id,project_id,title,description,status,opportunity_type,final_score,market_score,revenue_score,competition_score,synergy_score,strategic_fit,origin,rationale,confidence,risks,action_steps,created_at')
    .eq('user_id', uid)
    .order('final_score', { ascending: false })
    .limit(MAX_CONTEXT_ITEMS);

  if (projectId && ctx.project) oppQuery.eq('project_id', projectId);

  const { data: opps, error: oppsErr } = await oppQuery;
  if (oppsErr) ctx.limitations.push('oportunidades indisponíveis');
  else {
    ctx.opportunities = (opps ?? []) as Record<string, unknown>[];
    ctx.opportunities.forEach(o => ctx.evidence_ids.add(o.id as string));
  }

  // ── Ações ────────────────────────────────────────────────────────────────
  const actQuery = client
    .from('action_queue')
    .select('id,project_id,opportunity_lab_id,title,description,status,priority,impact_score,effort_score,roi_score,market_score,confidence,origin,rationale,plan,risks,created_at')
    .eq('user_id', uid)
    .order('priority', { ascending: false })
    .limit(MAX_CONTEXT_ITEMS);

  if (projectId && ctx.project) actQuery.eq('project_id', projectId);

  const { data: acts, error: actsErr } = await actQuery;
  if (actsErr) ctx.limitations.push('ações indisponíveis');
  else {
    ctx.actions = (acts ?? []) as Record<string, unknown>[];
    ctx.actions.forEach(a => ctx.evidence_ids.add(a.id as string));
  }

  // ── Knowledge Base ───────────────────────────────────────────────────────
  const kbQuery = client
    .from('knowledge_items')
    .select('id,title,content,created_at')
    .eq('user_id', uid)
    .order('created_at', { ascending: false })
    .limit(MAX_CONTEXT_ITEMS);

  if (projectId && ctx.project) kbQuery.eq('project_id', projectId);

  const { data: kb, error: kbErr } = await kbQuery;
  if (kbErr) ctx.limitations.push('base de conhecimento indisponível');
  else {
    ctx.kb_items = (kb ?? []) as Record<string, unknown>[];
    ctx.kb_items.forEach(k => ctx.evidence_ids.add(k.id as string));
  }

  return ctx;
}

// ── System confidence (server-computed, not model-invented) ──────────────────

function computeConfidence(ctx: ServerContext, clientCtxHints: Record<string, unknown>): number {
  let score = 30; // base

  if (ctx.project)               score += 20; // projeto validado
  if (ctx.opportunities.length)  score += 15; // oportunidades reais
  if (ctx.actions.length)        score += 15; // ações reais
  if (ctx.kb_items.length)       score += 10; // base de conhecimento
  if (clientCtxHints.scores)     score += 10; // scores do ecossistema (client hint)
  if (ctx.limitations.length === 0) score += 5; // sem limitações

  // Nunca ultrapassa 95 (nunca 100% — há sempre incerteza em IA)
  return Math.min(score, 95);
}

// ── Validate action proposal ─────────────────────────────────────────────────

interface ActionProposal {
  tool_name:      string;
  project_id:     string;
  title:          string;
  description?:   string;
  priority?:      string;
  impact?:        string;
  effort?:        string;
  due_date?:      string;
  rationale?:     string;
  evidence_ids?:  string[];
  opportunity_id?: string;
}

function validateActionProposal(
  raw: unknown,
  validatedProjectId: string | undefined,
  validEvidenceIds: Set<string>,
): ActionProposal | null {
  if (!raw || typeof raw !== 'object') return null;
  const a = raw as Record<string, unknown>;

  // Apenas action.create é permitida nesta sprint
  if (a.tool_name !== 'action.create') return null;

  // title obrigatório
  if (typeof a.title !== 'string' || a.title.trim().length === 0) return null;
  if (a.title.length > 200) return null;

  // description
  if (a.description !== undefined && (typeof a.description !== 'string' || a.description.length > 1000))
    return null;

  // project_id: usa o validado no servidor, nunca o do cliente
  const projectId = validatedProjectId ?? (a.project_id as string | undefined);

  // Enums
  const priority = typeof a.priority === 'string' && VALID_PRIORITIES.includes(a.priority)
    ? a.priority : 'medium';
  const impact = typeof a.impact === 'string' && VALID_IMPACTS.includes(a.impact)
    ? a.impact : 'medium';
  const effort = typeof a.effort === 'string' && VALID_EFFORTS.includes(a.effort)
    ? a.effort : 'medium';

  // evidence_ids: apenas IDs que existem de verdade
  const rawIds = Array.isArray(a.evidence_ids) ? a.evidence_ids as unknown[] : [];
  const evidence_ids = rawIds
    .filter((id): id is string => typeof id === 'string' && validEvidenceIds.has(id));

  return {
    tool_name:      'action.create',
    project_id:     projectId ?? '',
    title:          a.title as string,
    description:    a.description as string | undefined,
    priority,
    impact,
    effort,
    due_date:       typeof a.due_date === 'string' ? a.due_date : undefined,
    rationale:      typeof a.rationale === 'string' ? a.rationale.slice(0, 500) : undefined,
    evidence_ids,
    opportunity_id: typeof a.opportunity_id === 'string' ? a.opportunity_id : undefined,
  };
}

// ── Build system prompt with trusted context ──────────────────────────────────

function buildSystemPrompt(
  serverCtx: ServerContext,
  clientHints: Record<string, unknown>,
  screenName: string,
): string {
  const lines: string[] = [`TELA ATUAL: ${screenName}`];

  if (serverCtx.project) {
    const p = serverCtx.project;
    lines.push(`\n## PROJETO ATIVO (validado pelo servidor)\nNome: ${p.name}\nDescrição: ${p.description || '—'}\nTipo: ${p.type || '—'}\nStatus: ${p.status || '—'}\nScore de Oportunidade: ${p.opportunity_score || 0}/100\nPotencial de Receita: R$${p.revenue_potential || 0}`);
  }

  const opportunitySection = buildOpportunityContextSection(
    serverCtx.opportunities,
    serverCtx.project !== null,
  );
  if (opportunitySection) lines.push(`\n${opportunitySection}`);

  if (serverCtx.actions.length) {
    const acts = serverCtx.actions
      .slice(0, 5)
      .map(a => `• [${a.id}] ${a.title} [status=${a.status}, prioridade=${a.priority}, impacto=${a.impact_score}, esforço=${a.effort_score}, ROI=${a.roi_score}]`)
      .join('\n');
    lines.push(`\n## AÇÕES DO PROJETO (${serverCtx.actions.length} total, fonte: servidor)\n${acts}`);
  }

  if (serverCtx.kb_items.length) {
    const kb = serverCtx.kb_items
      .slice(0, 3)
      .map(k => `• [${k.id}] ${k.title}`)
      .join('\n');
    lines.push(`\n## BASE DE CONHECIMENTO (${serverCtx.kb_items.length} itens, fonte: servidor)\n${kb}`);
  }

  // Scores e mercado vêm dos hints do cliente (não temos tabela própria de scores calculados)
  const hints = clientHints;
  if (hints.scores) {
    const s = hints.scores as Record<string, unknown>;
    lines.push(`\n## SCORES DO ECOSSISTEMA (hint do cliente)\nEcosystem Score: ${s.ecosystem}/100\nExecution Score: ${s.execution}/100\nOportunidade: ${s.opportunity}/100\nMercado: ${s.market}/100\nFit estratégico: ${s.strategic_fit}/100\nSinergia: ${s.synergy}/100\nROI Score: ${s.roi}/100\nMomentum: ${s.momentum}/100`);
  }
  if (hints.market) {
    const m = hints.market as Record<string, unknown>;
    lines.push(`\n## MERCADO (hint do cliente)\nNicho: ${m.niche || '—'}\nCompetição: ${m.competition || '—'}`);
  }

  if (serverCtx.limitations.length) {
    lines.push(`\n## LIMITAÇÕES DE CONTEXTO\n${serverCtx.limitations.map(l => `• ${l}`).join('\n')}`);
  }

  const contextBlock = lines.join('\n');

  return `Você é o AI Social Copilot, assistente estratégico integrado à plataforma de gestão de projetos digitais.

Seu papel é analisar os dados do contexto atual e responder às perguntas do usuário com precisão, clareza e ação.

Quando houver oportunidades, compare apenas as oportunidades listadas para o projeto ativo. Para recomendar a melhor, informe nome, score final, critérios determinantes, risco e próxima ação. Nunca use dados de outro projeto nem invente oportunidades.

${contextBlock}

## SUAS CAPACIDADES

EXPLICAR: Explique por que, como, origem e evidências de qualquer score, recomendação ou dado.
SIMULAR: Simule cenários e impacto com base nos dados reais do contexto.
RECOMENDAR: Sugira próximas ações, prioridades e identifique riscos com base nos dados.

## REGRAS OBRIGATÓRIAS

1. Baseie TODA resposta nos dados do contexto acima — nunca invente dados.
2. Seja direto e objetivo — máximo 4 parágrafos curtos.
3. Use dados numéricos do contexto sempre que possível.
4. Quando citar oportunidades ou ações, use os IDs exatos fornecidos (ex: [abc-123]).
5. Ao final da resposta, inclua EXATAMENTE este bloco JSON e nada mais após ele:

\`\`\`json
{
  "sources": ["lista das fontes usadas — use apenas: Projeto, Oportunidades, Ações, Base de Conhecimento, Scores, Mercado"],
  "entities": ["nomes de projetos/oportunidades/ações mencionados"],
  "action_proposal": null
}
\`\`\`

Se e SOMENTE SE for muito claro que o usuário quer criar uma ação, substitua action_proposal por:
\`\`\`json
{
  "action_proposal": {
    "tool_name": "action.create",
    "title": "título conciso (máx 100 chars)",
    "description": "descrição da ação",
    "priority": "medium",
    "impact": "medium",
    "effort": "medium",
    "rationale": "por que esta ação é recomendada",
    "evidence_ids": ["use apenas IDs reais do contexto acima"],
    "opportunity_id": null
  }
}
\`\`\`

Valores válidos para priority/impact/effort: low, medium, high, critical (só priority).
NÃO invente evidence_ids — use apenas os IDs [uuid] mostrados no contexto.
NÃO proponha outras ferramentas além de action.create.

Responda sempre em Português do Brasil.`;
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  const correlationId = newId();

  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return errorResponse('METHOD_NOT_ALLOWED', 'apenas POST', 405, correlationId);
  }

  // ── 1. Payload size guard ──────────────────────────────────────────────────
  const contentLength = parseInt(req.headers.get('content-length') ?? '0', 10);
  if (contentLength > MAX_PAYLOAD_BYTES) {
    return errorResponse('PAYLOAD_TOO_LARGE', 'payload excede limite', 413, correlationId);
  }

  // ── 2. Autenticação JWT ────────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return errorResponse('UNAUTHORIZED', 'autenticação necessária', 401, correlationId);
  }

  const supabaseUrl  = Deno.env.get('SUPABASE_URL');
  const supabaseKey  = Deno.env.get('SUPABASE_ANON_KEY');
  const groqApiKey   = Deno.env.get('GROQ_API_KEY');

  if (!supabaseUrl || !supabaseKey) {
    // Nunca loga as chaves
    console.error(`[${correlationId}] configuração do servidor incompleta`);
    return errorResponse('SERVER_ERROR', 'erro de configuração do servidor', 500, correlationId);
  }

  if (!groqApiKey) {
    console.error(`[${correlationId}] GROQ_API_KEY não configurada`);
    return errorResponse('SERVER_ERROR', 'erro de configuração do servidor', 500, correlationId);
  }

  // Cliente autenticado com o JWT do usuário (RLS enforced)
  const client = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authHeader } },
    auth:   { persistSession: false },
  });

  const { data: { user }, error: authError } = await client.auth.getUser();
  if (authError || !user) {
    return errorResponse('UNAUTHORIZED', 'sessão inválida ou expirada', 401, correlationId);
  }

  const uid = user.id;
  console.log(`[${correlationId}] uid=${uid.slice(0, 8)}...`);

  // ── 3. Parse e validar body ────────────────────────────────────────────────
  let rawBody: unknown;
  try {
    rawBody = await req.json();
  } catch {
    return errorResponse('BAD_REQUEST', 'body não é JSON válido', 400, correlationId);
  }

  const validation = validateRequest(rawBody);
  if ('error' in validation) {
    return errorResponse('BAD_REQUEST', validation.error, 400, correlationId);
  }
  const body = validation.data;
  const clientCorrelationId = body.client_correlation_id ?? correlationId;

  // ── 4. Carregar contexto autorizado server-side ────────────────────────────
  const serverCtx = await loadServerContext(client, uid, body.project_id);

  // Se project_id foi enviado mas não validado, é 404 seguro
  if (body.project_id && !serverCtx.project) {
    console.log(`[${correlationId}] project_id não autorizado para uid=${uid.slice(0, 8)}`);
    return errorResponse('NOT_FOUND', 'projeto não encontrado', 404, correlationId);
  }

  // ── 5. Preparar histórico (sanitizado) ────────────────────────────────────
  const rawHistory = (body.history ?? [])
    .filter((h): h is { role: string; content: string } =>
      typeof h === 'object' && h !== null &&
      ['user', 'assistant'].includes((h as Record<string, unknown>).role as string) &&
      typeof (h as Record<string, unknown>).content === 'string',
    )
    .slice(-MAX_HISTORY_ITEMS)
    .map(h => ({
      role:    h.role,
      content: h.content.slice(0, MAX_HISTORY_MSG_CHARS),
    }));

  // ── 6. Calcular confidence server-side ────────────────────────────────────
  const clientHints = (body.context ?? {}) as Record<string, unknown>;
  const confidence  = computeConfidence(serverCtx, clientHints);

  // ── 7. Build system prompt com contexto validado ──────────────────────────
  const screenName   = body.screen_name ?? body.route ?? 'unknown';
  const systemPrompt = buildSystemPrompt(serverCtx, clientHints, screenName);

  // ── 8. Chamar Groq com timeout ────────────────────────────────────────────
  const abortController = new AbortController();
  const timeoutId = setTimeout(() => abortController.abort(), GROQ_TIMEOUT_MS);

  let rawContent: string;
  try {
    const groqRes = await fetch(GROQ_URL, {
      method:  'POST',
      signal:  abortController.signal,
      headers: {
        'Authorization': `Bearer ${groqApiKey}`,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify({
        model:           GROQ_MODEL,
        temperature:     0.35,
        max_tokens:      GROQ_MAX_TOKENS,
        response_format: { type: 'text' },
        messages: [
          { role: 'system', content: systemPrompt },
          ...rawHistory,
          { role: 'user', content: body.message },
        ],
      }),
    });

    clearTimeout(timeoutId);

    if (!groqRes.ok) {
      const errText = await groqRes.text().catch(() => '');
      // Nunca loga o errText completo (pode conter dados sensíveis do Groq)
      console.error(`[${correlationId}] groq status=${groqRes.status}`);
      return errorResponse('MODEL_ERROR', 'erro ao processar com modelo de IA', 502, correlationId);
    }

    const groqData = await groqRes.json();
    rawContent = groqData.choices?.[0]?.message?.content ?? '';

    if (!rawContent) {
      return errorResponse('MODEL_ERROR', 'resposta vazia do modelo', 502, correlationId);
    }
  } catch (err) {
    clearTimeout(timeoutId);
    const isTimeout = err instanceof Error && err.name === 'AbortError';
    console.error(`[${correlationId}] groq ${isTimeout ? 'timeout' : 'fetch error'}`);
    if (isTimeout) {
      return errorResponse('TIMEOUT', 'modelo não respondeu no tempo limite', 504, correlationId);
    }
    return errorResponse('MODEL_ERROR', 'erro de comunicação com modelo', 502, correlationId);
  }

  // ── 9. Parse metadata do modelo ───────────────────────────────────────────
  let modelSources: string[]  = [];
  let modelEntities: string[] = [];
  let rawActionProposal: unknown = null;
  let answerText = rawContent;

  const jsonMatch = rawContent.match(/```json\s*([\s\S]*?)```/);
  if (jsonMatch) {
    try {
      const meta = JSON.parse(jsonMatch[1]) as Record<string, unknown>;
      // Sources: apenas nomes de fontes permitidas, nunca IDs inventados
      const allowedSources = new Set(['Projeto', 'Oportunidades', 'Ações', 'Base de Conhecimento', 'Scores', 'Mercado', 'Histórico']);
      modelSources  = (meta.sources as unknown[])
        ?.filter((s): s is string => typeof s === 'string' && allowedSources.has(s)) ?? [];
      modelEntities = (meta.entities as unknown[])
        ?.filter((e): e is string => typeof e === 'string').slice(0, 20) ?? [];
      rawActionProposal = meta.action_proposal ?? null;
      answerText = rawContent.replace(/```json[\s\S]*?```/, '').trim();
    } catch {
      // Mantém padrões seguros; não propaga erro de parse
      answerText = rawContent;
    }
  }

  // ── 10. Validar proposta de ação ──────────────────────────────────────────
  const actionProposal = validateActionProposal(
    rawActionProposal,
    serverCtx.project ? (serverCtx.project.id as string) : undefined,
    serverCtx.evidence_ids,
  );

  // ── 11. Construir evidências estruturadas ─────────────────────────────────
  const evidence: Array<Record<string, unknown>> = [];

  if (serverCtx.project) {
    evidence.push({
      source_type: 'project',
      source_id:   serverCtx.project.id,
      title:       serverCtx.project.name,
      project_id:  serverCtx.project.id,
      timestamp:   null,
      relevance:   1.0,
    });
  }

  serverCtx.opportunities.slice(0, 3).forEach(o => {
    evidence.push({
      source_type:      'opportunity',
      source_id:        o.id,
      title:            o.title,
      structured_value: { status: o.status, score: o.final_score },
      project_id:       serverCtx.project?.id ?? null,
      timestamp:        o.created_at,
      relevance:        0.8,
    });
  });

  serverCtx.actions.slice(0, 3).forEach(a => {
    evidence.push({
      source_type:      'action',
      source_id:        a.id,
      title:            a.title,
      structured_value: { status: a.status, priority: a.priority },
      project_id:       serverCtx.project?.id ?? null,
      timestamp:        a.created_at,
      relevance:        0.7,
    });
  });

  // ── 12. Mapear para formato backward-compatible com o provider ────────────
  // O context_copilot_provider.dart espera: answer, sources, confidence,
  // entities, action_suggestion, timestamp

  // Mapeia action.create → create_action (formato legado do provider)
  let actionSuggestion: Record<string, unknown> | null = null;
  if (actionProposal) {
    actionSuggestion = {
      type:  'create_action',
      label: `Criar ação: ${actionProposal.title}`,
      data:  {
        title:          actionProposal.title,
        description:    actionProposal.description,
        action_type:    'tarefa',
        priority:       actionProposal.priority === 'high' || actionProposal.priority === 'critical' ? 80 : 50,
        project_id:     actionProposal.project_id,
        rationale:      actionProposal.rationale,
        evidence_ids:   actionProposal.evidence_ids,
        opportunity_id: actionProposal.opportunity_id,
        // campos do schema fechado
        _tool:          'action.create',
        _impact:        actionProposal.impact,
        _effort:        actionProposal.effort,
        _due_date:      actionProposal.due_date,
      },
    };
  }

  const responseId  = newId();
  const serverTs    = new Date().toISOString();

  console.log(`[${correlationId}] ok uid=${uid.slice(0, 8)} confidence=${confidence} sources=${modelSources.length} action=${!!actionProposal}`);

  return jsonResponse({
    // ── Campos backward-compatible (esperados pelo provider) ──
    answer:            answerText || '—',
    sources:           modelSources,
    confidence,
    entities:          modelEntities,
    action_suggestion: actionSuggestion,
    timestamp:         serverTs,

    // ── Campos novos (para o Codex / IVE v2) ──────────────────
    response_id:        responseId,
    correlation_id:     clientCorrelationId,
    intent:             detectIntent(body.message),
    project_id:         serverCtx.project?.id ?? null,
    evidence,
    limitations:        serverCtx.limitations,
    proposed_action:    actionProposal,
    prompt_version:     PROMPT_VERSION,
    model:              GROQ_MODEL,
    server_timestamp:   serverTs,
  });
});

// ── Intent detection (heurístico simples, sem IA) ─────────────────────────────

function detectIntent(message: string): string {
  const m = message.toLowerCase();
  if (/criar|adicionar|incluir|nova ação|novo item/.test(m)) return 'create';
  if (/explicar|por que|como|origem|motivo/.test(m))         return 'explain';
  if (/simular|se eu|e se|cenário/.test(m))                  return 'simulate';
  if (/prioridade|próximo passo|o que fazer|recomend/.test(m)) return 'recommend';
  return 'query';
}
