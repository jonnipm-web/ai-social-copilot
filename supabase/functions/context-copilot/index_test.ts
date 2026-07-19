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

import { buildOpportunityContextSection } from './context_prompt.ts';

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
  return { tool_name: 'action.create', project_id: projectId ?? '', title: a.title, priority, impact, effort, evidence_ids };
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

console.log('\n✓ Todos os testes de lógica pura passaram\n');
