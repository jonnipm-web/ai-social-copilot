# SHOW_01A_PRE_IMPLEMENTATION_AUDIT.md
# PROJECT INTELLIGENCE CONTENT GROUNDING — Auditoria Pré-Implementação

**Data:** 2026-08-14  
**Branch:** `claude/insightvalues-showcase-audit-ebsqhi`  
**Commit HEAD no momento da auditoria:** `4601a98`  
**Auditor:** Claude (claude-sonnet-4-6)  
**Status:** AUDITORIA CONCLUÍDA — IMPLEMENTAÇÃO PENDENTE

---

## SUMÁRIO EXECUTIVO

O conteúdo dos documentos do Knowledge Vault **existe no banco de dados** mas é **silenciosamente descartado** na camada de provider Flutter antes de chegar ao LLM. O modelo de linguagem recebe apenas títulos e status — nunca o texto real dos documentos. O problema é arquitetural, não de armazenamento.

**Princípio violado:**  
`DOCUMENT EXISTS ≠ DOCUMENT ANALYZED`  
`METADATA ≠ KNOWLEDGE`

**Nenhuma migration de banco é necessária.** O campo `knowledge_items.content` já existe, já é populado e já é retornado pelo service. O fix é inteiramente na camada de aplicação e edge function.

---

## 1. FLUXO ATUAL (estado pré-fix)

```
[DB: knowledge_items.content]
         │
         ▼
KnowledgeService.fetchAll()          → retorna KnowledgeItem COM content ✓
         │
         ▼
ive_context_provider.dart            → constrói knowledgeSummary
  knowledgeSorted.take(5).map((k) => {
    'title':  k.title,
    'score':  k.opportunityScore,
    'status': k.status,
    if (k.niche != null) 'niche': k.niche,
    // k.content EXISTE mas é OMITIDO  ← ROOT CAUSE
  })
         │
         ▼
IveContextData.knowledgeItemsSummary → List<Map> sem content
         │
         ▼
ive_overlay.dart._buildCopilotContext()
  CopilotContextData(
    documents: ctx.knowledgeItemsSummary,  ← apenas metadados
    ...
  )
         │
         ▼
CopilotContextData.toMap()           → serializa sem content
         │
         ▼
context_copilot_provider.dart        → envia context.toMap() para edge function
         │
         ▼
context-copilot/index.ts (Groq)
  const docs = ctx.documents
    .slice(0, 5)
    .map(d => `• ${d.title} [${d.status}]`)  ← LLM vê APENAS título e status
         │
         ▼
LLM (llama-3.3-70b-versatile)        → NUNCA recebe o conteúdo do documento
```

**Resultado:** A IVE pode afirmar "analisei seus documentos" com base zero no conteúdo real — violação direta do princípio de grounding.

---

## 2. ARQUIVOS ENVOLVIDOS

### 2.1 Arquivos com problema confirmado (a modificar)

| Arquivo | Linha(s) | Problema |
|---------|----------|----------|
| `lib/providers/ive_context_provider.dart` | ~70–75 | `k.content` omitido ao construir `knowledgeSummary` |
| `lib/data/models/copilot_context_data.dart` | — | Sem campos `documentCoverage`, `documentWarnings` |
| `lib/shared/widgets/ive_overlay.dart` | ~192 | Passa apenas `ctx.knowledgeItemsSummary` (sem grounding) |
| `supabase/functions/context-copilot/index.ts` | 46–51 | Renderiza `• ${d.title} [${d.status}]` sem excerpts; sem grounding contract no system prompt |

### 2.2 Arquivos novos a criar

| Arquivo | Tipo | Finalidade |
|---------|------|------------|
| `lib/data/models/document_grounding.dart` | Model | `DocumentExcerpt`, `GroundingCoverage`, `GroundingWarning`, `DocumentGrounding` |
| `lib/data/services/document_context_builder.dart` | Service | Chunker, relevance selector, coverage calculator, source manifest |

### 2.3 Arquivos lidos e confirmados SEM problema (não modificar)

| Arquivo | Conclusão |
|---------|-----------|
| `lib/data/models/knowledge_item.dart` | `content: String` existe (linha 13/47) — OK |
| `lib/data/services/knowledge_service.dart` | `fetchAll()` retorna content completo — OK |
| `lib/providers/knowledge_provider.dart` | `knowledgeItemsByProjectProvider` (family) existe e funciona — OK |
| `supabase/functions/process-file/index.ts` | Extrai e armazena text corretamente — OK |
| `supabase/migrations/003_knowledge_vault.sql` | `content TEXT NOT NULL DEFAULT ''` confirmado — OK |
| `supabase/migrations/020_p0_stabilization_fixes.sql` | `project_id` já existe em `knowledge_items` — OK |
| `supabase/functions/gap-analysis/index.ts` | Função de mercado puro — isolamento por design, não bug |

---

## 3. MODELOS E TABELAS RELEVANTES

### 3.1 Modelo Flutter: `KnowledgeItem`

