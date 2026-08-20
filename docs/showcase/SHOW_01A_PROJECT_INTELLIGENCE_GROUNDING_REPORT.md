# SHOW_01A_PROJECT_INTELLIGENCE_GROUNDING_REPORT.md
# PROJECT INTELLIGENCE CONTENT GROUNDING — Relatório de Implementação

**Data:** 2026-08-14  
**Branch:** `claude/insightvalues-showcase-audit-ebsqhi`  
**Status:** IMPLEMENTAÇÃO CONCLUÍDA

---

## SUMÁRIO EXECUTIVO

O problema de integridade epistêmica do InsightValues foi corrigido. A IVE (Inteligência Virtual Estratégica) agora distingue entre documentos **registrados** e documentos **analisados**. O conteúdo real dos documentos do Knowledge Vault entra no contexto do LLM. O modelo de linguagem recebe instrução explícita (grounding contract) para nunca afirmar análise de documentos cujo conteúdo não está em contexto.

**Princípio implementado:**  
`DOCUMENT EXISTS ≠ DOCUMENT ANALYZED`  
`METADATA ≠ KNOWLEDGE`

---

## ARQUIVOS CRIADOS

### 1. `lib/data/models/document_grounding.dart` (NOVO)

Structs que definem o contrato de grounding:

| Classe | Campos |
|--------|--------|
| `DocumentExcerpt` | `documentId`, `documentTitle`, `chunkIndex`, `text`, `charCount` |
| `GroundingCoverage` | `totalLinked`, `processed`, `usable`, `used`, `documentUsageCoverage` |
| `GroundingWarning` | `code`, `message` |
| `DocumentGrounding` | `excerpts`, `coverage`, `warnings`, `hasContent` |

Constantes estáticas `DocumentGrounding.empty` e `GroundingCoverage.empty` evitam null checks desnecessários.

### 2. `lib/data/services/document_context_builder.dart` (NOVO)

Serviço determinístico, sem chamadas de rede, 100% testável:

| Método | Responsabilidade |
|--------|-----------------|
| `chunk(content, maxSize, overlap)` | Divide texto em janelas sobrepostas de 800 chars com overlap de 100 |
| `relevanceScore(chunk, context)` | Proporção de palavras do contexto encontradas no chunk (sem embeddings) |
| `buildGrounding(items, projectContext, maxChars)` | Seleciona melhor chunk por relevância, respeita budget de 8000 chars, gera warnings |

**Budget:** `MAX_DOCUMENT_CONTEXT_CHARS = 8000` (~2000 tokens), `MAX_EXCERPT_CHARS = 500` por documento.

---

## ARQUIVOS MODIFICADOS

### 3. `lib/providers/ive_context_provider.dart`

**Mudanças:**
- Importado `KnowledgeItem` e `DocumentContextBuilder`
- Adicionados campos `documentCoverage: Map<String, dynamic>` e `documentWarnings: List<String>` ao modelo `IveContextData`
- Computação de `top` (projeto de maior score) movida para antes da seção de knowledge items, permitindo filtro por projeto
- Filtro in-memory: `knowledgeRaw.where((k) => k.projectId == projectId)` — usa projeto ativo; fallback para todos os itens se nenhum vinculado
- `DocumentContextBuilder.buildGrounding()` chamado sobre itens ordenados
- `knowledgeSummary` agora inclui `content_excerpt` quando disponível (grounded), ou apenas metadados (não grounded)

**Antes (problema):**
```dart
final knowledgeSummary = knowledgeSorted.take(5).map((k) => {
  'title':  k.title,
  'score':  k.opportunityScore,
  'status': k.status,
  // k.content NUNCA incluído
}).toList();
```

**Depois (correto):**
```dart
final excerptById = {for (final e in grounding.excerpts) e.documentId: e};
final knowledgeSummary = knowledgeSorted.take(5).map((k) {
  final excerpt = excerptById[k.id];
  return <String, dynamic>{
    'title':  k.title,
    'score':  k.opportunityScore,
    'status': k.status,
    if (k.niche != null) 'niche': k.niche,
    if (excerpt != null) 'content_excerpt': excerpt.text,  // ← GROUNDED
  };
}).toList();
```

### 4. `lib/data/models/copilot_context_data.dart`

Adicionados dois campos opcionais:
- `documentCoverage: Map<String, dynamic>?` — métricas de cobertura (total, processados, usados)
- `documentWarnings: List<String>` — avisos de grounding para o LLM

Ambos incluídos em `toMap()` condicionalmente (sem quebrar o contrato existente).

### 5. `lib/shared/widgets/ive_overlay.dart`

`_buildCopilotContext()` agora passa `documentCoverage` e `documentWarnings` para `CopilotContextData`:
```dart
documentCoverage: ctx.documentCoverage.isNotEmpty ? ctx.documentCoverage : null,
documentWarnings: ctx.documentWarnings,
```

### 6. `supabase/functions/context-copilot/index.ts`

**Mudança 1 — Renderização de documentos:**

Antes: `• ${d.title} [${d.status}]` (apenas título e status)  
Depois:
- Com content: `• ${d.title} [${d.status}] ✓ grounded\n  Trecho: "..."`
- Sem content: `• ${d.title} [${d.status}] ⚠ sem conteúdo processado`
- Header inclui contagem: `DOCUMENTOS (N vinculados, M com conteúdo analisado)`

