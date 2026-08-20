# SHOW-00 — Current State Map
## InsightValues™ / IVE — Architectural Reality Audit

**Data:** 2026-08-13  
**Auditor:** Senior Software Architect / AI Systems Auditor  
**Branch:** `claude/insightvalues-showcase-audit-ebsqhi`  
**HEAD:** `1784789`  
**Status git:** limpo (nenhuma alteração não commitada)

---

## 1. REPOSITÓRIO

| Item | Valor |
|---|---|
| Remote | `https://github.com/jonnipm-web/ai-social-copilot` |
| Branch de trabalho | `claude/insightvalues-showcase-audit-ebsqhi` |
| Quant repo | **NÃO DISPONÍVEL** (apenas um remote, um diretório) |
| Flutter SDK | `>=3.3.0 <4.0.0` |
| State management | Riverpod 2.5.1 |
| Navegação | go_router 14.2.7 |
| Backend | Supabase (DB + Edge Functions) |

---

## 2. ESTRUTURA REAL DO PROJETO

```
ai-social-copilot/
  lib/
    app.dart
    main.dart
    core/
      constants/app_constants.dart     ← todas as rotas e table names
      services/ive_event_bus.dart      ← singleton broadcast stream
      theme/app_theme.dart
      utils/
    data/
      models/                          ← 36+ modelos de domínio
      services/                        ← 22 serviços Supabase
    features/
      action_engine/                   ← Action Queue UI
      admin/
      advisor/
      auth/
      calendar/
      campaigns/
      content/
      dashboard/
      debug/                           ← Intelligence Debug Hub
      ecosystem/                       ← Ecosystem View + Decision Center
      history/
      home/
      ive/                             ← IVE Avatar V2 (arquitetura completa)
        domain/ive_visual_event.dart
        providers/ive_visual_provider.dart
        visual/                        ← 8 arquivos de runtime visual
      knowledge/                       ← Knowledge Vault
      market_intelligence/             ← Market Intelligence Hub (6 telas)
      opportunity_lab/
      performance/
      personas/
      projects/
      result/
      roi_tracker/
      splash/
      upgrade/
      website_analyzer/
    providers/                         ← 28 providers Riverpod
    shared/
      widgets/                         ← ive_overlay, ive_avatar (re-export), etc.
  supabase/
    functions/                         ← 17 Edge Functions
    migrations/                        ← 21 migrations
  assets/
    ive/
      reference/ive_character_reference.png  ← EXISTE
      rive/                                  ← DIRETÓRIO AUSENTE (ive_executive_v1.riv PENDENTE)
  docs/
    ive/                               ← 3 docs de auditoria IVE anteriores
    showcase/                          ← (este diretório — criado por SHOW-00)
  test/                                ← 5 arquivos de teste
```

---

## 3. EDGE FUNCTIONS MAPEADAS

| Função | Propósito | Modelo |
|---|---|---|
| `market-analysis` | Análise de mercado completa | LLaMA 3.3 70b (Groq) |
| `competitor-discovery` | Mapeamento de concorrentes | LLaMA 3.3 70b (Groq) |
| `gap-analysis` | Análise de gaps de conteúdo/SEO | LLaMA 3.3 70b (Groq) |
| `opportunity-discovery` | Descoberta de oportunidades | LLaMA 3.3 70b (Groq) |
| `niche-discovery` | Ranking de nichos | LLaMA 3.3 70b (Groq) |
| `revenue-planner` | Plano de receita | LLaMA 3.3 70b (Groq) |
| `content-cluster` | Clusters de conteúdo | LLaMA 3.3 70b (Groq) |
| `analyze-website` | Análise de website | LLaMA 3.3 70b (Groq) |
| `improve-post` | Melhoria de posts | LLaMA 3.3 70b (Groq) |
| `extract-knowledge` | Extração de conhecimento de documentos | LLaMA 3.3 70b (Groq) |
| `generate-strategy` | Geração de estratégia | LLaMA 3.3 70b (Groq) |
| `generate-campaign` | Geração de campanha | LLaMA 3.3 70b (Groq) |
| `process-file` | Extração de texto de PDF/DOCX/TXT | Determinístico (sem IA) |
| `generate-project-opportunities` | Geração de oportunidades por projeto | LLaMA 3.3 70b (Groq) |
| `generate-project-actions` | Geração de ações por projeto | LLaMA 3.3 70b (Groq) |
| `context-copilot` | Assistente contextual (chat) | LLaMA 3.3 70b (Groq) |
| `decision-simulator` | Simulação de cenários de decisão | LLaMA 3.3 70b (Groq) |