```dart
// lib/data/models/knowledge_item.dart
class KnowledgeItem {
  final String id;
  final String userId;
  final String title;
  final String sourceType;      // manual | url | file
  final String? sourceUrl;
  final String? fileName;
  final String content;         // ← EXISTE, POPULADO, MAS DESCARTADO
  final String? niche;
  final String? targetAudience;
  final String language;
  final String? personaId;
  final String status;          // pending | processing | analyzed | error
  final String? projectId;      // ← adicionado em migration 020
  // ... opportunityScore, autoTitle, etc.
}
```

### 3.2 Modelo Flutter: `KnowledgeAnalysis`

```dart
// lib/data/models/knowledge_analysis.dart
class KnowledgeAnalysis {
  final String id;
  final String knowledgeItemId;
  final String userId;
  final String? summary;        // ← resumo AI-processado do documento
  final String? projectId;
  // ... keywords, topics, contentPillars, etc.
}
```

### 3.3 Tabelas relevantes (Supabase)

| Tabela | Campo crítico | Tipo | Status |
|--------|---------------|------|--------|
| `knowledge_items` | `content` | `TEXT NOT NULL DEFAULT ''` | Populado |
| `knowledge_items` | `project_id` | `UUID REFERENCES projects(id)` | Populado (migration 020) |
| `knowledge_analysis` | `summary` | `TEXT` | Populado quando `status = 'analyzed'` |
| `knowledge_analysis` | `project_id` | `UUID` | Populado (migration 020) |

### 3.4 RLS (Row Level Security) — PRESERVAR

```sql
-- knowledge_items: apenas registros do próprio usuário
CREATE POLICY "ki_select_own" ON public.knowledge_items
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
```

O fix não altera RLS. O `KnowledgeService.fetchAll()` já opera sob RLS — o content que retorna é sempre do usuário autenticado.

---

## 4. CAUSA RAIZ CONFIRMADA

### 4.1 Causa Primária — Descarte silencioso do content

**Localização:** `lib/providers/ive_context_provider.dart`, linhas ~70–75

**Código atual (problema):**
```dart
final knowledgeSummary = knowledgeSorted.take(5).map((k) => {
  'title':  k.title,
  'score':  k.opportunityScore,
  'status': k.status,
  if (k.niche != null) 'niche': k.niche,
  // k.content EXISTE mas NUNCA é incluído
}).toList();
```

**Por que é crítico:** Este é o único ponto onde `KnowledgeItem` (com content) é transformado em `Map<String, dynamic>` para o pipeline do copilot. A omissão aqui propaga para todos os componentes downstream.

### 4.2 Causa Secundária — Seleção global, sem filtro por projeto

**Localização:** `lib/providers/ive_context_provider.dart`

O provider usa `knowledgeItemsProvider` (todos os itens) em vez de `knowledgeItemsByProjectProvider(projectId)`. Os top-5 por `opportunityScore` podem ser de projetos diferentes do contexto ativo.

### 4.3 Causa Terciária — Falta de grounding contract no system prompt

**Localização:** `supabase/functions/context-copilot/index.ts`, system prompt

O LLM não recebe instrução para distinguir o que foi analisado do que não foi. Sem essa instrução, o modelo pode — e tende a — afirmar análise de documentos que não estão em contexto.

---

## 5. IMPACTOS (estado atual)

| Impacto | Gravidade | Evidência |
|---------|-----------|-----------|
| IVE afirma análise de documentos sem ter processado o conteúdo | CRÍTICO | Código confirmado |
| Copilot context não reflete projeto ativo (seleção global top-5) | ALTO | Código confirmado |
| Nenhuma cobertura de documento é rastreada ou reportável | MÉDIO | Ausência de campo |
| Usuário não pode verificar quais documentos influenciaram a resposta | MÉDIO | Ausência de source manifest |
| gap-analysis não usa documentos do projeto (por design, aceitável) | INFO | Por design |

---

## 6. RISCOS DE REGRESSÃO

| Risco | Mitigação |
|-------|-----------|
| Incluir `content` bruto pode exceder `max_tokens: 800` da Groq | Implementar `MAX_DOCUMENT_CONTEXT_CHARS` com chunking + truncamento |
| Mudar estrutura de `CopilotContextData` pode quebrar edge function | Adicionar campos opcionais; edge function deve ser defensiva com `?? []` |
| Filtro por projeto pode resultar em zero documentos (projeto sem itens) | Fallback gracioso: usar top itens globais se nenhum item vinculado ao projeto |
| Grounding contract no system prompt pode reduzir max_tokens disponível | Calcular orçamento: system prompt ~ 600 tokens, reservar 200 para grounding |
| `knowledgeItemsByProjectProvider` requer `projectId` não-nulo | Guard: verificar `ctx.project?.id` antes de usar; fallback para provider global |
| Alterações em `ive_context_provider.dart` podem afetar outras telas | Provider é watch-only; modificar apenas o mapeamento de `knowledgeSummary` |

---

## 7. PLANO MÍNIMO DE ALTERAÇÃO

### Princípio: REUTILIZAR > ESTENDER > CRIAR

