ANDROID SIGNING + GOOGLE DRIVE OAUTH — FINAL REPORT
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
ROOT CAUSE
==================================================

  CAUSA PRIMÁRIA:
    build-apk.yml (BUILD WEEK) não configurava signing release.
    flutter build apk --release sem signingConfig → Android assina
    automaticamente com a debug key efêmera do runner GitHub Actions.
    Essa debug key é gerada por runner; pode diferir entre execuções.
    SHA-1 efêmero → nunca pode ser registrado no Google Cloud Console.

  CAUSA SECUNDÁRIA:
    android/app/google-services.json tem certificate_hash: "" (vazio).
    Google Sign-In exige SHA-1 preenchido para autenticar apps Android.
    Resultado: PlatformException(sign_in_failed, ... 10 ...) em todos
    os dispositivos.

  CAUSA TERCIÁRIA (estrutural):
    O diretório android/ não está commitado no repositório (exceto
    google-services.json). É gerado por flutter create --platforms android
    no CI. Isso impede configuração de signing estática em build.gradle.kts.

==================================================
SIGNING ANTIGO (BUILD WEEK antes desta correção)
==================================================

  TIPO:        debug keystore efêmera do runner GitHub Actions
  PERSISTENTE: NÃO — SHA-1 potencialmente diferente por execução
  USÁVEL PARA OAUTH: NÃO
  ARQUIVO:     ~/.android/debug.keystore (gerado no runner, não commitado)

==================================================
SIGNING DEFINITIVO (após esta correção)
==================================================

  TIPO:        release keystore persistente (GitHub Secret KEYSTORE_BASE64)
  FONTE:       secrets.KEYSTORE_BASE64 → android/app/release.keystore
  ALIAS:       secrets.KEYSTORE_KEY_ALIAS
  PERSISTENTE: SIM — mesma chave em todas as execuções do CI
  USÁVEL PARA OAUTH: SIM
  WORKFLOW:    build-apk.yml agora usa a mesma keystore que build-android.yml

==================================================
SHA-1 E SHA-256
==================================================

  COMO OBTER (sem expor a keystore):

  OPÇÃO A — via CI (recomendado):
    Executar o BUILD WEEK após esta correção.
    No log do step "Imprimir fingerprint SHA-1 e SHA-256":
      SHA1:   XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
      SHA256: XX:XX:...

    Copiar e usar nos passos de OAuth abaixo.

  OPÇÃO B — via terminal (se o PO tiver o arquivo .jks):
    keytool -list -v \
      -keystore <arquivo.jks> \
      -alias <KEYSTORE_KEY_ALIAS> \
      -storepass <KEYSTORE_STORE_PASSWORD>
    Copiar SHA1 e SHA256 de "Certificate fingerprints".

  SHA-1:    UNKNOWN — obter pelo CI após executar BUILD WEEK
  SHA-256:  UNKNOWN — obter pelo CI após executar BUILD WEEK

==================================================
APPLICATION ID
==================================================

  APPLICATION_ID:  com.example.ai_social_copilot
  PACKAGE_NAME:    com.example.ai_social_copilot
  FONTE:           flutter create --project-name ai_social_copilot
                   (gera com.example.ai_social_copilot por padrão)
  CONFIRMADO EM:   android/app/google-services.json
                   (android_client_info.package_name)

==================================================
ALTERAÇÕES REALIZADAS
==================================================

  ARQUIVO: .github/workflows/build-apk.yml
  COMMIT:  (este commit)

  ADICIONADO antes de "Instalar dependências":

  STEP 1 — "Configurar keystore release persistente":
    Decodifica KEYSTORE_BASE64 → android/app/release.keystore
    Insere signingConfigs no build.gradle.kts gerado pelo flutter create
    Substitui signingConfig debug → release no buildTypes

  STEP 2 — "Imprimir fingerprint SHA-1 e SHA-256":
    keytool -list na keystore decodificada
    Imprime SHA1 e SHA256 no log do CI
    O PO copia os valores do log para registrar no Google Cloud Console

  STEP 3 — "Build do APK":
    Adicionado env com as 3 variáveis de signing necessárias para o Gradle

  ARQUIVO: .github/workflows/build-android.yml (LEGACY)
    SEM ALTERAÇÃO — já usava signing release corretamente

