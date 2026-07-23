# Fase Atual — AI Social Copilot

**Data:** 2026-07-23
**Branch ativo:** `claude/access-social-copilot-wJ6B5`
**CI Status:** Requer disparo manual via workflow_dispatch

---

## Fases Concluídas

### Fase 1A — Fundação (CONCLUÍDA)
- Autenticação Supabase com RLS
- Modelos de dados base (Project, Persona, KnowledgeItem, etc.)
- Providers Riverpod com `_requireUid()` em todos os services
- `selectedProjectProvider` com persistência e restauração de sessão

### Fase 1B — IVE Agent Foundation (CONCLUÍDA — 70/70 testes Deno)
- Edge function `ive-agent-runner` com loop de agente (max 5 turnos)
- Tool Registry V1 (11 ferramentas)
- AIProvider abstrato (OpenAI primário, Groq fallback)
- Permission Engine (READ/PROPOSE/EXECUTE)
- Score Engine com fórmula idêntica à UI Flutter
- Resposta backward-compatible com `context-copilot` v2
- Todos os testes CI passando (Deno + Flutter analyze + Flutter test + APK)

### Fase 1C — Gateway de Roteamento IVE (CONCLUÍDA — aguardando CI)
- `IveCapabilityFetcher` — typedef injetável sem parâmetro uid
- `iveCapabilityFetcherProvider` — sobrescritível em testes
- `iveAgentModeProvider` — FutureProvider público com fail-safe duplo
- `IveRoutingGateway` — gateway observável e testável com metadado `gateway_used`
- `_defaultCapabilityFetcher` via queries DB (feature_flags) — sem timeout leaking
- Internal tester: row `ive_agent_mode_tester_<uid>` no feature_flags (sem migration)
- `isInternalTester()` no permission_engine.ts (server-side, lê INTERNAL_TESTER_IDS)
- Capability check endpoint: `POST ive-agent-runner { capability_check: true }`
- Testes: `ive_gateway_routing_test.dart` (T1–T5), `ive_phase1b_test.dart`, `index_test.ts` (70 testes)

---

## Fase Atual em Execução

### Fase P0/P1 — Hotfix Análise de Projetos + Social Copilot Release

**Status:** INICIANDO

**Objetivos:**
1. Auditar todos os projetos sem análise (A1–A3)
2. Auditar scores e detectar scores não confiáveis (A4–A5)
3. Implementar score explicável + separação score/confiança (A6–A7)
4. Métrica de completude e versionamento de metodologia (A8–A9)
5. Auditoria de recomendações e integração IVE (A10–A13)
6. Finalização módulos Social Copilot (B1–B12)
7. Fluxos E2E (C)
8. Documentação (G) — EM ANDAMENTO
9. Release Gate (H)

---

## Restrições Ativas (NÃO ALTERAR)

- NÃO expor INTERNAL_TESTER_IDS ao Flutter
- NÃO colocar UID hardcoded no APK
- NÃO ativar agent mode globalmente
- NÃO criar bypass baseado em email/client payload
- Identidade sempre derivada da sessão autenticada (JWT)
- NÃO criar migration automaticamente
- NÃO configurar OPENAI_API_KEY real
- NÃO fazer deploy ive-agent-runner
- NÃO ativar flag global ive_agent_mode
- NÃO iniciar POCs A-E
- NÃO mergear main
- NÃO remover context-copilot nem Groq legado
- NÃO implementar memória persistente, streaming, agentes especialistas
- NÃO alterar migrations 022/023/024
