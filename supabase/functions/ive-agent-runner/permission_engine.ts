/**
 * ive-agent-runner — Permission Engine
 *
 * Implementa os níveis READ / PROPOSE / EXECUTE.
 * user_id: exclusivamente do JWT, nunca do payload do cliente.
 * project_id: sempre revalidado server-side via ownership check.
 *
 * Camadas de segurança:
 *   1. JWT auth (Supabase)
 *   2. Project ownership check (SELECT WHERE user_id = uid)
 *   3. RLS automático (auth.uid() = user_id em todas as tabelas)
 *   4. ENTITY_ISOLATION (filtragem pós-query por project_id)
 *   5. Tool allowlist (apenas tools registrados podem ser chamados)
 *   6. Write tools: PROPOSE apenas — EXECUTE requer confirmação do usuário no Flutter
 */

import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import type { DbProject, ServerContext, DbOpportunity, DbAction, DbKbItem } from './types.ts';

export { SupabaseClient };

// ── Erro de permissão ──────────────────────────────────────────────────────────

export class PermissionError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly httpStatus: number,
  ) {
    super(message);
    this.name = 'PermissionError';
  }
}

// ── Autenticação JWT ───────────────────────────────────────────────────────────

/**
 * Cria um SupabaseClient autenticado com o JWT do usuário.
 * O client respeita RLS automaticamente — auth.uid() = user_id em todas as queries.
 */
export function createAuthenticatedClient(authHeader: string): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY');

  if (!supabaseUrl || !supabaseKey) {
    throw new PermissionError('Configuração do servidor incompleta', 'SERVER_CONFIG_ERROR', 500);
  }

  return createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authHeader } },
    auth:   { persistSession: false },
  });
}

/**
 * Extrai e valida o uid do JWT.
 * Retorna o uid ou lança PermissionError(401).
 */
export async function getAuthenticatedUid(client: SupabaseClient): Promise<string> {
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user?.id) {
    throw new PermissionError('Sessão inválida ou expirada', 'UNAUTHORIZED', 401);
  }
  return user.id;
}

// ── Project Ownership ──────────────────────────────────────────────────────────

/**
 * Verifica que project_id pertence ao uid.
 * NUNCA confia em project_id vindo do payload do cliente ou do LLM.
 * Retorna o projeto ou lança PermissionError(404).
 */
export async function verifyProjectOwnership(
  client:    SupabaseClient,
  projectId: string,
  uid:       string,
): Promise<DbProject> {
  const { data, error } = await client
    .from('projects')
    .select('id,name,description,type,status,opportunity_score,revenue_potential,priority_score,time_to_revenue_days,market_analysis_id,url,details')
    .eq('id', projectId)
    .eq('user_id', uid)   // ownership guard obrigatório
    .maybeSingle();

  if (error) throw new PermissionError('Erro ao verificar projeto', 'PROJECT_QUERY_ERROR', 500);
  if (!data)  throw new PermissionError('Projeto não encontrado ou não autorizado', 'NOT_FOUND', 404);

  return data as DbProject;
}

/**
 * Busca todos os projetos do usuário autenticado.
 * Usado pelo tool project.find e project.compare.
 */
export async function fetchUserProjects(
  client: SupabaseClient,
  uid:    string,
): Promise<DbProject[]> {
  const { data, error } = await client
    .from('projects')
    .select('id,name,description,type,status,opportunity_score,revenue_potential,priority_score')
    .eq('user_id', uid)   // somente projetos do usuário autenticado
    .order('priority_score', { ascending: false });

  if (error) return [];
  return (data ?? []) as DbProject[];
}

// ── Server Context Loader (idêntico ao context-copilot) ───────────────────────

const MAX_CONTEXT_ITEMS = 10;

/**
 * Carrega contexto completo server-side com RLS enforced.
 * Replica exatamente o loadServerContext do context-copilot.
 * Inclui ENTITY_ISOLATION pós-query.
 */
