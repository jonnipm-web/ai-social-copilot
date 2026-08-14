# SHOW_01A_VALIDATION_REPORT.md
# PROJECT INTELLIGENCE CONTENT GROUNDING — Relatório de Validação

**Data:** 2026-08-14  
**Branch:** `claude/insightvalues-showcase-audit-ebsqhi`  
**HEAD auditado:** `aeafc0e` → pós-fix: ver commit seguinte  
**Validador:** Claude (claude-sonnet-4-6)  
**Status corrigido:** IMPLEMENTATION COMPLETE — VALIDATION BLOCKED (toolchain)

---

## SEÇÃO 1 — STATUS DOCUMENTAL CORRIGIDO

O relatório anterior (`SHOW_01A_PROJECT_INTELLIGENCE_GROUNDING_REPORT.md`) declarou:
> "IMPLEMENTAÇÃO CONCLUÍDA"

Esse status foi prematuro. Os testes T01–T20 **não foram executados** (Flutter/Dart indisponível no ambiente remoto). O status correto é:

```
IMPLEMENTATION COMPLETE — VALIDATION BLOCKED (TOOLCHAIN UNAVAILABLE)
```

Nunca será declarado "os testes passarão" sem execução real. Esta seção corrige o registro documental.

Durante a auditoria de validação, foi encontrado e corrigido um bug real (Source Manifest Invariant — Seção 9). Um commit adicional foi criado para corrigi-lo.

---

## SEÇÃO 2 — VALIDAÇÃO GIT

```
Branch:    claude/insightvalues-showcase-audit-ebsqhi
HEAD:      aeafc0e (pré-fix) → commit de validação adicional
Status:    working tree clean, up to date with origin

Log recente:
  aeafc0e feat(SHOW-01A): implement project intelligence content grounding
  4601a98 docs(showcase): SHOW-00 — Auditoria arquitetural completa InsightValues™
  1784789 fix(ci): adicionar --verbose ao build sem pipe para expor erros do Gradle/NDK
  fa2df98 fix(ci): remover --verbose do build para expor erro real do Gradle
  bdf7c2c chore: ignorar diretório flutter/ do SDK local

Diff HEAD^..HEAD --stat (commit SHOW-01A):
  docs/showcase/SHOW_01A_PRE_IMPLEMENTATION_AUDIT.md       | 318 ++++++++
  docs/showcase/SHOW_01A_PROJECT_INTELLIGENCE_GROUNDING...  | 218 ++++++
  lib/data/models/copilot_context_data.dart                |  16 +-
  lib/data/models/document_grounding.dart                  |  85 +++
  lib/data/services/document_context_builder.dart          | 140 ++++
  lib/providers/ive_context_provider.dart                  | 122 +++-
  lib/shared/widgets/ive_overlay.dart                      |   6 +-
  supabase/functions/context-copilot/index.ts              |  29 +-
  test/data/services/document_context_builder_test.dart    | 229 ++++++
  9 files changed, 1114 insertions(+), 49 deletions(-)
```

**Inconsistência SHOW-00 (resolvida documentalmente):** O SHOW-00 tinha restrição "COMMIT: NONE". As 6 docs/showcase/ do SHOW-00 foram commitadas em `4601a98` via PR #89 (docs-only). O stop-hook sinalizava "untracked files" no ambiente local pois o clone remoto ainda não havia feito pull desse commit. O PR #89 confirma que os arquivos estão no repositório. Não há inconsistência real — apenas divergência entre ambiente local de auditoria e repositório remoto, agora resolvida.

---

## SEÇÃO 3 — TOOLCHAIN

```
Flutter:   NOT FOUND (ambiente remoto cloud)
Dart:      NOT FOUND
flutter analyze:  NOT EXECUTED — TOOLCHAIN UNAVAILABLE
flutter test:     NOT EXECUTED — TOOLCHAIN UNAVAILABLE
flutter build:    NOT EXECUTED — TOOLCHAIN UNAVAILABLE
```

**GitHub Actions disponíveis:**
- `.github/workflows/build-apk.yml` — `workflow_dispatch` (manual trigger)
- `.github/workflows/build-android.yml` — manual
- `.github/workflows/deploy-edge-functions.yml` — manual

Nenhum workflow executa `flutter test` automaticamente. Para validar T01–T21, o usuário deve executar:

```bash
flutter analyze --fatal-warnings
flutter test test/data/services/document_context_builder_test.dart
flutter test
```

Não foi criada infraestrutura CI nova nesta etapa.

---

## SEÇÃO 4 — AUDITORIA T01–T21 (revisão estática)

### T01 — chunk() string vazia

| Campo | Valor |
|-------|-------|
| SCENARIO | `chunk('')` e `chunk('   ')` |
| ASSERTION | `isEmpty` |
| ANÁLISE | `trimmed.isEmpty` → return `[]` imediatamente. Correto. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED (toolchain)** / Análise estática: PASS |
| RISCO DE FALSO POSITIVO | Nenhum |

