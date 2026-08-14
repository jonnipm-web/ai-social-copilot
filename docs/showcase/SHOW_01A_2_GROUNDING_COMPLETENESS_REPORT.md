# SHOW-01A.2 — Grounding Completeness Fix
## Document Depth + Project Gap Analysis

**Branch**: `claude/insightvalues-showcase-audit-ebsqhi`
**Data**: 2026-08-14
**Status**: IMPLEMENTATION COMPLETE — VALIDATION BLOCKED (Flutter toolchain indisponível no ambiente remoto)

---

## 1. Contexto

SHOW-01A corrigiu o bug P0 "DOCUMENT EXISTS ≠ DOCUMENT ANALYZED" e adicionou o algoritmo básico de grounding. Dois problemas residuais bloqueavam a completude:

1. **Hard limit de 500 chars/documento** (constante `maxExcerptChars`) era excessivamente rígido — documentos relevantes eram truncados a metade do tamanho de um chunk (800 chars), desperdiçando budget e ignorando conteúdo disponível.
2. **Gap Analysis não auditado** — 17 edge functions precisavam de classificação epistêmica.

---

## 2. Auditoria de Gap Analysis — 17 Edge Functions

### Classificação Completa

| Função | Tipo | Recebe Docs Internos? | Status |
|--------|------|----------------------|--------|
| `gap-analysis` | MARKET-ONLY | ❌ Apenas `{input}` string | ✅ Correto por design |
| `market-analysis` | MARKET-ONLY | ❌ URL/niche string | ✅ Correto por design |
| `opportunity-discovery` | MARKET-ONLY | ❌ Niche string | ✅ Correto por design |
| `niche-discovery` | MARKET-ONLY | ❌ Market string | ✅ Correto por design |
| `competitor-discovery` | MARKET-ONLY | ❌ Niche string | ✅ Correto por design |
| `revenue-planner` | MARKET-ONLY | ❌ Project desc string | ✅ Correto por design |
| `content-cluster` | MARKET-ONLY | ❌ Niche + keyword | ✅ Correto por design |
| `analyze-website` | MARKET-ONLY | ❌ URL externa | ✅ Correto por design |
| `extract-knowledge` | INGESTION | ✅ Conteúdo do documento | ✅ Pipeline de ingestão (não analysis) |
| `process-file` | INGESTION | ✅ Arquivo binário | ✅ Extração de texto (não analysis) |
| `generate-strategy` | HYBRID | ⚠ Metadados extraídos | ✅ Recebe resultado pós-extração, não raw docs |
| `generate-campaign` | HYBRID | ⚠ Metadados extraídos | ✅ Recebe resultado pós-extração |
| `improve-post` | CONTENT-ONLY | ❌ Texto do post | ✅ Não faz claims sobre projeto |
| `decision-simulator` | INTERNAL-METRICS | ✅ Ecosystem scores | ✅ Dados numéricos, não documentos |
| `generate-project-actions` | PROJECT | ⚠ Títulos de oportunidades | ✅ Recebe oportunidades já geradas |
| `generate-project-opportunities` | PROJECT-SPECIFIC | ✅ `documents[].content` | ⚠ FIXED: truncação 400→800 chars |
| `context-copilot` | PROJECT-SPECIFIC | ✅ `content_excerpt` grounded | ✅ Fixed em SHOW-01A |

### Achado Principal: `generate-project-opportunities`

Esta é a única função de gap analysis **PROJECT-SPECIFIC** que recebe conteúdo interno de documentos. O bug era:

```typescript
// ANTES (400 chars — mais restritivo que o próprio maxChunkSize do Dart):
.map((d) => `• ${d.title}: ${(d.content ?? '').substring(0, 400)}`)

// DEPOIS (800 chars — alinhado ao maxChunkSize):
.map((d) => `• ${d.title}: ${(d.content ?? '').substring(0, 800)}`)
```

**Não é P0**: a função já recebia conteúdo (não apenas metadata), portanto o princípio DOCUMENT EXISTS ≠ DOCUMENT ANALYZED não era violado. Era uma limitação de profundidade, não de episteme.

### Funções MARKET-ONLY — Corretas por Design

`gap-analysis`, `market-analysis`, `opportunity-discovery`, `niche-discovery`, `competitor-discovery`, `revenue-planner`, `content-cluster` e `analyze-website` analisam **mercado externo** com base no conhecimento do modelo (LLaMA 3.3 70b). Receber documentos internos seria conceitualmente errado — essas funções devem identificar o que o mercado faz, não o que o projeto tem.

A distinção semântica já está preservada por nomeação: funções "market" vs funções "project".

---

## 3. Mudanças Implementadas

### 3.1 `lib/data/models/document_grounding.dart`

Adicionados dois campos a `GroundingCoverage`:

