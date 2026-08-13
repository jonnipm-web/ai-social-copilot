# SHOW-00 — Capability Gap Matrix
## InsightValues™ / IVE — Estado real × Necessidade do Showcase

**Data:** 2026-08-13  
**Classificações:** EXISTS | PARTIAL | MISSING | DUPLICATED | CONFLICTING | NOT AUDITED

---

## LEGENDA DE COLUNAS

| Coluna | Descrição |
|---|---|
| **Capability** | Nome da capacidade |
| **Status** | Estado atual no código |
| **Evidence** | Arquivo / símbolo / tabela que confirma o status |
| **Production Readiness** | 🟢 Pronto / 🟡 Parcial / 🔴 Ausente |
| **Showcase Need** | CRITICAL / HIGH / MEDIUM / LOW |
| **Target Architecture** | O que deveria existir |
| **Priority** | P0 (bloqueador) / P1 (alta) / P2 (média) / P3 (baixa) |
| **Risk** | Alto / Médio / Baixo |
| **Dependency** | Pré-requisitos |

---

## MATRIZ PRINCIPAL

### 1. PROJECT INTELLIGENCE CONTEXT
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `lib/data/models/project_intelligence_profile.dart`, `lib/data/services/project_intelligence_service.dart`, `lib/providers/ive_context_provider.dart` |
| **Production Readiness** | 🟡 |
| **Showcase Need** | CRITICAL |
| **Gap crítico** | Documentos do Knowledge Vault são passados ao Copilot como **títulos apenas** (não o conteúdo). O context-copilot edge function recebe `documents: [{title, status}]` — o texto real dos livros/PDFs nunca entra no contexto do LLM. Isso explica o problema observado em device com análise de gaps ignorando livros. |
| **Target Architecture** | ProjectIntelligenceContext com: project snapshot + vault content excerpts + market analysis + action summary + opportunity summary + persona context. Limite de tokens gerenciado com priorização por relevância. |
| **Priority** | P0 |
| **Risk** | Alto |
| **Dependency** | — |

---

### 2. DOCUMENT INTELLIGENCE
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `supabase/functions/process-file/index.ts`, `lib/data/services/file_import_service.dart`, `lib/data/services/knowledge_service.dart` |
| **Production Readiness** | 🟡 |
| **Showcase Need** | CRITICAL |
| **Gap** | PDF: extração via pdf-parse + fallback regex (confiabilidade incerta para PDFs complexos). URL: não implementada no process-file (nenhum web scraper). YouTube: MISSING. Audio: MISSING. Google Drive: DriveService existe mas integração incerta. Conteúdo extraído não é indexado com embeddings — apenas armazenado como texto. |
| **Target Architecture** | Pipeline: upload → extraction → normalization → chunking → embedding → storage → retrieval por similaridade. Source attribution preservada em cada chunk. |
| **Priority** | P1 |
| **Risk** | Alto |
| **Dependency** | — |

---

### 3. TRUTH MODEL (FACT vs INFERENCE)
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | Nenhum arquivo contendo enum FactType, InferenceType, TruthLabel ou equivalente encontrado |
| **Production Readiness** | 🔴 |
| **Showcase Need** | HIGH |
| **Gap** | O sistema não distingue entre: OBSERVED_FACT, INFERENCE, HYPOTHESIS, ASSUMPTION, USER_PROVIDED_TRUTH, EXTERNAL_EVIDENCE, CONTRADICTION, UNKNOWN, STALE_INFORMATION. Toda informação tem o mesmo peso epistêmico. |
| **Target Architecture** | TruthLabel enum por claim. Mínimo viável: FACT / INFERENCE / UNKNOWN no output da IVE. |
| **Priority** | P1 |
| **Risk** | Alto |
| **Dependency** | Evidence Model |

---

### 4. EVIDENCE MODEL
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `lib/data/models/opportunity_lab_item.dart` (sources[], rationale, confidence), `lib/data/models/action_queue_item.dart` (sources[], rationale), `lib/data/models/business_memory.dart` (source: string, confidence_score) |
| **Production Readiness** | 🟡 |
| **Showcase Need** | HIGH |
| **Gap** | sources[] é lista de strings não estruturadas. Não há evidence_score, coverage, freshness, contradiction_detection, unsupported-claim detection. context-copilot retorna sources[] como lista de nomes genéricos (ex: "Ecosystem Score"). Não há vínculo entre evidência e claim específico. |
| **Target Architecture** | EvidenceManifest por análise: [{sourceId, sourceType, excerpt, confidence, freshness, contribution}]. Vinculado a cada claim da IVE. |
| **Priority** | P1 |
| **Risk** | Médio |
| **Dependency** | Truth Model |

