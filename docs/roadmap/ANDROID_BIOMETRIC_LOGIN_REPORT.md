# Relatório P1 — Login Biométrico Android
# AI Social Copilot

**Data:** 2026-07-24
**Versão:** 1.0.0
**Branch:** claude/access-social-copilot-wJ6B5

---

## VEREDICTO: GO

Implementação completa e segura. Todos os requisitos do spec P1 foram atendidos.
Nenhuma credencial exposta. Nenhuma migration necessária. Sem impacto em P0.

---

## 1. ARQUIVOS CRIADOS / MODIFICADOS

NOVO      lib/core/services/biometric_auth_service.dart
NOVO      lib/providers/biometric_auth_provider.dart
NOVO      lib/features/auth/screens/biometric_gate_screen.dart
NOVO      lib/features/auth/widgets/biometric_enrollment_sheet.dart
MODIFICADO lib/features/auth/screens/login_screen.dart
MODIFICADO lib/features/splash/splash_screen.dart
MODIFICADO lib/shared/widgets/app_drawer.dart
MODIFICADO lib/app.dart
MODIFICADO lib/core/constants/app_constants.dart
MODIFICADO pubspec.yaml (+ local_auth ^2.3.0, + flutter_secure_storage ^9.2.2)

---

## 2. PACOTES ADICIONADOS

PACOTE               VERSÃO      PLATAFORMAS
local_auth           ^2.3.0      Android, iOS, Linux, macOS, Windows
flutter_secure_storage ^9.2.2    Android, iOS, Web, Linux, macOS, Windows

NOTA CI:
- local_auth auto-injeta USE_BIOMETRIC no AndroidManifest via manifest merger.
  Nenhum passo manual no workflow necessário.
- O CI já roda "flutter create --platforms android" antes do build, gerando
  o AndroidManifest.xml base. O manifest merger aplica a permissão do plugin.
- flutter analyze roda em Linux — local_auth suporta Linux (stub).
- flutter build web — local_auth compila para web, retorna false em runtime.
  Nenhuma alteração no workflow necessária.

---

## 3. FLUXO IMPLEMENTADO

PRIMEIRO LOGIN (email + senha):
  1. Usuário loga normalmente com e-mail e senha.
  2. Se biometria disponível E ainda não habilitada:
     - Exibe bottom sheet: "Ativar login biométrico?"
     - [Ativar] → desafio biométrico → se OK → salva flag segura.
     - [Agora não] → continua sem biometria.
  3. Navega para Executive Dashboard.

COLD START COM BIOMETRIA HABILITADA:
  1. SplashScreen detecta sessão válida + biometria habilitada.
  2. Navega para BiometricGateScreen.
  3. Prompt biométrico disparado automaticamente (fingerprint / face ID).
  4. Sucesso → valida sessão Supabase → navega para app.
  5. Cancelamento → tela com botão "Tentar novamente" + link para login manual.
  6. Erro → tratamento específico por tipo (ver seção 5).

CONFIGURAÇÕES → LOGIN BIOMÉTRICO (drawer):
  - Toggle visível em todos os usuários autenticados.
  - Desativar: sem desafio (usuário já está no app).
  - Ativar: exibe BiometricEnrollmentSheet (desafio biométrico necessário).

LOGOUT:
  - Desativa biometria automaticamente antes do signOut().
  - Próximo login exige e-mail + senha → offer de re-habilitação.

---

## 4. MODELO DE SEGURANÇA

DADO ARMAZENADO        LOCAL                   VALOR
biometric_enabled      FlutterSecureStorage     "true"
biometric_user_id      FlutterSecureStorage     uid (Supabase)
biometric_enrolled_cnt FlutterSecureStorage     count(enrolled biometrics)

ANDROID: FlutterSecureStorage usa EncryptedSharedPreferences (AndroidKeystore).
WEB: FlutterSecureStorage usa localStorage — aceitável pois apenas um flag é
     armazenado. Biometria não funciona em web de qualquer forma.

SEGREDOS NÃO ARMAZENADOS:
  - Senha nunca armazenada (nem hasheada).
  - Credenciais Supabase nunca tocadas pela camada biométrica.
  - Token de sessão gerenciado pelo Supabase Flutter (HiveLocalStorage nativo).
  - UID nunca enviado ao servidor como parâmetro — sempre derivado do JWT.

VALIDACAO DE SESSAO POS-BIOMETRIA:
  - Após autenticação biométrica bem-sucedida, o código verifica
    Supabase.instance.client.auth.currentSession != null.
  - Se sessão expirou (TOKEN_REVOKED), biometria é desativada e usuário
    é redirecionado para login convencional.

INVALIDACAO POR MUDANCA DE BIOMETRIA:
  - Na habilitação, o count de biometrias cadastradas é salvo.
  - Em cada tentativa, o count atual é comparado ao salvo.
  - Se diferente (novo dedo cadastrado, face alterada, etc.):
    → biometria desativada automaticamente.
    → usuário redirecionado para login convencional.
    → mensagem explicativa exibida.

