# AI Social Copilot — Problemas Conhecidos

**Data:** 2026-08-02  
**Audit:** Phase 10 Stabilization

---

## P0 — Bloqueadores de Produção

### KI-001: Google Drive OAuth com SHA-1 não registrado

**Sintoma:** Autenticação Google Drive falha em builds release.  
**Causa:** `android/app/google-services.json` contém dois objetos com `"certificate_hash": ""` vazio. O SHA-1 do keystore de release nunca foi extraído e registrado no Google Cloud Console.  
**Impacto:** Funcionalidade de importação de documentos do Drive completamente inoperante em release.  
**Resolução pendente:**
1. Executar o workflow `generate-keystore.yml` e copiar os secrets
2. Executar `build-apk.yml` para gerar APK assinado
3. Extrair SHA-1 do keystore: `keytool -list -v -keystore release.jks -alias upload -storepass Android123!`
4. Registrar SHA-1 no Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client IDs
5. Fazer download do novo `google-services.json` e substituir no projeto

---

## P1 — Degradação Funcional

### KI-002: Sem Android App Bundle (AAB) para Google Play Store

**Sintoma:** Workflows de CI geram apenas APK, não AAB.  
**Causa:** Nenhum workflow configurado com `flutter build appbundle`.  
**Impacto:** Publicação na Google Play Store exige AAB desde agosto de 2021.  
**Resolução pendente:** Adicionar job em `build-apk.yml` com `flutter build appbundle --release`.

### KI-003: Divergência de migrations entre branches

**Contexto:** `release/phase-10-stabilization` (baseado em `access-social-copilot-wJ6B5`) tem migrations 001–024. Branch de desenvolvimento `claude/ive-avatar-system-v2-yzjlvw` tem migrations 001–021.  
**Impacto:** 3 migrations (022, 023, 024) presentes na baseline não estão na branch de desenvolvimento.  
**Resolução pendente:** Cherry-pick ou aplicação manual das 3 migrations ausentes.

---

## P2 — Melhorias Técnicas

### KI-004: Edge Functions sem observabilidade estruturada

**Detalhe:** 10 das 17 Edge Functions não têm `console.error()` em blocos `catch`. Nenhuma função usa campo `error_code` semântico nas respostas de erro — todos os erros retornam apenas `{ "error": "<string>" }`.  
**Impacto:** Diagnóstico de falhas em produção depende de logs manuais do dashboard Supabase.  
**Resolução sugerida:** Adicionar interceptor de erro padronizado com campos `code`, `message`, `function`, `timestamp`.

### KI-005: Workflow `build-android.yml` legado dispara em push para `main`

**Detalhe:** O workflow marcado "LEGACY" ainda está configurado com `on: push: branches: [main]`. Isso gera builds desnecessários a cada push.  
**Resolução pendente:** Remover trigger automático ou desativar o workflow.

### KI-006: Keystore com senha hardcoded no workflow de geração

**Detalhe:** `generate-keystore.yml` usa `storepass Android123!` hardcoded.  
**Impacto:** A segurança do keystore depende de não vazar o arquivo `release.jks`.  
**Resolução sugerida:** Usar senha aleatória e armazenar apenas em secrets do GitHub.

### KI-007: `.withOpacity()` deprecated (3 ocorrências)

**Localização:** `lib/shared/widgets/score_chip.dart:20,22`, `test/features/ive/ive_visual_runtime_test.dart:148,149,154`  
**Causa:** API deprecated no Flutter 3.x — substituir por `.withValues(alpha: ...)` e `.r/.g` respectivamente.  
**Impacto:** Apenas warning `info` — não-blocante.

---

## Resolvidos na Phase 10 Stabilization (ETAPA 9)

| ID | Descrição | Arquivo(s) |
|----|-----------|------------|
| FIX-01 | `.eq()` chamado após `.order()` (PostgrestTransformBuilder) | `business_memory_service.dart` |
| FIX-02 | `IveAvatarAnimationControllerV2` sem construtor público | `ive_avatar_animation_controller.dart` |
| FIX-03 | `SingleTickerProviderStateMixin` com múltiplos tickers | `ive_avatar_compact.dart`, `ive_avatar_assistant_button.dart`, `ive_avatar_v2.dart` |
| FIX-04 | `IveAvatarController.dispose()` não-idempotente | `ive_avatar_controller.dart` |
| FIX-05 | Badge debug "RIVE ASSET PENDING" poluindo semantic label | `ive_visual_fallback.dart` |
| FIX-06 | `matchesSemantics()` sem `isImage: true` | `ive_visual_runtime_test.dart` |
| FIX-07 | `AsyncData([p])` — igualdade por referência em lista | `project_provider_test.dart` |
| FIX-08 | Mocktail `.thenAnswer()` encadeado (void) | `project_provider_test.dart`, `project_reactive_chain_test.dart` |
| FIX-09 | Timer Riverpod pendente após `pump()` | `ive_avatar_v2_test.dart` |
| FIX-10 | `extract-knowledge` sem suporte PDF/DOCX | `supabase/functions/extract-knowledge/index.ts` |
| FIX-11 | Showcase overflow (`Row` horizontal + `GridView` aspect ratio) | `ive_avatar_showcase_page.dart` |
| FIX-12 | Diretório `assets/ive/rive/` ausente (referenciado em pubspec.yaml) | `assets/ive/rive/.gitkeep` |