### T02 — chunk() string curta (single chunk)

| Campo | Valor |
|-------|-------|
| SCENARIO | `chunk('Olá mundo', maxSize: 100)` |
| ASSERTION | `length == 1`, `first == 'Olá mundo'` |
| ANÁLISE | 9 chars < 100 → loop: start=0, end=9, end>=length → break. 1 chunk. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T03 — chunk() string longa (múltiplos chunks)

| Campo | Valor |
|-------|-------|
| SCENARIO | `'a' * 250`, maxSize=100, overlap=10 |
| ASSERTION | `length > 1` |
| ANÁLISE | 250 chars: chunk1=[0,100), start=90; chunk2=[90,190), start=180; chunk3=[180,250). Total=3. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T04 — chunk() overlap

| Campo | Valor |
|-------|-------|
| SCENARIO | `'A'*100 + 'B'*100`, maxSize=120, overlap=20 |
| ASSERTION | `chunks[0][-20:] == chunks[1][:20]` |
| ANÁLISE | chunk1=[0,120)='A'*100+'B'*20. start=100. chunk2=[100,200)='B'*100. `endOfFirst`='B'*20, `startOfSecond`='B'*20. Match. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | **BAIXO.** Fragilidade: `.trim()` em cada chunk remove whitespace que quebraria a igualdade se o conteúdo terminasse/iniciasse com espaços. No caso de teste (chars 'A'/'B'), não afeta. Para conteúdo com espaços em fronteiras, o overlap textual pode não ser idêntico. Não é bug no código — é limitação de design do chunker. |

### T05 — relevanceScore() contexto vazio

| Campo | Valor |
|-------|-------|
| SCENARIO | `relevanceScore('flutter dart mobile', '')` |
| ASSERTION | `== 0.0` |
| ANÁLISE | `context.isEmpty` → return 0.0. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T06 — relevanceScore() chunk vazio

| Campo | Valor |
|-------|-------|
| SCENARIO | `relevanceScore('', 'flutter mobile')` |
| ASSERTION | `== 0.0` |
| ANÁLISE | `chunkText.isEmpty` → return 0.0. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T07 — relevanceScore() palavras curtas ignoradas

| Campo | Valor |
|-------|-------|
| SCENARIO | contexto: `'the at in'`, chunk: `'the at in'` |
| ASSERTION | `== 0.0` |
| ANÁLISE | Todas as palavras têm ≤3 chars. `contextWords` (where length > 3) → empty set. return 0.0. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T08 — relevanceScore() match parcial

| Campo | Valor |
|-------|-------|
| SCENARIO | chunk=`'flutter mobile desenvolvimento'`, context=`'flutter mobile'` |
| ASSERTION | `> 0.0` e `<= 1.0` |
| ANÁLISE | contextWords = {'flutter', 'mobile'}. chunkWords = ['flutter','mobile','desenvolvimento']. hits=2. score=2/3≈0.667. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T09 — buildGrounding() lista vazia

| Campo | Valor |
|-------|-------|
| SCENARIO | `buildGrounding([])` |
| ASSERTION | `excerpts.isEmpty`, `warnings.isEmpty`, `coverage.totalLinked==0`, `hasContent==false` |
| ANÁLISE | Early return de `DocumentGrounding.empty`. Todos os campos corretos. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T10 — buildGrounding() content vazio → EMPTY_CONTENT

| Campo | Valor |
|-------|-------|
| SCENARIO | 1 item com `content: ''` |
| ASSERTION | `excerpts.isEmpty`, warning EMPTY_CONTENT presente, `coverage.usable==0` |
| ANÁLISE | `item.content.trim().isEmpty` → warning adicionado, continue. `usable` não incrementado. `excerpts` vazio. |
| SOURCE MANIFEST | `excerpts` está vazio → nenhuma fonte aparece como utilizada. Invariant: SET(em prompt)=∅ == SET(no manifest)=∅. CORRETO. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T11 — buildGrounding() content presente → excerpt

| Campo | Valor |
|-------|-------|
| SCENARIO | 1 item com content não vazio (51 chars) |
| ASSERTION | `excerpts.length==1`, `excerpts.first.text` não vazio, `hasContent==true` |
| ANÁLISE | 51 chars < maxChunkSize → 1 chunk. best=chunk[0]. excerpt=text (sem truncação). excerpts.add. used=1. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T12 — buildGrounding() truncation a maxExcerptChars

| Campo | Valor |
|-------|-------|
| SCENARIO | `'palavra ' * 200` ≈ 1400 chars |
| ASSERTION | `charCount <= maxExcerptChars (500)` |
| ANÁLISE | 1400 chars → chunked em [0,800), [700,1400). best.length=800>500 → `raw=best.substring(0,500)`. excerpt=raw. charCount=500. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T13 — buildGrounding() BUDGET_EXCEEDED

