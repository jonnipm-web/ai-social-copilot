# SHOW-01A.3 — Final Validation & Release Gate Report

**Branch**: `claude/insightvalues-showcase-audit-ebsqhi`
**Date**: 2026-08-14
**HEAD**: `8ed34cf`
**Auditor**: SHOW-01A.3 automated audit

---

## VEREDICTO EXECUTIVO

| Dimensão | Status | Nota |
|----------|--------|------|
| Implementação Dart | ✅ CORRETO | Auditado por inspeção de código |
| Implementação Edge Functions | ✅ CORRETO (com achado residual) | Ver §5.1 |
| Invariantes de episteme | ✅ MANTIDOS | Source Manifest Invariant preservado |
| Testes T01–T30 compilação | ✅ PASS ESTÁTICO | Auditados linha a linha |
| Testes T01–T30 execução | ❌ NÃO EXECUTADOS | Flutter toolchain indisponível (exit 127) |
| CI com `flutter test` | ❌ AUSENTE | Nenhum workflow executa testes |
| Segurança / RLS | ✅ CORRETO | Sem bypass detectado |
| SHOW-01B readiness | ⛔ NO-GO | Testes não executados |

**DECLARAÇÃO FORMAL**: SHOW-01A + SHOW-01A.V + SHOW-01A.2 estão implementados e corretos por análise estática. A release gate para SHOW-01B é **NO-GO** porque "PASS por análise estática ≠ PASS de testes" e os testes T01–T30 não foram executados no ambiente.

---

## 1. Estado do Repositório

```
Branch:    claude/insightvalues-showcase-audit-ebsqhi
HEAD:      8ed34cf
Status:    clean (sem modificações uncommitted)

Commits relevantes:
  8ed34cf  feat(grounding): 2-pass adaptive budget policy + gap analysis audit (SHOW-01A.2)
  ec62cc9  fix(SHOW-01A.V): correct Source Manifest Invariant + add T21 + validation report
  aeafc0e  feat(SHOW-01A): implement project intelligence content grounding
```

**Verificado**: `git status` retornou working tree clean. Todos os commits de SHOW-01A, V e .2 presentes.

---

## 2. Trace Completo do Pipeline

Rastreamento explícito do caminho:
`Knowledge (DB) → content → ive_context_provider → DocumentContextBuilder →
 chunking → relevance ranking → adaptive budget → selected excerpts →
 CopilotContextData → serialization → context-copilot Edge Function → prompt → LLM`

### Passo 1 — Banco de Dados (`knowledge_items`)

```
Tabela: knowledge_items
Coluna: content TEXT (nullable no schema)
RLS:    ki_select_own → auth.uid() = user_id  ← isola por usuário
```

**`KnowledgeItem.fromMap()` (lib/data/models/knowledge_item.dart:67)**:
```dart
content: map['content'] as String? ?? '',
```
→ Null-safe: `null` DB → `''` Dart. Sem risco de NPE.

### Passo 2 — `ive_context_provider.dart` (Filtro + Grounding)

```dart
// Filtra pelo projeto de maior score:
final projectId = top?.project.id;
final projectItems = knowledgeRaw.where((k) => k.projectId == projectId).toList();
final knowledgeForGrounding = projectItems.isNotEmpty ? projectItems : knowledgeRaw;

// Ordena por opportunityScore desc; preserva total ANTES do take(5):
final totalLinkedCount = knowledgeSorted.length;      // ← total real do projeto
final topItems = knowledgeSorted.take(5).toList();    // ← somente esses vão ao builder

// Constrói contexto textual para relevance scoring:
final projectContext = [name, description].join(' ');

// Chama o builder apenas nos top-5 (Source Manifest Invariant):
final grounding = DocumentContextBuilder.buildGrounding(
    topItems.cast<KnowledgeItem>(), projectContext: projectContext);
```

**Source Manifest Invariant** verificado: `buildGrounding` recebe exatamente os mesmos itens
que alimentarão o LLM. `totalLinkedCount` é preservado separadamente para o campo
`total_linked` do coverage (não confunde "docs no projeto" com "docs analisados").

### Passo 3 — `DocumentContextBuilder.buildGrounding()` (Algoritmo 2-pass)

