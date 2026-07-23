# Test Matrix — AI Social Copilot

**Data:** 2026-07-23
**CI:** workflow_dispatch → BUILD WEEK — VALIDAR E GERAR APK

---

## Status Geral

| Suite                    | Total  | Passando | Falhando | Última execução   |
|--------------------------|--------|----------|----------|-------------------|
| Deno (Edge Functions)    | 70     | 70       | 0        | 2026-07-23 (CI)   |
| Flutter Unit/Widget      | ~180   | ~180     | 0        | 2026-07-23 (CI)   |
| Flutter Analyze          | —      | OK       | —        | 2026-07-23 (CI)   |
| Build APK                | —      | OK       | —        | 2026-07-23 (CI)   |
| Build Web                | —      | OK       | —        | 2026-07-23 (CI)   |

---

## Deno Tests — supabase/functions/

### context-copilot/index_test.ts
- Autenticação JWT (válido/inválido/ausente)
- Validação de payload (message, project_id, history)
- History sanitization (tamanho, truncamento)
- Error handling (timeout, MODEL_ERROR, SERVER_ERROR)
- Response format (backward-compatible)

### ive-agent-runner/index_test.ts (70 testes)
| Grupo | Testes | Descrição |
|-------|--------|-----------|
| 1.x   | Score Engine (5) | opportunity, market, execution, strategic, weighted |
| 2.x   | Permission Engine (8) | READ/PROPOSE/EXECUTE, ownership, auth |
| 3.x   | Agent Loop (6) | max turns, tool calls, result format |
| 4.x   | Tool Registry (11) | Uma por ferramenta |
| 5.x   | AIProvider (4) | OpenAI/Groq fallback, error handling |
| 6.x   | Response Format (8) | backward-compat com context-copilot v2 |
| 7.x   | Payload Validation (6) | size, chars, history |
| 8.x   | Internal Tester (8) | allowlist, env var, combined, capability check |

---

## Flutter Tests — test/

### core/
| Arquivo                         | Descrição                            |
|---------------------------------|--------------------------------------|
| date_parser_test.dart           | DateParser utility                   |
| service_auth_guard_test.dart    | _requireUid() em todos os services   |
| profile_authorization_test.dart | Role-based permissions               |
| market_analysis_auth_test.dart  | Market analysis auth boundaries      |

### data/
| Arquivo                        | Descrição                            |
|--------------------------------|--------------------------------------|
| asset_integration_test.dart    | CRUD lifecycle de assets             |
| asset_model_test.dart          | Serialização/desserialização         |
| asset_score_test.dart          | Cálculo de AssetScore                |

### data/ingestion/
| Arquivo                          | Descrição                           |
|----------------------------------|-------------------------------------|
| asset_classifier_test.dart       | Detecção de tipo de asset           |
| text_parser_test.dart            | Parsing de conteúdo texto           |
| zip_security_test.dart           | ZIP bomb + path traversal           |
| url_parser_test.dart             | Parsing de URL                      |
| asset_ingestion_models_test.dart | Modelos de ingestão                 |
| asset_duplicate_checker_test.dart | SHA-256 deduplication              |

### providers/
| Arquivo                            | Descrição                          |
|------------------------------------|------------------------------------|
| ive_event_test.dart                | IVE event bus                      |
| opportunity_lab_flow_test.dart     | Opportunity → Action (idempotência)|
| asset_ingestion_provider_test.dart | AssetIngestionNotifier states      |
| asset_score_provider_test.dart     | assetScoreProvider family          |
| selected_project_provider_test.dart | Persistência + auth-change        |
| asset_provider_test.dart           | AssetsNotifier CRUD                |
| asset_integration_provider_test.dart | Provider chain integration       |
| project_provider_test.dart         | ProjectsNotifier + cascade         |

### features/ive/
| Arquivo                              | Descrição                         |
|--------------------------------------|-----------------------------------|
| ive_action_proposal_test.dart        | IveActionProposal data class      |
| ive_action_confirmation_card_test.dart | Widget test                     |
| ive_hotfix_regression_test.dart      | Regressões conhecidas             |
| ive_copilot_v2_contract_test.dart    | IveCopilotResponse.parse()        |
| ive_action_executor_test.dart        | IveActionExecutor dispatch        |
| ive_context_scope_test.dart          | Context isolation                 |
| ive_non_obstructive_context_test.dart | IVE não bloqueia interações      |
| ive_visual_runtime_test.dart         | Rive → PNG fallback               |
| ive_response_context_panel_test.dart | Widget: context panel             |
| ive_interaction_gate_test.dart       | Throttling/gating                 |
| ive_copilot_v2_notifier_test.dart    | ContextCopilotNotifier states     |
| ive_etapa3_hotfix_test.dart          | 39 widget tests (fase 3 hotfix)   |
| ive_phase1b_test.dart                | Phase 1B agent runner             |
| ive_project_context_hotfix_test.dart | Project context scope bug         |
| ive_p0_integration_hotfix_test.dart  | P0 integration regression         |
| ive_security_context_hotfix_test.dart | Security context isolation       |
| ive_gateway_routing_test.dart        | T1–T5 gateway routing             |

### features/projects/
| Arquivo                              | Descrição                         |
|--------------------------------------|-----------------------------------|
| project_command_center_logic_test.dart | Business logic                  |

### shared/widgets/
| Arquivo                           | Descrição                            |
|-----------------------------------|--------------------------------------|
| ive_overlay_interaction_test.dart | IVE overlay behavior                 |

### integration/
| Arquivo                         | Descrição                              |
|---------------------------------|----------------------------------------|
| e2e_foundation_01_test.dart     | auth → project → intelligence E2E      |
| project_reactive_chain_test.dart | Reactive invalidation chain           |
| user_isolation_test.dart        | Dados isolados por usuário             |

---

## Contratos de Teste Arquitetural

1. **IveCapabilityFetcher sem uid**: `_noUidFetcher` em `ive_gateway_routing_test.dart` garante que o typedef não aceita parâmetro uid
2. **_requireUid() em todos os services**: `service_auth_guard_test.dart` verifica que não há acesso a dados sem sessão
3. **User isolation**: `user_isolation_test.dart` verifica que dados de um usuário não aparecem para outro
4. **Idempotência Opportunity→Action**: índice UNIQUE no `opportunity_lab_id` (migration 020)
5. **ZIP security**: `zip_security_test.dart` verifica bomb detection e path traversal