**Sem:** nova tabela, nova edge function, RAG, embeddings, vector DB, nova migration.  
**Com:** 2 arquivos novos + 4 arquivos modificados.

### Passo 1 — Criar modelo `DocumentGrounding`

**Arquivo:** `lib/data/models/document_grounding.dart` (NOVO)

Structs necessárias:
- `DocumentExcerpt` — trecho de texto com índice de chunk, tamanho, relevância
- `GroundingCoverage` — métricas: totalLinked, processed, usable, used, documentUsageCoverage
- `GroundingWarning` — mensagem de aviso (ex: "3 documentos vinculados mas sem content processável")
- `DocumentGrounding` — objeto raiz: excerpts + coverage + warnings + sourceManifest

### Passo 2 — Criar serviço `DocumentContextBuilder`

**Arquivo:** `lib/data/services/document_context_builder.dart` (NOVO)

Responsabilidades:
- `chunk(content, maxChunkSize, overlap)` → `List<String>` (determinístico)
- `selectRelevant(chunks, context, maxChars)` → chunks por keyword overlap (sem embeddings)
- `buildGrounding(items, projectContext, maxChars)` → `DocumentGrounding`
- Constante: `MAX_DOCUMENT_CONTEXT_CHARS = 8000` (≈ 2000 tokens)

### Passo 3 — Modificar `ive_context_provider.dart`

**Mudança:** Incluir `content` truncado (primeiro chunk) no knowledgeSummary + filtrar por projeto quando `projectId` disponível.

```dart
// ANTES
'status': k.status,
// FIM

// DEPOIS  
'status': k.status,
if (k.content.isNotEmpty) 'content_excerpt': k.content.substring(0, min(500, k.content.length)),
```

Usar `knowledgeItemsByProjectProvider(projectId)` quando projeto ativo tiver ID; fallback para global.

### Passo 4 — Modificar `copilot_context_data.dart`

**Mudança:** Adicionar campos opcionais `documentCoverage` e `documentWarnings` no modelo e em `toMap()`.

### Passo 5 — Modificar `ive_overlay.dart`

**Mudança:** Montar `DocumentGrounding` via `DocumentContextBuilder` e passar `documentCoverage` e `documentWarnings` no `CopilotContextData`.

### Passo 6 — Modificar `context-copilot/index.ts`

**Mudança:**
1. Renderizar `content_excerpt` se presente: `• ${d.title} [${d.status}] — ${d.content_excerpt}`
2. Adicionar grounding contract ao system prompt:
   ```
   GROUNDING RULE: Você SOMENTE pode afirmar que analisou um documento se seu
   conteúdo aparecer explicitamente nos dados acima. "Documento vinculado" ≠
   "documento analisado". Se o conteúdo não estiver nos dados, diga:
   "Este documento está registrado mas seu conteúdo não foi processado nesta análise."
   ```

### Resumo do plano

| # | Ação | Arquivo | Tipo |
|---|------|---------|------|
| 1 | Criar model de grounding | `lib/data/models/document_grounding.dart` | NOVO |
| 2 | Criar service de chunking/relevância | `lib/data/services/document_context_builder.dart` | NOVO |
| 3 | Incluir content_excerpt + filtro por projeto | `lib/providers/ive_context_provider.dart` | MODIFICAR |
| 4 | Adicionar campos de cobertura | `lib/data/models/copilot_context_data.dart` | MODIFICAR |
| 5 | Passar grounding no contexto | `lib/shared/widgets/ive_overlay.dart` | MODIFICAR |
| 6 | Renderizar excerpts + grounding contract | `supabase/functions/context-copilot/index.ts` | MODIFICAR |
| 7 | Testes T01–T20 | `test/data/services/document_context_builder_test.dart` | NOVO |

**Estimativa de impacto:** Baixo risco de regressão. Todos os campos adicionados são opcionais. Edge function usa `?? []` / `?? {}` defensivamente. Fallback preservado em cada etapa.

---

## 8. DEFINIÇÕES DE PRONTO (Critérios de Aceite)

- [ ] `DocumentContextBuilder` implementado e testado (T01–T20)
- [ ] `knowledgeItemsSummary` inclui `content_excerpt` quando content disponível
- [ ] Provider usa projeto ativo como filtro quando `projectId` presente
- [ ] `CopilotContextData` serializa `documentCoverage` e `documentWarnings`
- [ ] Edge function renderiza excerpts no system prompt do LLM
- [ ] Grounding contract presente no system prompt
- [ ] `MAX_DOCUMENT_CONTEXT_CHARS` respeitado (sem overflow de tokens)
- [ ] RLS preservado (nenhuma alteração em políticas ou migrations)
- [ ] Nenhuma nova Edge Function criada
- [ ] Nenhuma nova tabela criada
- [ ] Nenhum merge em main
- [ ] Nenhum deploy de produção

---

*Documento gerado como deliverable obrigatório de SHOW-01A, Seção 2 — Auditoria Pré-Implementação.*  
*Próximo passo: implementação dos 7 itens acima, seguida de SHOW_01A_PROJECT_INTELLIGENCE_GROUNDING_REPORT.md.*
