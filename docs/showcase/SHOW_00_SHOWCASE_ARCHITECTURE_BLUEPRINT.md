# SHOW-00 — Showcase Architecture Blueprint
## InsightValues™ — Especificação Arquitetural para o Showcase

**Data:** 2026-08-13  
**Status:** BLUEPRINT — Especificação, não implementação

---

## 1. PRINCÍPIO CENTRAL

```
COMPLEXITY IN ARCHITECTURE
SIMPLICITY IN EXPERIENCE

ONE ECOSYSTEM
MULTIPLE EXPERIENCES
SHARED INTELLIGENCE
```

O Showcase não demonstra menus. Demonstra uma história decisória.

---

## 2. EXPERIÊNCIA PRINCIPAL (Candidate)

**"SHOULD WE LAUNCH THIS BUSINESS IN THE UK?"**

ou equivalente estratégico relevante para o contexto.

### Fluxo da experiência:

```
1.  STRATEGIC QUESTION
         ↓
2.  PROJECT CONTEXT LOADED
    (Projeto + Knowledge Vault + Análise de Mercado)
         ↓
3.  INTERNAL KNOWLEDGE LOADED
    (Documentos indexados + Análises anteriores)
         ↓
4.  EXTERNAL RESEARCH
    (Market Intelligence Pipeline)
         ↓
5.  EVIDENCE MANIFEST
    (FACT vs INFERENCE + Source lineage)
         ↓
6.  RISKS IDENTIFIED
         ↓
7.  OPPORTUNITIES IDENTIFIED
         ↓
8.  SCENARIOS
    (Bear / Base / Bull)
         ↓
9.  IVE VERDICT
    (GO / GO WITH CONDITIONS / NO-GO)
         ↓
10. WHY?
    (Explainability narrativa)
         ↓
11. RECOMMENDED ACTIONS
         ↓
12. HUMAN APPROVAL
    (Gate explícito)
         ↓
13. EXECUTION (simulada ou real)
         ↓
14. VERIFICATION
         ↓
15. OUTCOME / LEARNING
```

**Capacidades atuais que sustentam esta experiência:**

| Etapa | Capacidade necessária | Status atual |
|---|---|---|
| 1. Strategic Question | Input UI | EXISTS |
| 2. Project Context | ProjectIntelligenceProfile | PARTIAL |
| 3. Internal Knowledge | Knowledge Vault + extraction | PARTIAL |
| 4. External Research | Market Intelligence Pipeline | EXISTS |
| 5. Evidence Manifest | Sources[] + Truth Model | MISSING |
| 6. Risks | OpportunityLabItem.risks[] | PARTIAL |
| 7. Opportunities | Opportunity Lab | EXISTS |
| 8. Scenarios | Decision Simulator | PARTIAL |
| 9. IVE Verdict | EcosystemScore recommendation | PARTIAL |
| 10. Why? | IntelligenceDebugService + Copilot | PARTIAL |
| 11. Recommended Actions | Action Engine | EXISTS |
| 12. Human Approval | Action status approval | PARTIAL |
| 13. Execution | Action status update | PARTIAL |
| 14. Verification | MISSING | MISSING |
| 15. Outcome/Learning | ROI metrics + BusinessMemory | PARTIAL |

---

## 3. ARQUITETURA ALVO — CAMADAS

### Camada 1: STRATEGIC INTELLIGENCE CONTEXT

```
ProjectIntelligenceContext {
  project: ProjectSnapshot
  vaultContent: DocumentExcerpt[]    ← FALTA: conteúdo real dos docs
  marketAnalysis: MarketAnalysis
  previousAnalyses: AnalysisSummary[]
  personas: PersonaProfile[]
  actionHistory: ActionSummary[]
  opportunityHistory: OpportunitySummary[]
  tokenBudget: int                   ← FALTA: gestão de contexto
  relevanceScores: Map<String, int>  ← FALTA: priorização
}
```

**Gap crítico identificado:** O context-copilot atual passa `documents: [{title, status}]` — apenas títulos. O conteúdo real dos documentos (livros, PDFs) nunca entra no contexto do LLM. Isso é a causa raiz do problema observado em device com análise de gaps ignorando livros.