export async function loadServerContext(
  client:    SupabaseClient,
  uid:       string,
  project:   DbProject,
): Promise<ServerContext> {
  const projectId = project.id;
  const limitations: string[] = [];

  // ── Oportunidades ────────────────────────────────────────────────────────
  const { data: opps, error: oppsErr } = await client
    .from('opportunity_lab')
    .select('id,project_id,title,description,status,opportunity_type,final_score,market_score,revenue_score,competition_score,synergy_score,strategic_fit,origin,rationale,confidence,risks,action_steps,created_at')
    .eq('user_id', uid)
    .eq('project_id', projectId)
    .order('final_score', { ascending: false })
    .limit(MAX_CONTEXT_ITEMS);

  if (oppsErr) limitations.push('oportunidades indisponíveis');

  // ── Ações ────────────────────────────────────────────────────────────────
  const { data: acts, error: actsErr } = await client
    .from('action_queue')
    .select('id,project_id,title,description,status,priority,impact_score,effort_score,roi_score,market_score,origin,rationale,created_at')
    .eq('user_id', uid)
    .eq('project_id', projectId)
    .order('priority', { ascending: false })
    .limit(MAX_CONTEXT_ITEMS);

  if (actsErr) limitations.push('ações indisponíveis');

  // ── Knowledge Base ───────────────────────────────────────────────────────
  const { data: kb, error: kbErr } = await client
    .from('knowledge_items')
    .select('id,project_id,title,status,niche,created_at')
    .eq('user_id', uid)
    .eq('project_id', projectId)
    .order('created_at', { ascending: false })
    .limit(MAX_CONTEXT_ITEMS);

  if (kbErr) limitations.push('base de conhecimento indisponível');

  const opportunities = (opps ?? []) as DbOpportunity[];
  const actions       = (acts ?? []) as DbAction[];
  const kb_items      = (kb   ?? []) as DbKbItem[];

  // ── ENTITY_ISOLATION ────────────────────────────────────────────────────
  // Defesa secundária: descarta qualquer entidade com project_id divergente
  const safeOpps = opportunities.filter(o => o.project_id === projectId);
  const safeActs = actions.filter(a => a.project_id === projectId);

  if (safeOpps.length !== opportunities.length) {
    console.error(`[ENTITY_ISOLATION] descartando ${opportunities.length - safeOpps.length} oportunidades de projeto diferente`);
  }
  if (safeActs.length !== actions.length) {
    console.error(`[ENTITY_ISOLATION] descartando ${actions.length - safeActs.length} ações de projeto diferente`);
  }

  // ── Reconstrói evidence_ids ──────────────────────────────────────────────
  const evidence_ids = new Set<string>();
  evidence_ids.add(projectId);
  safeOpps.forEach(o => { if (o.id) evidence_ids.add(o.id); });
  safeActs.forEach(a => { if (a.id) evidence_ids.add(a.id); });
  kb_items.forEach(k => { if (k.id) evidence_ids.add(k.id); });

  return {
    project:       project,
    opportunities: safeOpps,
    actions:       safeActs,
    kb_items,
    evidence_ids,
    limitations,
  };
}

// ── Feature Flag ──────────────────────────────────────────────────────────────

/**
 * Verifica se o agent mode está ativo para esta sessão.
 * Flag lida da tabela feature_flags no banco — controlada remotamente.
 *
 * Fail-open: se a tabela não existir ou houver erro, o edge function
 * continua executando (o Flutter já selecionou este endpoint via seu próprio
 * flag check). O servidor não bloqueia chamadas legítimas do Flutter.
 */
export async function isAgentModeEnabled(client: SupabaseClient): Promise<boolean> {
  try {
    const { data, error } = await client
      .from('feature_flags')
      .select('enabled')
      .eq('feature_name', 'ive_agent_mode')
      .maybeSingle();
    if (error) return false; // fail-safe: erro → legado
    return data?.enabled === true;
  } catch {
    return false; // fail-safe: se a tabela não existe, usa legado
  }
}

// ── Observabilidade ───────────────────────────────────────────────────────────

/**
 * Registra métricas de execução server-side.
 * NUNCA loga: API keys, JWT completo, conteúdo sensível.
 */
export function logExecution(params: {
  correlationId: string;
  uidPrefix:     string;
  provider:      string;
  model:         string;
  turns:         number;
  tools:         string[];
  latencyMs:     number;
  ok:            boolean;
  errorCode?:    string;
}): void {
  const tools = params.tools.join(',') || 'none';
  const status = params.ok ? 'ok' : `error:${params.errorCode ?? 'unknown'}`;
  console.log(
    `[${params.correlationId}] ${status} uid=${params.uidPrefix} ` +
    `provider=${params.provider} model=${params.model} ` +
    `turns=${params.turns} tools=[${tools}] latency=${params.latencyMs}ms`,
  );
}

// ── UUID validation ────────────────────────────────────────────────────────────

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isValidUuid(v: unknown): v is string {
  return typeof v === 'string' && UUID_RE.test(v);
}