```dart
final int selectedCharacterCount;    // chars selecionados (soma de excerpt.charCount)
final int availableContentCharCount; // chars disponíveis (soma de content.trim().length)
```

Ambos com default=0 para retrocompatibilidade. Mapeados em `toMap()`:
```
'selected_char_count'     → selectedCharacterCount
'available_content_chars' → availableContentCharCount
```

**Racional**: permite ao sistema (e ao LLM via `context-copilot`) saber _quanta informação foi aproveitada_ vs _quanta estava disponível_ — fundamental para episteme honesta.

### 3.2 `lib/data/services/document_context_builder.dart`

**Removido**: constante `maxExcerptChars = 500` (hard limit por documento).

**Adicionado**: algoritmo de 2 passes com budget global adaptativo.

#### Algoritmo

```
Fase 0: Para cada item
  - Marca EMPTY_CONTENT se content vazio
  - Divide em chunks (maxChunkSize=800, overlap=100)
  - Pontua cada chunk por relevância ao projectContext
  - Ordena chunks por relevância desc

Pass 1 (Document Diversity):
  Ordena documentos por relevância do melhor chunk desc
  Para cada documento:
    Se charBudget <= 0: BUDGET_EXCEEDED, break
    Aloca min(bestChunk.length, charBudget) chars
    Adiciona excerpt; reduz charBudget

Pass 2 (Budget Fill):
  Se charBudget > 0:
    Coleta todos os chunks não usados de todos os docs
    Ordena globalmente por relevância desc
    Para cada chunk: aloca min(chunk.length, charBudget); reduz charBudget

Coverage:
  used = len(SET(excerpts.documentId))   ← único docs, não total excerpts
  selectedCharacterCount = maxChars - charBudget
  availableContentCharCount = Σ item.content.trim().length (itens usáveis)
```

#### Por que 2 passes?

| Aspecto | Pass 1 (1 chunk/doc) | Pass 2 (chunks globais) |
|---------|---------------------|------------------------|
| Objetivo | Toda diversidade de fontes representada | Profundidade nos tópicos mais relevantes |
| Ordering | Por relevância do melhor chunk | Globalmente por relevância |
| Per-doc cap | Nenhum (só budget global) | Nenhum (permite multi-excerpt) |
| Budget | Subtrai conforme usa | Subtrai conforme usa |

#### Invariantes preservados

1. **Source Manifest Invariant**: `SET(excerpts.documentId) ⊆ SET(items com content não-vazio)` — verificado por T21 (SHOW-01A) e T26 (SHOW-01A.2).
2. **Determinismo**: mesmo input → mesmo output (sort estável em relevância, sem aleatoriedade).
3. **BUDGET_EXCEEDED** ainda gerado quando algum documento usável é completamente excluído por budget insuficiente.
4. **coverage.used** conta documentos únicos, não excerpts totais (T27).

### 3.3 `lib/providers/ive_context_provider.dart`

Substituída lookup por documento único com lookup por lista concatenada:

```dart
// ANTES:
final excerptById = {for (final e in grounding.excerpts) e.documentId: e};
if (excerpt != null) 'content_excerpt': excerpt.text,

// DEPOIS:
final excerptTextByDoc = <String, String>{};
for (final e in grounding.excerpts) {
  if (excerptTextByDoc.containsKey(e.documentId)) {
    excerptTextByDoc[e.documentId] =
        '${excerptTextByDoc[e.documentId]!}\n\n[...]\n\n${e.text}';
  } else {
    excerptTextByDoc[e.documentId] = e.text;
  }
}
if (excerptTextByDoc.containsKey(k.id)) 'content_excerpt': excerptTextByDoc[k.id]!,
```

Múltiplos excerpts do mesmo documento são concatenados com `\n\n[...]\n\n` — separador legível pelo LLM indicando que há descontinuidade entre trechos.

### 3.4 `supabase/functions/generate-project-opportunities/index.ts`

```typescript
// ANTES:
.map((d) => `• ${d.title}: ${(d.content ?? '').substring(0, 400)}`)

// DEPOIS:
.map((d) => `• ${d.title}: ${(d.content ?? '').substring(0, 800)}`)
```

Alinhado ao `maxChunkSize = 800` do `DocumentContextBuilder`. Dobra o conteúdo disponível por documento neste pipeline sem criar nova arquitetura.

---

## 4. Testes T22–T30

Adicionados ao arquivo `test/data/services/document_context_builder_test.dart`.