| Campo | Valor |
|-------|-------|
| SCENARIO | 20 items, cada com content de 500 'a'. maxChars=600. |
| ASSERTION | warning BUDGET_EXCEEDED presente, `coverage.used < 20` |
| ANÁLISE | Item 1: budget=600, excerpt=500 chars. budget=100. Item 2: raw=500>100 → excerpt=100 chars. budget=0. `charBudget<=0` → BUDGET_EXCEEDED warning, break. used=2 < 20. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T14 — buildGrounding() coverage metrics

| Campo | Valor |
|-------|-------|
| SCENARIO | 2 itens: item1 com content, item2 sem content |
| ASSERTION | totalLinked=2, processed=2, usable=1, used=1, coverage≈0.5 |
| ANÁLISE | item1: processed++, usable++, excerpt adicionado, used++. item2: processed++, warning. Coverage: 2/2/1/1, 1/2=0.5. |
| LLM CONTEXT | item1 tem `content_excerpt` no prompt. item2 não tem. LLM distingue os dois. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T15 — buildGrounding() documentUsageCoverage=0.0 para lista vazia

| Campo | Valor |
|-------|-------|
| SCENARIO | `buildGrounding([])` |
| ASSERTION | `documentUsageCoverage == 0.0` |
| ANÁLISE | `DocumentGrounding.empty` → `GroundingCoverage.empty` → documentUsageCoverage=0.0. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T16 — buildGrounding() relevance selection

| Campo | Valor |
|-------|-------|
| SCENARIO | content com 'bloco irrelevante' * 3 + 'flutter mobile desenvolvimento android' |
| ASSERTION | `excerpts.first.text` contém 'flutter' |
| ANÁLISE | Content total ≈ 169 chars < maxChunkSize(800) → 1 único chunk. Chunk contém tanto 'bloco irrelevante' quanto 'flutter'. O test passa trivialmente — não há seleção entre múltiplos chunks. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: **PASS COM RESSALVA** |
| RISCO | **MÉDIO — FALSO POSITIVO.** O test não valida seleção de chunk relevante entre múltiplos. Com content de 169 chars há apenas 1 chunk. O algoritmo de seleção não é realmente exercitado. Para validação real, o content deve ter >800 chars com partes contrastantes. Não é bug no código; é limitação do test. |

### T17 — buildGrounding() múltiplos itens

| Campo | Valor |
|-------|-------|
| SCENARIO | 3 itens com content diferentes |
| ASSERTION | `excerpts.length==3`, `coverage.used==3` |
| ANÁLISE | Todos com content, todos dentro do budget default (8000 chars). 3 excerpts produzidos. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T18 — buildGrounding() charCount == text.length

| Campo | Valor |
|-------|-------|
| SCENARIO | 1 item com content curto |
| ASSERTION | `e.charCount == e.text.length` |
| ANÁLISE | `charCount: excerpt.length` e `text: excerpt`. Sempre iguais por construção. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T19 — buildGrounding() status pending com content vazio

| Campo | Valor |
|-------|-------|
| SCENARIO | item `status='pending'`, `content=''` |
| ASSERTION | warning EMPTY_CONTENT, `excerpts.isEmpty` |
| ANÁLISE | `content.trim().isEmpty` → warning, continue. Status não afeta o fluxo — apenas o content importa. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | **BAIXO — NAMING MISMATCH.** O prompt do SHOW-01A descreveu T19 como teste de "determinismo" (mesma entrada → seleção determinística). O test implementado cobre outro caso (pending + empty content). O determinismo do algoritmo é garantido pela natureza de função pura estática, mas não é explicitamente testado. Não é um bug; é uma cobertura de teste incompleta. |

### T20 — DocumentGrounding.hasContent

| Campo | Valor |
|-------|-------|
| SCENARIO | (a) item sem content, (b) item com content |
| ASSERTION | (a) `hasContent==false`, (b) `hasContent==true` |
| ANÁLISE | `hasContent = excerpts.isNotEmpty`. (a) excerpts vazio → false. (b) 1 excerpt → true. |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum |

### T21 — Source Manifest Invariant (ADICIONADO durante validação)

| Campo | Valor |
|-------|-------|
| SCENARIO | 3 itens: si1 com content, si2 sem content, si3 com content |
| ASSERTION | excerptIds ⊆ usableIds; si2 ∉ excerptIds; `coverage.used == excerpts.length` |
| ANÁLISE | si1 e si3 → excerpts adicionados. si2 → warning, continue. manifest={si1,si3}. usable={si1,si3}. Invariant: SET(manifest)==SET(usable com excerpt). |
| PASS/FAIL/NOT EXECUTED | **NOT EXECUTED** / Estático: PASS |
| RISCO | Nenhum — invariant verificável estaticamente pela análise do código |