**CONSTATAÇÃO:** 100% das Edge Functions de IA usam o mesmo modelo (LLaMA 3.3 70b) pelo mesmo provedor (Groq). Não há model routing, sem fallback, sem uso de Claude/Anthropic.

---

## 4. DATABASE — TABELAS AUDITADAS

| Tabela | Propósito | Cascade |
|---|---|---|
| `profiles` | Usuários e papéis | ON DELETE CASCADE (auth.users) |
| `personas` | Personas de conteúdo | ON DELETE CASCADE |
| `content_items` | Biblioteca de conteúdo | ON DELETE CASCADE |
| `calendar_items` | Calendário editorial | ON DELETE CASCADE |
| `knowledge_items` | Vault de conhecimento (docs/URLs) | ON DELETE CASCADE |
| `knowledge_analysis` | Análise AI de itens | ON DELETE SET NULL (knowledge_item_id) |
| `knowledge_strategies` | Estratégias geradas | — |
| `campaigns` | Campanhas | ON DELETE CASCADE |
| `campaign_calendar` | Calendário de campanha | — |
| `persona_training` | Treinamento de personas | ON DELETE SET NULL |
| `performance_metrics` | Métricas de performance | ON DELETE SET NULL |
| `website_analyses` | Análises de site | ON DELETE CASCADE |
| `market_analyses` | Análises de mercado | ON DELETE CASCADE |
| `competitors` | Concorrentes descobertos | ON DELETE SET NULL |
| `gap_analyses` | Análises de gap | ON DELETE SET NULL |
| `opportunities` | Oportunidades (Market Intelligence) | ON DELETE SET NULL |
| `niche_rankings` | Rankings de nichos | — |
| `content_clusters` | Clusters de conteúdo | — |
| `revenue_plans` | Planos de receita | ON DELETE SET NULL (nullable market_analysis_id) |
| `projects` | Projetos do portfólio | ON DELETE CASCADE |
| `roi_metrics` | Métricas de ROI | ON DELETE CASCADE |
| `business_memory` | Memória de negócio | ON DELETE SET NULL (project_id) |
| `advisor_profiles` | Perfis de advisor | ON DELETE CASCADE |
| `opportunity_lab` | Opportunity Lab | ON DELETE SET NULL |
| `action_queue` | Fila de ações | ON DELETE SET NULL |
| `feature_flags` | Feature flags | — |
| `copilot_sessions` | Sessões do copilot | — |
| `copilot_messages` | Mensagens do copilot | — |
| `copilot_context` | Contexto do copilot | — |
| `trend_signals` | Sinais de tendência | — |

**Migrations aplicadas:** 21 (001 a 021). Migration 020 foi uma migration de estabilização P0 que garantiu colunas ausentes em produção, indicando divergência entre migrações locais e estado real do banco.

---

## 5. ROTAS DA APLICAÇÃO (38 rotas)

Aplicativo de gestão de portfólio de projetos digitais com: autenticação, personas, content, campanhas, knowledge vault, market intelligence, opportunity lab, action engine, ecosystem view, dashboard executivo, histórico, ROI tracker, performance, website analyzer, calendar, debug hub, admin.

**Telas de maior relevância para Showcase:**
- `/executive-dashboard` — Dashboard executivo
- `/ecosystem` — Visão de ecossistema
- `/market-intelligence/:id` — Hub de inteligência
- `/opportunity-lab` — Opportunity Lab
- `/action-engine` — Action Engine
- `/intelligence-debug` — Debug de inteligência

---

## 6. MODELOS DE DADOS DE MAIOR RELEVÂNCIA

### IVE Core
- `IveState`: screenName, message, expression (5), bubbleVisible, activeIssue
- `IveVisualState`: 10 estados (idle, attentive, listening, thinking, speaking, success, warning, error, opportunity, executive)
- `IveMemory`: lastRoute, lastProjectId, lastProjectName, recentQuestions[5], interactionCount
- `IveEvent`: 17 tipos de eventos (knowledge, ecosystem, action, decision, project)
- `IveIssue`: severity, title, detail, action — modelo de problemas