---

### 5. SOURCE LINEAGE
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | context-copilot retorna `sources: string[]` mas não há ID de documento, trecho citado, ou vínculo com knowledge_items |
| **Production Readiness** | 🔴 |
| **Showcase Need** | HIGH |
| **Gap** | Impossível saber qual trecho de qual documento fundamentou qual conclusão da IVE. |
| **Target Architecture** | Cada claim da IVE referencia: knowledge_item_id + excerpt + score de contribuição. |
| **Priority** | P1 |
| **Risk** | Alto |
| **Dependency** | Document Intelligence, Evidence Model |

---

### 6. MEMORY FABRIC

#### 6a. Episodic Memory
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `lib/data/models/ive_memory.dart` (lastRoute, recentQuestions[5], interactionCount) — SharedPreferences |
| **Production Readiness** | 🟡 |
| **Gap** | Apenas sessão atual e últimas 5 perguntas. Sem histórico de análises, sem memória de qual problema foi apresentado quando. |
| **Priority** | P2 |

#### 6b. Semantic Memory
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | knowledge_analysis (keywords, entities, topics) — mas sem vector store |
| **Production Readiness** | 🟡 |
| **Gap** | Não há busca semântica. Recuperação é por filtros SQL (project_id, user_id). |
| **Priority** | P2 (FUTURE para embedding) |

#### 6c. Project Memory
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `ProjectIntelligenceProfile` (computado em runtime, não persistido) |
| **Production Readiness** | 🟡 |
| **Gap** | Profile é recomputado a cada sessão. Sem snapshot histórico. |
| **Priority** | P2 |

#### 6d. Decision Memory
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `business_memory` (memory_type: 'decision') — estrutura mínima |
| **Production Readiness** | 🟡 |
| **Gap** | Sem vínculo com análise específica, sem timestamp de quando foi tomada, sem quem tomou. |
| **Priority** | P2 |

#### 6e. Evidence Memory
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | Não encontrado |
| **Production Readiness** | 🔴 |
| **Priority** | P2 |

#### 6f. Outcome Memory
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `roi_metrics` table, `business_memory` (success/failure types) |
| **Production Readiness** | 🟡 |
| **Gap** | ROI metrics são independentes de análises e decisões. Sem vínculo estruturado. |
| **Priority** | P2 |

#### 6g. Learning Memory
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | Não encontrado |
| **Production Readiness** | 🔴 |
| **Priority** | P3 (FUTURE) |

---

### 7. RESEARCH / MARKET INTELLIGENCE
| Campo | Valor |
|---|---|
| **Status** | EXISTS |
| **Evidence** | `supabase/functions/market-analysis/index.ts`, `competitor-discovery`, `gap-analysis`, `niche-discovery`, `content-cluster`, `revenue-planner`, `lib/features/market_intelligence/` |
| **Production Readiness** | 🟢 |
| **Showcase Need** | CRITICAL |
| **Gap** | Sem source attribution nas análises externas. Todas as pesquisas são via LLM paramétrico (sem web search real). Não há freshness tracking. |
| **Target Architecture** | Research pipeline com: input → LLM research → evidence manifest → confidence score → resultado |
| **Priority** | P0 (Showcase) |
| **Risk** | Baixo |

---

### 8. SCENARIO ENGINE
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `supabase/functions/decision-simulator/index.ts`, `lib/features/ecosystem/screens/executive_decision_center_screen.dart` |
| **Production Readiness** | 🟡 |
| **Showcase Need** | HIGH |
| **Gap** | Simulator gera: health_delta, execution_delta, opportunity_delta, roi_estimate, risk_level, timeline_weeks. Falta: Bear/Base/Bull scenario distintos, conditions, unknowns, alternative comparison. |
| **Target Architecture** | ScenarioEngine com 3 cenários (pessimista/base/otimista), confidence por cenário, assumptions explícitas. |
| **Priority** | P1 |
| **Risk** | Médio |
| **Dependency** | Decision Assurance |

---

### 9. OPPORTUNITY ANALYSIS
| Campo | Valor |
|---|---|
| **Status** | EXISTS |
| **Evidence** | `lib/features/opportunity_lab/`, `lib/data/services/opportunity_lab_service.dart`, `opportunity_lab` table, `supabase/functions/generate-project-opportunities/` |
| **Production Readiness** | 🟢 |
| **Showcase Need** | HIGH |
| **Gap** | Sem source attribution por oportunidade. Sem vínculo com evidence específica. |
| **Priority** | P1 |
| **Risk** | Baixo |