| Teste | Verifica |
|-------|---------|
| T22 | Sem hard cap de 500 chars — excerpt do primeiro chunk usa até 800 chars |
| T23 | Pass 1 cobre todos os docs usáveis antes do Pass 2 (diversidade) |
| T24 | Pass 2 adiciona chunks extras quando budget sobra |
| T25 | Doc altamente relevante acumula mais chars que doc irrelevante após Pass 2 |
| T26 | Source Manifest Invariant com multi-excerpt (SET ⊆ usableIds, sm2 ausente) |
| T27 | coverage.used conta docs únicos, não total de excerpts |
| T28 | selectedCharacterCount == soma dos charCounts dos excerpts |
| T29 | availableContentCharCount == soma dos content.trim().length dos itens usáveis |
| T30 | BUDGET_EXCEEDED gerado corretamente no novo algoritmo (budget apertado) |

**T12 atualizado**: removida referência a `maxExcerptChars` (constante removida); nova asserção: cada excerpt individual ≤ `maxChunkSize`.

### Análise Estática T22–T30

**T22** (`'palavra ' * 120` = 960 chars → chunk1 = 800 chars):
- `g.excerpts.first.charCount` = 800 > 500 ✓ ; ≤ 800 ✓

**T23** (3 docs, budget=8000):
- Pass 1: d1 (flutter, relevante), d2 (receita, irrelevante), d3 (investimento, irrelevante)
- Todos recebem um excerpt no Pass 1 → excerptIds = {'d1','d2','d3'} ✓

**T24** (1 doc, ~1330 chars, 2 chunks, budget=8000):
- Pass 1: chunk0 (800 chars), charBudget=7200
- Pass 2: chunk1 (~630 chars), charBudget~6570
- `g.excerpts.length == 2 > 1` ✓

**T25** (2 docs, ambos ~1344 chars, 2 chunks each):
- Pass 1: ambos recebem chunk de ~800 chars
- Pass 2: hr1.chunk1 tem score > lr1.chunk1 → hr1 recebe mais chars ✓

**T26** (3 items: si1 com content, si2 vazio, si3 com content):
- excerptIds ⊆ usableIds = {'sm1','sm3'} ✓
- 'sm2' ∉ excerptIds ✓
- coverage.used == excerptIds.length ✓

**T27** (1 doc, 2 chunks):
- usedDocIds = {'cu1'} → coverage.used = 1 ✓
- excerpts.length = 2 ≠ coverage.used = 1 (multi-excerpt detectável)

**T28** (2 docs curtos):
- selectedCharacterCount = Σ excerpt.charCount ✓ (por construção: `maxChars - charBudget`)

**T29** (3 items: 2 usáveis, 1 vazio):
- availableContentCharCount = content1.trim().length + content3.trim().length ✓

**T30** (10 docs × 300 chars, maxChars=600):
- Pass 1: doc0 (300), charBudget=300; doc1 (300), charBudget=0; doc2: BUDGET_EXCEEDED ✓
- coverage.used = 2 < 10 ✓

---

## 5. Status de Testes

| Conjunto | T01-T11 | T12 | T13-T20 | T21 | T22-T30 |
|----------|---------|-----|---------|-----|---------|
| Status | PASS (estático) | PASS (atualizado) | PASS (estático) | PASS (estático) | PASS (estático) |
| Executado? | ❌ Flutter toolchain indisponível no ambiente remoto | | | | |

**Para executar**: `flutter test test/data/services/document_context_builder_test.dart`

---

## 6. Impacto no Budget

### Antes (SHOW-01A)

Com 5 docs de 2000 chars cada e budget=8000:
- Cada doc: min(best_chunk, 500, remaining) = 500 chars
- Total usado: 5 × 500 = 2500 chars
- Budget desperdiçado: 5500 chars (69% do budget ignorado)

### Depois (SHOW-01A.2)

Com os mesmos 5 docs e budget=8000:
- Pass 1: cada doc recebe 1 chunk de 800 chars → 4000 chars usados
- Pass 2: restam 4000 chars → chunks adicionais dos docs mais relevantes
- Total usado: até 8000 chars (budget totalmente aproveitado para conteúdo real)

---

## 7. O Que NÃO Foi Feito

- **RAG, embeddings, vector DB**: não implementado (restrição explícita do projeto)
- **Nova Edge Function**: não criada (reutilizado `generate-project-opportunities`)
- **Nova migration**: não necessária (sem mudança de schema)
- **Deploy de produção**: não realizado (restrição explícita)
- **Merge em main**: não realizado (restrição explícita)
- **SHOW-01B**: não iniciado (restrição explícita)

---

## 8. Arquivos Modificados

```
lib/data/models/document_grounding.dart          — novos campos GroundingCoverage
lib/data/services/document_context_builder.dart  — 2-pass adaptive budget (reescrito)
lib/providers/ive_context_provider.dart          — multi-excerpt lookup
supabase/functions/generate-project-opportunities/index.ts — truncação 400→800
test/data/services/document_context_builder_test.dart — T12 fix + T22-T30
docs/showcase/SHOW_01A_2_GROUNDING_COMPLETENESS_REPORT.md — este relatório
```