### Business Intelligence
- `ProjectIntelligenceProfile`: projeto + análise + coverage + maturity + tópicos + gaps
- `EcosystemScore`: 7 scores + recommendation (6 valores) + strengths + risks
- `DecisionValidation`: coverageScore, learningScore, blockReasons, status
- `BusinessMemory`: 7 tipos (opportunity/campaign/strategy/revenue/decision/success/failure)

### Market Intelligence
- `MarketAnalysis`: niche, targetAudience, opportunityScore, 4 subscores, revenue estimates, priority actions
- `OpportunityLabItem`: 6 scores (market/revenue/competition/synergy/strategic/final), origin, sources[], rationale, confidence, risks[]
- `ActionQueueItem`: 3 scores (impact/effort/roi), status flow (5 estados), origin, sources[], plan[], risks[]

---

## 7. TESTES AUDITADOS

| Arquivo | Cobertura |
|---|---|
| `test/providers/ive_event_test.dart` | IveEvent factories, IveEventBus pubsub |
| `test/features/ive/ive_visual_runtime_test.dart` | IveVisualState enum, mapper, IveAvatar widget |
| `test/providers/project_provider_test.dart` | Project CRUD provider |
| `test/integration/project_reactive_chain_test.dart` | Cadeia reativa de projeto |
| `test/features/projects/project_command_center_logic_test.dart` | Lógica do command center |

**NÃO ENCONTRADO:** testes para context retrieval, evidence attribution, contradiction detection, hallucination resistance, decision consistency, memory retrieval, AI output regression, authorization, project isolation.

---

## 8. CI/CD AUDITADO

| Workflow | Propósito |
|---|---|
| `build-android.yml` | Build Android release |
| `build-apk.yml` | Build APK geral |
| `build-debug-device-test.yml` | Build APK com credenciais Supabase reais |
| `build-ive-avatar-lab.yml` | Build APK do laboratório IVE Avatar |
| `deploy-context-copilot-v2.yml` | Deploy da função context-copilot |
| `deploy-edge-functions.yml` | Deploy de todas as Edge Functions |
| `deploy-ive-backend-controlled.yml` | Deploy controlado do backend IVE |
| `deploy-supabase.yml` | Deploy Supabase (schema migrations) |
| `deploy-web.yml` | Deploy web |
| `generate-keystore.yml` | Geração de keystore Android |

---

## 9. ASSETS IVE

| Asset | Status |
|---|---|
| `assets/ive/reference/ive_character_reference.png` | **EXISTE** (PNG 1536×1024, RGB) |
| `assets/ive/rive/ive_executive_v1.riv` | **AUSENTE** (diretório não existe) |

O sistema está em modo fallback: exibe imagem de referência + anel de status animado. A arquitetura Rive completa (IveRiveRuntime, IveAvatarController) está implementada e aguarda o arquivo `.riv`.

---

## 10. DEPENDÊNCIAS EXTERNAS

| Serviço | Propósito | Status |
|---|---|---|
| Supabase | Auth + DB + Edge Functions + Storage | ATIVO |
| Groq API | LLM (LLaMA 3.3 70b) | ATIVO (único provedor de IA) |
| Google Sign-In / Drive | Importação de documentos | PARCIAL (GoogleDriveService existe) |
| Rive | Animação do Avatar IVE | BLOQUEADO (asset .riv ausente) |

---

## 11. AUSÊNCIAS CONFIRMADAS

| Item | Status | Evidência |
|---|---|---|
| Vector embeddings | NÃO ENCONTRADO | Nenhum package de embedding no pubspec |
| Semantic search / RAG | NÃO ENCONTRADO | Nenhum vector store ou similarity search |
| Multi-agent orchestration | NÃO ENCONTRADO | Edge Functions independentes, sem coordenação |
| ARB / intl / l10n | NÃO ENCONTRADO | Nenhum arquivo .arb no projeto |
| Quant repository | NÃO DISPONÍVEL | Apenas um remote/diretório |
| Audio ingestion | NÃO ENCONTRADO | Nenhum serviço de transcrição |
| YouTube ingestion | NÃO ENCONTRADO | Nenhum cliente YouTube |
| Action receipts | NÃO ENCONTRADO | Apenas atualização de status |
| Idempotency keys | NÃO ENCONTRADO | Nenhum mecanismo de deduplicação |
| Outcome verification | NÃO ENCONTRADO | Status 'completed' é auto-declarado |
| Living Thesis | NÃO ENCONTRADO | Sem mecanismo de rastreamento de premissas |
| Claude/Anthropic | NÃO ENCONTRADO | Apenas Groq/LLaMA usado |
