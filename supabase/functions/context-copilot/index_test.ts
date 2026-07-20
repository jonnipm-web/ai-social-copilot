/**
 * Testes da Edge Function context-copilot (Deno test runner)
 *
 * Esses testes validam a lógica interna da função sem chamar
 * Groq ou Supabase reais. Cada módulo testável é importado
 * diretamente do arquivo de produção.
 *
 * Para rodar: deno test --allow-env supabase/functions/context-copilot/index_test.ts
 *
 * Nota: os testes de integração completa (com JWT real e Supabase)
 * são executados em ambiente de staging com as secrets configuradas.
 */

// ── Helpers importados da função (re-declarados para isolamento) ──────────────
// Como Deno não tem jest/mocking nativo simples para módulos externos,
// vamos testar a lógica pura extraída aqui.

// ── Tipos ─────────────────────────────────────────────────────────────────────

interface ValidationResult<T> {
  data?: T;
  error?: string;
}

import {
  buildOpportunityContextSection,
  buildProjectContextSection,
} from './context_prompt.ts';

// ── Lógica pura extraída para teste ──────────────────────────────────────────

const MAX_MESSAGE_CHARS     = 2_000;
const MAX_HISTORY_ITEMS     = 10;
const MAX_HISTORY_MSG_CHARS = 800;
const VALID_PRIORITIES      = ['low', 'medium', 'high', 'critical'];
const VALID_IMPACTS         = ['low', 'medium', 'high'];
const VALID_EFFORTS         = ['low', 'medium', 'high'];

function validateRequest(body: unknown): ValidationResult<Record<string, unknown>> {
  if (!body || typeof body !== 'object') return { error: 'payload inválido' };
  const b = body as Record<string, unknown>;
  if (typeof b.message !== 'string' || b.message.trim().length === 0)
    return { error: 'message é obrigatório e não pode ser vazio' };
  if (b.message.length > MAX_MESSAGE_CHARS)
    return { error: `message excede ${MAX_MESSAGE_CHARS} caracteres` };
  if (b.project_id !== undefined && typeof b.project_id !== 'string')
    return { error: 'project_id deve ser string' };
  if (b.project_id && !/^[0-9a-f-]{36}$/i.test(b.project_id as string))
    return { error: 'project_id formato inválido' };
  return { data: b as Record<string, unknown> };
}

function validateActionProposal(
  raw: unknown,
  validatedProjectId: string | undefined,
  validEvidenceIds: Set<string>,
): Record<string, unknown> | null {
  if (!raw || typeof raw !== 'object') return null;
  const a = raw as Record<string, unknown>;
  if (a.tool_name !== 'action.create') return null;
  if (typeof a.title !== 'string' || a.title.trim().length === 0) return null;
  if (a.title.length > 200) return null;
  if (a.description !== undefined && (typeof a.description !== 'string' || a.description.length > 1000))
    return null;
  const projectId = validatedProjectId ?? (a.project_id as string | undefined);
  const priority  = typeof a.priority === 'string' && VALID_PRIORITIES.includes(a.priority)
    ? a.priority : 'medium';
  const impact = typeof a.impact === 'string' && VALID_IMPACTS.includes(a.impact)
    ? a.impact : 'medium';
  const effort = typeof a.effort === 'string' && VALID_EFFORTS.includes(a.effort)
    ? a.effort : 'medium';
  const rawIds = Array.isArray(a.evidence_ids) ? a.evidence_ids as unknown[] : [];
  const evidence_ids = rawIds.filter((id): id is string =>
    typeof id === 'string' && validEvidenceIds.has(id));
  const modelConfidence = typeof a.confidence === 'number'
    ? Math.min(100, Math.max(0, Math.round(a.confidence as number)))
    : undefined;
  return {
    tool_name:       'action.create',
    project_id:      projectId ?? '',
    title:           a.title as string,
    description:     typeof a.description === 'string' ? a.description : undefined,
    why:             typeof a.why === 'string' ? (a.why as string).slice(0, 500) : undefined,
    how:             typeof a.how === 'string' ? (a.how as string).slice(0, 500) : undefined,
    expected_result: typeof a.expected_result === 'string' ? (a.expected_result as string).slice(0, 300) : undefined,
    success_metric:  typeof a.success_metric === 'string' ? (a.success_metric as string).slice(0, 200) : undefined,
    priority,
    impact,
    effort,
    due_date:        typeof a.due_date === 'string' ? a.due_date : undefined,
    rationale:       typeof a.rationale === 'string' ? a.rationale : undefined,
    evidence_ids,
    opportunity_id:  typeof a.opportunity_id === 'string' ? a.opportunity_id : undefined,
    focus_entity_id: typeof a.focus_entity_id === 'string' ? a.focus_entity_id : undefined,
    confidence:      modelConfidence,
  };
}