---

### 10. RISK ANALYSIS
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `OpportunityLabItem.risks[]`, `ActionQueueItem.risks[]`, `EcosystemScore.risks[]` — listas de strings |
| **Production Readiness** | 🟡 |
| **Showcase Need** | HIGH |
| **Gap** | Riscos são strings, sem severity, probability, mitigation, owner. Não há risk register formal. |
| **Target Architecture** | Risk model: {title, category, severity, probability, mitigation, status} |
| **Priority** | P2 |
| **Risk** | Médio |

---

### 11. DECISION ASSURANCE
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `lib/data/models/decision_validation.dart`, `lib/data/services/ecosystem_intelligence_service.dart` (recommendations), `supabase/functions/decision-simulator/` |
| **Production Readiness** | 🟡 |
| **Showcase Need** | CRITICAL |
| **Gap** | DecisionValidation bloqueia análise quando dados insuficientes (coverageScore < 60, learningScore < 50). EcosystemScore gera recomendação em 6 valores. Falta: estrutura completa de Decision (alternatives, unknowns, conditions, recommendation narrative). |
| **Target Architecture** | DecisionContract: question, context, evidence, alternatives, risks, opportunities, scenarios, confidence, recommendation, conditions, unknowns |
| **Priority** | P0 |
| **Risk** | Alto |
| **Dependency** | Truth Model, Evidence Model |

---

### 12. IVE VERDICT
| Campo | Valor |
|---|---|
| **Status** | MISSING (formalmente) |
| **Evidence** | EcosystemScore.recommendation = 'ESCALAR'/'ACELERAR'/'MANTER'/'VALIDAR'/'PAUSAR'/'ANÁLISE INCOMPLETA' — próximo mas não é um Verdict estruturado |
| **Production Readiness** | 🔴 |
| **Showcase Need** | CRITICAL |
| **Gap** | Não há enum IveVerdict (GO/GO WITH CONDITIONS/NO-GO). Não há narrativa de veredicto com justificativa estruturada. |
| **Target Architecture** | IveVerdict: {verdict: GO|GO_WITH_CONDITIONS|NO_GO, confidence, rationale, conditions[], unknowns[], recommendation} |
| **Priority** | P0 |
| **Risk** | Alto |
| **Dependency** | Decision Assurance |

---

### 13. EXPLAINABILITY
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `IntelligenceDebugService` gera ScoreBreakdown, ValidationReport. `ive_explain_button.dart` existe. context-copilot tem modo EXPLICAR. |
| **Production Readiness** | 🟡 |
| **Showcase Need** | HIGH |
| **Gap** | Explainability existe para scores de ecossistema. Não existe para: recomendações de mercado, análises de gap, conclusões de knowledge. |
| **Priority** | P1 |
| **Risk** | Médio |

---

### 14. AUTHORITY MODEL
| Campo | Valor |
|---|---|
| **Status** | MISSING (formalmente) |
| **Evidence** | ActionQueueItem.status flow (pending→approved→executing→completed) existe mas sem enforcement de gate. FeatureFlags controlam acesso a features mas não autoridade de ação. |
| **Production Readiness** | 🔴 |
| **Showcase Need** | HIGH |
| **Gap** | Não há separação explícita entre READ/ANALYZE/PROPOSE/DRAFT/REQUEST_APPROVAL/EXECUTE/VERIFY. A IVE pode sugerir create_action, approve_opportunity diretamente sem gate humano explícito. |
| **Target Architecture** | AuthorityLevel enum. Ações acima de PROPOSE requerem confirmação humana. |
| **Priority** | P1 |
| **Risk** | Alto |
| **Dependency** | — |

---

### 15. ACTION GATEWAY
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `lib/data/services/action_queue_service.dart`, action_queue table |
| **Production Readiness** | 🟡 |
| **Showcase Need** | HIGH |
| **Gap** | Action Gateway existe como fila de status, mas: sem authority check, sem idempotency, sem result verification, sem receipts, sem retry logic. |
| **Target Architecture** | PROPOSED ACTION → AUTHORITY CHECK → EXECUTION → EXPECTED STATE → OBSERVED STATE → VERIFY → RECEIPT |
| **Priority** | P2 |
| **Risk** | Médio |
| **Dependency** | Authority Model |

---

### 16. EXECUTION ASSURANCE
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | Status 'completed' é auto-declarado (sem verificação externa). Nenhum mecanismo de receipt ou rollback. |
| **Production Readiness** | 🔴 |
| **Showcase Need** | MEDIUM |
| **Gap** | Uma ação é "completa" quando o usuário muda o status para completed — sem verificação de resultado real. |
| **Priority** | P2 |
| **Risk** | Médio |
| **Dependency** | Action Gateway |

