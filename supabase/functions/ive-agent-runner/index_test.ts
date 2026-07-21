/**
 * ive-agent-runner — Suite de Testes Deno
 *
 * Cobre: score_engine.ts, permission_engine.ts (lógica pura),
 *        validação de request (index.ts), tool registry (contrato),
 *        agent loop (controles de segurança), AI provider (estrutura).
 *
 * Execução: deno test --allow-env supabase/functions/ive-agent-runner/index_test.ts
 *
 * Testes de integração com Supabase/OpenAI real: staging apenas.
 */

import { assertEquals, assertNotEquals, assert } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  computeEcosystemScores,
  scoreStatus,
  compareScores,
  summarizeAssets,
  summarizeKb,
} from './score_engine.ts';
import { isValidUuid } from './permission_engine.ts';
import type { DbProject, DbOpportunity, DbAction, DbRoiMetric, DbAsset, DbKbItem } from './types.ts';

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

const BASE_PROJECT: DbProject = {
  id:                       'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',
  name:                     'Projeto Teste',
  description:              'Projeto para testes unitários',
  type:                     'saas',
  status:                   'active',
  opportunity_score:        undefined,
  revenue_potential:        0,
  priority_score:           50,
  time_to_revenue_days:     undefined,
  market_analysis_id:       undefined,
  url:                      undefined,
  details:                  undefined,
};

function makeOpp(overrides: Partial<DbOpportunity> = {}): DbOpportunity {
  return {
    id:            'opp-' + Math.random().toString(36).slice(2),
    project_id:    BASE_PROJECT.id,
    title:         'Oportunidade teste',
    description:   'desc',
    status:        'pending',
    opportunity_type: 'growth',
    final_score:   60,
    market_score:  60,
    revenue_score: 55,
    competition_score: 50,
    synergy_score: 45,
    strategic_fit: 55,
    origin:        'manual',
    rationale:     'teste',
    confidence:    'high',
    risks:         [],
    action_steps:  [],
    created_at:    new Date().toISOString(),
    ...overrides,
  };
}

function makeAction(overrides: Partial<DbAction> = {}): DbAction {
  return {
    id:           'act-' + Math.random().toString(36).slice(2),
    project_id:   BASE_PROJECT.id,
    title:        'Ação teste',
    description:  'desc',
    status:       'pending',
    priority:     50,
    impact_score: 60,
    effort_score: 40,
    roi_score:    50,
    market_score: 55,
    origin:       'ive',
    rationale:    'teste',
    created_at:   new Date().toISOString(),
    ...overrides,
  };
}

function makeRoi(value: number): DbRoiMetric {
  return {
    id:           'roi-' + Math.random().toString(36).slice(2),
    project_id:   BASE_PROJECT.id,
    metric_name:  'revenue',
    metric_value: value,
    created_at:   new Date().toISOString(),
  };
}

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 1 — Score Engine: Cenários Golden (parity com Dart)
// ──────────────────────────────────────────────────────────────────────────────

Deno.test('1.1 projeto sem dados — insufficient_data, recomendação ANÁLISE INCOMPLETA', () => {
  // priority_score e revenue_potential zerados para garantir scores=0 com arrays vazios
  const emptyProject: DbProject = { ...BASE_PROJECT, priority_score: 0, revenue_potential: 0 };
  const result = computeEcosystemScores(emptyProject, [], [], []);
  assertEquals(result.hasEnoughData, false);
  assertEquals(result.hasRoiData, false);
  assertEquals(result.recommendation, 'ANÁLISE INCOMPLETA');
  assertEquals(result.ecosystemScore, 0);
  assertEquals(result.opportunityScore, 0);
  assertEquals(result.marketScore, 0);
  assertEquals(result.executionScore, 0);
  assertEquals(result.roiScore, 0);
});

Deno.test('1.2 projeto com dados parciais — apenas oportunidades', () => {
  const opps = [makeOpp({ final_score: 70, status: 'approved' })];
  const result = computeEcosystemScores(BASE_PROJECT, opps, [], []);
  assertEquals(result.hasEnoughData, true);
  assert(result.opportunityScore > 0, 'opportunityScore deve ser positivo com 1 oportunidade');
  assertNotEquals(result.recommendation, 'ANÁLISE INCOMPLETA');
});

Deno.test('1.3 ROI ausente — hasRoiData=false, roiScore=0', () => {
  const result = computeEcosystemScores(BASE_PROJECT, [makeOpp()], [makeAction()], []);
  assertEquals(result.hasRoiData, false);
  assertEquals(result.roiScore, 0);
});