**Solução arquitetural:** Adicionar ao context assembly:
```typescript
// Em context-copilot/index.ts
if (ctx.documentContents?.length) {
  const excerpts = ctx.documentContents
    .slice(0, 3)
    .map(d => `### ${d.title}\n${d.content.slice(0, 800)}`)
    .join('\n\n');
  lines.push(`\n## CONTEÚDO DOS DOCUMENTOS\n${excerpts}`);
}
```

---

### Camada 2: TRUTH & EVIDENCE MODEL

**Modelo conceitual mínimo viável:**

```dart
enum ClaimType { fact, inference, hypothesis, unknown }

class EvidencedClaim {
  final String claim;
  final ClaimType type;
  final List<EvidenceSource> sources;
  final int confidence;  // 0-100
}

class EvidenceSource {
  final String? knowledgeItemId;
  final String? marketAnalysisId;
  final String sourceType;  // 'document' | 'market_data' | 'llm_inference'
  final String excerpt;
  final int contribution;  // 0-100
}
```

**Implementação progressiva:**
1. **Nível 0 (agora):** Adicionar `source_type: 'llm_inference'` a todos os outputs da IVE
2. **Nível 1 (SHOW-02):** Distinguir FACT vs INFERENCE no output do Copilot
3. **Nível 2 (SHOW-03):** Source lineage com ID de documento + trecho

---

### Camada 3: IVE MEMORY FABRIC (arquitetura conceitual)

```
EPISODIC MEMORY     → SharedPreferences (EXISTS) + análises recentes
SEMANTIC MEMORY     → KnowledgeAnalysis (EXISTS) + embeddings futuros
PROJECT MEMORY      → ProjectIntelligenceProfile (EXISTS, não persistido)
DECISION MEMORY     → BusinessMemory 'decision' type (EXISTS, minimal)
EVIDENCE MEMORY     → MISSING → criar EvidenceLog
OUTCOME MEMORY      → ROI metrics + BusinessMemory 'success'/'failure' (EXISTS)
LEARNING MEMORY     → MISSING → criar LearningEntry
```

---

### Camada 4: SPECIALIST CONTRACTS

**Mínimo viável:** Formalizar como JSON Schema os contratos das Edge Functions existentes.

| Especialista | Input | Output | Authority | Failure |
|---|---|---|---|---|
| MarketAnalyst | url/niche | MarketAnalysis JSON | READ+ANALYZE | erro 500 → log |
| DocumentExtractor | file_base64, file_type | text, char_count | READ | erro 422 → user error |
| KnowledgeExtractor | content, language | KnowledgeAnalysis JSON | READ+ANALYZE | erro → status 'error' |
| GapAnalyst | input (niche/url) | gap categories | READ+ANALYZE | erro → empty arrays |
| DecisionSimulator | scenario, ecosystem, projects | impact deltas + narrative | ANALYZE+PROPOSE | erro → fallback |
| ContextCopilot | message, context, history | answer + sources + confidence | READ+ANALYZE+PROPOSE | erro 500 |
| ActionGenerator | project_name, opportunities | actions[] | PROPOSE | erro → empty |
| OpportunityGenerator | project_name, documents | opportunities[] | PROPOSE | erro → empty |

---

### Camada 5: IVE VERDICT MODEL

**Enum e modelo conceitual:**

```dart
enum IveVerdict { go, goWithConditions, noGo }

class IveDecision {
  final String question;
  final String context;
  final List<EvidencedClaim> evidence;
  final List<String> alternatives;
  final List<Risk> risks;
  final List<Opportunity> opportunities;
  final ScenarioTriple scenarios;  // bear/base/bull
  final int confidence;
  final IveVerdict verdict;
  final String recommendation;
  final List<String> conditions;   // apenas para goWithConditions
  final List<String> unknowns;
  final List<RecommendedAction> actions;
}
```

**Mapeamento a partir do estado atual:**

| Estado atual | IveDecision field |
|---|---|
| EcosystemScore.recommendation = 'ESCALAR' | verdict = IveVerdict.go |
| EcosystemScore.recommendation = 'VALIDAR' | verdict = IveVerdict.goWithConditions |
| EcosystemScore.recommendation = 'PAUSAR' | verdict = IveVerdict.noGo |
| DecisionValidation.blockReasons | conditions |
| DecisionValidation.status = 'structuring' | verdict = noGo (dados insuficientes) |

---

### Camada 6: AUTHORITY MODEL

**Hierarquia de autoridade para o Showcase:**

```
READ
  ↳ Qualquer provider pode ler dados
  ↳ IVE pode ler contexto completo