---

## SEÇÃO 5 — CONTEXT BUDGET

**Arquivo:** `lib/data/services/document_context_builder.dart`  
**Classe:** `DocumentContextBuilder`

```dart
static const int maxChunkSize          = 800;   // chars por chunk bruto
static const int chunkOverlap          = 100;   // overlap entre chunks
static const int maxDocumentContextChars = 8000; // budget total (~2000 tokens)
static const int maxExcerptChars       = 500;   // máx por excerptDocumento
```

**Comportamento ao exceder:**
1. Cada item consome `excerpt.length` (≤500) do `charBudget`
2. Quando `charBudget <= 0` após adicionar um excerpt: `BUDGET_EXCEEDED` warning e `break`
3. Caso especial: se `excerpt.length > charBudget`, o excerpt é truncado a `charBudget` chars antes de ser adicionado (nenhum conteúdo é perdido silenciosamente)

**Exemplo sanitizado (5 docs, budget=8000):**

```
Doc A: content=2000 chars → chunk[0..799]=800 → excerpt=500 chars → budget=7500
Doc B: content=600 chars  → chunk[0..599]=600 → excerpt=500 chars → budget=7000
Doc C: content=100 chars  → chunk=100 chars    → excerpt=100 chars → budget=6900
Doc D: content=''         → EMPTY_CONTENT warning, skip          → budget=6900
Doc E: content=1500 chars → chunk[0..799]=800 → excerpt=500 chars → budget=6400
─────────────────────────────────────────────────────────────────────────────
available items: 5
usable items:    4 (1 sem content)
selected items:  4
budget used:     1600 / 8000 chars (20%)
budget remaining: 6400
BUDGET_EXCEEDED: não
```

**Diversidade:** Cada documento contribui no máximo com 1 excerpt (máx 500 chars). Não há concentração de budget em 1 documento. Documentos são processados em ordem de `opportunityScore` (mais relevante primeiro).

---

## SEÇÃO 6 — CHUNKING

**Implementação real:**

```
chunk size:   maxChunkSize = 800 chars (default)
overlap:      chunkOverlap = 100 chars (default)
normalização: content.trim() inicial; cada part.trim() antes de adicionar
```

**Comportamento verificado:**

| Cenário | Resultado |
|---------|-----------|
| Content vazio (`''` ou `'   '`) | `[]` — sem chunks |
| Content < 800 chars | `[content.trim()]` — 1 chunk |
| Content de 1000 chars | `[0..799]`, `[700..999]` — 2 chunks com 100-char overlap |
| Part após trim vazia | não adicionada à lista — sem chunks vazios |

**Ausência de chunks vazios:** `if (part.isNotEmpty) chunks.add(part)` — garantido.  
**Ausência de duplicação:** Cada start avança `maxSize - overlap` (700 chars) → sem repetição completa.  
**Perda silenciosa:** Não ocorre. O loop itera até `end >= trimmed.length` e faz break.

**Limitação conhecida:** O chunker quebra em posição de char, não em palavra/frase. Um chunk pode começar/terminar no meio de uma palavra. Sem impacto para relevance selection por keyword overlap (palavras parcialmente cortadas raramente casam). Melhoria possível: quebrar em espaço. Não implementado para manter escopo SHOW-01A.

---

## SEÇÃO 7 — RELEVANCE SELECTION

**Algoritmo:** Keyword Overlap (sem embeddings, sem RAG, sem vector DB)

**Fórmula:**
```
relevanceScore(chunk, context) = 
  |{words in chunk} ∩ {words in context with len > 3}| 
  / 
  |{words in chunk}|
```

**Sinais utilizados:**
- Palavras do `projectContext` (nome + descrição do projeto de maior score)
- Palavras do chunk atual
- Filtro: palavras contextuais com >3 chars (ignora artigos/preposições)

**Desempate:** Primeiro chunk com score mais alto vence (`if (s > topScore)` — ties mantêm índice menor).

**Determinismo:** Função pura. Mesma entrada → mesmo output. Sem estado global ou aleatoriedade.

**Diversidade entre documentos:** 1 excerpt por documento. Budget total limita a quantidade de documentos, não concentra em um.

**Fallback:** `projectContext.isEmpty` → `chunks.first` (chunk 0 de cada documento).

**Exemplo sanitizado:**

```
projectContext: "flutter mobile android"
contextWords:   {"flutter", "mobile", "android"}

Documento D1 — 2 chunks:
  chunk[0]: "blocos sobre finanças e investimentos" 
    → chunkWords=["blocos","sobre","finanças","investimentos"]
    → hits=0
    → score=0.0

  chunk[1]: "mobile first flutter desenvolvimento android"
    → chunkWords=["mobile","first","flutter","desenvolvimento","android"]
    → hits=3 (mobile, flutter, android)
    → score=3/5=0.6

  → selected: chunk[1] (score=0.6 > 0.0)

Documento D2 — 1 chunk:
  chunk[0]: "marketing digital conteúdo orgânico seo"
    → hits=0
    → score=0.0

  → selected: chunk[0] (único disponível)
```

