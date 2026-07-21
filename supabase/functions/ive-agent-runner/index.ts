/**
 * ive-agent-runner — Edge Function Principal
 *
 * Agent Runner v1.0 — IVE Agent Foundation Phase 1B
 *
 * Diferenças vs context-copilot:
 *  - Loop de agente com múltiplas chamadas de ferramentas (max 5 turnos)
 *  - Tool Registry V1 com 11 ferramentas
 *  - AIProvider abstrato (OpenAI primário, Groq fallback)
 *  - Permission Engine (READ/PROPOSE/EXECUTE)
 *  - Comparação cross-project segura
 *  - Score Engine com mesma fórmula da UI
 *
 * Compatibilidade:
 *  - Retorna o MESMO formato de resposta que context-copilot v2
 *  - IveCopilotResponse.parse() processa sem modificação
 *  - IveActionProposal e confirmProposal() sem alteração
 *
 * Observabilidade:
 *  - Registra: provider, model, turns, tools, latency, correlation_id
 *  - NUNCA loga: API keys, JWT, conteúdo sensível
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  createAuthenticatedClient,
  getAuthenticatedUid,
  isAgentModeEnabled,
  loadServerContext,
  logExecution,
  verifyProjectOwnership,
} from './permission_engine.ts';
import { createAIProvider, AIProviderError } from './ai_provider.ts';
import { runAgentLoop } from './agent_orchestrator.ts';
import type { AgentRequestBody } from './types.ts';

// ── Constants ──────────────────────────────────────────────────────────────────

const MAX_PAYLOAD_BYTES     = 64_000;
const MAX_MESSAGE_CHARS     = 2_000;
const MAX_HISTORY_ITEMS     = 10;
const MAX_HISTORY_MSG_CHARS = 800;
const AGENT_TIMEOUT_MS      = 55_000;  // 55s (Supabase limit = 60s; extra 5s de margem)

// ── CORS ───────────────────────────────────────────────────────────────────────

const CORS_HEADERS = {
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

// ── Request validation ─────────────────────────────────────────────────────────

function validateRequest(body: unknown): { data: AgentRequestBody } | { error: string } {
  if (!body || typeof body !== 'object') return { error: 'payload inválido' };
  const b = body as Record<string, unknown>;

  if (typeof b.message !== 'string' || b.message.trim().length === 0)
    return { error: 'message é obrigatório e não pode ser vazio' };
  if (b.message.length > MAX_MESSAGE_CHARS)
    return { error: `message excede ${MAX_MESSAGE_CHARS} caracteres` };

  if (b.project_id !== undefined) {
    if (typeof b.project_id !== 'string') return { error: 'project_id deve ser string' };
    if (!/^[0-9a-f-]{36}$/i.test(b.project_id)) return { error: 'project_id formato inválido' };
  }

  return { data: b as AgentRequestBody };
}

// ── Main handler ───────────────────────────────────────────────────────────────

serve(async (req) => {
  const correlationId = crypto.randomUUID();
  const t0            = Date.now();

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

  let client: ReturnType<typeof createAuthenticatedClient>;
  let uid: string;

  try {
    client = createAuthenticatedClient(authHeader);
    uid    = await getAuthenticatedUid(client);
  } catch (err) {
    const code   = (err as { code?: string }).code ?? 'UNAUTHORIZED';
    const status = (err as { httpStatus?: number }).httpStatus ?? 401;
    return errorResponse(code, (err as Error).message, status, correlationId);
  }

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
  const body                = validation.data;
  const clientCorrelationId = body.client_correlation_id ?? correlationId;

  // ── 4. Verificar feature flag (server-side check) ──────────────────────────
  // Fail-open: se a flag não existir, deixa prosseguir (Flutter já selecionou este endpoint)
  const agentEnabled = await isAgentModeEnabled(client);
  if (!agentEnabled) {
    // Retorna erro no formato do provider — Flutter faz fallback para context-copilot
    return errorResponse(
      'AGENT_DISABLED',
      'Agent mode não está habilitado para esta sessão.',
      503,
      clientCorrelationId,
    );
  }

  // ── 5. Verificar project_id e ownership ───────────────────────────────────
  if (!body.project_id) {
    return errorResponse('BAD_REQUEST', 'project_id é obrigatório para o agent mode', 400, correlationId);
  }

  let project: Awaited<ReturnType<typeof verifyProjectOwnership>>;
  try {
    project = await verifyProjectOwnership(client, body.project_id, uid);
  } catch (err) {
    const code   = (err as { code?: string }).code ?? 'NOT_FOUND';
    const status = (err as { httpStatus?: number }).httpStatus ?? 404;
    return errorResponse(code, (err as Error).message, status, correlationId);
  }

  // ── 6. Carregar contexto autorizado server-side ───────────────────────────
  const serverCtx = await loadServerContext(client, uid, project);

  // ── 7. Preparar histórico (sanitizado) ───────────────────────────────────
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

  // ── 8. Criar AI Provider ──────────────────────────────────────────────────
  let aiProvider: ReturnType<typeof createAIProvider>;
  try {
    aiProvider = createAIProvider();
  } catch (err) {
    console.error(`[${correlationId}] AI provider config error`);
    return errorResponse('SERVER_ERROR', 'configuração do provedor de IA incompleta', 500, correlationId);
  }

  // ── 9. Executar agent loop com timeout ────────────────────────────────────
  const abortController = new AbortController();
  const timeoutId       = setTimeout(() => abortController.abort(), AGENT_TIMEOUT_MS);

  let result: Awaited<ReturnType<typeof runAgentLoop>>;
  try {
    const clientHints = (body.context ?? {}) as Record<string, unknown>;
    const screenName  = body.screen_name ?? body.route ?? 'unknown';

    result = await runAgentLoop({
      message:     body.message,
      history:     rawHistory,
      project,
      serverCtx,
      clientHints,
      screenName,
      aiProvider,
      supabase:    client,
      uid,
      projectId:   project.id,
      signal:      abortController.signal,
    });
  } catch (err) {
    clearTimeout(timeoutId);

    if (err instanceof AIProviderError) {
      console.error(`[${correlationId}] AI provider error: ${err.code}`);
      if (err.status === 401) {
        return errorResponse('SERVER_ERROR', 'erro de autenticação com provedor de IA', 500, correlationId);
      }
      return errorResponse('MODEL_ERROR', 'erro ao processar com modelo de IA', 502, correlationId);
    }

    const isTimeout = err instanceof Error && err.name === 'AbortError';
    if (isTimeout) {
      console.error(`[${correlationId}] agent timeout`);
      return errorResponse('TIMEOUT', 'A IVE demorou para responder. Tente novamente.', 504, correlationId);
    }

    console.error(`[${correlationId}] agent error: ${(err as Error).message?.slice(0, 100)}`);
    return errorResponse('MODEL_ERROR', 'erro de comunicação com modelo', 502, correlationId);
  } finally {
    clearTimeout(timeoutId);
  }

  const latencyMs = Date.now() - t0;

  // ── 10. Observabilidade (sem dados sensíveis) ──────────────────────────────
  logExecution({
    correlationId,
    uidPrefix:  uid.slice(0, 8),
    provider:   aiProvider.providerName,
    model:      aiProvider.model,
    turns:      result.agentTurns,
    tools:      result.toolsLog.map(t => t.tool_name),
    latencyMs,
    ok:         true,
  });

  // ── 11. Montar resposta backward-compatible com IveCopilotResponse ──────────
  // Formato idêntico ao context-copilot v2 para compatibilidade com IveCopilotResponse.parse()
  const serverTs = new Date().toISOString();

  // Mapeia proposed_action para action_suggestion (formato legado, para Flutter < IVE v2)
  let actionSuggestion: Record<string, unknown> | null = null;
  if (result.proposedAction) {
    const pa = result.proposedAction;
    actionSuggestion = {
      type:  'create_action',
      label: `Criar ação: ${pa.title}`,
      data: {
        title:          pa.title,
        description:    pa.description,
        action_type:    'tarefa',
        priority:       ['high', 'critical'].includes(pa.priority as string) ? 80 : 50,
        project_id:     pa.project_id,
        rationale:      pa.rationale,
        evidence_ids:   pa.evidence_ids,
        opportunity_id: pa.opportunity_id,
        _tool:          'action.create',
        _impact:        pa.impact,
        _effort:        pa.effort,
        _due_date:      pa.due_date,
      },
    };
  }

  return jsonResponse({
    // ── Campos backward-compatible (esperados pelo provider) ──
    answer:            result.responseText || '—',
    response_text:     result.responseText || '—',
    sources:           [],
    confidence:        result.confidence,
    entities:          [],
    action_suggestion: actionSuggestion,
    timestamp:         serverTs,

    // ── Campos novos IVE v2 (IveCopilotResponse.parse espera estes) ──
    response_id:     result.responseId,
    correlation_id:  clientCorrelationId,
    intent:          result.intent,
    project_id:      project.id,
    evidence:        result.evidence,
    limitations:     result.limitations,
    proposed_action: result.proposedAction,
    prompt_version:  result.promptVersion,
    model:           result.model,
    server_timestamp: serverTs,

    // ── Campos adicionais do agent (não quebram parsing legado) ──
    agent_turns: result.agentTurns,
    tools_used:  result.toolsLog.map(t => t.tool_name),
    token_usage: result.tokenUsage ?? null,
  });
});
