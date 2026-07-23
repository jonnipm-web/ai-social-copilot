# Handoff — AI Social Copilot

**Data:** 2026-07-23
**Branch:** `claude/access-social-copilot-wJ6B5`
**Último commit:** 10fbc4f (fix: capability check via DB queries)

---

## Estado Atual do Branch

O branch está à frente do histórico original e contém toda a Fase 1B e 1C.
CI último resultado: SUCCESS (commit 2143912, 4/4 jobs passando).
Commit 10fbc4f aguarda CI manual (workflow_dispatch).

---

## Para Disparar o CI

1. Acesse: https://github.com/jonnipm-web/ai-social-copilot/actions
2. Clique em "BUILD WEEK — VALIDAR E GERAR APK"
3. Run workflow → branch `claude/access-social-copilot-wJ6B5`

---

## Arquivos Principais Modificados nesta Sessão

| Arquivo | O que mudou |
|---------|-------------|
| `lib/features/ive/services/ive_copilot_gateway.dart` | _defaultCapabilityFetcher migrado para DB queries; IveRoutingGateway adicionado |
| `supabase/functions/ive-agent-runner/permission_engine.ts` | isInternalTester() + isAgentModeEnabled() com uid param |
| `supabase/functions/ive-agent-runner/index.ts` | Step 3b capability check; Step 4 passa uid |
| `supabase/functions/ive-agent-runner/index_test.ts` | 70 testes Deno; testes 8.5–8.8 adicionados |
| `test/features/ive/ive_gateway_routing_test.dart` | T1–T5 novos (criado nesta sessão) |
| `lib/core/constants/app_constants.dart` | edgeFunctionAgentRunner adicionado |
| `docs/roadmap/` | Todos os arquivos de documentação criados |

---

## Próximos Passos (Por Prioridade)

### IMEDIATO — Validar CI
- Disparar workflow_dispatch no branch
- Confirmar 4/4 jobs passando com commit 10fbc4f

### P0 — Migrations 022/023/024
- Revisar KNOWN_ISSUES.md KI-001
- Após autorização: `supabase db push` ou aplicar via Supabase Dashboard
- Isso desbloqueia o módulo Asset Intelligence (B1)

### P1 — Tela de Asset Intelligence
- Criar `lib/features/asset_intelligence/asset_intelligence_screen.dart`
- Conectar aos providers existentes (assetsForProjectProvider, assetScoreProvider)
- Incluir Smart Import (asset_ingestion_provider)

### P1 — Backfill de Projetos Sem Análise
- Executar query de inventário (PROJECT_ANALYSIS_AUDIT.md seção 3)
- Para cada projeto sem dados: reprocessar via AutoBootstrap
- Verificar `has_enough_data = true`

### P1 — UI de Score Explicável
- Expor `ScoreBreakdown` na tela de projeto
- Mostrar `confidence` (HIGH/MEDIUM/LOW/INSUFFICIENT) além do score numérico
- Exibir alerta visual quando `has_enough_data = false`

### P2 — Deploy ive-agent-runner
- Requer autorização explícita
- Requer OPENAI_API_KEY configurada no Supabase
- Requer INTERNAL_TESTER_IDS configurado para testes internos
- Requer testes de integração E2E com o agent mode

---

## Segredos Necessários em Produção

| Segredo Supabase          | Onde usar                   | Status    |
|---------------------------|-----------------------------|-----------|
| OPENAI_API_KEY            | ive-agent-runner            | NÃO configurado |
| GROQ_API_KEY              | context-copilot, ive-agent-runner | Configurado? |
| INTERNAL_TESTER_IDS       | ive-agent-runner (env var)  | NÃO configurado |

---

## Arquitetura de Segurança (NUNCA ALTERAR)

1. **uid sempre do JWT**: `getAuthenticatedUid(client)` no servidor, `client.auth.currentUser?.id` no Flutter apenas para lookup local
2. **INTERNAL_TESTER_IDS**: variável de ambiente server-side, NUNCA exposta ao Flutter
3. **Capability check via DB**: Flutter lê `feature_flags` diretamente, servidor valida INTERNAL_TESTER_IDS via JWT em cada request real
4. **Gateway fail-safe**: qualquer erro → `false` → context-copilot legado
5. **IveRoutingGateway**: `AGENT_DISABLED` do servidor recua ao legado automaticamente

---

## Checklist de Release Gate (PART H)

- [ ] CI: 4/4 jobs passando (Deno + analyze + test + build)
- [ ] 0 warnings flutter analyze --fatal-warnings
- [ ] ive_gateway_routing_test.dart T1–T5 passando
- [ ] index_test.ts 70/70 passando
- [ ] KNOWN_ISSUES.md atualizado
- [ ] Migrations 022/023/024 autorizadas ou explicitamente adiadas
- [ ] ive-agent-runner deployado ou explicitamente adiado
- [ ] Documentação /docs/roadmap/ completa e revisada