**Fase 0** — chunking + scoring de cada item:
```
Para cada KnowledgeItem em topItems:
  ├─ content.trim().isEmpty? → GroundingWarning(EMPTY_CONTENT); continue
  ├─ availableChars += content.trim().length
  ├─ chunk(content, maxSize=800, overlap=100) → List<String>
  └─ Pontua cada chunk: score = matchingWords / totalWords (palavras >3 chars)
      ordenado por score desc
```

**Pass 1** — um chunk por documento (diversidade):
```
docs ordenados por score do melhor chunk desc
Para cada doc:
  └─ charBudget <= 0? → BUDGET_EXCEEDED warning; break
     best = chunks.first
     text = best.text.length > charBudget ? substring(0,charBudget) : best.text
     excerpts.add(DocumentExcerpt(...))
     charBudget -= text.length
```

**Pass 2** — preenche budget com chunks não usados (profundidade):
```
Se charBudget > 0:
  candidates = todos os chunks não usados de todos os docs
  ordenados globalmente por score desc
  Para cada candidate:
    └─ charBudget <= 0? → break
       texto alocado até charBudget
       excerpts.add(...)
```

**Coverage**:
```dart
used = SET(excerpts.map(e => e.documentId)).length   // docs únicos
selectedChars = maxChars - charBudget
```

**Determinismo**: sort estável por score; sem aleatoriedade. Mesmo input → mesmo output. ✅

### Passo 4 — Multi-excerpt concatenation (`ive_context_provider.dart:113`)

```dart
final excerptTextByDoc = <String, String>{};
for (final e in grounding.excerpts) {
  if (excerptTextByDoc.containsKey(e.documentId)) {
    excerptTextByDoc[e.documentId] =
        '${excerptTextByDoc[e.documentId]!}\n\n[...]\n\n${e.text}';
  } else {
    excerptTextByDoc[e.documentId] = e.text;
  }
}
```

Múltiplos excerpts do mesmo documento (gerados pelo Pass 2) são concatenados com `[...]`.
O campo `content_excerpt` no `knowledgeItemsSummary` contém o texto completo.

### Passo 5 — `IveContextData` → `CopilotContextData` (`ive_overlay.dart:175`)

```dart
CopilotContextData _buildCopilotContext(IveContextData ctx) => CopilotContextData(
  documents:        ctx.knowledgeItemsSummary,       // ← list com content_excerpt
  documentCoverage: ctx.documentCoverage.isNotEmpty ? ctx.documentCoverage : null,
  documentWarnings: ctx.documentWarnings,
  ...
);
```

`ctx.knowledgeItemsSummary` é a lista de maps com `{'title', 'score', 'status', ?'content_excerpt'}`.

### Passo 6 — Serialização e invoke (`context_copilot_provider.dart:70`)

```dart
final res = await _client.functions.invoke(
  AppConstants.edgeFunctionContextCopilot,
  body: {
    'message':     message,
    'screen_name': screenName,
    'context':     context.toMap(),   // ← CopilotContextData.toMap()
    'history':     history,
  },
);
```

`CopilotContextData.toMap()` inclui `'documents': documents` quando não vazio,
`'document_coverage': documentCoverage`, `'document_warnings': documentWarnings`.

### Passo 7 — Edge Function `context-copilot/index.ts`