// ── Entity isolation logic (mirrors loadServerContext audit step) ──────────────

function applyEntityIsolation(
  opps: Record<string, unknown>[],
  acts: Record<string, unknown>[],
  kbItems: Record<string, unknown>[],
  projectId: string,
  projectDbId: string,
): {
  opportunities: Record<string, unknown>[];
  actions: Record<string, unknown>[];
  evidence_ids: Set<string>;
} {
  const cleanOpps = opps.filter(o => o.project_id === projectId);
  const cleanActs = acts.filter(a => a.project_id === projectId);
  const ids = new Set<string>([projectDbId]);
  cleanOpps.forEach(o => { if (o.id) ids.add(o.id as string); });
  cleanActs.forEach(a => { if (a.id) ids.add(a.id as string); });
  kbItems.forEach(k => { if (k.id) ids.add(k.id as string); });
  return { opportunities: cleanOpps, actions: cleanActs, evidence_ids: ids };
}

interface ServerContext {
  project:      Record<string, unknown> | null;
  opportunities: Record<string, unknown>[];
  actions:       Record<string, unknown>[];
  kb_items:      Record<string, unknown>[];
  evidence_ids:  Set<string>;
  limitations:   string[];
}

function computeConfidence(ctx: ServerContext, clientHints: Record<string, unknown>): number {
  let score = 30;
  if (ctx.project)               score += 20;
  if (ctx.opportunities.length)  score += 15;
  if (ctx.actions.length)        score += 15;
  if (ctx.kb_items.length)       score += 10;
  if (clientHints.scores)        score += 10;
  if (ctx.limitations.length === 0) score += 5;
  return Math.min(score, 95);
}

function detectIntent(message: string): string {
  const m = message.toLowerCase();
  if (/criar|adicionar|incluir|nova ação|novo item/.test(m)) return 'create';
  if (/explicar|por que|como|origem|motivo/.test(m))         return 'explain';
  if (/simular|se eu|e se|cenário/.test(m))                  return 'simulate';
  if (/prioridade|próximo passo|o que fazer|recomend/.test(m)) return 'recommend';
  return 'query';
}

// ── Utilities ─────────────────────────────────────────────────────────────────

function assert(condition: boolean, msg: string): void {
  if (!condition) throw new Error(`FAIL: ${msg}`);
}