CONSTRAINTS DE SEGURANÇA MANTIDAS:
  - NÃO expõe INTERNAL_TESTER_IDS ao Flutter.
  - NÃO hardcoda UID no APK.
  - NÃO altera agent mode.
  - NÃO cria bypass baseado em email/client payload.
  - Identidade sempre derivada da sessão autenticada.

---

## 5. ESTADOS DE ERRO TRATADOS

CODIGO / ESTADO                 COMPORTAMENTO
BIOMETRIC_SUCCESS               Valida sessão → navega para app.
BIOMETRIC_FAILED / userCancel   Exibe botões "Tentar novamente" + "Login manual".
BIOMETRIC_ERROR_LOCKOUT         Mensagem: "Muitas tentativas. Aguarde."
BIOMETRIC_ERROR_LOCKOUT_PERM    Mensagem: "Bloqueada. Use PIN/senha no dispositivo."
BIOMETRIC_ERROR_NO_HARDWARE     Desativa biometria → redireciona para login manual.
BIOMETRIC_ERROR_HW_UNAVAILABLE  Desativa biometria → redireciona para login manual.
BIOMETRIC_ERROR_NONE_ENROLLED   Detectado via count check → desativa → login manual.
BIOMETRY_CHANGED (novo dedo)    Detectado via count check → desativa → login manual.
SESSION_EXPIRED / TOKEN_REVOKED Verificado pós-auth → desativa → login manual.
notSupported (web/desktop)      kIsWeb guard → retorna false → biometria oculta.

---

## 6. COMPONENTES IMPLEMENTADOS

BiometricAuthService:
  + isAvailable()         — hardware + enrollment check
  + isEnabled(userId)     — verifica flag no secure storage
  + authenticate(...)     — prompt biométrico com detecção de mudança de biometria
  + enable(...)           — desafio + salva flag (inclui enrolled count)
  + disable(...)          — limpa todas as chaves do secure storage
  + _hasBiometryChanged() — compara enrolled count atual vs salvo

BiometricGateScreen (/biometric-gate):
  + Prompt automático no initState (postFrameCallback)
  + Tratamento de todos os BiometricStatus
  + Botões: "Tentar novamente" + "Entrar com e-mail e senha"
  + Sem exposição de dados de sessão na UI

BiometricEnrollmentSheet (bottom sheet):
  + Offer pós-login com design consistente com o app
  + Loading state durante desafio
  + Erros inline (lockout, noneEnrolled, etc.)

LoginScreen (modificado):
  + Botão "Entrar com biometria" aparece apenas em sign-in mode
    quando biometricEnabledProvider == true
  + Offer de enrollment chamada após signIn bem-sucedido
  + Sem impacto no fluxo de sign-up

AppDrawer (modificado):
  + Toggle "Login biométrico" com Switch
  + Loading indicator durante operação
  + Logout desativa biometria automaticamente

SplashScreen (modificado):
  + Verifica isEnabled(userId) após session check
  + Redireciona para /biometric-gate se habilitado
  + Redireciona para /executive-dashboard se não habilitado

Router (modificado):
  + /biometric-gate isenta do redirect de "sessão nula → login"
    (goingToGate incluído no guard de exceções)
  + Rota GoRoute adicionada ao routes list

---

## 7. COMPATIBILIDADE DE PLATAFORMA

PLATAFORMA   STATUS         NOTA
Android      SUPORTADO      Fingerprint + Face (Android 6+ / API 23+)
iOS          SUPORTADO      Face ID + Touch ID (via local_auth)
Web          NAO SUPORTADO  kIsWeb guard → biometria oculta / desabilitada
Linux        STUB           local_auth retorna unsupported
Windows      STUB           local_auth retorna unsupported
macOS        SUPORTADO      Touch ID via local_auth_darwin

---

## 8. IMPACTO EM TESTES EXISTENTES

Nenhum teste existente alterado.
BiometricAuthService pode ser mockado via biometricAuthServiceProvider.overrideWithValue().
Novos testes recomendados (não incluídos neste commit):
  - test/features/auth/biometric_service_test.dart
  - test/features/auth/biometric_gate_screen_test.dart

---

## 9. PROXIMOS PASSOS RECOMENDADOS

1. Testar em dispositivo Android físico (emuladores têm suporte limitado a biometria).
2. Configurar minSdkVersion >= 23 no build.gradle gerado pelo CI
   (local_auth funciona com API 16+, mas BiometricPrompt é API 28+
   e local_auth usa o compat library para API 23+).
3. Adicionar testes unitários para BiometricAuthService.
4. Validar no CI com APK real no Firebase Test Lab ou dispositivo físico.

---

VEREDICTO FINAL: GO
Implementação segura, sem credenciais expostas, sem migration, sem impacto em P0.
