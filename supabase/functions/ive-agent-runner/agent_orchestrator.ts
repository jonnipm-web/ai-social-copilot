/**
 * ive-agent-runner — Agent Orchestrator
 *
 * Implementa o ciclo do agente IVE:
 * authenticate → resolve context → LLM call → tool_call → validate → execute → repeat
 *
 * Proteções:
 *   - max_agent_turns = 5 (previne loops infinitos)
 *   - Detecção de chamadas duplicadas (mesmo tool + mesmos args)
 *   - Token budget tracking
 *   - Timeout total configurável
 *   - Nunca mais de 1 write tool por sessão (action.create)
 */

import type {
  AgentOrchestrationResult,
  AgentTurnLog,
  AIMessage,
  AIToolCall,
  ServerContext,
} from './types.ts';
import type { AIProvider } from './ai_provider.ts';
import { assistantMsg, systemMsg, toolResultMsg, userMsg } from './ai_provider.ts';
import { SupabaseClient } from 'npm:@supabase/supabase-js@2';
import {
  executeTool,
  getToolDefinitions,
  getToolPermission,
} from './tool_registry.ts';
import { fetchUserProjects } from './permission_engine.ts';
import type { DbProject, ToolExecutionContext } from './types.ts';

// ── Constants ──────────────────────────────────────────────────────────────────

const MAX_AGENT_TURNS     = 5;
const MAX_WRITE_TOOLS     = 1;   // Apenas 1 action.create por conversa
const PROMPT_VERSION      = '3.0.0';

// ── System Prompt ──────────────────────────────────────────────────────────────