ANALYZE
  ↳ IVE pode analisar e computar scores
  ↳ Edge Functions podem processar inputs

PROPOSE
  ↳ IVE pode sugerir ações, oportunidades, decisões
  ↳ context-copilot pode sugerir create_action

DRAFT
  ↳ IVE pode rascunhar conteúdo (campanhas, posts)
  ↳ Não modifica dados persistentes

REQUEST_APPROVAL ← GATE HUMANO
  ↳ Toda ação acima de PROPOSE requer input humano
  ↳ UI apresenta proposta + evidence + consequence

EXECUTE ← APENAS APÓS APROVAÇÃO
  ↳ Status updates no banco
  ↳ Edge Function calls que criam/modificam dados

VERIFY
  ↳ Confirmação de que resultado esperado foi alcançado
```

---

### Camada 7: DEMO RELIABILITY

**Arquitetura para apresentações:**

```
REAL SYSTEM
   + DEMO PROJECT (project_type: 'showcase_demo', is_demo: true)
   + DEMO KNOWLEDGE VAULT (5-7 documentos pré-analisados)
   + CACHED MARKET ANALYSIS (análise pré-computada, armazenada no DB)
   + CACHED OPPORTUNITIES (oportunidades pré-geradas)
   + CACHED ACTIONS (ações pré-geradas)
   + FALLBACK RESPONSES (respostas pré-escritas para falha de API)
```

**Princípio:** Toda falha de Edge Function deve ter fallback cacheado. O Showcase nunca deve mostrar spinner indefinido.

**Identificação de dados demo:** Campo `origin: 'showcase_demo'` em todos os registros demo. Badge visual "[DEMO]" obrigatório.

---

### Camada 8: IVE PRESENCE (estados operacionais)

**Estados atuais (implementados):**
```
idle, attentive, listening, thinking, speaking,
success, warning, error, opportunity, executive
```

**Estados adicionais necessários para o Showcase:**
```dart
// Adicionar ao IveVisualState:
researching,    // IVE buscando dados externos
checkingEvidence, // IVE verificando fontes
waitingApproval,  // IVE aguardando decisão humana
executing,        // IVE processando ação aprovada
verifying,        // IVE verificando resultado
```

**Mapeamento para Rive state machine:** stateIndex 10-14 (a definir)

---

## 4. SHOWCASE UX PRINCIPLES

### Trust = Evidence
- Cada conclusão da IVE deve mostrar suas fontes
- Separação visual entre FATO e INFERÊNCIA
- Confidence score visível (não apenas interno)

### Clarity = Single Outcome
- Cada tela do Showcase tem um objetivo declarado
- Narrativa linear: pergunta → pesquisa → evidência → decisão → ação
- Sem menus de navegação durante a experiência guiada

### Delight = IVE Presence
- IVE presente em cada etapa do fluxo
- Estado visual do avatar reflete o estágio atual (researching/reasoning/waiting)
- IVE fala com o usuário, não apenas exibe dados

---

## 5. SEGURANÇA PARA SHOWCASE PÚBLICO

### NÃO expor:
- Prompts das Edge Functions (permanecem no backend)
- Algoritmos de scoring (EcosystemIntelligenceService)
- Credenciais de qualquer tipo
- Dados de projetos de clientes reais
- Lógica do Quant

### PODE ser demonstrado:
- Fluxo decisório completo com dados de demonstração
- IVE Avatar e estados visuais
- Scores e recomendações (com dados demo)
- Evidence manifest (com dados demo)

---

## 6. SHOWCASE vs PRODUTO PRINCIPAL — DIFERENCIAÇÃO

| Aspecto | Produto Principal | Showcase |
|---|---|---|
| Objetivo | Gestão operacional de portfólio | Demonstração de capacidades decisórias |
| Usuário | Empreendedor digital BR | Jurado/Investidor/Parceiro |
| Fluxo | Livre (multi-feature) | Guiado (linear) |
| Dados | Reais do usuário | Demonstração identificada |
| IVE | Overlay flutuante | Presença central na experiência |
| Idioma | Português BR | Inglês (para Showcase internacional) |
| Duração da demo | Sessão livre | 3-5 minutos |
| Confiabilidade | Alta (produção) | CRÍTICA (fallbacks obrigatórios) |
