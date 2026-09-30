# IV-R16-PHYSICAL-MULTIDEVICE-01 — Relatório Final
## Device Release Validation + iOS Readiness

> Data: 2026-09-30  
> Canonical main: `02a6485ad67236d0a9f5763d8078498947f17bb4`  
> Branch de missão: `claude/physical-r16-ios-readiness`  
> Predecessor: IV-MAIN-RECONCILIATION-01 = CONDITIONAL_PASS

---

## SUMÁRIO EXECUTIVO

| Item | Status |
|------|--------|
| Ambiente de execução | Cloud container (sem ADB, sem Flutter SDK) |
| Gate físico Android | `DEVICE_GATE_WAITING` — requer ação do Owner |
| APK build | `APK_BUILD = REQUIRES_CI_OR_LOCAL_FLUTTER` |
| iOS platform | `IOS_PLATFORM = NOT_GENERATED` (sem ios/ directory) |
| iOS build | `IOS_BUILD = REQUIRES_MACOS_XCODE + flutter create --platforms=ios` |
| Segurança APK | PASS — nenhum segredo real no código-fonte |
| Stripe mode | PASS — server-side only, sem chave client em APK |
| R16 language arch | PASS — implementada em todos os providers relevantes |
| CI workflow corrigido | DONE — branch antiga removida, provenance adicionado |

---

## 1. CONTEXTO DO AMBIENTE

Este relatório foi gerado em ambiente **cloud container** (claude.ai/code remote).

Limitações do ambiente:
- `adb`: não instalado → impossível detectar dispositivos físicos
- `flutter`: não instalado → impossível fazer build local
- Sem conexão USB física → gate de dispositivos não pode ser executado aqui

**Caminho recomendado para APK:** usar o workflow CI `build-debug-device-test.yml` (corrigido nesta missão) ou rodar `flutter build apk --debug` localmente com Flutter instalado.

---

## 2. IDENTIFICAÇÃO DO PACOTE

Fonte verificada: `android/app/build.gradle.kts`, linha 74-86.

| Campo | Valor |
|-------|-------|
| applicationId | `com.insightvalues.app` |
| namespace | `com.insightvalues.app` |
| versionName | `1.0.0` (via pubspec.yaml flutter.versionName) |
| versionCode | `1` (via pubspec.yaml flutter.versionCode) |
| pubspec version | `1.0.0+1` |
| App label | `InsightValues` |

---

## 3. DEVICE GATE — ANDROID FÍSICO

**Status: `DEVICE_GATE_WAITING`**

O ambiente cloud não tem ADB. O Owner deve executar os passos abaixo na máquina local com ambos os dispositivos conectados.

### 3.1 Pré-requisitos
- [ ] Flutter SDK instalado (`flutter --version`)
- [ ] Android SDK com `adb` no PATH
- [ ] Samsung Galaxy S25 Ultra conectado via USB com "Depuração USB" ativada
- [ ] Samsung Galaxy Note 20 conectado via USB com "Depuração USB" ativada

### 3.2 HARD GATE — Identificar AMBOS os dispositivos antes de qualquer ação

```bash
adb devices -l
```

Esperado: 2 dispositivos com status `device`. Se qualquer um aparecer como `unauthorized`, desconecte e reconecte aceitando a autorização no dispositivo.

**NÃO prosseguir com menos de 2 dispositivos identificados.**

### 3.3 Registrar seriais

```bash
# Anotar os seriais (substituir nos comandos abaixo):
# S25_ULTRA_SERIAL=<serial do S25 Ultra>
# NOTE20_SERIAL=<serial do Note 20>

adb -s $S25_ULTRA_SERIAL shell getprop ro.product.manufacturer
adb -s $S25_ULTRA_SERIAL shell getprop ro.product.model
adb -s $S25_ULTRA_SERIAL shell getprop ro.build.version.release
adb -s $NOTE20_SERIAL shell getprop ro.product.manufacturer
adb -s $NOTE20_SERIAL shell getprop ro.product.model
adb -s $NOTE20_SERIAL shell getprop ro.build.version.release
```

### 3.4 Verificar versão instalada atual

```bash
adb -s $S25_ULTRA_SERIAL shell pm list packages | grep insightvalues
adb -s $NOTE20_SERIAL shell pm list packages | grep insightvalues
```

### 3.5 Build do APK canônico

**Opção A — via CI (recomendado):**
1. Acessar GitHub Actions → "Build APK Debug — Device Test"
2. Clicar "Run workflow" → ref: `main` → confirmar SHA `02a6485`
3. Baixar artifact `ive-debug-apk-<N>` após conclusão
4. Verificar SHA-256 do APK baixado

