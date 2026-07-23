# Known Issues — AI Social Copilot

**Data:** 2026-07-23

---

## Críticos (P0) — Bloqueadores

### KI-001: Migrations 022/023/024 não aplicadas em produção
**Status:** ABERTO — aguardando autorização explícita
**Descrição:** As migrations para Asset Intelligence (022), asset_id em opp/action (023), e asset_resources (024) foram criadas mas marcadas como "proposta". O código Flutter e os providers de assets já existem e funcionam, mas as tabelas não existem em produção.
**Impacto:** Módulo Asset Intelligence (M15) não funciona em produção.
**Resolução:** Requer autorização manual do usuário antes de aplicar.
**Arquivo:** `supabase/migrations/022_asset_intelligence_foundation.sql`

---

## Altos (P1)

### KI-002: ive-agent-runner não deployado
**Status:** ABERTO — intencional (restrição de segurança)
**Descrição:** A edge function `ive-agent-runner` existe no código mas não está deployada em produção. Isso significa que o agent mode (Phase 1B/1C) não está ativo.
**Impacto:** IVE sempre usa `context-copilot` legado.
**Resolução:** Deploy separado com aprovação explícita + OPENAI_API_KEY configurada.

### KI-003: Feature flag ive_agent_mode = false globalmente
**Status:** ABERTO — intencional (restrição de segurança)
**Descrição:** A flag `ive_agent_mode` está desativada para todos os usuários. Apenas internal testers com row `ive_agent_mode_tester_<uid>` teriam acesso ao agent mode se a função estivesse deployada.
**Impacto:** Nenhum usuário acessa o agent mode.
**Resolução:** Ativar somente após deploy e testes de integração.

### KI-004: UI de Asset Intelligence sem tela principal
**Status:** ABERTO
**Descrição:** Os providers, services e modelos de Asset Intelligence existem e têm testes, mas não há tela Flutter principal para o Cofre de Ativos (M15).
**Impacto:** Usuário não consegue acessar Assets pela UI.
**Resolução:** Implementar `features/asset_intelligence/asset_intelligence_screen.dart`.

---

## Médios (P2)

### KI-005: Projetos sem análise de mercado têm scores derivados de fallback
**Status:** ABERTO — documentado
**Descrição:** Quando um projeto não tem `market_analysis` vinculada, o `opportunity_score` é calculado via fallback com `priority_score` e `revenue_potential` do projeto. Esses valores podem ser arbitrários (não derivados de análise real).
**Impacto:** `ecosystem_score` e `market_score` = 0 para projetos sem análise.
**Resolução:** A1–A5 do hotfix (inventário + análise + backfill).
**Detecção:** `has_enough_data = false` + `market_score = 0` no EcosystemScore.

### KI-006: ROI Score = 0 sem métricas registradas
**Status:** ABERTO — comportamento esperado, mas não visível para o usuário
**Descrição:** O ROI Score sempre retorna 0 para projetos que não registraram métricas de ROI ou não têm revenue_plan.
**Impacto:** Projetos novos têm ecosystem_score artificialmente baixo.
**Resolução:** UI deve exibir claramente que o score é parcial quando has_enough_data=false.

### KI-013: IveRoutingGateway não cobria fallback para exceções não-IveCopilotHttpException
**Status:** RESOLVIDO (hotfix H2)
**Descrição:** `IveRoutingGateway.invoke()` só capturava `IveCopilotHttpException`. Exceções inesperadas do agent (ex: `SocketException`, `FormatException`) propagavam para fora sem atingir o branch de fallback para o legado. Adicionalmente, se `resolveAgentMode()` lançasse, a exceção subia sem fallback.
**Fix:** Adicionado `try-catch` ao redor de `resolveAgentMode()` (default: false → legado) e adicionado `catch (e)` genérico após o handler tipado para log + fallback a `context-copilot`.
**Arquivos:** `lib/features/ive/services/ive_copilot_gateway.dart`

### KI-014: saveAnalysis sobrescrevia análise anterior silenciosamente
**Status:** RESOLVIDO (hotfix H1)
**Descrição:** `KnowledgeService.saveAnalysis()` fazia upsert por `knowledge_item_id` (comportamento intencional — 1 análise por item), mas sem nenhum rastro da análise anterior.
**Fix:** Antes do upsert, lê a análise existente e persiste `score_opportunity` + `replaced_at` em `scoreDetails['_prev']` (campo JSONB existente). Sem migration. O score anterior é rastreável via `knowledge_analysis.score_details._prev`.
**Arquivos:** `lib/data/services/knowledge_service.dart`

### KI-007: Timeout .timeout(5s) removido da capability check
**Status:** RESOLVIDO (commit 29b78a9)
**Descrição:** O `.timeout(const Duration(seconds: 5))` em `_defaultCapabilityFetcher` causava timer leaking em widget tests (39 falhas). Removido em 29b78a9 e substituído por queries DB em 10fbc4f.
**Fix:** `_defaultCapabilityFetcher` agora usa queries DB diretas.

### KI-008: Google Drive Picker requer configuração OAuth em produção
**Status:** ABERTO — requer configuração de credenciais
**Descrição:** O `drive_picker_screen.dart` usa `google_sign_in` que requer `google-services.json` (Android) ou `GoogleService-Info.plist` (iOS) configurados.
**Impacto:** Feature de importação do Drive não funciona sem configuração OAuth.

---

## Baixos (P3)

### KI-009: supabase_flutter pinado < 2.15.0
**Status:** ABERTO — intencional
**Descrição:** `supabase_flutter: ">=2.5.6 <2.15.0"` para evitar crash `passkeys_web` no GitHub Pages.
**Impacto:** Não pode usar features das versões 2.15+.
**Resolução:** Monitorar quando `passkeys_web` for corrigido upstream.

### KI-010: file_picker em versão beta
**Status:** ABERTO — intencional
**Descrição:** `file_picker: ">=12.0.0-beta.1"` necessário para compatibilidade com `win32 ^6`.
**Impacto:** Potencial instabilidade em edge cases.

### KI-011: Rive animation fallback sempre ativo
**Status:** ABERTO
**Descrição:** A IVE usa fallback PNG quando o arquivo `.riv` não está disponível. O arquivo `.riv` não está no repositório.
**Impacto:** IVE aparece como PNG estático, não animação Rive.
**Resolução:** Adicionar o arquivo `.riv` ou aceitar o fallback como comportamento padrão.

### KI-012: esm.sh substituído por npm: em imports Deno
**Status:** RESOLVIDO (commit 73a9463)
**Descrição:** `esm.sh/@supabase/supabase-js@2` retornava HTTP 522 (CDN timeout) em CI.
**Fix:** Todos os imports Deno nas edge functions usam `npm:@supabase/supabase-js@2`.
