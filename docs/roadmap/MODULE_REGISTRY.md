# Registro de Módulos — AI Social Copilot

**Data:** 2026-07-23

---

## Módulos Implementados

### M0 — Núcleo / Foundation
| Item                   | Status   | Arquivo                                    |
|------------------------|----------|--------------------------------------------|
| Autenticação           | ATIVO    | features/auth/login_screen.dart            |
| Profile/Roles          | ATIVO    | providers/profile_provider.dart            |
| Project CRUD           | ATIVO    | providers/project_provider.dart            |
| Selected Project       | ATIVO    | providers/selected_project_provider.dart   |
| Feature Flags          | ATIVO    | providers/feature_flag_provider.dart       |
| Admin Panel            | ATIVO    | features/admin/admin_panel_screen.dart     |
| Splash / Routing       | ATIVO    | features/splash/splash_screen.dart         |

### M1 — Post Generation (MVP Core)
| Item                   | Status   | Arquivo                                    |
|------------------------|----------|--------------------------------------------|
| Geração de conteúdo    | ATIVO    | features/home/content_generation_screen.dart |
| Result screen          | ATIVO    | features/result/result_screen.dart         |
| Histórico              | ATIVO    | features/history/history_screen.dart       |
| Edge fn improve-post   | ATIVO    | supabase/functions/improve-post/           |

### M2 — Advisor / Onboarding IA
| Item                   | Status   | Arquivo                                    |
|------------------------|----------|--------------------------------------------|
| Advisor Onboarding     | ATIVO    | features/advisor/advisor_onboarding_screen.dart |
| Advisor Provider       | ATIVO    | providers/advisor_provider.dart            |

### M3 — Knowledge Vault
| Item                   | Status   | Arquivo                                    |
|------------------------|----------|--------------------------------------------|
| Knowledge Items CRUD   | ATIVO    | features/knowledge/knowledge_vault_screen.dart |
| Knowledge Analysis     | ATIVO    | features/knowledge/knowledge_analysis_screen.dart |
| Strategy Generation    | ATIVO    | features/knowledge/strategy_screen.dart    |
| Drive Picker           | ATIVO    | features/knowledge/drive_picker_screen.dart |
| Edge fn extract-knowledge | ATIVO | supabase/functions/extract-knowledge/      |
| Edge fn generate-strategy | ATIVO | supabase/functions/generate-strategy/     |

### M4 — Market Intelligence
| Item                      | Status   | Arquivo                                 |
|---------------------------|----------|-----------------------------------------|
| Market Intelligence Hub   | ATIVO    | features/market_intelligence/hub        |
| Competitor Discovery      | ATIVO    | features/market_intelligence/competitor |
| Niche Discovery           | ATIVO    | features/market_intelligence/niche      |
| Gap Analysis              | ATIVO    | features/market_intelligence/gap        |
| Content Cluster           | ATIVO    | features/market_intelligence/cluster    |
| Opportunity Discovery     | ATIVO    | features/market_intelligence/opportunity |
| Revenue Planner           | ATIVO    | features/market_intelligence/revenue    |
| Edge fn market-analysis   | ATIVO    | supabase/functions/market-analysis/     |
| Edge fn gap-analysis      | ATIVO    | supabase/functions/gap-analysis/        |
| Edge fn competitor-discovery | ATIVO | supabase/functions/competitor-discovery/|
| Edge fn niche-discovery   | ATIVO    | supabase/functions/niche-discovery/     |
| Edge fn opportunity-discovery | ATIVO | supabase/functions/opportunity-discovery/ |
| Edge fn revenue-planner   | ATIVO    | supabase/functions/revenue-planner/     |
| Edge fn content-cluster   | ATIVO    | supabase/functions/content-cluster/     |

### M5 — Opportunity Lab
| Item                     | Status         | Arquivo                                  |
|--------------------------|----------------|------------------------------------------|
| Opportunity Lab Screen   | ATIVO          | features/opportunity_lab/                |
| Opportunity Detail       | ATIVO          | features/opportunity_lab/detail          |
| OpportunityLabNotifier   | ATIVO          | providers/opportunity_lab_provider.dart  |
| Generate opp edge fn     | ATIVO          | supabase/functions/generate-project-opportunities/ |

### M6 — Action Engine
| Item                  | Status   | Arquivo                                     |
|-----------------------|----------|---------------------------------------------|
| Action Engine Screen  | ATIVO    | features/action_engine/action_engine_screen.dart |
| Action Detail         | ATIVO    | features/action_engine/action_detail_screen.dart |
| ActionQueueNotifier   | ATIVO    | providers/action_queue_provider.dart        |
| Generate actions fn   | ATIVO    | supabase/functions/generate-project-actions/ |