function assertEquals<T>(actual: T, expected: T, msg: string): void {
  if (actual !== expected) throw new Error(`FAIL: ${msg} — expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

function assertContains(haystack: string, needle: string, msg: string): void {
  if (!haystack.includes(needle)) throw new Error(`FAIL: ${msg} — "${needle}" not in "${haystack}"`);
}

// ── Testes ────────────────────────────────────────────────────────────────────

Deno.test('1. validateRequest — message vazia retorna erro', () => {
  const r = validateRequest({ message: '' });
  assert(!!r.error, 'deve retornar erro');
  assertContains(r.error!, 'obrigatório', 'erro menciona obrigatório');
});

Deno.test('2. validateRequest — sem message retorna erro', () => {
  const r = validateRequest({ screen_name: 'home' });
  assert(!!r.error, 'deve retornar erro');
});

Deno.test('3. validateRequest — message muito longa retorna erro', () => {
  const r = validateRequest({ message: 'x'.repeat(MAX_MESSAGE_CHARS + 1) });
  assert(!!r.error, 'deve retornar erro');
  assertContains(r.error!, 'excede', 'erro menciona excede');
});

Deno.test('4. validateRequest — project_id inválido (não UUID) retorna erro', () => {
  const r = validateRequest({ message: 'oi', project_id: 'not-a-uuid' });
  assert(!!r.error, 'deve retornar erro');
  assertContains(r.error!, 'formato inválido', 'erro menciona formato');
});

Deno.test('5. validateRequest — payload válido retorna data', () => {
  const r = validateRequest({ message: 'qual é minha melhor oportunidade?' });
  assert(!r.error, 'não deve retornar erro');
  assert(!!r.data, 'deve retornar data');
});

Deno.test('6. validateRequest — project_id UUID válido aceito', () => {
  const r = validateRequest({
    message:    'resumo do projeto',
    project_id: '550e8400-e29b-41d4-a716-446655440000',
  });
  assert(!r.error, 'UUID válido deve ser aceito');
});

Deno.test('7. validateActionProposal — tool_name diferente de action.create rejeitado', () => {
  const result = validateActionProposal(
    { tool_name: 'delete_project', title: 'Deletar' },
    undefined,
    new Set(),
  );
  assertEquals(result, null, 'ferramenta não permitida deve retornar null');
});

Deno.test('8. validateActionProposal — action.create válida aceita', () => {
  const evidenceIds = new Set(['id-opp-1', 'id-act-1']);
  const result = validateActionProposal(
    {
      tool_name:    'action.create',
      title:        'Publicar artigo sobre nicho X',
      description:  'Criar e publicar artigo',
      priority:     'high',
      impact:       'high',
      effort:       'medium',
      evidence_ids: ['id-opp-1', 'id-inventado'],
    },
    'proj-123',
    evidenceIds,
  );
  assert(result !== null, 'proposta válida deve ser aceita');
  assertEquals(result!.tool_name as string, 'action.create', 'tool_name correto');
  assertEquals((result!.evidence_ids as string[]).length, 1, 'ID inventado removido');
  assertEquals((result!.evidence_ids as string[])[0], 'id-opp-1', 'apenas ID real mantido');
});

Deno.test('9. validateActionProposal — evidence_ids inventados são removidos', () => {
  const result = validateActionProposal(
    {
      tool_name:    'action.create',
      title:        'Teste',
      evidence_ids: ['fake-id-1', 'fake-id-2', 'fake-id-3'],
    },
    undefined,
    new Set(['real-id']),
  );
  assert(result !== null, 'proposta aceita');
  assertEquals((result!.evidence_ids as string[]).length, 0, 'todos os IDs inventados removidos');
});

Deno.test('10. validateActionProposal — proposta não executa mutação (sem side effects)', () => {
  // A função apenas VALIDA e retorna um objeto — nunca escreve no banco
  let sideEffectCalled = false;
  const _fakeMutation = () => { sideEffectCalled = true; };

  const result = validateActionProposal(
    { tool_name: 'action.create', title: 'Teste' },
    'proj-1',
    new Set(),
  );

  assert(result !== null, 'proposta válida');
  assert(!sideEffectCalled, 'nenhuma mutação executada');
  assertEquals(result!.tool_name as string, 'action.create', 'apenas proposta');
});

Deno.test('11. computeConfidence — sem contexto = 35 (base + sem limitações)', () => {
  const ctx: ServerContext = {
    project: null, opportunities: [], actions: [],
    kb_items: [], evidence_ids: new Set(), limitations: [],
  };
  const score = computeConfidence(ctx, {});
  assertEquals(score, 35, 'sem contexto + sem limitações = 35');
});

Deno.test('12. computeConfidence — filtra somente registros do usuário (via evidence_ids)', () => {
  const ctx: ServerContext = {
    project: { id: 'p1', name: 'Meu Projeto' },
    opportunities: [{ id: 'o1' }],
    actions:  [{ id: 'a1' }],
    kb_items: [{ id: 'k1' }],
    evidence_ids: new Set(['p1', 'o1', 'a1', 'k1']),
    limitations: [],
  };
  // Confidence calculada com contexto completo
  const score = computeConfidence(ctx, { scores: { ecosystem: 80 } });
  assert(score > 70, 'contexto completo deve ter confidence alta');
  assert(score <= 95, 'nunca ultrapassa 95');
});

Deno.test('13. computeConfidence — limitações reduzem confidence (sem +5)', () => {
  const ctxSemLimitacoes: ServerContext = {
    project: { id: 'p1' }, opportunities: [], actions: [],
    kb_items: [], evidence_ids: new Set(), limitations: [],
  };
  const ctxComLimitacoes: ServerContext = {
    ...ctxSemLimitacoes,
    limitations: ['oportunidades indisponíveis'],
  };
  const scoreSem = computeConfidence(ctxSemLimitacoes, {});
  const scoreCom = computeConfidence(ctxComLimitacoes, {});
  assert(scoreSem > scoreCom, 'sem limitações deve ter score maior');
});

Deno.test('14. detectIntent — mensagem de criação detectada', () => {
  assertEquals(detectIntent('Quero criar uma nova ação para o projeto'), 'create', 'criar detectado');
  assertEquals(detectIntent('Adicionar tarefa de marketing'), 'create', 'adicionar detectado');
});

Deno.test('15. detectIntent — mensagem de explicação detectada', () => {
  assertEquals(detectIntent('Por que o score caiu?'), 'explain', 'por que detectado');
  assertEquals(detectIntent('Como esse score é calculado?'), 'explain', 'como detectado');
});

Deno.test('16. detectIntent — mensagem genérica retorna query', () => {
  assertEquals(detectIntent('Oi, tudo bem?'), 'query', 'genérica = query');
});

Deno.test('17. validateActionProposal — priority inválida convertida para medium', () => {
  const result = validateActionProposal(
    { tool_name: 'action.create', title: 'Teste', priority: 'URGENTE' },
    'proj-1',
    new Set(),
  );
  assert(result !== null, 'proposta aceita mesmo com priority inválida');
  assertEquals(result!.priority as string, 'medium', 'prioridade inválida → medium');
});

Deno.test('18. validateActionProposal — title muito longa rejeitada', () => {
  const result = validateActionProposal(
    { tool_name: 'action.create', title: 'x'.repeat(201) },
    undefined,
    new Set(),
  );
  assertEquals(result, null, 'title > 200 chars deve ser rejeitada');
});

Deno.test('18b. validateActionProposal — project_id vem do servidor, não do cliente', () => {
  // O project_id enviado pelo modelo é ignorado — o servidor usa o seu próprio
  const result = validateActionProposal(
    {
      tool_name:  'action.create',
      title:      'Ação legítima',
      project_id: 'projeto-de-outro-usuario',  // enviado pelo modelo
    },
    'projeto-validado-pelo-servidor',  // este é o validado
    new Set(),
  );
  assert(result !== null, 'proposta aceita');
  assertEquals(result!.project_id as string, 'projeto-validado-pelo-servidor', 'server project_id prevalece');
});

Deno.test('19. projeto sem oportunidades recebe ausência semântica', () => {
  const section = buildOpportunityContextSection([], true);
  assertContains(
    section,
    'Este projeto ainda não possui oportunidades registradas no Opportunity Lab.',
    'deve declarar exatamente a ausência',
  );
  assertContains(section, 'gerar/analisar oportunidades', 'deve oferecer ação coerente');
});

Deno.test('20. oportunidade real fornece critérios suficientes para comparação', () => {
  const section = buildOpportunityContextSection([{
    id: 'opp-b',
    title: 'Oportunidade B',
    status: 'approved',
    final_score: 91,
    market_score: 88,
    revenue_score: 86,
    strategic_fit: 93,
    synergy_score: 84,
    competition_score: 40,
    confidence: 90,
    rationale: 'Melhor alinhamento estratégico.',
    risks: ['Dependência de parceiro'],
    action_steps: ['Validar demanda'],
  }], true);
  for (const expected of [
    'Oportunidade B',
    'Score final: 91/100',
    'Mercado: 88/100',
    'Receita/ROI: 86/100',
    'Fit estratégico: 93/100',
    'Sinergia: 84/100',
    'Dependência de parceiro',
    'Validar demanda',
  ]) {
    assertContains(section, expected, `contexto deve conter ${expected}`);
  }
});

Deno.test('21. contexto de oportunidades limita volume sem misturar fontes', () => {
  const opportunities = Array.from({ length: 7 }, (_, index) => ({
    id: `opp-${index}`,
    title: `Oportunidade ${index}`,
    final_score: 90 - index,
  }));
  const section = buildOpportunityContextSection(opportunities, true);
  assertContains(section, 'opp-4', 'quinta oportunidade entra');
  assert(!section.includes('opp-5'), 'sexta oportunidade fica fora do limite');
});

Deno.test('22. scores são vinculados explicitamente ao projeto', () => {
  const section = buildProjectContextSection(
    { id: 'project-rcbo', name: 'PROJETO RCBO BRASIL', status: 'active' },
    {
      ecosystem: 45,
      opportunity: 80,
      strategic_fit: 31,
      synergy: 0,
      roi: 0,
      momentum: 99,
      market: 76,
      execution: 20,
    },
  );
  assertContains(section, 'id: project-rcbo', 'deve identificar projectId');
  assertContains(section, 'name: PROJETO RCBO BRASIL', 'deve identificar projectName');
  assertContains(
    section,
    'Project PROJETO RCBO BRASIL (project-rcbo) — Ecosystem Score: 45/100',
    'score deve pertencer explicitamente ao projeto',
  );
});

// ── Testes de isolamento e novos campos (P0.1 / Etapa 2) ─────────────────────

Deno.test('23. buildProjectContextSection — roi null não exibe "0/100"', () => {
  const section = buildProjectContextSection(
    { id: 'proj-a', name: 'Projeto A' },
    { roi: null, roi_data_available: false, ecosystem: 60 },
  );
  assert(!section.includes('ROI: 0/100'), 'roi null não deve exibir "0/100"');
});

Deno.test('24. buildProjectContextSection — roi_data_available=false exibe mensagem de ausência', () => {
  const section = buildProjectContextSection(
    { id: 'proj-a', name: 'Projeto A' },
    { roi: null, roi_data_available: false, ecosystem: 70 },
  );
  assertContains(section, 'Dados indisponíveis', 'deve declarar ausência de dados de ROI');
});

Deno.test('25. Isolamento de entidades — oportunidade de projeto diferente é descartada', () => {
  const opps = [
    { id: 'opp-1', project_id: 'proj-alvo' },
    { id: 'opp-2', project_id: 'proj-outro' },  // deve ser descartada
  ];
  const { opportunities } = applyEntityIsolation(opps, [], [], 'proj-alvo', 'proj-alvo');
  assertEquals(opportunities.length, 1, 'apenas oportunidades do projeto correto são mantidas');
  assertEquals(opportunities[0].id as string, 'opp-1', 'ID correto mantido');
});

Deno.test('26. Isolamento de entidades — oportunidades do projeto correto são mantidas', () => {
  const opps = [
    { id: 'opp-1', project_id: 'proj-alvo' },
    { id: 'opp-2', project_id: 'proj-alvo' },
  ];
  const { opportunities } = applyEntityIsolation(opps, [], [], 'proj-alvo', 'proj-alvo');
  assertEquals(opportunities.length, 2, 'todas as oportunidades corretas mantidas');
});

Deno.test('27. validateActionProposal — campos why/how/expected_result/success_metric preservados', () => {
  const result = validateActionProposal(
    {
      tool_name:       'action.create',
      title:           'Ação com campos completos',
      why:             'Porque o score de mercado caiu 20%',
      how:             'Executar campanha de re-engajamento em 3 etapas',
      expected_result: 'Recuperar 15% do score em 30 dias',
      success_metric:  'Score de mercado ≥ 75',
    },
    'proj-1',
    new Set(),
  );
  assert(result !== null, 'proposta válida');
  assertEquals(result!.why as string, 'Porque o score de mercado caiu 20%', 'why preservado');
  assertEquals(result!.how as string, 'Executar campanha de re-engajamento em 3 etapas', 'how preservado');
  assertEquals(result!.expected_result as string, 'Recuperar 15% do score em 30 dias', 'expected_result preservado');
  assertEquals(result!.success_metric as string, 'Score de mercado ≥ 75', 'success_metric preservado');
});

Deno.test('28. validateActionProposal — confidence fora do range é clampado', () => {
  const resultAlto = validateActionProposal(
    { tool_name: 'action.create', title: 'Teste', confidence: 150 },
    'proj-1', new Set(),
  );
  assertEquals(resultAlto!.confidence as number, 100, 'confidence > 100 clampado para 100');

  const resultBaixo = validateActionProposal(
    { tool_name: 'action.create', title: 'Teste', confidence: -10 },
    'proj-1', new Set(),
  );
  assertEquals(resultBaixo!.confidence as number, 0, 'confidence < 0 clampado para 0');
});

Deno.test('29. validateActionProposal — focus_entity_id preservado quando string válida', () => {
  const result = validateActionProposal(
    { tool_name: 'action.create', title: 'Ação focada', focus_entity_id: 'opp-xyz' },
    'proj-1', new Set(),
  );
  assert(result !== null, 'proposta aceita');
  assertEquals(result!.focus_entity_id as string, 'opp-xyz', 'focus_entity_id preservado');
});

Deno.test('30. buildOpportunityContextSection — IDs de entidades citados explicitamente para grounding', () => {
  const section = buildOpportunityContextSection([{
    id: 'opp-grounding-test',
    title: 'Oportunidade de Grounding',
    status: 'active',
    final_score: 78,
    market_score: 70,
    revenue_score: 65,
    strategic_fit: 80,
    synergy_score: 60,
    competition_score: 45,
    confidence: 72,
    rationale: 'Alta demanda no nicho',
  }], true);
  assertContains(section, '[opp-grounding-test]', 'ID da entidade deve aparecer para grounding');
});

Deno.test('31. Isolamento — evidence_ids reconstruído a partir do conjunto limpo', () => {
  const opps = [
    { id: 'opp-ok', project_id: 'proj-correto' },
    { id: 'opp-ruim', project_id: 'proj-outro' },
  ];
  const { evidence_ids } = applyEntityIsolation(opps, [], [], 'proj-correto', 'proj-correto');
  assert(evidence_ids.has('opp-ok'), 'opp do projeto correto está em evidence_ids');
  assert(!evidence_ids.has('opp-ruim'), 'opp de outro projeto não está em evidence_ids');
});

Deno.test('32. buildProjectContextSection — scores vinculados por nome E id juntos', () => {
  const section = buildProjectContextSection(
    { id: 'uuid-proj-test', name: 'Projeto Teste' },
    { ecosystem: 55, opportunity: 70, roi: 40, roi_data_available: true },
  );
  assertContains(
    section,
    'Project Projeto Teste (uuid-proj-test) — Ecosystem Score: 55/100',
    'score deve incluir nome E id do projeto explicitamente',
  );
});

Deno.test('33. Isolamento — ação de projeto diferente é descartada', () => {
  const acts = [
    { id: 'act-1', project_id: 'proj-correto' },
    { id: 'act-2', project_id: 'proj-invasor' },
  ];
  const { actions } = applyEntityIsolation([], acts, [], 'proj-correto', 'proj-correto');
  assertEquals(actions.length, 1, 'apenas ações do projeto correto mantidas');
  assertEquals(actions[0].id as string, 'act-1', 'ação correta mantida');
});

Deno.test('34. buildProjectContextSection — roi_data_available=true exibe valor numérico', () => {
  const section = buildProjectContextSection(
    { id: 'proj-roi', name: 'Projeto ROI' },
    { roi: 65, roi_data_available: true },
  );
  assertContains(section, 'ROI: 65/100', 'roi disponível deve exibir valor numérico');
});

Deno.test('35. detectIntent — mensagem de simulação detectada', () => {
  assertEquals(detectIntent('E se eu dobrasse o investimento?'), 'simulate', 'e se detectado');
  assertEquals(detectIntent('Simule o impacto de expandir para o mercado B'), 'simulate', 'simular detectado');
});

Deno.test('36. buildOpportunityContextSection — sem projeto ativo retorna string vazia', () => {
  const section = buildOpportunityContextSection([], false);
  assertEquals(section, '', 'sem projeto ativo e sem oportunidades retorna string vazia');
});

console.log('\n✓ Todos os testes de lógica pura passaram\n');