**Mudança 2 — Grounding contract no system prompt:**

```
## CONTRATO DE GROUNDING — REGRA ABSOLUTA

Você SOMENTE pode afirmar que analisou ou leu o conteúdo de um documento se esse
conteúdo aparecer explicitamente na seção "DOCUMENTOS" acima, marcado com ✓ grounded
e com um trecho visível.

Documentos marcados com ⚠ sem conteúdo processado estão REGISTRADOS mas NÃO ANALISADOS.
DOCUMENT EXISTS ≠ DOCUMENT ANALYZED. METADATA ≠ KNOWLEDGE.
```

---

## TESTES T01–T20

**Arquivo:** `test/data/services/document_context_builder_test.dart`

| Teste | Descrição | Cobertura |
|-------|-----------|-----------|
| T01 | `chunk('')` retorna `[]` | chunk() base case |
| T02 | String < maxSize → 1 chunk | chunk() single |
| T03 | String > maxSize → múltiplos chunks | chunk() splitting |
| T04 | Overlap correto entre chunks adjacentes | chunk() overlap |
| T05 | `relevanceScore('...', '')` → 0.0 | relevance empty context |
| T06 | `relevanceScore('', '...')` → 0.0 | relevance empty chunk |
| T07 | Palavras curtas (≤3 chars) ignoradas | relevance filter |
| T08 | Match parcial retorna valor positivo ≤ 1.0 | relevance score |
| T09 | Lista vazia → `DocumentGrounding.empty` | buildGrounding empty |
| T10 | Content vazio → warning `EMPTY_CONTENT` | buildGrounding warning |
| T11 | Content presente → excerpt gerado | buildGrounding excerpt |
| T12 | Excerpt truncado a `maxExcerptChars` | buildGrounding truncation |
| T13 | Budget excedido → warning `BUDGET_EXCEEDED` | buildGrounding budget |
| T14 | Métricas de coverage corretas (2 itens, 1 vazio) | buildGrounding metrics |
| T15 | `documentUsageCoverage` = 0.0 para lista vazia | buildGrounding zero |
| T16 | Com `projectContext` seleciona chunk relevante | buildGrounding relevance |
| T17 | Múltiplos itens → múltiplos excerpts | buildGrounding multi |
| T18 | `charCount` bate com `text.length` | buildGrounding charCount |
| T19 | Status `pending` com content vazio → aviso | buildGrounding status |
| T20 | `hasContent` false/true conforme excerpts | DocumentGrounding.hasContent |

---

## INVARIANTES PRESERVADOS

| Invariante | Status |
|------------|--------|
| RLS: `user_id = auth.uid()` em `knowledge_items` | ✓ Preservado — nenhuma alteração em políticas |
| Nenhuma migration de banco | ✓ Campo `content` já existia |
| Nenhuma nova Edge Function | ✓ Apenas `context-copilot` modificado |
| Nenhuma nova tabela | ✓ |
| `gap-analysis` isolado por design | ✓ Não modificado |
| `toMap()` de `CopilotContextData` compatível backward | ✓ Campos opcionais com `if` guard |
| Fallback: sem documentos vinculados ao projeto → usa globais | ✓ |
| Fallback: sem `content_excerpt` → metadados apenas (sem quebra) | ✓ |

---

## FLUXO CORRIGIDO (estado pós-fix)

```
[DB: knowledge_items.content]
         │
         ▼
KnowledgeService.fetchAll()          → retorna KnowledgeItem COM content ✓
         │
         ▼
ive_context_provider.dart
  DocumentContextBuilder.buildGrounding(knowledgeSorted)
  → chunks → relevance → budget → DocumentGrounding ✓
         │
         ▼
IveContextData.knowledgeItemsSummary → Maps COM content_excerpt ✓
IveContextData.documentCoverage     → métricas de cobertura ✓
IveContextData.documentWarnings     → avisos de honestidade ✓
         │
         ▼
ive_overlay.dart._buildCopilotContext()
  CopilotContextData(
    documents: ctx.knowledgeItemsSummary,     ← COM content_excerpt ✓
    documentCoverage: ctx.documentCoverage,   ← novo ✓
    documentWarnings: ctx.documentWarnings,   ← novo ✓
  )
         │
         ▼
context-copilot/index.ts (Groq)
  • Doc A [analyzed] ✓ grounded             ← LLM vê o trecho real ✓
    Trecho: "conteúdo real do documento..."
  • Doc B [pending]  ⚠ sem conteúdo        ← LLM sabe que não foi processado ✓
  
  + CONTRATO DE GROUNDING no system prompt ✓
         │
         ▼
LLM (llama-3.3-70b-versatile)        → SOMENTE afirma análise de docs grounded ✓
```

---

## RESULTADO

A IVE agora opera com integridade epistêmica verificável. Documentos com conteúdo processado são marcados como ✓ grounded e incluídos no contexto do LLM. Documentos sem conteúdo são marcados como ⚠ e o LLM é instruído a reconhecer a limitação. O usuário pode confiar que quando a IVE afirma ter "analisado" um documento, ela de fato leu seu conteúdo.

---

*Deliverable de SHOW-01A. Próxima fase: SHOW-01B (conforme roadmap SHOW-00).*  
*Implementação: SHOW-01A completo. Não avançar automaticamente para SHOW-01B.*