```typescript
if (ctx.documents?.length) {
  const groundedCount = docs.filter(d => d.content_excerpt).length;
  const docs = docs.slice(0, 5).map(d => {
    if (d.content_excerpt) {
      return `• ${d.title} [${d.status}] ✓ grounded\n  Trecho: "${d.content_excerpt.substring(0, 300)}"`;
    }
    return `• ${d.title} [${d.status}] ⚠ sem conteúdo processado`;
  }).join('\n');
  lines.push(`\n## DOCUMENTOS (${ctx.documents.length} vinculados, ${groundedCount} com conteúdo analisado)\n${docs}`);
}
```

O campo `content_excerpt` é recebido integralmente na request mas **renderizado com cap de 300 chars**
no system prompt enviado ao LLM (ver §5.1 — achado residual).

---

## 3. Auditoria de Implementação por Arquivo

### 3.1 `lib/data/models/document_grounding.dart`

| Campo | Tipo | Default | toMap() key | Status |
|-------|------|---------|------------|--------|
| `totalLinked` | `int` | required | `total_linked` | ✅ |
| `processed` | `int` | required | `processed` | ✅ |
| `usable` | `int` | required | `usable` | ✅ |
| `used` | `int` | required | `used` | ✅ |
| `documentUsageCoverage` | `double` | required | `document_usage_coverage` | ✅ |
| `selectedCharacterCount` | `int` | `= 0` | `selected_char_count` | ✅ (SHOW-01A.2) |
| `availableContentCharCount` | `int` | `= 0` | `available_content_chars` | ✅ (SHOW-01A.2) |

`GroundingCoverage.empty` inicializa ambos os novos campos com `0`. ✅ Retrocompatível.

### 3.2 `lib/data/services/document_context_builder.dart`

| Constante | Valor | Presença |
|-----------|-------|---------|
| `maxChunkSize` | 800 | ✅ |
| `chunkOverlap` | 100 | ✅ |
| `maxDocumentContextChars` | 8000 | ✅ |
| ~~`maxExcerptChars`~~ | ~~500~~ | ✅ REMOVIDA |

Algoritmo 2-pass: implementado conforme especificado. ✅

### 3.3 `lib/providers/ive_context_provider.dart`

- Multi-excerpt concatenation: ✅ implementado
- `total_linked` preservado antes do `take(5)`: ✅
- `buildGrounding` chamado com `topItems` (não todos os items): ✅ Source Manifest Invariant

### 3.4 `supabase/functions/generate-project-opportunities/index.ts`

```typescript
// ANTES: .substring(0, 400)
// DEPOIS: .substring(0, 800)  ← alinhado ao maxChunkSize
```
✅ Confirmado no arquivo.

### 3.5 `supabase/functions/context-copilot/index.ts`

CONTRATO DE GROUNDING presente: ✅
Render de docs com `✓ grounded` / `⚠ sem conteúdo`: ✅
`DOCUMENT EXISTS ≠ DOCUMENT ANALYZED`: ✅
Cap de 300 chars: ver §5.1

---

## 4. Auditoria da Suite de Testes T01–T30

### Status de execução

```
flutter test → exit 127 (flutter not found)
TODOS OS TESTES: NÃO EXECUTADOS
```

Conforme regra explícita do SHOW-01A.3: "PASS por análise estática NÃO é PASS de testes."
Os resultados abaixo são análise estática, **não PASS**.

### T01–T04 — `chunk()`

| Teste | Verifica | Análise |
|-------|---------|---------|
| T01 | string curta → 1 chunk | ✅ lógica correta |
| T02 | string de 1200 chars → 2 chunks com overlap | ✅ math: start=800-100=700, end=min(1500,1200)=1200 → chunk2 existe |
| T03 | string vazia → `[]` | ✅ `trimmed.isEmpty` guarda |
| T04 | string exatamente 800 chars → 1 chunk | ✅ `end >= trimmed.length → break` |

### T05–T08 — `relevanceScore()`

| Teste | Verifica | Análise |
|-------|---------|---------|
| T05 | chunk com todas as palavras → score > 0.5 | ✅ |
| T06 | chunk sem palavras → score = 0.0 | ✅ |
| T07 | context vazio → 0.0 | ✅ guarda `context.isEmpty` |
| T08 | chunk vazio → 0.0 | ✅ guarda `chunkWords.isEmpty` |

### T09–T11 — `buildGrounding()` básico

| Teste | Verifica | Análise |
|-------|---------|---------|
| T09 | lista vazia → `DocumentGrounding.empty` | ✅ guard `items.isEmpty` |
| T10 | item sem conteúdo → `EMPTY_CONTENT` warning | ✅ `item.content.trim().isEmpty` |
| T11 | 1 item com conteúdo → excerpt + coverage | ✅ |

### T12 — Sem hard cap de 500 chars (atualizado no SHOW-01A.2)

```dart
for (final e in g.excerpts) {
  expect(e.charCount, lessThanOrEqualTo(DocumentContextBuilder.maxChunkSize));
}
```
Corretamente atualizado: referencia `maxChunkSize` (800), não a constante removida. ✅

### T13–T20 — `buildGrounding()` features

| Teste | Verifica | Análise |
|-------|---------|---------|
| T13 | `BUDGET_EXCEEDED` com budget=50 | ✅ |
| T14 | docs mais relevantes primeiro no manifest | ✅ |
| T15 | `documentUsageCoverage` correto | ✅ |
| T16 | `processed` e `usable` corretos | ✅ |
| T17 | `coverage.used` conta docs com excerpt | ✅ |
| T18 | doc com apenas espaços → `EMPTY_CONTENT` | ✅ `.trim().isEmpty` |
| T19 | budget exato → sem `BUDGET_EXCEEDED` | ✅ |
| T20 | `chunkIndex` correto no excerpt | ✅ |

### T21 — Source Manifest Invariant

```dart
// T21 (linha 395-406) — 3 items: si1 (content), si2 (vazio), si3 (content)
for (final id in excerptIds) {
  expect(usableIds, contains(id));        // ← invariant correto
}
expect(excerptIds, isNot(contains('si2'))); // ← si2 (vazio) não aparece
expect(g.coverage.used, g.excerpts.length); // ← ⚠ QUALITY GAP (ver abaixo)
```

**Quality Gap identificado**: a última asserção `coverage.used == excerpts.length` é
coincidentalmente correta para os inputs do T21 (conteúdo curto → 1 chunk/doc → Pass 2
não ativa → 1 excerpt por doc → used == excerpts.length). Porém como invariante geral
é **falsa**: quando o Pass 2 adiciona múltiplos excerpts ao mesmo doc,
`coverage.used` (docs únicos) < `excerpts.length` (total de excerpts).

O T27 testa a relação correta. A asserção do T21 é misleading mas não causa
falso PASS para os inputs deste teste específico.

**Ação**: documentado. Não é bug de código. Recomenda-se corrigir para
`expect(g.coverage.used, lessThanOrEqualTo(g.excerpts.length))` em manutenção futura.

### T22–T30 — Adaptive Budget (SHOW-01A.2)

| Teste | Verifica | Análise Estática |
|-------|---------|----------------|
| T22 | `excerpt.charCount > 500` e `<= 800` | ✅ math: 120× 'palavra ' = 960 chars → chunk=800 |
| T23 | Pass 1 cobre todos 3 docs | ✅ budget=8000 >> 3×800 → todos passam |
| T24 | Pass 2 adiciona 2º chunk ao mesmo doc | ✅ 1 doc com 2 chunks; budget=8000 >> 1330 chars |
| T25 | Doc relevante acumula mais chars no Pass 2 | ✅ hr1.chunk1.score > lr1.chunk1.score |
| T26 | Source Manifest Invariant com multi-excerpt | ✅ excerptIds ⊆ {'sm1','sm3'}; 'sm2' ausente |
| T27 | `coverage.used == 1` com 2 excerpts do mesmo doc | ✅ usedDocIds = {'cu1'}.length = 1 |
| T28 | `selectedCharacterCount == Σ charCounts` | ✅ por construção: `maxChars - charBudget` |
| T29 | `availableContentCharCount` == Σ usable contents | ✅ 2 itens usáveis; 1 vazio excluído |
| T30 | `BUDGET_EXCEEDED` com budget=600, 10 docs×300 | ✅ 2 docs × 300 = 600; docs restantes excluídos |

---

## 5. Achados Críticos e Residuais

### 5.1 ACHADO RESIDUAL — Edge Function Trunca Excerpt a 300 chars

**Localização**: `supabase/functions/context-copilot/index.ts:52`

```typescript
return `• ${d.title} [${d.status}] ✓ grounded\n  Trecho: "${d.content_excerpt.substring(0, 300)}"`;
```

**Impacto**:

| Métrica | Valor |
|---------|-------|
| Budget Dart-side (após SHOW-01A.2) | 8000 chars |
| Chars visíveis ao LLM em context-copilot | 5 docs × 300 = **1500 chars** |
| Eficiência | **18.75%** do budget alocado |
| Pass 2 multi-chunk: contribuição ao LLM | **0 chars** (além dos primeiros 300 do chunk1) |

**Classificação**: DESIGN LIMITATION — não é P0. Antes do SHOW-01A o LLM recebia 0 chars
de conteúdo de documentos. O limit 300 foi estabelecido conscientemente no SHOW-01A como
parte do prompt render. A melhoria do SHOW-01A.2 aumentou a qualidade da seleção no lado
Dart, mas o gargalo de renderização na edge function não foi endereçado.

**Consequência do SHOW-01A.2 para context-copilot**: o algoritmo 2-pass agora seleciona
os 300 chars **mais relevantes** por documento (antes do cap), o que é uma melhoria real —
mas o cap de 300 chars permanece.

**Recomendação para SHOW-01B ou tarefa futura**: alinhar edge function a 600–800 chars
para aproveitar o budget selecionado. Análogo ao fix `generate-project-opportunities`
400→800.

**Fora de escopo do SHOW-01A.2**: o SHOW-01A.2 foi scoped para o algoritmo Dart-side.
Não é regressão — é limitação pré-existente.

### 5.2 ACHADO — T21 Assertion Quality Gap

**Localização**: `test/data/services/document_context_builder_test.dart:405`

```dart
expect(g.coverage.used, g.excerpts.length, reason: 'coverage.used deve ser igual ao número de excerpts no manifest');
```

**Classificação**: TEST QUALITY GAP — não é bug de código. A asserção é coincidentalmente
correta para os inputs do T21 mas falsa como invariante geral. O T27 testa o invariante
correto. Recomenda-se corrigir para `lessThanOrEqualTo` em manutenção futura.

### 5.3 AUSÊNCIA — Nenhum workflow de CI executa `flutter test`

**Localização**: `.github/workflows/` — todos os workflows auditados

| Workflow | Executa `flutter test`? |
|----------|------------------------|
| `build-android.yml` | ❌ Apenas `flutter build apk --release` |
| `build-debug-device-test.yml` | ❌ Apenas `flutter build apk --debug` |
| `build-apk.yml` | ❌ Build apenas |
| `build-ive-avatar-lab.yml` | ❌ Build apenas |
| `deploy-edge-functions.yml` | ❌ Deploy apenas |
| `deploy-web.yml` | ❌ Deploy apenas |

**Classificação**: PROCESS GAP — testes de unidade não são executados em CI.
Os testes T01-T30 só podem ser executados localmente por `flutter test`.

---

## 6. Auditoria de Segurança

### 6.1 Isolamento de dados por usuário (RLS)

```sql
-- Migration: ki_select_own
CREATE POLICY ki_select_own ON knowledge_items
  FOR SELECT USING (auth.uid() = user_id);