---

### 17. RECEIPTS
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | Não encontrado |
| **Production Readiness** | 🔴 |
| **Showcase Need** | MEDIUM |
| **Priority** | P2 |

---

### 18. LIVING THESIS / LEARNING LOOP
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | Nenhum mecanismo de rastreamento de premissas, comparison previsão × resultado, ou atualização de conclusão. ROI metrics e business_memory parcialmente cobrem Outcome mas sem vínculo com Thesis. |
| **Production Readiness** | 🔴 |
| **Showcase Need** | MEDIUM (para Showcase completo) |
| **Priority** | P3 (FUTURE) |
| **Risk** | Baixo (não bloqueia SHOW-01) |

---

### 19. SPECIALIST CONTRACTS
| Campo | Valor |
|---|---|
| **Status** | MISSING (formalmente) |
| **Evidence** | Edge Functions atuam como especialistas implícitos mas sem: allowedInputs, allowedSources, outputSchema, evidenceRequirements, confidenceRules, authorityLevel, failureConditions, auditRequirements |
| **Production Readiness** | 🔴 |
| **Showcase Need** | HIGH |
| **Gap** | market-analysis, extract-knowledge, gap-analysis, decision-simulator, context-copilot são especialistas de facto sem contrato. |
| **Target Architecture** | SpecialistContract por Edge Function. Começar com JSON Schema de entrada/saída. |
| **Priority** | P1 |
| **Risk** | Médio |
| **Dependency** | — |

---

### 20. MODEL ROUTING
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | Todas as 16 Edge Functions de IA usam `llama-3.3-70b-versatile` via Groq API com a mesma chave GROQ_API_KEY |
| **Production Readiness** | 🔴 |
| **Showcase Need** | MEDIUM |
| **Gap** | Sem routing por complexidade, sem fallback, sem cost control, sem Claude/Anthropic, sem modelos menores para tarefas simples. |
| **Target Architecture** | ModelRouter: task → complexity assessment → model selection (Claude para raciocínio, modelos menores para extração/classificação) |
| **Priority** | P2 |
| **Risk** | Médio |

---

### 21. INTELLIGENCE EVALUATION
| Campo | Valor |
|---|---|
| **Status** | PARTIAL (defensiva) |
| **Evidence** | `IntelligenceDebugService` (ValidationReport, 12+ testes de sanidade como T01-T12), `lib/features/debug/screens/intelligence_debug_hub_screen.dart` |
| **Production Readiness** | 🟡 |
| **Showcase Need** | HIGH |
| **Gap** | Avaliação de inteligência existe mas cobre apenas consistência de scores e cobertura de dados, não: hallucination resistance, context retrieval quality, source lineage, decision consistency. |
| **Target Architecture** | IVE Intelligence Regression Suite com casos de teste para qualidade de raciocínio |
| **Priority** | P2 |
| **Risk** | Médio |

---

### 22. IVE PRESENCE / AVATAR V2
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | `lib/features/ive/visual/` (8 arquivos completos), `lib/shared/widgets/ive_overlay.dart`, `lib/shared/widgets/ive_avatar.dart` (re-export) |
| **Production Readiness** | 🟡 |
| **Showcase Need** | HIGH |
| **Gap** | Arquitetura completa (IveRiveRuntime, IveAvatarController, 10 IveVisualStates). BLOQUEADOR: arquivo `assets/ive/rive/ive_executive_v1.riv` AUSENTE. Fallback ativo (imagem referência + anel). Estados faltantes para Showcase: researching, checkingEvidence, waitingApproval, executing, verifying. Reduced motion: não implementado. |
| **Target Architecture** | Expandir IveVisualState para incluir estados operacionais do pipeline decisório. |
| **Priority** | P1 |
| **Risk** | Alto (depende de asset externo) |

---

### 23. GLOBALIZATION / LOCALIZATION
| Campo | Valor |
|---|---|
| **Status** | MISSING (infraestrutura) |
| **Evidence** | Sem ARB, sem intl, sem l10n.yaml. Language field existe nos modelos (KnowledgeItem.language, ContentItem.language, Persona.mainLanguage — default 'pt-BR'). UI 100% hardcoded em português. |
| **Production Readiness** | 🔴 |
| **Showcase Need** | MEDIUM (inglês para Showcase internacional) |
| **Gap** | Sem separação entre: UI Language / Project Language / Research Language / Report Language. Mistura de PT/EN em labels técnicos. |
| **Target Architecture** | ARB-based i18n. Conceitos de language scope independentes. |
| **Priority** | P3 (para SHOW-14) |
| **Risk** | Alto (refactor amplo) |

