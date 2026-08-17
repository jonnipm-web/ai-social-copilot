# AI Social Copilot — Current Technical Baseline

**Data:** 2026-08-02  
**Branch canônica:** `release/phase-10-stabilization`  
**Branch de desenvolvimento ativo:** `claude/ive-avatar-system-v2-yzjlvw`  
**Audit:** Phase 10 Stabilization — 12 ETAPAs concluídas

---

## Versão e SDK

| Item | Valor |
|------|-------|
| App version | 1.0.0+1 |
| Dart SDK constraint | `>=3.3.0 <4.0.0` |
| Flutter channel | stable |
| Supabase Flutter | `>=2.5.6 <2.15.0` |
| Flutter Riverpod | `^2.5.1` |
| Rive | `^0.13.12` |
| Google Sign-In | `^6.2.1` |
| Mocktail (dev) | `^1.0.4` |

---

## Resultados da Auditoria de Estabilização

### Testes — VERDE ✅
- **101 testes passando / 0 falhas**
- Suítes: `ive_avatar_v2_test`, `ive_visual_runtime_test`, `project_provider_test`, `project_reactive_chain_test`, `project_command_center_logic_test`
- 9 bugs corrigidos nesta sessão (ver KNOWN_ISSUES.md para detalhes)

### Análise Estática — VERDE ✅
- `flutter analyze` — **0 erros / 0 warnings** no código da aplicação
- Avisos `info` remanescentes: uso de `.withOpacity()` deprecated (3 ocorrências em `score_chip.dart` e `ive_visual_runtime_test.dart`) — não-blocantes

### Formatação — VERDE ✅
- `dart format` aplicado em toda `lib/` e `test/`
- 183 arquivos reformatados na ETAPA 9

---

## Estrutura do Projeto

### Features (24)
`action_engine`, `admin`, `advisor`, `auth`, `calendar`, `campaigns`, `content`,
`dashboard`, `debug`, `ecosystem`, `history`, `home`, `ive`, `knowledge`,
`market_intelligence`, `opportunity_lab`, `performance`, `personas`, `projects`,
`result`, `roi_tracker`, `splash`, `upgrade`, `website_analyzer`

### Serviços de Dados (28)
Localizados em `lib/data/services/`. Todos usam `SupabaseClient` via injeção de dependência.

### Providers Riverpod (32)
Localizados em `lib/providers/`. Padrão: `AsyncNotifierProvider` / `FutureProvider` + `StateNotifierProvider`.

### Edge Functions Supabase (17)
`analyze-website`, `competitor-discovery`, `content-cluster`, `context-copilot`,
`decision-simulator`, `extract-knowledge`, `gap-analysis`, `generate-campaign`,
`generate-project-actions`, `generate-project-opportunities`, `generate-strategy`,
`improve-post`, `market-analysis`, `niche-discovery`, `opportunity-discovery`,
`process-file`, `revenue-planner`

---

## Migrations Aplicadas

| Número | Arquivo | Status |
|--------|---------|--------|
| 001–021 | `supabase/migrations/*.sql` | Aplicadas no ambiente de desenvolvimento |

> **ATENÇÃO:** A branch `release/phase-10-stabilization` contém migrations até 024 (do baseline `access-social-copilot-wJ6B5`). A branch de desenvolvimento (`claude/ive-avatar-system-v2-yzjlvw`) tem até 021. Divergência de 3 migrations — ver KNOWN_ISSUES.md.

---

## CI/CD

| Workflow | Trigger | Finalidade |
|----------|---------|------------|
| `build-apk.yml` | `workflow_dispatch` | APK release assinado (canônico) |
| `build-android.yml` | `push main` + `workflow_dispatch` | LEGADO — APK simples |
| `deploy-edge-functions.yml` | — | Deploy de Edge Functions |
| `deploy-supabase.yml` | — | Deploy de migrations |
| `generate-keystore.yml` | `workflow_dispatch` | Geração única do keystore |

> **Sem AAB:** Nenhum workflow gera Android App Bundle (`.aab`). Necessário para Google Play Store.

---

## Feature Flags

| Flag | Default | Status |
|------|---------|--------|
| `iveAvatarV2Enabled` | `false` | DESATIVADA — não integrada em produção |

---

## Segurança — Confirmações

- `SUPABASE_SERVICE_KEY` **NÃO** escrito em nenhum arquivo
- Secrets de signing apenas no job de release, via `workflow_dispatch`
- Avatar V2 isolado em `lib/shared/ive_avatar/` — sem entrada em `main.dart`
- `IveOverlay` (legacy) preservado intacto