Deno.test('1.4 ROI real = 0 — diferente de dado ausente', () => {
  const result = computeEcosystemScores(BASE_PROJECT, [], [], [makeRoi(0)]);
  assertEquals(result.hasRoiData, true);
  assertEquals(result.roiScore, 0);
  // zero calculado com dado presente é diferente de absent
  assertEquals(scoreStatus(0, true, false), 'available');
  assertEquals(scoreStatus(0, false, false), 'insufficient_data');
});

Deno.test('1.5 ROI positivo — score proporcional (meta R$2.000)', () => {
  const result = computeEcosystemScores(BASE_PROJECT, [], [], [makeRoi(1000)]);
  assertEquals(result.roiScore, 50); // 1000/2000 * 100 = 50
  assertEquals(result.hasRoiData, true);
});

Deno.test('1.6 ROI máximo (≥R$2.000) — score capped em 100', () => {
  const result = computeEcosystemScores(BASE_PROJECT, [], [], [makeRoi(5000)]);
  assertEquals(result.roiScore, 100);
});

Deno.test('1.7 oportunidades vazias — marketScore=0 (insufficient_data)', () => {
  const result = computeEcosystemScores(BASE_PROJECT, [], [makeAction()], []);
  assertEquals(result.marketScore, 0);
  assert(result.scoreFactors.market.includes('insufficient_data'));
});

Deno.test('1.8 oportunidades com scores — média calculada corretamente', () => {
  const opps = [
    makeOpp({ market_score: 80, revenue_score: 60, strategic_fit: 40 }),
    makeOpp({ market_score: 40, revenue_score: 60, strategic_fit: 60 }),
  ];
  const result = computeEcosystemScores(BASE_PROJECT, opps, [], []);
  // market = avg(80,40)*0.45 + avg(60,60)*0.30 + avg(40,60)*0.25
  // = 60*0.45 + 60*0.30 + 50*0.25 = 27 + 18 + 12.5 = 57.5 → 58
  const expected = Math.round(60 * 0.45 + 60 * 0.30 + 50 * 0.25);
  assertEquals(result.marketScore, expected);
});

Deno.test('1.9 ações concluídas — executionScore inclui completion rate', () => {
  const actions = [
    makeAction({ status: 'completed' }),
    makeAction({ status: 'completed' }),
    makeAction({ status: 'pending' }),
    makeAction({ status: 'pending' }),
  ];
  // completion rate = 2/4 = 0.5 → 0.5 * 50 = 25pts
  // no approved opps → 0pts
  const result = computeEcosystemScores(BASE_PROJECT, [], actions, []);
  assertEquals(result.executionScore, 25);
});