---

### 24. DELETE LIFECYCLE
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | delete() existe em: MarketAnalysisService, KnowledgeService, ProjectService, ActionQueueService, BusinessMemoryService. CASCADE definido no DB. |
| **Production Readiness** | 🟡 |
| **Showcase Need** | HIGH (requisito real identificado) |
| **Gap** | delete() existe mas: sem soft delete, sem cascade control explícito (ex: ao deletar market_analysis, o que acontece com competitors/gap_analyses/opportunities?), sem audit log de deleção, sem proteção contra deleção acidental. |
| **Target Architecture** | Soft delete (deleted_at) + cascade review + confirmation gate + undo window |
| **Priority** | P1 |
| **Risk** | Alto |

---

### 25. QUANT INTEGRATION
| Campo | Valor |
|---|---|
| **Status** | NOT AVAILABLE |
| **Evidence** | Apenas um remote (`ai-social-copilot`). Nenhum arquivo relacionado a Quant no workspace. |
| **Production Readiness** | 🔴 |
| **Showcase Need** | HIGH (para experiência SHOW-13) |
| **Gap** | Repositório Quant não acessível. Nenhuma interface/contrato para integração existe. |
| **Target Architecture** | QuantInterface: {strategy, backtestEvidence, robustness, risk, iveAnalysis, decision} |
| **Priority** | P2 (depende de acesso ao repo) |
| **Risk** | Alto |

---

### 26. DEMO DATASET / DEMO RELIABILITY
| Campo | Valor |
|---|---|
| **Status** | MISSING |
| **Evidence** | Nenhum dataset de demonstração, nenhum cache de análises, nenhum fallback determinístico para apresentações |
| **Production Readiness** | 🔴 |
| **Showcase Need** | CRITICAL (apresentações para investidores) |
| **Gap** | Falha de rede/API durante apresentação = demo destruída. |
| **Target Architecture** | REAL SYSTEM + DEMO DATASET + CACHED EVIDENCE + CACHED ANALYSES + DETERMINISTIC FALLBACKS. Todo dado demo identificado como demo/sample. |
| **Priority** | P0 (antes de qualquer apresentação pública) |
| **Risk** | Crítico |

---

### 27. SECURITY BOUNDARY
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | RLS ativo em todas as tabelas. Edge Functions acessam GROQ_API_KEY via env var. Sem prompts proprietários expostos (estão nas Edge Functions, não no cliente). |
| **Production Readiness** | 🟡 |
| **Showcase Need** | CRITICAL (produto pode ser público no Showcase) |
| **Gap** | Prompts são proprietários mas estão no código do repositório GitHub (público ou privado). Sem separação explícita PUBLIC SHOWCASE BOUNDARY vs PRIVATE INTELLIGENCE CORE. |
| **Target Architecture** | Separação arquitetural entre capacidades demonstráveis e core intelectual proprietário. |
| **Priority** | P1 |
| **Risk** | Alto |

---

### 28. TELEMETRY / AUDITABILITY
| Campo | Valor |
|---|---|
| **Status** | PARTIAL |
| **Evidence** | IveEventBus (eventos internos), IntelligenceDebugService (ValidationReport), created_at/updated_at em todas as tabelas |
| **Production Readiness** | 🟡 |
| **Showcase Need** | MEDIUM |
| **Gap** | Sem telemetria de latência das Edge Functions, sem contagem de tokens, sem error rate por função, sem logging estruturado. |
| **Priority** | P2 |
| **Risk** | Baixo |

---

## RESUMO EXECUTIVO DA MATRIZ

| Prioridade | Capabilities | Ação necessária |
|---|---|---|
| **P0 — Bloqueadores** | Project Intelligence Context, Decision Assurance, IVE Verdict, Demo Dataset | Resolver antes de SHOW-01 |
| **P1 — Alta** | Document Intelligence, Truth Model, Evidence Model, Source Lineage, Opportunity+Risk Analysis, Scenario Engine, Specialist Contracts, Authority Model, Delete Lifecycle, IVE Presence (asset .riv), Security Boundary | Resolver em SHOW-01 a SHOW-06 |
| **P2 — Média** | Memory Fabric, Model Routing, Action Gateway, Execution Assurance, Intelligence Evaluation, Telemetry | Resolver em SHOW-07 a SHOW-12 |
| **P3 — Baixa/Futura** | Globalization, Living Thesis, Quant Integration | SHOW-13+ |