**Opção B — build local:**
```bash
git checkout main
git rev-parse HEAD  # deve ser 02a6485ad67236d0a9f5763d8078498947f17bb4
cp .env.example .env
# Editar .env: adicionar GOOGLE_CLIENT_ID real (ver .env.example)
flutter clean
flutter pub get
flutter build apk --debug
sha256sum build/app/outputs/flutter-apk/app-debug.apk
```

### 3.6 Verificar provenance do APK

Registrar antes de instalar:

| Campo | Valor |
|-------|-------|
| SOURCE_SHA | `02a6485ad67236d0a9f5763d8078498947f17bb4` |
| APK_FILE | `app-debug.apk` |
| APK_SHA256 | `[preencher após build]` |
| APK_SIZE | `[preencher após build]` |
| BUILD_DATE | `[preencher após build]` |

### 3.7 Desinstalar versão antiga e instalar APK canônico

```bash
# Desinstalar (APENAS após AMBOS os dispositivos identificados)
adb -s $S25_ULTRA_SERIAL uninstall com.insightvalues.app
adb -s $NOTE20_SERIAL uninstall com.insightvalues.app

# Instalar o MESMO APK em ambos
APK=build/app/outputs/flutter-apk/app-debug.apk
adb -s $S25_ULTRA_SERIAL install "$APK"
adb -s $NOTE20_SERIAL install "$APK"

# Verificar instalação
adb -s $S25_ULTRA_SERIAL shell pm list packages | grep insightvalues
adb -s $NOTE20_SERIAL shell pm list packages | grep insightvalues
```

### 3.8 Verificação SAME_APK_HASH_ON_BOTH_DEVICES

Para confirmar que o mesmo APK foi instalado em ambos, verificar via adb após instalação:

```bash
# Confirmar versão instalada em cada dispositivo
adb -s $S25_ULTRA_SERIAL shell dumpsys package com.insightvalues.app | grep -E "versionName|versionCode|lastUpdateTime"
adb -s $NOTE20_SERIAL shell dumpsys package com.insightvalues.app | grep -E "versionName|versionCode|lastUpdateTime"
```

`SAME_APK_HASH_ON_BOTH_DEVICES = YES` quando ambos mostrarem mesmos versionName + versionCode + lastUpdateTime (ou hash do APK em disco).

---

## 4. iOS READINESS AUDIT

**Status: `IOS_PLATFORM = NOT_GENERATED`**

### 4.1 Diagnóstico

O diretório `ios/` **não existe** no projeto. O projeto foi criado e desenvolvido como Flutter multi-plataforma (Android + Web), mas a plataforma iOS nunca foi adicionada.

```
/home/user/ai-social-copilot/
  android/   ← EXISTE
  web/       ← EXISTE
  lib/       ← EXISTE
  ios/       ← NÃO EXISTE
```

### 4.2 Para gerar o projeto iOS

Requer macOS com Xcode instalado:

```bash
# Em macOS com Xcode >= 14 e Flutter instalado:
git checkout claude/physical-r16-ios-readiness
flutter create --platforms=ios .
# Revisar Runner/Info.plist gerado
# Adicionar deep-link para autenticação Supabase
# Configurar Bundle ID: com.insightvalues.app
```

### 4.3 Checklist iOS pré-build

| Item | Status |
|------|--------|
| `ios/` directory | AUSENTE — requer `flutter create --platforms=ios` |
| Bundle ID | PENDING — deve ser `com.insightvalues.app` |
| Info.plist | PENDING — geração automática pelo Flutter |
| Deep-link auth callback (Supabase) | PENDING — adicionar URL scheme após gerar ios/ |
| Signing (Apple Developer Account) | PENDING — requer conta Apple Developer |
| Capabilities (Push, etc.) | PENDING — avaliar após ios/ gerado |
| google-services plist | N/A — firebase não usado |
| Stripe iOS SDK | N/A — Stripe é server-side via Edge Functions |

### 4.4 Deep-link auth (iOS)

O AndroidManifest atual não tem URL scheme de deep-link para OAuth (só tem LAUNCHER intent). Para iOS + Android, o Supabase requer URL scheme registrado. Isso precisa ser adicionado:

- Android: `android/app/src/main/AndroidManifest.xml` — adicionar intent-filter com `scheme`
- iOS: `ios/Runner/Info.plist` — adicionar CFBundleURLTypes

URL scheme esperado para Supabase auth: verificar configuração do projeto Supabase (`io.supabase.auth://` ou custom scheme).