function buildAgentSystemPrompt(
  project:    DbProject,
  serverCtx:  ServerContext,
  clientHints: Record<string, unknown>,
  screenName:  string,
): string {
  const scores      = clientHints.scores as Record<string, unknown> | null ?? null;
  const hasEnoughData = scores ? (scores.has_enough_data as boolean ?? true) : false;
  const hasRoiData    = scores ? (scores.roi_data_available as boolean ?? false) : false;

  const roiRule = hasRoiData
    ? 'Se perguntado sobre ROI, use o valor do score.get.'
    : 'ROI: declare "Não há dados de ROI registrados para este projeto" se perguntado.';

  const opportunitiesCtx = serverCtx.opportunities.length > 0
    ? serverCtx.opportunities.slice(0, 5).map(o =>
        `• [${o.id}] ${o.title} [score=${o.final_score}, status=${o.status}]`,
      ).join('\n')
    : 'Nenhuma oportunidade registrada neste projeto.';

  const actionsCtx = serverCtx.actions.length > 0
    ? serverCtx.actions.slice(0, 5).map(a =>
        `• [${a.id}] ${a.title} [status=${a.status}, prioridade=${a.priority}]`,
      ).join('\n')
    : 'Nenhuma ação registrada neste projeto.';

  return `Você é a IVE — agente estratégico de inteligência do AI Social Copilot.

== CONTEXTO VALIDADO PELO SERVIDOR ==

TELA ATUAL: ${screenName}

## PROJETO ATIVO (verificado server-side)
ID: ${project.id}
Nome: ${project.name}
Tipo: ${project.type ?? '—'}
Status: ${project.status ?? '—'}
${project.description ? `Descrição: ${project.description}` : ''}

## OPORTUNIDADES (top 5, fonte: servidor)
${opportunitiesCtx}

## AÇÕES (top 5, fonte: servidor)
${actionsCtx}

${!hasEnoughData ? '## AVISO: DADOS INSUFICIENTES\nScores são provisórios. Ao citar valores, indique que são estimativas iniciais.' : ''}
${!hasRoiData    ? '## AVISO: SEM DADOS DE ROI\nNão mencione ROI como dado disponível; declare a ausência explicitamente.' : ''}

${serverCtx.limitations.length ? `## LIMITAÇÕES DE CONTEXTO\n${serverCtx.limitations.map(l => `• ${l}`).join('\n')}` : ''}

== SUAS FERRAMENTAS ==

Você tem acesso a ferramentas para buscar dados em tempo real. Use-as ANTES de responder quando precisar de dados atualizados ou dados de outros projetos.

FERRAMENTAS DISPONÍVEIS:
- project_get_active: dados do projeto ativo
- project_find: buscar projetos por nome (ex: quando usuário menciona outro projeto)
- project_get_overview: visão completa de um projeto específico
- project_compare: comparar dois projetos do mesmo usuário (cross-project)
- score_get: scores atuais de um projeto (mesma fórmula da UI)
- score_explain: explicação detalhada de como um score foi calculado
- action_list: listar ações do projeto
- action_create: PROPOR criação de ação (requer confirmação do usuário — não executa automaticamente)
- opportunity_list: listar oportunidades
- kb_search: buscar na knowledge base (retorna apenas metadados)
- asset_list: listar assets do projeto

== REGRAS OBRIGATÓRIAS ==

1. ISOLAMENTO: Responda com dados do PROJETO ATIVO. Para dados de outros projetos, use project_find + project_compare ou project_get_overview.

2. GROUNDING: Toda afirmação estratégica deve citar a fonte exata (ID [uuid] ou nome da entidade + valor). Nunca invente dados.

3. DADOS AUSENTES: Se os dados não estão disponíveis, declare o que está faltando. Não invente. Use as ferramentas para buscar dados ausentes.

4. SCORES: Cite apenas scores recuperados via score_get. O valor exibido é idêntico ao da UI. ${!hasEnoughData ? 'ATENÇÃO: scores são provisórios.' : ''}

5. COMPARAÇÃO: Para comparar projetos, use project_find para localizar cada projeto, depois project_compare. Nunca invente scores de projetos não carregados.

6. ${roiRule}

7. ESCRITA: Proponha action.create SOMENTE quando o usuário claramente pediu para criar uma ação. A ação só é persistida após confirmação explícita do usuário no app.

8. CONFIANÇA: Informe limitações da resposta quando os dados forem insuficientes. Não declare 100% de certeza.

9. Responda sempre em Português do Brasil. Seja direto — máximo 4 parágrafos curtos.

10. SEGURANÇA: Não execute nenhuma operação de escrita sem proposta explícita. Nunca acesse dados de outros usuários.`;
}

// ── Intent detection ───────────────────────────────────────────────────────────

function detectIntent(message: string): string {
  const m = message.toLowerCase();
  if (/criar|adicionar|incluir|nova ação|novo item/.test(m)) return 'create';
  if (/explicar|por que|como|origem|motivo/.test(m))         return 'explain';
  if (/simul|se eu|e se|cenário/.test(m))                    return 'simulate';
  if (/prioridade|próximo passo|o que fazer|recomend/.test(m)) return 'recommend';
  if (/comparar|versus|vs\.?|melhor entre/.test(m))           return 'compare';
  return 'query';
}

// ── Duplicate call detection ───────────────────────────────────────────────────

function makeCallKey(toolName: string, args: string): string {
  return `${toolName}::${args}`;
}

// ── Build evidence from tool results ──────────────────────────────────────────

function buildEvidence(
  projectId:   string,
  projectName: string,
  toolResults: Array<{ tool: string; data: Record<string, unknown> }>,
): Record<string, unknown>[] {
  const evidence: Record<string, unknown>[] = [{
    source_type: 'project',
    source_id:   projectId,
    title:       projectName,
    project_id:  projectId,
    timestamp:   null,
    relevance:   1.0,
  }];

  for (const r of toolResults) {
    if (r.tool === 'action_list' && Array.isArray(r.data.actions)) {
      for (const a of (r.data.actions as Array<Record<string, unknown>>).slice(0, 3)) {
        if (a.id && a.title) {
          evidence.push({
            source_type:      'action',
            source_id:        a.id,
            title:            a.title,
            structured_value: { status: a.status, priority: a.priority },
            project_id:       projectId,
            timestamp:        a.created_at ?? null,
            relevance:        0.7,
          });
        }
      }
    }

    if (r.tool === 'opportunity_list' && Array.isArray(r.data.opportunities)) {
      for (const o of (r.data.opportunities as Array<Record<string, unknown>>).slice(0, 3)) {
        if (o.id && o.title) {
          evidence.push({
            source_type:      'opportunity',
            source_id:        o.id,
            title:            o.title,
            structured_value: { status: o.status, score: o.final_score },
            project_id:       projectId,
            timestamp:        o.created_at ?? null,
            relevance:        0.8,
          });
        }
      }
    }

    if (r.tool === 'kb_search' && Array.isArray(r.data.items)) {
      for (const k of (r.data.items as Array<Record<string, unknown>>).slice(0, 3)) {
        if (k.id && k.title) {
          evidence.push({
            source_type: 'kb_item',
            source_id:   k.id,
            title:       k.title,
            project_id:  projectId,
            timestamp:   null,
            relevance:   0.6,
          });
        }
      }
    }
  }

  return evidence;
}

// ── Confidence calculator ─────────────────────────────────────────────────────

function computeConfidence(
  serverCtx:   ServerContext,
  clientHints: Record<string, unknown>,
  agentTurns:  number,
  toolsUsed:   string[],
): number {
  let score = 30;
  if (serverCtx.project)              score += 20;
  if (serverCtx.opportunities.length) score += 10;
  if (serverCtx.actions.length)       score += 10;
  if (clientHints.scores)             score += 5;
  if (serverCtx.limitations.length === 0) score += 5;
  if (toolsUsed.length > 0)           score += 10;
  if (agentTurns >= 2)                score += 5;  // mais turnos = mais dados coletados
  return Math.min(score, 95);
}

// ── Main Orchestration Loop ────────────────────────────────────────────────────

export interface OrchestratorInput {
  message:     string;
  history:     Array<{ role: string; content: string }>;
  project:     DbProject;
  serverCtx:   ServerContext;
  clientHints: Record<string, unknown>;
  screenName:  string;
  aiProvider:  AIProvider;
  supabase:    SupabaseClient;
  uid:         string;
  projectId:   string;
  signal?:     AbortSignal;
}

export async function runAgentLoop(input: OrchestratorInput): Promise<AgentOrchestrationResult> {
  const {
    message, history, project, serverCtx, clientHints, screenName,
    aiProvider, supabase, uid, projectId, signal,
  } = input;

  // ── Contexto de execução de ferramentas ───────────────────────────────────
  const userProjects  = await fetchUserProjects(supabase, uid);
  const allProjectIds = new Set(userProjects.map(p => p.id));

  const toolCtx: ToolExecutionContext = {
    uid,
    projectId,
    supabase,
    evidenceIds:   serverCtx.evidence_ids,
    allProjectIds,
  };

  // ── Prepara mensagens iniciais ────────────────────────────────────────────
  const systemPrompt = buildAgentSystemPrompt(project, serverCtx, clientHints, screenName);
  const messages: AIMessage[] = [
    systemMsg(systemPrompt),
    ...history.map(h => ({
      role:    h.role as 'user' | 'assistant',
      content: h.content,
    })),
    userMsg(message),
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  const toolsLog:      AgentTurnLog[]                                      = [];
  const toolResults:   Array<{ tool: string; data: Record<string, unknown> }> = [];
  const seenCallKeys:  Set<string>                                         = new Set();
  const toolsUsed:     string[]                                            = [];
  let   writeToolsUsed = 0;
  let   agentTurns     = 0;
  let   tokenUsage     = { prompt: 0, completion: 0, total: 0 };
  let   proposedAction: Record<string, unknown> | null = null;
  let   finalResponseText = '';

  // ── Tool definitions para o LLM ───────────────────────────────────────────
  const toolDefs = getToolDefinitions();

  // ── Agent Loop ────────────────────────────────────────────────────────────
  while (agentTurns < MAX_AGENT_TURNS) {
    agentTurns++;

    const completion = await aiProvider.complete({
      messages,
      tools:       toolDefs,
      temperature: 0.35,
      max_tokens:  1200,
    }, signal);

    // Acumula token usage
    if (completion.usage) {
      tokenUsage.prompt     += completion.usage.prompt_tokens;
      tokenUsage.completion += completion.usage.completion_tokens;
      tokenUsage.total      += completion.usage.total_tokens;
    }

    // ── Resposta final (sem tool_calls) ────────────────────────────────────
    if (!completion.tool_calls || completion.tool_calls.length === 0) {
      finalResponseText = (completion.content ?? '').trim();
      break;
    }

    // ── Processa tool_calls ────────────────────────────────────────────────
    const assistantWithCalls = assistantMsg(completion.content, completion.tool_calls);
    messages.push(assistantWithCalls);

    for (const toolCall of completion.tool_calls) {
      const { id, function: fn } = toolCall;
      const toolName             = fn.name;
      const toolArgs             = fn.arguments ?? '{}';

      // ── Detecção de chamada duplicada ────────────────────────────────────
      const callKey = makeCallKey(toolName, toolArgs);
      if (seenCallKeys.has(callKey)) {
        console.warn(`[agent] duplicate call detected: ${toolName}`);
        messages.push(toolResultMsg(id, JSON.stringify({
          ok:    false,
          error: `Chamada duplicada de "${toolName}" com os mesmos argumentos. Use os resultados anteriores.`,
        })));
        continue;
      }
      seenCallKeys.add(callKey);

      // ── Verificação de write tool limit ──────────────────────────────────
      const permission = getToolPermission(toolName);
      if (permission === 'propose' && ++writeToolsUsed > MAX_WRITE_TOOLS) {
        messages.push(toolResultMsg(id, JSON.stringify({
          ok:    false,
          error: 'Limite de propostas de escrita atingido nesta sessão (máximo 1).',
        })));
        continue;
      }

      // ── Executa a ferramenta ──────────────────────────────────────────────
      const t0     = Date.now();
      const result = await executeTool(toolName, toolArgs, toolCtx);
      const latency = Date.now() - t0;

      toolsLog.push({
        turn:      agentTurns,
        tool_name: toolName,
        args_hash: callKey.slice(0, 40),
        ok:        result.ok,
        latency_ms: latency,
      });

      if (result.ok) {
        toolsUsed.push(toolName);
        toolResults.push({ tool: toolName, data: result.data });

        // Captura proposta de ação (action_create retorna proposed_action)
        if (toolName === 'action_create' && result.data.tool_name === 'action.create') {
          proposedAction = result.data;
        }
      }

      // Retorna resultado ao LLM (tanto sucesso quanto erro)
      messages.push(toolResultMsg(id, JSON.stringify(result)));
    }

    // Se max_turns atingido na próxima iteração, força resposta final
    if (agentTurns >= MAX_AGENT_TURNS) {
      const finalCompletion = await aiProvider.complete({
        messages: [...messages, systemMsg('INSTRUÇÃO FINAL: Responda agora baseado nos dados coletados. Não chame mais ferramentas.')],
        temperature: 0.35,
        max_tokens:  800,
      }, signal);
      finalResponseText = (finalCompletion.content ?? '').trim();
      if (finalCompletion.usage) {
        tokenUsage.total += finalCompletion.usage.total_tokens ?? 0;
      }
      break;
    }
  }

  if (!finalResponseText) {
    finalResponseText = 'Não foi possível gerar uma resposta com os dados disponíveis. Tente reformular sua pergunta.';
  }

  // ── Monta resultado final ──────────────────────────────────────────────────
  const confidence = computeConfidence(serverCtx, clientHints, agentTurns, toolsUsed);
  const evidence   = buildEvidence(projectId, project.name, toolResults);
  const limitations = [
    ...serverCtx.limitations,
    ...(toolResults.some(r => r.tool === 'kb_search')
      ? ['Knowledge Base: apenas metadados retornados. Conteúdo integral dos documentos não está disponível.']
      : []),
  ];

  return {
    responseText:   finalResponseText,
    responseId:     crypto.randomUUID(),
    intent:         detectIntent(message),
    evidence,
    proposedAction,
    limitations,
    confidence,
    model:          aiProvider.model,
    promptVersion:  PROMPT_VERSION,
    agentTurns,
    toolsLog,
    tokenUsage:     tokenUsage.total > 0 ? { prompt: tokenUsage.prompt, completion: tokenUsage.completion, total: tokenUsage.total } : undefined,
  };
}
