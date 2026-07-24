DIAGNÓSTICO — P0-C GOOGLE DRIVE (DEVELOPER_ERROR 10)
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
STATUS: AGUARDANDO AÇÃO EXTERNA DO PO
==================================================

SINTOMA CONFIRMADO EM DISPOSITIVO:
  PlatformException(sign_in_failed, z0.d: 10)
  DEVELOPER_ERROR code 10 = OAuth SHA-1 não registrada

CAUSA RAIZ IDENTIFICADA:
  O arquivo google-services.json contém certificate_hash vazio:

    "oauth_client": [{
      "client_id": "...",
      "client_type": 1,
      "android_info": {
        "package_name": "com.example.ai_social_copilot",
        "certificate_hash": ""   ← VAZIO
      }
    }]

  O Google Sign-In exige que a SHA-1 do certificado usado para
  assinar o APK esteja registrada no Google Cloud Console E
  no google-services.json. Quando o campo está vazio, qualquer
  APK assinado com qualquer keystore falha com code 10.

==================================================
PASSOS PARA CORREÇÃO (ação do PO)
==================================================

PARTE 1 — Obter SHA-1 do keystore de release:

  Opção A (keystore local):
    keytool -list -v -keystore release.keystore -alias <alias>
    (copiar a linha "SHA1: XX:XX:XX:...:XX")

  Opção B (APK já assinado — mais confiável):
    apksigner verify --print-certs app-release.apk | grep SHA-1
    (o APK gerado pela CI já está assinado com o keystore correto)

  Opção C (da CI — recomendada se não tiver o keystore local):
    No GitHub Actions: Workflow > build-apk > job > step "Sign APK"
    Os logs exibem a SHA-1 usada pelo keystore de release.

PARTE 2 — Registrar SHA-1 no Google Cloud Console:

  1. Acessar: https://console.cloud.google.com/
  2. Selecionar o projeto: AI Social Copilot (ou nome configurado)
  3. Menu: APIs e serviços > Credenciais
  4. Localizar a credencial OAuth 2.0 do tipo "Android"
     (package name: com.example.ai_social_copilot)
  5. Editar > adicionar a SHA-1 obtida no Passo 1
  6. Salvar

PARTE 3 — Baixar o google-services.json atualizado:

  1. No mesmo console: projeto > Configurações do projeto
     (ícone de engrenagem)
  2. Aba "Seus apps" > app Android
  3. Baixar google-services.json
  4. Substituir o arquivo em: android/app/google-services.json
  5. Verificar que certificate_hash NÃO está mais vazio
  6. Commit e push

PARTE 4 — Testar:

  Gerar novo APK via CI ou localmente (flutter build apk --release)
  Instalar no Samsung Galaxy S25 Ultra
  Testar: Cofre > Adicionar > Google Drive
  Esperado: seletor de arquivo abre sem erro

==================================================
PACKAGE NAME ESPERADO
==================================================

  com.example.ai_social_copilot

  Verificar em: android/app/build.gradle.kts
    applicationId = "com.example.ai_social_copilot"

  Se o package name difere entre o console e o APK,
  o erro também ocorrerá independente da SHA-1.

==================================================
CONFIGURAÇÃO ATUAL NO REPO
==================================================

  Arquivo: android/app/google-services.json
  Campo:   oauth_client[].android_info.certificate_hash
  Valor:   "" (string vazia — INCORRETO)

  Após correção, o valor deve ser a SHA-1 no formato:
  "XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX"

==================================================
IMPACTO SE NÃO CORRIGIR
==================================================

  Todo fluxo de Google Sign-In falha com code 10.
  Inclui: Google Drive, Google Docs, qualquer OAuth Google.
  NÃO afeta login por email/senha ou login biométrico.