```

O Flutter client apenas lê items que o Supabase RLS permite. A filtragem por `projectId`
acontece no cliente APÓS a query — mas a query base já está restrita ao `user_id` autenticado.
**Sem bypass de RLS detectado.** ✅

### 6.2 Cross-user exposure

O `ive_context_provider` filtra `knowledgeRaw.where((k) => k.projectId == projectId)`.
O `knowledgeRaw` já é isolado por RLS. Não há possibilidade de content_excerpt de outro
usuário chegar ao sistema. ✅

### 6.3 Content logging

`context-copilot/index.ts` não faz log do `content_excerpt` ou do `system_prompt`.
Sem statement de `console.log` contendo dados do usuário detectado. ✅

### 6.4 Autenticação na Edge Function

A edge function recebe os dados do cliente via body JSON. Não há validação de JWT
no body — a autenticação é delegada ao Supabase client (Authorization header automático).
Padrão consistente com o restante das edge functions do projeto. ✅

### 6.5 Injeção de conteúdo no prompt

O `content_excerpt` é inserido no system prompt como string. Não há sanitização de
caracteres de controle. Se um documento contiver texto como `## SISTEMA:`, isso poderia
tentar confundir o modelo. Risco LOW dado que o conteúdo vem do próprio usuário
(ele inseriu o documento). Não é cross-user. ✅ Aceitável.