**Limitação:** Sem semântica. "Desenvolvimento mobile" casaria melhor que "Android" numa abordagem semântica. Para SHOW-01A (sem RAG/embeddings por restrição explícita), keyword overlap é suficiente e honesto.

---

## SEÇÃO 8 — USED DOCUMENTS / COVERAGE

**Definições semânticas verificadas no código:**

| Métrica | Definição real | Calculada em |
|---------|---------------|--------------|
| `totalLinked` | Documentos vinculados ao projeto ativo (todos os itens em `knowledgeSorted`) | `ive_context_provider.dart`: `totalLinkedCount = knowledgeSorted.length` |
| `processed` | Documentos para os quais o builder chegou a verificar o content | `DocumentContextBuilder.buildGrounding()`: incrementado a cada iteração |
| `usable` | Documentos com `content.trim().isNotEmpty` | Incrementado após verificação de content |
| `used` | Documentos que efetivamente geraram um `DocumentExcerpt` | Incrementado após `excerpts.add()` |
| `selectedExcerptCount` | Equivale a `used` (1 excerpt por documento) | `grounding.excerpts.length` |
| `documentUsageCoverage` | `used / items.length` onde items é o conjunto passado ao builder | Calculado com denominador do subset passado (top-5) |

**Verificação de semântica:**

```
DOCUMENT LINKED ≠ DOCUMENT USED  →  totalLinked pode ser > used. CORRETO.
DOCUMENT PROCESSED ≠ DOCUMENT USED  →  processed >= used (items sem content são processed mas não used). CORRETO.
```

**Cenários obrigatórios:**

```
Cenário 1: 4 linked / 4 usable / 4 used
  totalLinked=4, processed=4, usable=4, used=4
  documentUsageCoverage=1.0

Cenário 2: 4 linked / 4 usable / 2 used  (budget esgotado após 2)
  totalLinked=4, processed=4, usable=4, used=2
  BUDGET_EXCEEDED warning
  documentUsageCoverage=0.5

Cenário 3: 4 linked / 3 usable / 3 used  (1 sem content)
  totalLinked=4, processed=4, usable=3, used=3
  EMPTY_CONTENT warning
  documentUsageCoverage=0.75

Cenário 4: 4 linked / 0 usable / 0 used  (todos sem content)
  totalLinked=4, processed=4, usable=0, used=0
  4x EMPTY_CONTENT warnings
  documentUsageCoverage=0.0
```

**Semântica da coverage:** `documentUsageCoverage` representa a proporção dos documentos apresentados ao builder que tiveram conteúdo efetivamente incluído no contexto do LLM. Não é "percentual de conhecimento compreendido" (impossível sem semântica). O nome correto é "document excerpt inclusion rate among presented documents".

---

## SEÇÃO 9 — SOURCE MANIFEST INVARIANT

**Bug encontrado e corrigido durante a validação:**

### Bug original

```dart
// ANTES (bug)
final grounding = DocumentContextBuilder.buildGrounding(
  knowledgeSorted.cast<KnowledgeItem>(),  // TODOS os items (potencialmente >5)
  ...
);
final knowledgeSummary = knowledgeSorted.take(5).map(...).toList();  // apenas top-5
```

Problema: `grounding.excerpts` poderia conter excerpts para itens 6–N que NÃO entram em `knowledgeSummary`. Resultado: `coverage.used` sobre-contava; `grounding.excerpts` continha entradas para docs que jamais chegavam ao LLM.

Invariant violado:
```
SET(excerpts in manifest) ≠ SET(docs with content_excerpt in prompt)
```

### Fix aplicado

```dart
// DEPOIS (correto)
final totalLinkedCount = knowledgeSorted.length;  // total real para coverage
final topItems = knowledgeSorted.take(5).toList();  // apenas o conjunto exibido

final grounding = DocumentContextBuilder.buildGrounding(
  topItems.cast<KnowledgeItem>(),  // mesmo conjunto que entrará no summary
  ...
);

// Coverage com total_linked real (todos os docs do projeto, não só top-5)
final documentCoverage = {
  ...grounding.coverage.toMap(),
  'total_linked': totalLinkedCount,
};

// knowledgeSummary iterado sobre topItems — mesmo conjunto
final knowledgeSummary = topItems.map((k) { ... }).toList();
```

Invariant garantido após fix:
```
SET(grounding.excerpts) ⊆ SET(topItems with usable content)
SET(docs with content_excerpt in knowledgeSummary) ⊆ SET(grounding.excerpts)
→ SET(in manifest) == SET(in LLM prompt)  ✓
```