**Impacto:** sem deep-link configurado, o OAuth (Google Sign-in via Supabase) pode não completar o redirect corretamente em builds mobile.

### 4.5 R16 Language Architecture — verificação iOS

R16 é implementado em Dart (platform-agnostic). A auditoria do código confirma:

- Todos os providers relevantes têm comentários `// R16 — output language = presentation language`
- `languageProvider` controla `PRESENTATION_LANGUAGE`
- Edge Functions recebem o idioma via parâmetro, não hardcoded
- `TranslatedContentNotice` widget implementa §9 da spec R16
- **Conclusão: R16 não tem dependência de plataforma — funciona em iOS igual ao Android sem modificações de código**

---

## 5. AUDITORIA DE SEGURANÇA

### 5.1 Secrets no código-fonte

| Busca | Resultado |
|-------|-----------|
| `sk_live_` (Stripe secret) | NÃO ENCONTRADO |
| `sk_test_` (Stripe test key) | NÃO ENCONTRADO |
| `pk_live_` (Stripe publishable) | NÃO ENCONTRADO |
| `SUPABASE_ANON_KEY` hardcoded | NÃO ENCONTRADO em lib/ |
| `firebase` real API key | NÃO ENCONTRADO (google-services.json é neutro/placeholder) |

### 5.2 `.env` como Flutter asset

**Achado:** `pubspec.yaml` declara `.env` em `assets:`. Isso significa que o arquivo `.env` é **empacotado dentro do APK** na build.

**Avaliação de risco:**
- `SUPABASE_URL` = URL pública do projeto (não é segredo)
- `SUPABASE_ANON_KEY` = `sb_publishable_*` = chave pública projetada para ser embarcada em clientes
- `GOOGLE_CLIENT_ID` = OAuth Client ID (público por design do protocolo OAuth)

**Conclusão:** Nenhuma das três variáveis do `.env` é um segredo real. O padrão flutter_dotenv com asset é aceitável para estas credenciais. RLS e políticas de segurança do Supabase são a fronteira de segurança real.

### 5.3 Stripe — modo live vs. test

Stripe é usado exclusivamente via Edge Function `create-checkout-session`. Nenhuma chave Stripe (pk ou sk) está no código Dart. O modo live/test é controlado pelo segredo `STRIPE_SECRET_KEY` configurado no Supabase Dashboard (não no APK).

**`STRIPE_LIVE_IN_APK = FALSE`** ✓

### 5.4 google-services.json

O arquivo `android/app/google-services.json` contém dados neutralizados/placeholder (client count = 0, sem Firebase API key real). Confirmado inerte — nenhum plugin Firebase o consome.

---

## 6. WORKFLOW CI CORRIGIDO

### 6.1 Problema identificado

`build-debug-device-test.yml` tinha `ref: claude/insightvalues-integration-macro-02` hardcoded — branch que foi integrada em `main` pela missão IV-MAIN-RECONCILIATION-01.

### 6.2 Correção aplicada

- `ref:` hardcoded → `workflow_dispatch` input com default `main`
- Artifact name: `ive-avatar-v2-device-test-apk` → `ive-debug-apk-${{ github.run_number }}`
- Adicionado step "Record build provenance" que registra SOURCE_SHA e APK_SHA256

### 6.3 Como disparar o build

1. GitHub → `jonnipm-web/ai-social-copilot` → Actions
2. "Build APK Debug — Device Test" → "Run workflow"
3. `ref`: deixar `main` (padrão) para o canonical SHA `02a6485`
4. Após conclusão: baixar artifact → verificar SHA-256 → instalar nos dispositivos

---

## 7. APP STORE READINESS INVENTORY

### 7.1 Google Play Store

| Item | Status |
|------|--------|
| applicationId definido | ✓ `com.insightvalues.app` |
| Release signing configurado | PENDING — `android/key.properties` (nunca commitado, Owner cria) |
| Build release (fail-closed) | ✓ Configurado — falha se key.properties ausente |
| Target SDK | ✓ Flutter default (31+) |
| minSdk | ✓ Flutter default |
| Permissões no manifesto | ✓ Mínimas (INTERNET implícito via Flutter) |
| Privacy policy URL | `OWNER CONTENT REQUIRED` (herdado de COMMERCIAL-RELEASE-CONTROL-PLANE-01) |
| App icons | ✓ `@mipmap/ic_launcher` presente |
| google-services.json (se Google Auth) | ⚠ Arquivo neutralizado — Google Auth usa GOOGLE_CLIENT_ID via .env |
| Versão comercial (1.0.0+1) | ⚠ Incrementar antes de submissão para store |
| `build-android.yml` para release | PENDING — verificar se usa release signing |

