GOOGLE DRIVE OAUTH FIX INSTRUCTIONS
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
SINTOMA
==================================================

  Dispositivo: Samsung Galaxy S25 Ultra (Android 16)
  Erro: PlatformException(sign_in_failed, z0.d: 10, null, null)
  Tela: DrivePickerScreen → botão "Entrar com Google"
  Mensagem exibida ao usuário (após este hotfix):
    "Erro de autenticação Google (código 10).
     O SHA-1 do APK não está registrado no Google Cloud Console."

==================================================
CAUSA RAIZ
==================================================

  Arquivo: android/app/google-services.json
  Campo: oauth_client[0].android_info.certificate_hash
  Valor atual: "" (VAZIO)

  O Google Sign-In para Android exige que o SHA-1 do certificado
  de assinatura do APK esteja registrado no Google Cloud Console
  E presente no google-services.json.

  Sem o SHA-1 correto, a autenticação retorna erro código 10
  (DEVELOPER_ERROR) em todos os dispositivos.

==================================================
DADOS DO APP (CONFIRMADOS NO CÓDIGO)
==================================================

  Package name:  com.example.ai_social_copilot
  Project ID:    focused-code-423720-r1
  Project #:     221504834589

  OAuth Client (Android, type 1):
    client_id: 221504834589-e918u3i4fh6cjps9hdu6lchpnqrpjh9j.apps.googleusercontent.com
    certificate_hash: "" ← ESTE É O PROBLEMA

  OAuth Client (Web, type 3):
    client_id: 221504834589-jll1257ccns2sprai9ps949rv21gf7p2.apps.googleusercontent.com

==================================================
SOBRE O APK ATUAL (CI sem keystore configurado)
==================================================

  O workflow build-apk.yml usa `flutter build apk --release`
  SEM configurar um keystore de release.

  Isso significa:
  - O APK é assinado com a debug key padrão do Android SDK
  - SHA-1 da debug key: varia por máquina, mas a padrão é:
    DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09
    (ou a do runner do GitHub Actions — pode ser diferente)

  Para uso em produção / distribuição real:
  - Necessário criar um keystore de release dedicado
  - Registrar o SHA-1 desse keystore no Google Cloud Console
  - Guardar keystore como secret no GitHub

==================================================
PASSO A PASSO PARA O PO
==================================================

OPÇÃO A — DEBUG KEY (para testes imediatos no dispositivo pessoal)
------------------------------------------------------------------

  1. No terminal do seu computador com Android SDK instalado:

     keytool -list -v \
       -keystore ~/.android/debug.keystore \
       -alias androiddebugkey \
       -storepass android \
       -keypass android

  2. Copie o SHA-1 (ex: DA:39:A3:EE:5E:6B:4B:0D:...)

  3. No Google Cloud Console:
     https://console.cloud.google.com/apis/credentials
     Projeto: focused-code-423720-r1

  4. Clique no OAuth 2.0 Android Client:
     "221504834589-e918u3i4fh6cjps9hdu6lchpnqrpjh9j.apps.googleusercontent.com"

  5. Em "Huella digital del certificado SHA-1" (ou "Certificate fingerprint"):
     Cole o SHA-1 copiado no passo 2

  6. Salve

  7. No Google Cloud Console → APIs & Services → Credentials:
     Clique em "Baixar" (ícone de download) para baixar o
     google-services.json atualizado

  8. Substitua android/app/google-services.json pelo arquivo baixado

  9. Verifique que certificate_hash não está mais vazio:
     grep certificate_hash android/app/google-services.json

  10. Commit e push → disparar CI

OPÇÃO B — RELEASE KEY DEDICADA (para distribuição / Play Store)
---------------------------------------------------------------

  1. Criar keystore (execute UMA VEZ e guarde com segurança):

     keytool -genkey -v \
       -keystore ai-social-copilot-release.jks \
       -keyalg RSA -keysize 2048 -validity 10000 \
       -alias ai_social_copilot \
       -dname "CN=AI Social Copilot, OU=Mobile, O=InsightValues, C=BR"

  2. Extrair SHA-1 e SHA-256:

     keytool -list -v \
       -keystore ai-social-copilot-release.jks \
       -alias ai_social_copilot

  3. Registrar SHA-1 (e opcionalmente SHA-256) no Google Cloud Console
     (mesmos passos 3-9 da Opção A)

  4. Adicionar ao GitHub Secrets:
     KEYSTORE_BASE64   = base64 do arquivo .jks
     KEY_ALIAS         = ai_social_copilot
     KEY_PASSWORD      = <senha definida no keytool>
     STORE_PASSWORD    = <senha do keystore>

  5. Atualizar android/app/build.gradle para usar o keystore:
     (necessário abrir uma tarefa para o Claude configurar isso)

  6. Atualizar CI para configurar o keystore antes do build

==================================================
VERIFICAÇÃO PÓS-CORREÇÃO
==================================================

  Após aplicar e rebuildar o APK:
  1. Instalar APK no dispositivo
  2. Abrir Cofre → Novo Item → selecionar "Google Drive"
  3. Tocar "Entrar com Google"
  4. Esperado: popup de conta Google abre sem erro
  5. Esperado: após login, lista de arquivos do Drive carrega

==================================================
STATUS
==================================================

  CÓDIGO: atualizado — DrivePickerScreen exibe mensagem específica
          para código 10 (guia este documento)
  OAUTH:  AGUARDANDO PO (RED GATE — ação no Google Cloud Console)
  APK:    builds sem keystore de release → só debug key funciona