### M7 — Ecosystem Intelligence
| Item                      | Status   | Arquivo                                       |
|---------------------------|----------|-----------------------------------------------|
| Ecosystem Scores          | ATIVO    | providers/ecosystem_intelligence_provider.dart |
| Weekly Briefing           | ATIVO    | features/ecosystem/weekly_briefing_screen.dart |
| Executive Decision Center | ATIVO    | features/ecosystem/executive_decision_center_screen.dart |
| Resource Allocation       | ATIVO    | features/ecosystem/resource_allocation_screen.dart |
| Ecosystem View            | ATIVO    | features/ecosystem/ecosystem_view_screen.dart |
| Decision Simulator        | ATIVO    | providers/decision_simulator_provider.dart    |
| Edge fn decision-simulator | ATIVO   | supabase/functions/decision-simulator/        |

### M8 — Personas
| Item             | Status   | Arquivo                                  |
|------------------|----------|------------------------------------------|
| Personas CRUD    | ATIVO    | features/personas/                       |
| Persona Training | ATIVO    | features/personas/persona_training_screen.dart |

### M9 — Content Library
| Item               | Status   | Arquivo                                |
|--------------------|----------|----------------------------------------|
| Content Library    | ATIVO    | features/content/content_library_screen.dart |
| Content Form       | ATIVO    | features/content/content_form_screen.dart   |

### M10 — Campaign Builder
| Item                | Status   | Arquivo                                     |
|---------------------|----------|---------------------------------------------|
| Campaign Builder    | ATIVO    | features/campaigns/campaign_builder_screen.dart |
| Campaign Detail     | ATIVO    | features/campaigns/campaign_detail_screen.dart  |
| Edge fn campaign    | ATIVO    | supabase/functions/generate-campaign/       |

### M11 — Editorial Calendar
| Item            | Status   | Arquivo                              |
|-----------------|----------|--------------------------------------|
| Calendar Screen | ATIVO    | features/calendar/calendar_screen.dart |

### M12 — Website Analyzer
| Item                   | Status   | Arquivo                                       |
|------------------------|----------|-----------------------------------------------|
| Website Analyzer       | ATIVO    | features/website_analyzer/                   |
| Edge fn analyze-website | ATIVO   | supabase/functions/analyze-website/           |

### M13 — Performance Tracker
| Item                | Status   | Arquivo                                    |
|---------------------|----------|--------------------------------------------|
| Performance Screen  | ATIVO    | features/performance/performance_screen.dart |

### M14 — ROI Tracker
| Item           | Status   | Arquivo                                 |
|----------------|----------|-----------------------------------------|
| ROI Tracker    | ATIVO    | features/roi_tracker/roi_tracker_screen.dart |

### M15 — Asset Intelligence (Cofre)
| Item                   | Status     | Arquivo                                    |
|------------------------|------------|--------------------------------------------|
| Asset CRUD             | ATIVO      | providers/asset_provider.dart              |
| Asset Ingestion Hub    | ATIVO      | providers/asset_ingestion_provider.dart    |
| Asset Scores           | ATIVO      | providers/asset_score_provider.dart        |
| Asset Resources        | ATIVO      | data/models/asset_resource.dart            |
| Migrations 022/023/024 | PROPOSTA   | supabase/migrations/ (não aplicadas)       |
| UI Screen              | PENDENTE   | features/asset_intelligence/ (sem tela)    |

### M16 — IVE (Inteligência Virtual Executiva)
| Item                  | Status   | Arquivo                                    |
|-----------------------|----------|--------------------------------------------|
| context-copilot v2    | ATIVO    | supabase/functions/context-copilot/        |
| ive-agent-runner      | ATIVO    | supabase/functions/ive-agent-runner/       |
| IVE Gateway Routing   | ATIVO    | features/ive/services/ive_copilot_gateway.dart |
| IVE Agent Gateway     | ATIVO    | features/ive/services/ive_agent_gateway.dart |
| IVE Visual Runtime    | ATIVO    | features/ive/visual/                       |
| IVE Action Executor   | ATIVO    | features/ive/services/ive_action_executor.dart |
| IVE Memory Layer      | ATIVO    | providers/ive_memory_provider.dart         |

---

## Módulos NÃO Implementados (Fora de Escopo)

- InsightValues migration (PART E)
- IVE Research Engine (PART E)
- Living Thesis (PART E)
- Predictive Intelligence (PART E)
- SaaS / Billing / Multi-tenant (PART E)
- Memória persistente de agente (PART E)
- Streaming de respostas (PART E)
- Agentes especialistas (PART E)