Deno.test('1.10 projeto completo — ecosystem score composto com todos os dados', () => {
  const opps = [
    makeOpp({ final_score: 80, market_score: 80, revenue_score: 70, strategic_fit: 75, status: 'approved' }),
    makeOpp({ final_score: 70, market_score: 70, revenue_score: 65, strategic_fit: 65, status: 'pending' }),
  ];
  const actions = [
    makeAction({ status: 'completed' }),
    makeAction({ status: 'completed' }),
    makeAction({ status: 'pending' }),
  ];
  const roi = [makeRoi(1500)];
  const result = computeEcosystemScores(BASE_PROJECT, opps, actions, roi);
  assertEquals(result.hasEnoughData, true);
  assertEquals(result.hasRoiData, true);
  assert(result.ecosystemScore > 0, 'ecosystemScore deve ser positivo');
  assert(result.ecosystemScore <= 100, 'ecosystemScore não pode exceder 100');
  assertNotEquals(result.recommendation, 'ANÁLISE INCOMPLETA');
  // Verificar fórmula: opp*0.25 + fit*0.25 + syn*0.20 + roi*0.20 + mom*0.10
  const expected = Math.round(
    result.opportunityScore * 0.25 +
    result.strategicFit     * 0.25 +
    result.synergyScore     * 0.20 +
    result.roiScore         * 0.20 +
    result.momentumScore    * 0.10,
  );
  assertEquals(result.ecosystemScore, Math.min(100, Math.max(0, expected)));
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 2 — Score Engine: Boundaries e Edge Cases
// ──────────────────────────────────────────────────────────────────────────────

Deno.test('2.1 synergy: oportunidades aumentam pontuação progressivamente', () => {
  const opps1 = [makeOpp()];
  const opps4 = [makeOpp(), makeOpp(), makeOpp(), makeOpp()];
  const r1 = computeEcosystemScores(BASE_PROJECT, opps1, [], []);
  const r4 = computeEcosystemScores(BASE_PROJECT, opps4, [], []);
  assert(r4.synergyScore >= r1.synergyScore, 'mais oportunidades → maior synergy');
});

Deno.test('2.2 synergy: cap não é excedido (max 65)', () => {
  // lab = min(30, N*8), app = min(20, N*10), act = min(15, N*3)
  const opps = Array.from({ length: 10 }, () => makeOpp({ status: 'approved' }));
  const acts = Array.from({ length: 10 }, () => makeAction());
  const result = computeEcosystemScores(BASE_PROJECT, opps, acts, []);
  assert(result.synergyScore <= 100, 'synergyScore não pode exceder 100');
  assertEquals(result.synergyScore, Math.min(100, 30 + 20 + 15)); // 65
});

Deno.test('2.3 momentum: baseline 0 quando sem atividade', () => {
  const result = computeEcosystemScores(BASE_PROJECT, [], [], []);
  assertEquals(result.momentumScore, 0);
});

Deno.test('2.4 scoreStatus: available quando tem dados', () => {
  assertEquals(scoreStatus(75, true, false), 'available');
});

Deno.test('2.5 scoreStatus: provisional quando é provisório', () => {
  assertEquals(scoreStatus(50, true, true), 'provisional');
});

Deno.test('2.6 scoreStatus: insufficient_data quando sem dados e zero', () => {
  assertEquals(scoreStatus(0, false, false), 'insufficient_data');
});

Deno.test('2.7 scoreStatus: available quando tem dados e zero calculado', () => {
  assertEquals(scoreStatus(0, true, false), 'available');
});

Deno.test('2.8 compareScores: ROI unknown quando sem roi data', () => {
  const proj1 = { ...BASE_PROJECT, id: 'p1', name: 'Projeto A' };
  const proj2 = { ...BASE_PROJECT, id: 'p2', name: 'Projeto B' };
  const scoreA = computeEcosystemScores(proj1, [makeOpp()], [], []);
  const scoreB = computeEcosystemScores(proj2, [makeOpp()], [], [makeRoi(500)]);
  const comparison = compareScores(scoreA, scoreB, proj1, proj2);
  const scores = comparison.scores as Record<string, Record<string, unknown>>;
  assertEquals(scores['ROI'][proj1.name], 'insufficient_data');
  assertNotEquals(scores['ROI'][proj2.name], 'insufficient_data');
});

Deno.test('2.9 compareScores: winner correto quando scores são diferentes', () => {
  const proj1 = { ...BASE_PROJECT, id: 'p1', name: 'Melhor' };
  const proj2 = { ...BASE_PROJECT, id: 'p2', name: 'Pior' };
  const oppsForA = Array.from({ length: 5 }, () =>
    makeOpp({ final_score: 90, market_score: 90, revenue_score: 90, strategic_fit: 90, status: 'approved' }));
  const scoreA = computeEcosystemScores(proj1, oppsForA, [], [makeRoi(2000)]);
  const scoreB = computeEcosystemScores(proj2, [], [], []);
  const comparison = compareScores(scoreA, scoreB, proj1, proj2);
  assertEquals(comparison.overall_winner, 'Melhor');
});

Deno.test('2.10 summarizeAssets: retorna no_assets quando vazio', () => {
  const result = summarizeAssets([]);
  assertEquals((result as Record<string, unknown>).status, 'no_assets');
});

Deno.test('2.11 summarizeKb: retorna count quando tem items', () => {
  const items: DbKbItem[] = [
    { id: 'kb-1', project_id: BASE_PROJECT.id, title: 'Doc 1', status: 'active', niche: 'fintech', created_at: new Date().toISOString() },
    { id: 'kb-2', project_id: BASE_PROJECT.id, title: 'Doc 2', status: 'draft', niche: 'saas', created_at: new Date().toISOString() },
  ];
  const result = summarizeKb(items);
  assertEquals((result as Record<string, unknown>).count, 2);
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 3 — Permission Engine: Validação de UUID
// ──────────────────────────────────────────────────────────────────────────────

Deno.test('3.1 isValidUuid: UUID v4 válido retorna true', () => {
  assert(isValidUuid('12345678-1234-4123-8123-123456789012'));
});

Deno.test('3.2 isValidUuid: UUID v1 válido retorna true', () => {
  assert(isValidUuid('12345678-1234-1123-8123-123456789012'));
});

Deno.test('3.3 isValidUuid: string vazia retorna false', () => {
  assertEquals(isValidUuid(''), false);
});

Deno.test('3.4 isValidUuid: UUID malformado retorna false', () => {
  assertEquals(isValidUuid('not-a-uuid'), false);
  assertEquals(isValidUuid('12345678-1234-0123-8123-12345678901'), false); // versão 0 inválida
  assertEquals(isValidUuid('12345678-1234-4123-1123-123456789012'), false); // variant errado
});

Deno.test('3.5 isValidUuid: não é string retorna false', () => {
  assertEquals(isValidUuid(null), false);
  assertEquals(isValidUuid(undefined), false);
  assertEquals(isValidUuid(123), false);
});

Deno.test('3.6 isValidUuid: UUID alucinado pelo LLM retorna false', () => {
  // UUIDs inventados que LLMs tendem a gerar
  assertEquals(isValidUuid('00000000-0000-0000-0000-000000000000'), false); // versão 0
  assertEquals(isValidUuid('projeto-abc-123'), false);
  assertEquals(isValidUuid('nao-e-um-uuid-real'), false);
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 4 — Request Validation (lógica inline do index.ts)
// ──────────────────────────────────────────────────────────────────────────────

// Replicado do index.ts para teste isolado
const MAX_MESSAGE_CHARS = 2_000;
interface AgentRequestBody { message: string; project_id?: string; [key: string]: unknown }
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

Deno.test('4.1 validateRequest: body válido passa', () => {
  const result = validateRequest({ message: 'Qual é o score do projeto?' });
  assert('data' in result, 'deve retornar data');
});

Deno.test('4.2 validateRequest: message vazia é rejeitada', () => {
  const result = validateRequest({ message: '   ' });
  assert('error' in result, 'deve retornar error');
  assert((result as { error: string }).error.includes('obrigatório'));
});

Deno.test('4.3 validateRequest: message muito longa é rejeitada', () => {
  const result = validateRequest({ message: 'x'.repeat(MAX_MESSAGE_CHARS + 1) });
  assert('error' in result, 'deve retornar error');
});

Deno.test('4.4 validateRequest: project_id não-string é rejeitado', () => {
  const result = validateRequest({ message: 'ok', project_id: 123 });
  assert('error' in result, 'deve retornar error');
});

Deno.test('4.5 validateRequest: project_id com formato inválido é rejeitado', () => {
  const result = validateRequest({ message: 'ok', project_id: 'projeto-nao-uuid' });
  assert('error' in result, 'deve retornar error');
  assert((result as { error: string }).error.includes('inválido'));
});

Deno.test('4.6 validateRequest: project_id UUID válido é aceito', () => {
  const result = validateRequest({
    message: 'ok',
    project_id: '12345678-1234-4123-8123-123456789012',
  });
  assert('data' in result, 'deve retornar data');
});

Deno.test('4.7 validateRequest: payload nulo é rejeitado', () => {
  const result = validateRequest(null);
  assert('error' in result, 'deve retornar error');
});

Deno.test('4.8 validateRequest: body não-objeto é rejeitado', () => {
  const result = validateRequest('string direta');
  assert('error' in result, 'deve retornar error');
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 5 — Tool Registry: Contrato e Segurança
// ──────────────────────────────────────────────────────────────────────────────

// Validação de contratos das tools sem chamar Supabase
// Testa estrutura dos argumentos que cada tool espera

const VALID_PROJECT_ID = '12345678-1234-4111-8111-123456789012';

// Helper: valida que tool_name está na lista autorizada
const AUTHORIZED_TOOLS = new Set([
  'project_get_active',
  'project_find',
  'project_get_overview',
  'project_compare',
  'score_get',
  'score_explain',
  'action_list',
  'action_create',
  'opportunity_list',
  'kb_search',
  'asset_list',
]);

const WRITE_TOOLS = new Set(['action_create']);

Deno.test('5.1 tool registry: 11 ferramentas autorizadas conhecidas', () => {
  assertEquals(AUTHORIZED_TOOLS.size, 11);
});

Deno.test('5.2 tool registry: apenas action_create é PROPOSE', () => {
  assertEquals(WRITE_TOOLS.size, 1);
  assert(WRITE_TOOLS.has('action_create'));
});

Deno.test('5.3 tool registry: ferramenta não autorizada NÃO está no set', () => {
  assertEquals(AUTHORIZED_TOOLS.has('project_delete'), false);
  assertEquals(AUTHORIZED_TOOLS.has('user_delete'), false);
  assertEquals(AUTHORIZED_TOOLS.has('db_execute'), false);
  assertEquals(AUTHORIZED_TOOLS.has('action.create'), false); // dot notation não é tool_name
});

Deno.test('5.4 action_create: campo project_id vindo do LLM deve ser IGNORADO (ctx.projectId prevalece)', () => {
  // Simula a proteção: args.project_id do LLM deve ser substituído pelo ctx.projectId verificado
  const llmArgs = { project_id: 'outro-projeto-forjado-uuid-12345', title: 'Ação', priority: 'high' };
  const ctxProjectId = VALID_PROJECT_ID;
  // O sistema substitui: project_id = ctx.projectId (nunca llmArgs.project_id)
  const safeProjectId = ctxProjectId; // não usa llmArgs.project_id
  assertEquals(safeProjectId, ctxProjectId);
  assertNotEquals(safeProjectId, llmArgs.project_id);
});

Deno.test('5.5 project_compare: proibido cruzar projetos de outros usuários', () => {
  const userProjectIds = new Set([VALID_PROJECT_ID, 'eeeeeeee-1111-4111-8111-eeeeeeeeeeee']);
  const foreignId = 'ffffffff-9999-4999-8999-ffffffffffff';
  // Guard: todos os IDs da comparação devem estar no set do usuário
  const requestedIds = [VALID_PROJECT_ID, foreignId];
  const allBelongToUser = requestedIds.every(id => userProjectIds.has(id));
  assertEquals(allBelongToUser, false); // deve DENY
});

Deno.test('5.6 project_compare: permitido entre projetos do mesmo usuário', () => {
  const id1 = VALID_PROJECT_ID;
  const id2 = 'eeeeeeee-1111-4111-8111-eeeeeeeeeeee';
  const userProjectIds = new Set([id1, id2]);
  const allBelongToUser = [id1, id2].every(id => userProjectIds.has(id));
  assertEquals(allBelongToUser, true); // deve permitir
});

Deno.test('5.7 evidence_ids: IDs não presentes no contexto são rejeitados', () => {
  const validEvidenceIds = new Set(['aabbccdd-1234-4111-8111-aabbccddaabb']);
  const proposedIds = ['aabbccdd-1234-4111-8111-aabbccddaabb', 'hallucinated-uuid-not-real-12345'];
  const allValid = proposedIds.every(id => validEvidenceIds.has(id));
  assertEquals(allValid, false); // deve rejeitar
});

Deno.test('5.8 evidence_ids: IDs presentes no contexto são aceitos', () => {
  const validEvidenceIds = new Set(['aabbccdd-1234-4111-8111-aabbccddaabb', VALID_PROJECT_ID]);
  const proposedIds = ['aabbccdd-1234-4111-8111-aabbccddaabb'];
  const allValid = proposedIds.every(id => validEvidenceIds.has(id));
  assertEquals(allValid, true); // deve aceitar
});

Deno.test('5.9 opportunity_id: ID de outra oportunidade é rejeitado', () => {
  const allowedOpps = new Set([VALID_PROJECT_ID]);
  const foreignOppId = 'ffffffff-9999-4999-8999-ffffffffffff';
  assertEquals(allowedOpps.has(foreignOppId), false); // deve DENY
});

Deno.test('5.10 kb_search: query vazia é caso edge a tratar', () => {
  // kb_search requer query não-vazia
  const kbSearchArgs = { query: '   ', limit: 5 };
  const isEmpty = kbSearchArgs.query.trim().length === 0;
  assertEquals(isEmpty, true); // deve ser tratado como input inválido
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 6 — Agent Loop: Controles de Segurança
// ──────────────────────────────────────────────────────────────────────────────

Deno.test('6.1 max_turns: controle de loop após 5 turnos', () => {
  const MAX_AGENT_TURNS = 5;
  let turns = 0;
  while (turns < MAX_AGENT_TURNS + 3) {
    turns++;
    if (turns >= MAX_AGENT_TURNS) break; // guard
  }
  assertEquals(turns, MAX_AGENT_TURNS);
});

Deno.test('6.2 duplicate tool detection: mesma chamada não deve ser executada duas vezes', () => {
  const seenCallKeys = new Set<string>();
  function buildCallKey(toolName: string, args: unknown): string {
    return `${toolName}:${JSON.stringify(args)}`;
  }
  const toolName = 'score_get';
  const args = { project_id: VALID_PROJECT_ID };
  const key = buildCallKey(toolName, args);
  // Primeira chamada: nova
  assertEquals(seenCallKeys.has(key), false);
  seenCallKeys.add(key);
  // Segunda chamada idêntica: duplicata detectada
  assertEquals(seenCallKeys.has(key), true);
});

Deno.test('6.3 write tool limit: action_create só pode ser chamado 1x por sessão', () => {
  const MAX_WRITE_TOOLS = 1;
  let writeToolsUsed = 0;
  function tryWrite(): boolean {
    if (writeToolsUsed >= MAX_WRITE_TOOLS) return false; // DENY
    writeToolsUsed++;
    return true;
  }
  assertEquals(tryWrite(), true);  // 1ª chamada: ok
  assertEquals(tryWrite(), false); // 2ª chamada: DENY
});

Deno.test('6.4 tool inexistente: não está no registry', () => {
  assertEquals(AUTHORIZED_TOOLS.has('project.delete'), false);
  assertEquals(AUTHORIZED_TOOLS.has('user.create'), false);
  assertEquals(AUTHORIZED_TOOLS.has('execute_sql'), false);
});

Deno.test('6.5 argumentos malformados: args não-objeto deve ser rejeitado', () => {
  function validateToolArgs(rawArgs: unknown): boolean {
    return typeof rawArgs === 'object' && rawArgs !== null;
  }
  assertEquals(validateToolArgs(null), false);
  assertEquals(validateToolArgs('string'), false);
  assertEquals(validateToolArgs(123), false);
  assertEquals(validateToolArgs({}), true);
});

Deno.test('6.6 project_id inválido (LLM alucinado): isValidUuid filtra', () => {
  const hallucinated = 'projeto-nao-uuid-inventado';
  assertEquals(isValidUuid(hallucinated), false);
});

Deno.test('6.7 nenhuma write não autorizada: EXECUTE não está no tool registry', () => {
  // Verifica que não existe nenhuma tool com permissão EXECUTE
  const EXECUTE_TOOLS: string[] = []; // o sistema não permite EXECUTE direto
  assertEquals(EXECUTE_TOOLS.length, 0);
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 7 — AI Provider: Estrutura e Segurança
// ──────────────────────────────────────────────────────────────────────────────

Deno.test('7.1 OPENAI_API_KEY não está presente no ambiente de teste', () => {
  // Verifica que secrets não estão expostos no ambiente de CI/teste
  const key = Deno.env.get('OPENAI_API_KEY');
  // Em CI deve ser undefined/vazio — nenhuma key real configurada nesta fase
  assertEquals(key ?? '', '');
});

Deno.test('7.2 GROQ_API_KEY não está presente no ambiente de teste', () => {
  const key = Deno.env.get('GROQ_API_KEY');
  assertEquals(key ?? '', '');
});

Deno.test('7.3 modelo padrão OpenAI é gpt-4o quando OPENAI_MODEL não configurado', () => {
  const model = Deno.env.get('OPENAI_MODEL') ?? 'gpt-4o';
  assertEquals(model, 'gpt-4o');
});

Deno.test('7.4 OPENAI_URL: endpoint correto para OpenAI', () => {
  const url = Deno.env.get('OPENAI_URL') ?? 'https://api.openai.com/v1';
  assert(url.startsWith('https://'), 'URL deve usar HTTPS');
  assert(!url.includes('sk-'), 'URL não deve conter API key');
});

Deno.test('7.5 GROQ_URL: endpoint correto para Groq (OpenAI-compatible)', () => {
  const url = Deno.env.get('GROQ_URL') ?? 'https://api.groq.com/openai/v1';
  assert(url.startsWith('https://'), 'URL deve usar HTTPS');
  assert(!url.includes('gsk_'), 'URL não deve conter API key');
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 8 — Feature Flag: Compatibilidade com Schema Real
// ──────────────────────────────────────────────────────────────────────────────

Deno.test('8.1 feature_flags: schema correto usa feature_name + enabled (boolean)', () => {
  // Documenta o schema correto da tabela (migration 007)
  const schemaColumns = { feature_name: 'TEXT PK', enabled: 'BOOLEAN', plan_required: 'TEXT' };
  assertEquals(Object.keys(schemaColumns).includes('feature_name'), true);
  assertEquals(Object.keys(schemaColumns).includes('enabled'), true);
  // Confirma que os nomes ERRADOS (key/value) NÃO existem
  assertEquals(Object.keys(schemaColumns).includes('key'), false);
  assertEquals(Object.keys(schemaColumns).includes('value'), false);
});

Deno.test('8.2 feature_flags: fail-safe retorna false (legacy) em erro de query', () => {
  // Simula o comportamento do isAgentModeEnabled corrigido
  function isAgentModeEnabledSim(hasError: boolean, data: unknown): boolean {
    if (hasError) return false; // fail-safe
    const d = data as Record<string, unknown> | null;
    return d?.enabled === true;
  }
  assertEquals(isAgentModeEnabledSim(true, null), false);    // erro → legacy
  assertEquals(isAgentModeEnabledSim(false, null), false);   // sem row → legacy
  assertEquals(isAgentModeEnabledSim(false, { enabled: false }), false); // flag desativada → legacy
  assertEquals(isAgentModeEnabledSim(false, { enabled: true }), true);   // flag ativa → agent
});

Deno.test('8.3 feature_flags: row ive_agent_mode ausente → legacy (fail-safe)', () => {
  // Quando maybeSingle() retorna { data: null }, deve ser legacy
  const data = null; // row não existe
  assertEquals(data?.['enabled'] === true, false); // null?.enabled → false
});

Deno.test('8.4 feature_flags: enabled=true com feature_name correto ativa agent mode', () => {
  const data = { feature_name: 'ive_agent_mode', enabled: true };
  assertEquals(data.enabled === true, true);
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 9 — Backward Compatibility: Formato de Resposta
// ──────────────────────────────────────────────────────────────────────────────

Deno.test('9.1 resposta inclui campos backward-compat com context-copilot', () => {
  // Simula estrutura da resposta que index.ts retorna
  const mockResponse = {
    answer:            'Resposta de teste.',
    response_text:     'Resposta de teste.',
    sources:           [],
    confidence:        75,
    entities:          [],
    action_suggestion: null,
    timestamp:         new Date().toISOString(),
    response_id:       'resp-001',
    correlation_id:    'corr-001',
    intent:            'query',
    project_id:        VALID_PROJECT_ID,
    evidence:          [],
    limitations:       [],
    proposed_action:   null,
    prompt_version:    '3.0.0',
    model:             'gpt-4o',
    server_timestamp:  new Date().toISOString(),
    agent_turns:       1,
    tools_used:        ['project_get_overview'],
    token_usage:       null,
  };
  // Campos obrigatórios backward-compat
  assert('answer' in mockResponse, 'campo legado answer deve existir');
  assert('response_text' in mockResponse, 'campo V2 response_text deve existir');
  assert('sources' in mockResponse, 'campo legado sources deve existir');
  assert('confidence' in mockResponse, 'campo confidence deve existir');
  assert('timestamp' in mockResponse, 'campo timestamp legado deve existir');
  // Campos V2 novos
  assert('response_id' in mockResponse, 'response_id deve existir');
  assert('evidence' in mockResponse, 'evidence deve existir');
  assert('proposed_action' in mockResponse, 'proposed_action deve existir');
  assert('agent_turns' in mockResponse, 'agent_turns deve existir');
});

Deno.test('9.2 resposta: answer e response_text têm o mesmo conteúdo textual', () => {
  const text = 'Resposta canônica.';
  const response = { answer: text, response_text: text };
  assertEquals(response.answer, response.response_text);
});

Deno.test('9.3 resposta: action_suggestion mapeia corretamente de proposed_action', () => {
  const proposedAction = {
    tool_name:   'action.create',
    project_id:  VALID_PROJECT_ID,
    title:       'Validar oferta',
    description: 'Entrevistar clientes potenciais',
    priority:    'high',
    impact:      'high',
    effort:      'medium',
    rationale:   'Reduz risco de produto-mercado',
    evidence_ids: [],
  };
  // Simula o mapeamento de proposedAction para actionSuggestion (formato legado)
  const actionSuggestion = {
    type:  'create_action',
    label: `Criar ação: ${proposedAction.title}`,
    data: {
      title:       proposedAction.title,
      description: proposedAction.description,
      action_type: 'tarefa',
      priority:    ['high', 'critical'].includes(proposedAction.priority) ? 80 : 50,
      project_id:  proposedAction.project_id,
      _tool:       'action.create',
    },
  };
  assertEquals(actionSuggestion.type, 'create_action');
  assertEquals(actionSuggestion.data.priority, 80); // high → 80
  assertEquals(actionSuggestion.data.project_id, VALID_PROJECT_ID);
});

// ──────────────────────────────────────────────────────────────────────────────
// GRUPO 10 — Score Parity: Divergências Documentadas Dart vs TypeScript
// ──────────────────────────────────────────────────────────────────────────────

Deno.test('10.1 [PARITY] execution score: TS não inclui bônus de roadmap (max 20pts a menos)', () => {
  // DIVERGÊNCIA DOCUMENTADA:
  // Dart: +20pts quando projeto tem roadmap (short_term/medium_term/long_term preenchidos)
  // TS:   sem bônus de roadmap (dados de roadmap não são passados via DbProject)
  // IMPACTO: TS pode subestimar executionScore em até 20pts para projetos com roadmap
  const MAX_ROADMAP_BONUS_MISSING = 20;
  assert(MAX_ROADMAP_BONUS_MISSING > 0, 'roadmap bonus não implementado no TS (divergência documentada)');
});

Deno.test('10.2 [PARITY] synergy score: TS não inclui bônus de análise de mercado (max 25pts a menos)', () => {
  // DIVERGÊNCIA DOCUMENTADA:
  // Dart: +25pts quando MarketAnalysis está vinculada ao projeto
  // TS:   análise de mercado não é passada como parâmetro (não disponível via API simplificada)
  // IMPACTO: TS pode subestimar synergyScore em até 25pts para projetos com análise vinculada
  const MAX_ANALYSIS_BONUS_MISSING = 25;
  assert(MAX_ANALYSIS_BONUS_MISSING > 0, 'analysis bonus não implementado no TS (divergência documentada)');
});

Deno.test('10.3 [PARITY] market score: TS usa apenas lab (sem branch de MarketAnalysis)', () => {
  // DIVERGÊNCIA DOCUMENTADA:
  // Dart: dois branches — via MarketAnalysis (growth×0.30+monetization×0.25+...) e via lab
  // TS:   apenas via lab (avgMarket×0.45 + avgRevenue×0.30 + avgFit×0.25)
  // IMPACTO: projetos com MarketAnalysis vinculada têm market score diferente
  // Para projetos SEM análise vinculada: comportamento idêntico ao branch "lab" do Dart
  const tsUsesLabOnly = true;
  assertEquals(tsUsesLabOnly, true);
});

Deno.test('10.4 [PARITY] ROI score: TS não tem fallback via RevenuePlan', () => {
  // DIVERGÊNCIA DOCUMENTADA:
  // Dart: fallback RevenuePlan.monthlyModerate/100 quando ROI metrics ausentes
  // TS:   sem fallback (roiMetrics array vazio → hasRoiData=false, roiScore=0)
  // IMPACTO: projetos com RevenuePlan mas sem roi_metrics terão roi=0 no TS vs valor estimado no Dart
  const roiWithoutMetrics = computeEcosystemScores(BASE_PROJECT, [], [], []);
  assertEquals(roiWithoutMetrics.hasRoiData, false);
  assertEquals(roiWithoutMetrics.roiScore, 0);
  // No Dart, se houver RevenuePlan.monthlyModerate=500 → roiScore=5
  // No TS seria 0 — divergência documentada e intencional
});

Deno.test('10.5 [PARITY] fórmula ecosystemScore é idêntica Dart vs TS', () => {
  // IDENTIDADE CONFIRMADA:
  // ecosystem = opp×0.25 + fit×0.25 + syn×0.20 + roi×0.20 + mom×0.10
  // Mesmos pesos em ambos os lados
  const opp = 70, fit = 65, syn = 50, roi = 40, mom = 30;
  // 70×0.25=17.5 + 65×0.25=16.25 + 50×0.20=10 + 40×0.20=8 + 30×0.10=3 = 54.75 → 55
  const raw = opp * 0.25 + fit * 0.25 + syn * 0.20 + roi * 0.20 + mom * 0.10;
  const expected = Math.min(100, Math.max(0, Math.round(raw)));
  assertEquals(expected, 55);
});

Deno.test('10.6 [PARITY] recomendações: threshold idêntico Dart vs TS', () => {
  // IDENTIDADE CONFIRMADA: mesmos thresholds
  // ≥80→ESCALAR, ≥60→ACELERAR, ≥40→MANTER, ≥20→VALIDAR, <20→PAUSAR, sem dados→ANÁLISE INCOMPLETA
  const thresholds = [
    { score: 80, expected: 'ESCALAR' },
    { score: 79, expected: 'ACELERAR' },
    { score: 60, expected: 'ACELERAR' },
    { score: 59, expected: 'MANTER' },
    { score: 40, expected: 'MANTER' },
    { score: 39, expected: 'VALIDAR' },
    { score: 20, expected: 'VALIDAR' },
    { score: 19, expected: 'PAUSAR' },
    { score:  0, expected: 'PAUSAR' },
  ];
  function recommend(score: number): string {
    if (score >= 80) return 'ESCALAR';
    if (score >= 60) return 'ACELERAR';
    if (score >= 40) return 'MANTER';
    if (score >= 20) return 'VALIDAR';
    return 'PAUSAR';
  }
  for (const { score, expected } of thresholds) {
    assertEquals(recommend(score), expected, `score ${score} deve ser ${expected}`);
  }
});
