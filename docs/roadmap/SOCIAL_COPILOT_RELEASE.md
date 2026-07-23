# Social Copilot — Release Readiness

**Data:** 2026-07-23
**Objetivo:** Finalização dos módulos B1–B12 para release

---

## Status por Módulo

### B1 — Assets / Cofre de Ativos (M15)
| Item                   | Status     | Notas                                         |
|------------------------|------------|-----------------------------------------------|
| Providers/Services     | COMPLETO   | asset_provider, asset_ingestion_provider       |
| Modelos de dados       | COMPLETO   | Asset, AssetScore, AssetResource, AssetProvenance |
| Testes de providers    | COMPLETO   | asset_provider_test, asset_score_test, etc.   |
| Migrations 022/023/024 | PENDENTE   | Aguarda autorização para aplicar em prod      |
| Tela principal UI      | PENDENTE   | features/asset_intelligence/ não existe        |
| **Bloqueador**         | KI-001     | Migrations não aplicadas                      |

### B2 — Knowledge Vault / Library (M3)
| Item                   | Status     | Notas                                         |
|------------------------|------------|-----------------------------------------------|
| CRUD de Knowledge Items | COMPLETO  | knowledge_vault_screen.dart                   |
| Knowledge Analysis     | COMPLETO   | knowledge_analysis_screen.dart                |
| Strategy Generation    | COMPLETO   | strategy_screen.dart                          |
| Drive Picker           | COMPLETO   | drive_picker_screen.dart (requer OAuth config)|
| Edge functions         | COMPLETO   | extract-knowledge, generate-strategy          |
| **Status geral**       | PRONTO     | Sem bloqueadores pendentes                    |

### B3 — Personas (M8)
| Item                   | Status     | Notas                                         |
|------------------------|------------|-----------------------------------------------|
| CRUD de Personas       | COMPLETO   | personas_screen.dart, persona_form_screen.dart |
| Persona Training       | COMPLETO   | persona_training_screen.dart                  |
| **Status geral**       | PRONTO     | Sem bloqueadores pendentes                    |

### B4 — Content Generation (M1 + M9)
| Item                     | Status     | Notas                                       |
|--------------------------|------------|---------------------------------------------|
| Post Generation (MVP)    | COMPLETO   | content_generation_screen.dart              |
| Result Screen            | COMPLETO   | result_screen.dart                          |
| Content Library          | COMPLETO   | content_library_screen.dart                 |
| Content Form             | COMPLETO   | content_form_screen.dart                    |
| Histórico de posts       | COMPLETO   | history_screen.dart                         |
| Edge fn improve-post     | COMPLETO   | supabase/functions/improve-post/            |
| **Status geral**         | PRONTO     | Sem bloqueadores pendentes                  |

### B5 — Campaign Builder (M10)
| Item                   | Status     | Notas                                         |
|------------------------|------------|-----------------------------------------------|
| Campaign Builder       | COMPLETO   | campaign_builder_screen.dart                  |
| Campaign Detail        | COMPLETO   | campaign_detail_screen.dart                   |
| Edge fn campaign       | COMPLETO   | generate-campaign                             |
| **Status geral**       | PRONTO     | Sem bloqueadores pendentes                    |

### B6 — Editorial Calendar (M11)
| Item                   | Status     | Notas                                         |
|------------------------|------------|-----------------------------------------------|
| Calendar Screen        | COMPLETO   | calendar_screen.dart                          |
| Status workflow        | COMPLETO   | ideia → publicado pipeline                    |
| **Status geral**       | PRONTO     | Sem bloqueadores pendentes                    |

### B7 — Website Analyzer (M12)
| Item                   | Status     | Notas                                         |
|------------------------|------------|-----------------------------------------------|
| Analyzer Screen        | COMPLETO   | website_analyzer_screen.dart                  |
| Result Screen          | COMPLETO   | website_analysis_result_screen.dart           |
| Edge fn analyze-website | COMPLETO  | supabase/functions/analyze-website/           |
| **Status geral**       | PRONTO     | Sem bloqueadores pendentes                    |

### B8 — Performance Tracker (M13)
| Item                   | Status     | Notas                                         |
|------------------------|------------|-----------------------------------------------|
| Performance Screen     | COMPLETO   | performance_screen.dart                       |
| 12+ tipos de métricas  | COMPLETO   | impressões, clicks, likes, leads, sales, etc. |
| **Status geral**       | PRONTO     | Sem bloqueadores pendentes                    |

### B9 — Market Intelligence (M4)
| Item                   | Status     | Notas                                         |
|------------------------|------------|-----------------------------------------------|
| Intelligence Hub       | COMPLETO   | market_intelligence_hub_screen.dart           |
| Todos os sub-módulos   | COMPLETO   | competitor, niche, gap, cluster, opportunity  |
| Revenue Planner        | COMPLETO   | revenue_planner_screen.dart                   |
| **Status geral**       | PRONTO     | Sem bloqueadores pendentes                    |

### B10 — Opportunity Lab (M5)
| Item                     | Status     | Notas                                       |
|--------------------------|------------|---------------------------------------------|
| Opportunity Lab Screen   | COMPLETO   | opportunity_lab_screen.dart                 |
| Opportunity Detail       | COMPLETO   | opportunity_detail_screen.dart              |
| IVE context sync         | COMPLETO   | openIveWithContext / synchronize             |
| **Status geral**         | PRONTO     | Sem bloqueadores pendentes                  |

### B11 — IVE Audit (M16)
| Item                       | Status     | Notas                                     |
|----------------------------|------------|-------------------------------------------|
| context-copilot v2         | COMPLETO   | deployado e funcionando                   |
| Gateway routing            | COMPLETO   | IveRoutingGateway + capability check      |
| ive-agent-runner           | COMPLETO   | código pronto, deploy pendente (KI-002)   |
| Agent mode interno testers | COMPLETO   | via feature_flags DB row                  |
| **Status geral**           | PARCIAL    | Agent mode não ativo em prod              |

### B12 — ROI Tracker + Ecosystem (M14 + M7)
| Item                     | Status     | Notas                                       |
|--------------------------|------------|---------------------------------------------|
| ROI Tracker              | COMPLETO   | roi_tracker_screen.dart                     |
| Ecosystem Intelligence   | COMPLETO   | scores, briefing, decisão, recursos         |
| Executive Dashboard      | COMPLETO   | executive_dashboard_screen.dart             |
| Weekly Briefing          | COMPLETO   | weekly_briefing_screen.dart                 |
| **Status geral**         | PRONTO     | Scores dependem de dados (A1–A5)            |

---

## Sumário de Release Readiness

| Módulo | Status   | Bloqueadores      |
|--------|----------|-------------------|
| B1 Cofre    | PARCIAL  | KI-001 + UI       |
| B2 Library  | PRONTO   | —                 |
| B3 Personas | PRONTO   | —                 |
| B4 Content  | PRONTO   | —                 |
| B5 Campaigns | PRONTO  | —                 |
| B6 Calendar | PRONTO   | —                 |
| B7 Website  | PRONTO   | —                 |
| B8 Performance | PRONTO | —                |
| B9 Market   | PRONTO   | —                 |
| B10 Opp Lab | PRONTO   | —                 |
| B11 IVE     | PARCIAL  | KI-002 (intencional)|
| B12 ROI/Eco | PRONTO   | Qualidade dos dados|

**10/12 módulos prontos para release.**
**2/12 com bloqueadores conhecidos e documentados.**