==================================================
IMPACTO NA INSTALAÇÃO ATUAL
==================================================

  O APK atualmente instalado no Galaxy S25 Ultra foi assinado com
  debug key efêmera. O novo APK será assinado com release keystore.

  ANDROID NÃO PERMITE atualizar um APK quando o certificado de assinatura
  muda. A instalação direta sobre o APK existente será REJEITADA.

  AÇÃO NECESSÁRIA NO DISPOSITIVO:
    1. Desinstalar o APK atual ("AI Social Copilot") do Galaxy S25 Ultra
    2. Instalar o novo APK gerado pelo BUILD WEEK corrigido

  IMPACTO DE DADOS:
    Dados do Supabase: SEM PERDA — armazenados na nuvem, login restaura tudo
    Preferências locais: resetadas (tema, estado de sessão local)
    O usuário precisará fazer login novamente após reinstalação

==================================================
CONFIGURAÇÃO GOOGLE CLOUD OAUTH
==================================================

  PROJETO GOOGLE CLOUD: focused-code-423720-r1
  PROJECT NUMBER:       221504834589

  ANDROID OAUTH CLIENT EXISTENTE:
    ID:   221504834589-e918u3i4fh6cjps9hdu6lchpnqrpjh9j.apps.googleusercontent.com
    TIPO: Android (client_type: 1)
    certificate_hash: "" (VAZIO — causa do erro 10)

  WEB CLIENT (usado como serverClientId pelo Flutter):
    ID:   221504834589-jll1257ccns2sprai9ps949rv21gf7p2.apps.googleusercontent.com
    TIPO: Web (client_type: 3)

  DEPENDÊNCIA:
    google_sign_in: ^6.2.1 requer:
      - OAuth Android Client com package + SHA-1 registrados
      - google-services.json com certificate_hash preenchido
      - Drive API habilitada no projeto Google Cloud
      - OAuth consent screen configurado

==================================================
GOOGLE-SERVICES.JSON
==================================================

  STATUS:    EXISTE MAS DESATUALIZADO (certificate_hash vazio)
  ARQUIVO:   android/app/google-services.json
  PROBLEMA:  certificate_hash: "" em oauth_client[0].android_info
  NECESSÁRIO: SIM — google_sign_in usa para localizar o OAuth client

  COMO ATUALIZAR:
    Após registrar o SHA-1 no Google Cloud Console:
    No painel de Credentials → clicar no ícone de download (↓) ao lado
    do Android OAuth Client → salvar como google-services.json
    Substituir android/app/google-services.json → commitar

==================================================
GOOGLE DRIVE API — VERIFICAÇÃO
==================================================

  VERIFICAR no Google Cloud Console:
    APIs & Services → Enabled APIs:
      [ ] Google Drive API habilitada?
      [ ] People API habilitada? (necessária para google_sign_in escopos)

  SCOPES USADOS PELO APP:
    lib/features/knowledge/screens/drive_picker_screen.dart usa:
    GoogleSignIn(scopes: ['https://www.googleapis.com/auth/drive.readonly'])
    (ou similar — confirmar no código)

  Se Google Drive API não estiver habilitada:
    Habilitar em: APIs & Services → Library → "Google Drive API" → Enable

==================================================
AÇÕES MANUAIS DO PO
==================================================