**Estrutura real do manifest:**

Cada `DocumentExcerpt` contém:
```dart
class DocumentExcerpt {
  final String documentId;    // ← identifica a fonte
  final String documentTitle; // ← nome legível
  final int chunkIndex;       // ← qual chunk foi selecionado
  final String text;          // ← trecho real incluído no prompt
  final int charCount;        // ← tamanho exato
}
```

Para cada excerpt, é possível recuperar: `documentId`, `documentTitle`, `chunkIndex`, `text` (=`content_excerpt` no prompt), `charCount`. Campo `includedInPrompt` não é explícito — está implícito: se está em `grounding.excerpts` E o documento está em `topItems`, então está no prompt.

**T21 adicionado** verifica o invariant programaticamente.

---

## SEÇÃO 10 — LLM PAYLOAD

**Exemplo SANITIZADO do payload para `context-copilot`:**

```json
{
  "message": "[mensagem do usuário]",
  "screen_name": "Conhecimento",
  "context": {
    "scores": {
      "ecosystem_health": 72,
      "total_projects": 3,
      "pending_actions": 4,
      "top_project_name": "[nome do projeto]",
      "top_project_score": 82
    },
    "project": {
      "projects": [
        { "name": "[proj1]", "score": 82, "type": "[tipo]", "status": "active" },
        { "name": "[proj2]", "score": 61, "type": "[tipo]", "status": "active" }
      ]
    },
    "documents": [
      {
        "title": "[Doc com conteúdo processado]",
        "score": 75,
        "status": "analyzed",
        "content_excerpt": "[primeiros 500 chars do melhor chunk do documento]"
      },
      {
        "title": "[Doc sem conteúdo processado]",
        "score": 40,
        "status": "pending"
      }
    ],
    "document_coverage": {
      "total_linked": 5,
      "processed": 2,
      "usable": 1,
      "used": 1,
      "document_usage_coverage": 0.2
    },
    "document_warnings": [
      "\"[Nome do doc]\": registrado mas sem conteúdo processável."
    ]
  },
  "history": [...]
}
```

**Distinção no system prompt do LLM (após rendering na edge function):**

```
## DOCUMENTOS (5 vinculados, 1 com conteúdo analisado)
• [Doc com conteúdo] [analyzed] ✓ grounded
  Trecho: "[300 chars do excerpt]"
• [Doc sem conteúdo] [pending] ⚠ sem conteúdo processado
```

**Distinções garantidas ao modelo:**

| Caso | Indicador no prompt |
|------|---------------------|
| Documento com conteúdo incluído | `✓ grounded` + trecho visível |
| Documento sem conteúdo processado | `⚠ sem conteúdo processado` |
| (sem documento — não vinculado ao projeto) | Ausente do prompt |

**Grounding contract no system prompt:**
```
DOCUMENT EXISTS ≠ DOCUMENT ANALYZED. METADATA ≠ KNOWLEDGE.
```
Instrução explícita para: (a) não afirmar análise de doc sem trecho; (b) não inventar conteúdo; (c) reportar cobertura parcial com a frase prescrita; (d) reconhecer ausência de evidência ≠ evidência de ausência.

---

## SEÇÃO 11 — GAP ANALYSIS E OUTROS PIPELINES

**A. O Gap Analysis usa context-copilot?**  
**NÃO.** `supabase/functions/gap-analysis/index.ts` é uma função independente. Recebe apenas `{input}` (string de nicho/URL). Faz chamada direta ao Groq com system prompt de análise de mercado. Sem relação com `context-copilot`.

**B. O conteúdo dos documentos entra no fluxo de gap-analysis?**  
**NÃO — por design explícito.** Gap analysis é análise de mercado externo (nicho, concorrência, oportunidades de SEO). O input é um identificador de nicho, não o portfólio de documentos do usuário. Este comportamento é correto e não deve ser alterado em SHOW-01A.

**C. Há outro pipeline de gap-analysis ainda usando metadata-only?**  
**NÃO aplicável.** O único pipeline que faz afirmações sobre documentos analisados é o `context-copilot`. Os demais são batch processors:

| Função | Input | Grounding necessário? |
|--------|-------|----------------------|
| `gap-analysis` | niche/URL text | Não (análise de mercado externo) |
| `generate-project-opportunities` | dados do projeto | Não pertence ao fluxo de "analisei seus docs" |
| `generate-project-actions` | dados do projeto | Idem |
| `generate-strategy` | dados do projeto | Idem |
| `extract-knowledge` | conteúdo do documento | Processa o doc — não é consumer do grounding |
| `decision-simulator` | cenários | Idem |
| `market-analysis` | dados de mercado | Idem |