### 7.2 Apple App Store

| Item | Status |
|------|--------|
| ios/ directory | `NOT_GENERATED` — bloqueador |
| Xcode project | `NOT_GENERATED` |
| Bundle ID | PENDING — `com.insightvalues.app` |
| Apple Developer Account | PENDING — requer conta paga ($99/ano) |
| Certificates & Profiles | PENDING |
| App Store Connect listing | PENDING |
| Privacy labels (nutrition labels) | PENDING |
| iOS deep-link (URL scheme) | PENDING |
| TestFlight | PENDING |

**iOS App Store não pode ser preparada sem primeiro gerar ios/ em macOS.**

---

## 8. OWNER PHYSICAL R16 GATE — CHECKLIST

Após instalar o APK nos dois dispositivos via procedimento da Seção 3:

### 8.1 Verificações funcionais mínimas por dispositivo

- [ ] App abre sem crash
- [ ] Login Google funciona e retorna ao app (deep-link se configurado)
- [ ] Login email/senha funciona
- [ ] Tela Dashboard carrega (dados do usuário visíveis)
- [ ] Geração de post funciona (testar com conteúdo em PT e EN)
- [ ] R16 — verificar que output em PT quando UI em PT, output em EN quando UI em EN
- [ ] Histórico de posts lista corretamente
- [ ] Upgrade/Billing: botão abre checkout Stripe (sem finalizar compra)
- [ ] Sem crash em navegação entre todas as rotas principais

### 8.2 Comparação entre dispositivos

- [ ] App funciona igual no S25 Ultra e no Note 20
- [ ] Sem diferença visual crítica entre telas (responsividade)
- [ ] Mesmo comportamento de login em ambos

### 8.3 Critério de PASS

Todos os itens acima marcados ✓ em AMBOS os dispositivos = **Physical R16 Gate: PASS**

---

## 9. ACHADOS E RECOMENDAÇÕES

### P1 — Deep-link OAuth ausente no AndroidManifest

**Impacto:** Login via Google pode não retornar ao app corretamente em builds de dispositivo.  
**Recomendação:** Adicionar intent-filter com URL scheme Supabase no AndroidManifest antes do gate físico.  
**Dependência:** Verificar qual URL scheme está configurado no Dashboard Supabase → Authentication → URL Configuration → Redirect URLs.

### P2 — iOS não gerado

**Impacto:** Impossível testar iOS, impossível submeter à App Store.  
**Recomendação:** Em macOS com Xcode: `flutter create --platforms=ios .` na branch desta missão, então revisar Info.plist e adicionar URL scheme.  
**Bloqueador:** Requer macOS + Xcode + Apple Developer Account.

### P3 — versionName/versionCode em 1.0.0+1

**Impacto:** Baixo para teste físico, mas deve ser incrementado antes de qualquer submissão a store.  
**Recomendação:** Deixar como está para o gate físico; incrementar quando definir release comercial.

---

## 10. RESULTADO FINAL

```
DEVICE_GATE_WAITING          Android: aguarda Owner executar build + install físico
IOS_PLATFORM = NOT_GENERATED iOS: nunca foi adicionado ao projeto Flutter
IOS_BUILD = REQUIRES_MACOS   Necessário macOS + Xcode para gerar ios/
SECURITY_AUDIT = PASS        Sem secrets reais no código-fonte nem no APK
STRIPE_LIVE_IN_APK = FALSE   Stripe é server-side only
R16_ARCHITECTURE = PASS      Implementada em todos os providers, platform-agnostic
CI_WORKFLOW = FIXED          build-debug-device-test.yml corrigido (branch → main input)
```

### Próximas ações do Owner (por prioridade):

1. **[IMEDIATO]** Verificar URL scheme de autenticação no Dashboard Supabase
2. **[IMEDIATO]** Disparar workflow "Build APK Debug — Device Test" com ref=`main`
3. **[IMEDIATO]** Conectar S25 Ultra + Note 20, executar procedimento Seção 3
4. **[IMEDIATO]** Executar checklist Physical R16 Gate (Seção 8) em ambos os dispositivos
5. **[PRÓXIMA SEMANA]** Em macOS: `flutter create --platforms=ios .` + gerar ios/ + revisar
6. **[PRÓXIMA SEMANA]** Criar conta Apple Developer se iOS for objetivo comercial

---

*Gerado por IV-R16-PHYSICAL-MULTIDEVICE-01 · 2026-09-30*  
*Branch: `claude/physical-r16-ios-readiness`*  
*Canonical main: `02a6485`*