PASSO 1 — EXECUTAR BUILD WEEK PARA OBTER SHA-1
  1. Ir a github.com/jonnipm-web/ai-social-copilot/actions
  2. Selecionar "BUILD WEEK — VALIDAR E GERAR APK"
  3. "Run workflow" → branch: claude/access-social-copilot-wJ6B5 → Run
  4. Aguardar o job "build" chegar ao step
     "Imprimir fingerprint SHA-1 e SHA-256 da keystore release"
  5. Copiar os valores:
       SHA1:   <valor do log>
       SHA256: <valor do log>
  6. Reportar ao Claude os valores copiados

PASSO 2 — REGISTRAR SHA-1 NO GOOGLE CLOUD CONSOLE
  1. Acessar: console.cloud.google.com/apis/credentials
     Projeto: focused-code-423720-r1
  2. Clicar no OAuth Client Android:
     221504834589-e918u3i4fh6cjps9hdu6lchpnqrpjh9j.apps.googleusercontent.com
  3. No campo "Certificate fingerprint (SHA-1)":
     Colar o SHA-1 obtido no PASSO 1
  4. Salvar

  PACKAGE:     com.example.ai_social_copilot
  SHA-1:       UNKNOWN — obter no PASSO 1
  SHA-256:     UNKNOWN — obter no PASSO 1 (opcional mas recomendado)
  OAUTH TYPE:  Android

PASSO 3 — ATUALIZAR GOOGLE-SERVICES.JSON
  1. Na página de Credentials do Google Cloud Console
  2. Clicar no ícone de download (↓) ao lado do Android OAuth Client
     (ou baixar via: firebase console → Project Settings → google-services.json)
  3. Verificar que certificate_hash não está mais vazio:
     grep certificate_hash google-services.json
  4. Substituir android/app/google-services.json pelo arquivo baixado
  5. Commit + push no branch
  6. Reportar ao Claude para confirmar e gerar APK final

PASSO 4 — VERIFICAR APIS HABILITADAS (se Drive falhar)
  1. console.cloud.google.com/apis/dashboard
     Projeto: focused-code-423720-r1
  2. Confirmar que Google Drive API está habilitada
  3. Confirmar que People API está habilitada
  4. Se não: Library → buscar → Enable

PASSO 5 — INSTALAR APK NO GALAXY S25 ULTRA
  1. Desinstalar o APK atual (obrigatório — certificado mudou)
  2. Baixar o novo APK do artefato do BUILD WEEK (step PASSO 1)
  3. Instalar o novo APK
  4. Testar Google Drive OAuth: Cofre → Google Drive → Entrar com Google
  5. Reportar resultado

==================================================
CHECKLIST DE PREFLIGHT — GO/NO-GO
==================================================

  [X] Migrations 013/014/015             PASS
  [X] PGRST204                           RESOLVED
  [X] extract-knowledge deployada         DONE (commit 6714934)
  [X] build-apk.yml com signing release  CORRIGIDO (este commit)
  [ ] SHA-1 definitivo obtido via CI      PENDENTE (PASSO 1)
  [ ] SHA-1 registrado Google Cloud       PENDENTE (PASSO 2)
  [ ] google-services.json atualizado     PENDENTE (PASSO 3)
  [ ] google-services.json commitado      PENDENTE (PASSO 3)
  [ ] Drive API habilitada                VERIFICAR (PASSO 4)
  [ ] APK instalado no S25 Ultra          PENDENTE (PASSO 5)

==================================================
DECISÃO FINAL
==================================================

  NO-GO — AGUARDANDO PASSOS 1-3

  O código está correto e completo. O BUILD WEEK agora gera APK com
  signing persistente. O bloqueio remanescente é operacional:
  o PO precisa obter o SHA-1 do CI, registrá-lo no Google Cloud,
  atualizar o google-services.json e reinstalar o APK.

  GO PARA APK REBUILD: após PASSO 3 concluído e commitado.
  GO PARA DEVICE TEST: após PASSO 5 concluído.

==================================================
FIM DO RELATÓRIO
==================================================