**D. Análises de projeto que continuam fora do grounding?**  
Sim — todas as funções listadas acima operam fora do pipeline de grounding. Isso é **por design**: são ferramentas batch que processam dados específicos, não assistentes interativos que afirmam ter "lido" documentos.

**SHOW-01A corrige apenas o `context-copilot` pipeline** — o único que fazia afirmações interativas sobre documentos. Os demais pipelines não violam o princípio `DOCUMENT EXISTS ≠ DOCUMENT ANALYZED` porque não fazem essa afirmação.

---

## SEÇÃO 12 — SEGURANÇA

| Verificação | Status | Evidência |
|-------------|--------|-----------|
| RLS não alterado | ✓ PASS | Nenhum arquivo de migration ou policy modificado |
| Queries isoladas por usuário | ✓ PASS | `knowledgeItemsProvider` usa Supabase client autenticado via `auth.uid()` RLS |
| Nenhum service-role client-side | ✓ PASS | `DocumentContextBuilder` é Flutter-side, sem acesso a banco |
| Nenhum conteúdo integral em logs | ✓ PASS | Edge function não loga `content_excerpt`; truncado a 300 chars no render |
| Nenhum secret novo | ✓ PASS | Sem novas variáveis de ambiente |
| Nenhum cross-project leakage | ✓ PASS | Filtro por `projectId` adiciona restrição acima do RLS |

**Trust boundary do DocumentContextBuilder:**

O `DocumentContextBuilder` pressupõe que `items` foi filtrado corretamente pelo upstream (`ive_context_provider.dart`). O builder não tem acesso ao banco — opera sobre a lista Dart recebida.

O filtro de segurança é: `knowledgeItemsProvider` (via Supabase) → RLS (`user_id = auth.uid()`) → Flutter provider → filtro por `projectId` → `DocumentContextBuilder`.

Se `ive_context_provider.dart` passasse itens de outros usuários (impossível via RLS + SDK padrão), o builder os processaria sem discriminação. Esta trust boundary está documentada e é responsabilidade do upstream (enforced por RLS).

**Cross-project leakage risk:**  
O filtro `k.projectId == projectId` é client-side (in-memory). Se `knowledgeItemsProvider` retornasse itens de outros usuários por falha de RLS, o filtro de projectId não seria suficiente. Mas o RLS `ki_select_own` garante que o cliente nunca recebe itens de outros usuários. Risco: **MUITO BAIXO** (depende de falha RLS Supabase).

---

## SEÇÃO 13 — PERFORMANCE

**Complexidade:**

| Operação | Complexidade |
|----------|-------------|
| `chunk(content)` | O(n) onde n = content.length |
| `relevanceScore(chunk, context)` | O(c × w) onde c = chunk words, w = context words |
| `buildGrounding(items)` | O(N × C × L) onde N = items, C = chunks/item, L = chunk length |
| Mapa `excerptById` | O(E) onde E = excerpts (≤5) |

**Limites práticos:**
- N (items para top-5) ≤ 5 por design (take(5) antes de buildGrounding)
- C (chunks por item) ≤ content.length/700 ≈ limitado por maxExcerptChars e DB
- Conteúdo típico (2000–10000 chars): 3–15 chunks/item
- Budget: máx 5 × 500 = 2500 chars efetivamente enviados ao LLM (<<8000 limit)

**Risco com muitos documentos:** O `knowledgeItemsProvider` pode retornar N > 1000 itens se o usuário tiver muitos. O `knowledgeSorted` cresce com N, mas `take(5)` limita o processamento a 5 itens no máximo. A ordenação é O(N log N) mas é feita sobre a lista já carregada em memória (existia antes do SHOW-01A). **Nenhum novo risco de performance introduzido.**

**Não otimizado prematuramente.** Sem benchmark real necessário para os limites atuais.

---

## SEÇÃO 14 — CRITÉRIO FINAL DE GO

| Critério | Status |
|----------|--------|
| Conteúdo real chega ao LLM | ✓ VERIFIED (análise estática completa do pipeline) |
| Metadata-only bug removido | ✓ VERIFIED (content_excerpt agora incluído) |
| Chunking correto | ✓ VERIFIED estaticamente |
| Relevance selection correta | ✓ VERIFIED (com ressalva em T16) |
| Budget funciona | ✓ VERIFIED estaticamente |
| usedDocuments semanticamente correto | ✓ VERIFIED e documentado |
| coverage semanticamente correto | ✓ VERIFIED — não é "conhecimento compreendido" |
| Source Manifest invariant | ✓ BUG FOUND E CORRIGIDO (fix commitado) |
| Warnings funcionam | ✓ VERIFIED (EMPTY_CONTENT + BUDGET_EXCEEDED) |
| Gap Analysis relevante recebe grounding | ✓ N/A por design — gap-analysis é mercado externo |
| Isolamento projeto/usuário preservado | ✓ VERIFIED (RLS + filtro in-memory) |
| T01–T21 executaram PASS | ✗ **NOT EXECUTED — TOOLCHAIN UNAVAILABLE** |
| Testes existentes executaram PASS | ✗ **NOT EXECUTED — TOOLCHAIN UNAVAILABLE** |
| analyze executou PASS | ✗ **NOT EXECUTED — TOOLCHAIN UNAVAILABLE** |