---

## 7. Auditoria de Payload / Regressão

### 7.1 Tamanho do payload

Budget Dart: 8000 chars de documentos.
Payload completo estimado (projeto + scores + 5 docs × 800 chars + oportunidades + ações):
~12–14KB JSON. Groq API suporta contexto de 128k tokens (LLaMA 3.3 70b). Sem risco. ✅

### 7.2 Null handling crítico

| Local | Campo | Null guard | Status |
|-------|-------|-----------|--------|
| `KnowledgeItem.fromMap` | `content` | `?? ''` | ✅ |
| `DocumentContextBuilder` | `item.content.trim().isEmpty` | guarda | ✅ |
| `ive_context_provider` | `excerptTextByDoc.containsKey(k.id)` | guarda | ✅ |
| `CopilotContextData.toMap()` | `if (documents.isNotEmpty)` | guarda | ✅ |
| `context-copilot` | `d.content_excerpt?.substring(0,300)` | truthy check | ✅ |

### 7.3 Regressão Source Manifest Invariant

SHOW-01A.V corrigiu: `buildGrounding(topItems)` em vez de `buildGrounding(allSorted)`.
SHOW-01A.2 não alterou essa lógica. Invariant mantido. ✅

### 7.4 Budget com 0 itens usáveis

```dart
if (items.isEmpty) return DocumentGrounding.empty;
```
Todos os itens com conteúdo vazio → `itemChunks` vazio → excerpts vazio → `used=0`.
Sem divisão por zero: `documentUsageCoverage = total > 0 ? used / total : 0.0`. ✅

