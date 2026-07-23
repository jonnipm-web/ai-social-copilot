# Changelog — AI Social Copilot

**Branch:** `claude/access-social-copilot-wJ6B5`

---

## [Fase 1C] — 2026-07-21 / 2026-07-23

### Adicionado
- `IveCapabilityFetcher` typedef sem parâmetro uid (segurança arquitetural)
- `iveCapabilityFetcherProvider` sobrescritível em testes
- `iveAgentModeProvider` FutureProvider público com fail-safe duplo
- `IveRoutingGateway` com metadado `gateway_used` (diagnóstico sem dados sensíveis)
- `isInternalTester()` no `permission_engine.ts` (lê INTERNAL_TESTER_IDS server-side)
- Capability check endpoint no `ive-agent-runner` (step 3b, sem rodar agent loop)
- `AppConstants.edgeFunctionAgentRunner`
- Testes T1–T5 em `ive_gateway_routing_test.dart`
- Testes 8.5–8.8 em `index_test.ts` (allowlist, combined, response shape)
- `_defaultCapabilityFetcher` via queries DB (feature_flags table)
- Suporte a internal tester via row `ive_agent_mode_tester_<uid>`

### Corrigido
- Timer leaking em widget tests (removido `.timeout(5s)` da capability check — commit 29b78a9)
- `_defaultCapabilityFetcher` migrado para queries DB (commit 10fbc4f)
- `prefer_function_declarations_over_variables` lint warning (commit 9b0623e)
- UUID RFC 4122 inválido em `ive_phase1b_test.dart` (commit 04dc7d9)
- `esm.sh` → `npm:` em todos os imports Deno (commit 73a9463)
- `null` → `undefined` em campos opcionais TypeScript (commit 0946c8e)
- `ecosystemScore = 0` no test 1.1 via `emptyProject` (commit 04dc7d9)
- Imports não utilizados removidos de test files

---

## [Fase 1B] — 2026-07-18 / 2026-07-21

### Adicionado
- Edge function `ive-agent-runner` completa (5 turnos, 11 ferramentas)
- `AIProvider` abstrato com OpenAI primário e Groq fallback
- `Permission Engine` (READ/PROPOSE/EXECUTE levels)
- `Score Engine` com fórmula idêntica à UI Flutter
- Comparação cross-project segura
- Observabilidade: correlation_id, provider, model, turns, tools, latency
- 70 testes Deno cobrindo todos os componentes da edge function

### CI
- Todos os 4 jobs passando: Deno, validate, build-web, build

---

## [Fase 1A] — 2026-07 (anterior)

### Base
- Autenticação Supabase com JWT
- 24 migrations (001–024, sendo 022/023/024 propostas)
- Providers Riverpod para todos os módulos
- 16 módulos implementados (M0–M16)
- Ecosystem Intelligence com scoring ponderado
- IVE Visual Runtime com fallback Rive→PNG
- Asset Intelligence Foundation (providers e models, sem UI e sem migrations)
- Todos os edge functions de análise (market, knowledge, campaign, etc.)
- AutoBootstrap para projetos sem dados de inteligência
- Security guards: admin trigger, RLS policies, _requireUid()