**Decisão:**

```
SHOW-01A FINAL STATUS: IMPLEMENTATION COMPLETE — VALIDATION BLOCKED

Razão do bloqueio: Flutter/Dart indisponível no ambiente remoto de execução.
Todos os critérios técnicos foram verificados estaticamente com resultado PASS.
O único bloqueador é a execução real dos testes.

GO com condição: executar localmente
  flutter analyze --fatal-warnings
  flutter test test/data/services/document_context_builder_test.dart
  flutter test
  
  Se todos passarem → STATUS muda para: COMPLETE / GO
  Se algum falhar → reportar a falha específica para diagnóstico

SHOW-01B READINESS: NO-GO até T01–T21 executarem PASS localmente.
```

---

## SEÇÃO 15 — RESUMO FINAL

```
SHOW-01A VALIDATION STATUS:
  IMPLEMENTATION COMPLETE — VALIDATION BLOCKED (toolchain)

BRANCH:     claude/insightvalues-showcase-audit-ebsqhi
HEAD:       [ver commit de validação — SHOW_01A_VALIDATION]

CI:         0 runs (sem workflow de test automático para flutter test)

FLUTTER ANALYZE:   NOT EXECUTED — TOOLCHAIN UNAVAILABLE
T01-T20:           NOT EXECUTED — TOOLCHAIN UNAVAILABLE
T21 (adicionado):  NOT EXECUTED — TOOLCHAIN UNAVAILABLE
FULL TEST SUITE:   NOT EXECUTED — TOOLCHAIN UNAVAILABLE
BUILD APK:         NOT EXECUTED — TOOLCHAIN UNAVAILABLE

ROOT CAUSE (SHOW-01A):
  k.content descartado em ive_context_provider.dart (linhas 70-75).
  LLM via apenas título+status. Corrigido via DocumentContextBuilder.

ROOT CAUSE ADICIONAL (encontrado na validação):
  Source Manifest Invariant: buildGrounding() processava todos os itens,
  mas knowledgeSummary.take(5) limitava o prompt. coverage.used sobre-contava.
  CORRIGIDO: buildGrounding() agora recebe apenas topItems (take(5)).

CONTENT REACHES LLM:
  YES (verificado estaticamente via análise completa do pipeline)

CONTEXT BUDGET:
  maxDocumentContextChars = 8000 chars (~2000 tokens)
  maxExcerptChars = 500 chars/documento
  Máximo efetivo enviado: 5 docs × 500 chars = 2500 chars
  BUDGET_EXCEEDED: aviso gerado quando limite atingido

CHUNKING:
  800 chars/chunk, overlap 100 chars, determinístico, sem chunks vazios

RELEVANCE:
  Keyword overlap (sem embeddings). contextWords com len>3.
  score = hits/chunkWords. Determinístico. 1 chunk/documento.

USED DOCUMENTS:
  DOCUMENT LINKED ≠ DOCUMENT USED  ✓
  DOCUMENT PROCESSED ≠ DOCUMENT USED  ✓
  Cenários 4x verificados estaticamente

COVERAGE:
  total_linked = todos os docs do projeto (não apenas top-5)
  documentUsageCoverage = used / presented (not "knowledge understood")

SOURCE MANIFEST INVARIANT:
  FAIL → BUG ENCONTRADO → FIX APLICADO → PASS (estático pós-fix)

GAP ANALYSIS GROUNDED:
  N/A — gap-analysis é análise de mercado externo (por design).
  context-copilot (pipeline corrigido) é o único consumer interativo.

SECURITY:
  RLS preservado. Sem novos secrets. Sem cross-user leakage.
  Trust boundary documentada: RLS → provider → projectId filter → builder.

REGRESSIONS:
  Nenhuma detectada na análise estática.
  Campos adicionados são opcionais (backward compat).

SHOW-01A FINAL:
  GO COM CONDIÇÃO — executar flutter test localmente para confirmar.
  (Se toolchain disponível: COMPLETE / GO)

SHOW-01B READINESS:
  NO-GO — aguardar confirmação de flutter test PASS.

COMMIT (implementação):  aeafc0e
COMMIT (fix validação):  [hash do commit de validação]
PUSH:                    ✓ (branch atualizado)
PR:                      #89 (draft, open)
```

---

*Relatório produzido como deliverable obrigatório de SHOW-01A.V.*  
*Próximo passo: executar `flutter test` localmente e reportar resultado.*  
*NÃO iniciar SHOW-01B sem confirmação de GO.*