---

## 8. Comparativo: Antes vs Depois

### context-copilot (LLM recebe)

| Cenário | ANTES (pré-SHOW-01A) | DEPOIS (pós-SHOW-01A.2) |
|---------|---------------------|------------------------|
| Conteúdo de documentos | 0 chars (apenas título + status) | até 300 chars × 5 docs = 1500 chars |
| Seleção | Nenhuma | Por relevância ao projeto (keyword overlap) |
| Avisos epistêmicos | Nenhum | `DOCUMENT EXISTS ≠ DOCUMENT ANALYZED` |
| Docs vazios | Silenciosamente misturados | Marcados `⚠ sem conteúdo processado` |

### Budget utilization (Dart-side)

| Cenário | SHOW-01A | SHOW-01A.2 |
|---------|---------|-----------|
| 5 docs × 2000 chars, budget=8000 | 5 × 500 = 2500 chars (31%) | Pass1: 5 × 800 = 4000; Pass2: +4000 = **8000 chars (100%)** |
| Seleção por relevância | Apenas 1 chunk/doc | Melhor chunk/doc no Pass1; chunks adicionais no Pass2 |

---

## 9. Instrução para Validação Executável

O Flutter toolchain não está disponível no ambiente remoto de CI. Para validar os testes:

```bash
# No ambiente local com Flutter instalado:
cd /caminho/para/ai-social-copilot
git checkout claude/insightvalues-showcase-audit-ebsqhi

flutter --version          # deve ser >=3.3.0
flutter pub get
flutter analyze --fatal-warnings
flutter test test/data/services/document_context_builder_test.dart --verbose

# Resultado esperado: "All tests passed!" (T01–T30)
```

---

## 10. SHOW-01B Readiness

### Critério de Release Gate

| Critério | Exigido | Status |
|---------|---------|--------|
| Implementação completa | ✅ | ✅ PASS |
| Análise estática limpa | ✅ | ✅ PASS (estimado) |
| `flutter analyze` sem erros | ✅ | ❌ NÃO EXECUTADO |
| T01–T30 PASS executados | ✅ | ❌ NÃO EXECUTADOS |
| CI verde | ✅ | ❌ CI não tem `flutter test` |
| Nenhum P0 aberto | ✅ | ✅ (achado §5.1 é DESIGN LIMITATION) |
| Autorização explícita do usuário | ✅ | ❌ NÃO CONCEDIDA |

### Declaração Formal

**SHOW-01B: NO-GO**

Razões:
1. `flutter test` não foi executado — não há evidência de execução dos testes
2. Autorização explícita para iniciar SHOW-01B não foi concedida
3. "PROIBIDO converter ausência de evidência em PASS" — regra explícita do SHOW-01A.3

**Após o usuário executar `flutter test` localmente e confirmar "All tests passed!":**
o gate técnico estará satisfeito. A autorização para SHOW-01B continua sendo uma
decisão humana separada.

---

## 11. Arquivos Auditados

```
lib/data/models/knowledge_item.dart                     — pipeline origin
lib/data/models/document_grounding.dart                 — modelo de grounding
lib/data/services/document_context_builder.dart         — algoritmo 2-pass
lib/providers/ive_context_provider.dart                 — filtragem + grounding
lib/data/models/copilot_context_data.dart               — estrutura de serialização
lib/shared/widgets/ive_overlay.dart                     — montagem CopilotContextData
lib/providers/context_copilot_provider.dart             — invoke da edge function
lib/data/services/copilot_service.dart                  — sessions/messages (sem grounding)
supabase/functions/context-copilot/index.ts             — renderização no prompt LLM
supabase/functions/generate-project-opportunities/index.ts — pipeline alternativo
test/data/services/document_context_builder_test.dart   — T01–T30
.github/workflows/build-android.yml                     — CI: sem flutter test
.github/workflows/build-debug-device-test.yml           — CI: sem flutter test
```

---

*SHOW-01A.3 concluído. Implementação auditada e correta por inspeção estática.
Release gate: NO-GO até execução confirmada dos testes.*
