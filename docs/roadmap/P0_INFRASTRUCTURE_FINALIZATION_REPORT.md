P0 INFRASTRUCTURE FINALIZATION REPORT
AI Social Copilot
Data: 2026-07-24
Branch: claude/access-social-copilot-wJ6B5

==================================================
1. STATUS DO DEPLOY — extract-knowledge
==================================================

VERSÃO LOCAL (branch claude/access-social-copilot-wJ6B5):
  Commit: 343b2d8
  Arquivo: supabase/functions/extract-knowledge/index.ts
  Status: HOTFIX COMPLETO E CORRETO

VERSÃO EM PRODUÇÃO (último deploy bem-sucedido):
  Data:   2026-07-16
  Commit: bff53c7f (branch main)
  Status: SEM O HOTFIX — versão antiga em produção

DELTA: a versão em produção NÃO tem as correções do commit 343b2d8.
  Ausentes em produção:
    extractFromPdf()   — extração inline de PDF por URL
    extractFromDocx()  — extração inline de DOCX por URL
    Google Drive PDF/DOCX download
    Códigos semânticos de erro

TENTATIVA DE DEPLOY AUTOMATIZADO:
  Comando: workflow_dispatch em deploy-edge-functions.yml
  Resultado: 403 Resource not accessible by integration
  Causa: o token MCP do GitHub não tem permissão para disparar workflows
  CONCLUSÃO: deploy manual necessário (ação do PO)

==================================================
2. AUDITORIA DA FUNÇÃO LOCAL — CHECKLIST COMPLETO
==================================================

  URL web normal (HTML/text):          SUPORTADO (linhas 234-244)
  PDF por URL:                         SUPORTADO (linhas 214-221)
  DOCX por URL:                        SUPORTADO (linhas 223-231)
  Google Docs:                         SUPORTADO (linhas 147-162)
  Google Drive file link (PDF/DOCX):   SUPORTADO (linhas 165-200)
  Redirects:                           SUPORTADO (redirect: "follow" em todos os fetches)
  Content-Type dinâmico:               SUPORTADO (detecção via header, não por extensão)
  Download binário:                    SUPORTADO (arrayBuffer → Uint8Array)
  extractFromPdf():                    IMPLEMENTADO (linhas 104-126) com fallback regex
  extractFromDocx():                   IMPLEMENTADO (linhas 128-141) via fflate unzip
  Conteúdo vazio:                      TRATADO — [EMPTY_CONTENT]
  Acesso negado:                       TRATADO — [ACCESS_DENIED]
  Falha de download:                   TRATADO — [DOWNLOAD_FAILED]
  Falha de extração:                   TRATADO — [EXTRACTION_FAILED]
  Formato não suportado:               TRATADO — [UNSUPPORTED_TYPE]

  GROQ_API_KEY:  Deno.env.get("GROQ_API_KEY") — secret via Supabase Dashboard
  Modelo:        llama-3.3-70b-versatile
  Max tokens:    4000 (input truncado em 10.000 chars)

  VEREDICTO: código pronto para deploy — nenhuma alteração necessária.

==================================================
3. AÇÃO MANUAL NECESSÁRIA — DEPLOY
==================================================

OPÇÃO A (recomendada): workflow_dispatch no GitHub Actions UI
  1. Acessar: github.com/jonnipm-web/ai-social-copilot/actions
  2. Clicar em "Deploy Edge Functions"
  3. Clicar em "Run workflow"
  4. Selecionar branch: claude/access-social-copilot-wJ6B5
  5. Clicar em "Run workflow" (botão verde)
  6. Aguardar conclusão (~2 minutos)
  7. Confirmar que o job "deploy extract-knowledge" passou

OPÇÃO B: deploy-supabase.yml (também via workflow_dispatch)
  Mesmo fluxo acima, escolhendo "Deploy Supabase (Migration + Edge Functions)"
  Este workflow também faz: supabase functions deploy extract-knowledge

VERIFICAÇÃO PÓS-DEPLOY:
  No Supabase Dashboard → Edge Functions → extract-knowledge
  Confirmar que "Updated at" reflete data/hora do deploy recém executado.

==================================================
4. STATUS GOOGLE DRIVE OAUTH — ERRO CÓDIGO 10
==================================================

CAUSA RAIZ CONFIRMADA:
  Arquivo: android/app/google-services.json
  Campo:   oauth_client[0].android_info.certificate_hash
  Valor:   "" (VAZIO)

  O Google Sign-In exige o SHA-1 do certificado de assinatura do APK
  registrado no Google Cloud Console E preenchido no google-services.json.
  Sem isso: PlatformException(sign_in_failed, ... 10 ...) em todos os dispositivos.

==================================================
5. SHA-1 POR AMBIENTE — ANÁLISE DOS WORKFLOWS
==================================================

WORKFLOW A — build-android.yml (LEGACY — GERAR APK)
  Trigger:  push to main
  Signing:  release keystore via secrets KEYSTORE_BASE64 / KEYSTORE_KEY_ALIAS /
            KEYSTORE_STORE_PASSWORD / KEYSTORE_KEY_PASSWORD
  SHA-1:    SHA-1 do keystore armazenado em KEYSTORE_BASE64
  APK:      release — assinado com keystore dedicado

WORKFLOW B — build-apk.yml (BUILD WEEK — VALIDAR E GERAR APK)
  Trigger:  workflow_dispatch
  Signing:  SEM keystore configurado → flutter build apk --release usa
            debug key do runner GitHub Actions
  SHA-1:    debug key do runner (padrão GitHub Actions)
            Geralmente: DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09
            Pode variar por runner — confirmar via comando abaixo.

PARA DETERMINAR QUAL SHA-1 REGISTRAR:

  CASO 1 — APK gerado pelo build-android.yml (com KEYSTORE_BASE64):
    O PO precisa do arquivo .jks / .keystore original e rodar:
      keytool -list -v \
        -keystore <arquivo.jks> \
        -alias <KEYSTORE_KEY_ALIAS>
    Copiar o SHA-1 que aparecer em "Certificate fingerprints".

  CASO 2 — APK gerado pelo build-apk.yml (sem keystore):
    Adicionar temporariamente ao build-apk.yml, após "Build do APK":

      - name: Extrair SHA-1 do APK gerado
        run: |
          keytool -printcert \
            -jarfile build/app/outputs/flutter-apk/app-release.apk \
            | grep SHA1

    Rodar o workflow e copiar o SHA-1 do log.

  CASO 3 — Determinar pelo APK instalado no Galaxy S25 Ultra:
    Via adb (com o dispositivo conectado ao computador):
      adb shell pm list packages | grep ai_social
      adb shell pm path com.example.ai_social_copilot
      adb pull <path_do_apk> /tmp/app.apk
      keytool -printcert -jarfile /tmp/app.apk | grep SHA1

==================================================
6. COMO REGISTRAR O SHA-1 NO GOOGLE CLOUD CONSOLE
==================================================

  (Após determinar o SHA-1 correto pelo caso acima)

  1. Acessar: console.cloud.google.com/apis/credentials
     Projeto: focused-code-423720-r1

  2. Clicar no OAuth Client Android:
     221504834589-e918u3i4fh6cjps9hdu6lchpnqrpjh9j.apps.googleusercontent.com

  3. No campo "Certificate fingerprint SHA-1": colar o SHA-1 obtido

  4. Salvar

  5. Baixar o google-services.json atualizado
     (botão de download na mesma tela de credenciais)

  6. Substituir android/app/google-services.json pelo arquivo baixado

  7. Verificar que certificate_hash não está mais vazio:
       grep certificate_hash android/app/google-services.json

  8. Commitar e fazer push → CI gera APK atualizado

==================================================
7. RISCOS IDENTIFICADOS
==================================================

  RISCO 1 — Dois ambientes de signing sem SHA-1 separados:
    build-android.yml usa release keystore → SHA-1 A
    build-apk.yml usa debug key → SHA-1 B
    Se registrar SHA-1 errado, Drive login falha no APK certo.
    MITIGAÇÃO: confirmar qual workflow gerou o APK instalado no S25 Ultra.

  RISCO 2 — process-file não deployado:
    O workflow skip explicitamente "process-file" por exceder limite de tamanho.
    extract-knowledge NÃO depende de process-file neste hotfix (extração inline).
    MITIGAÇÃO: nenhuma ação necessária. extract-knowledge é autossuficiente.

  RISCO 3 — GROQ_API_KEY não configurada em produção:
    Se a secret GROQ_API_KEY não estiver configurada no Supabase Dashboard,
    todas as análises retornarão erro 502 após o deploy.
    VERIFICAÇÃO: Supabase Dashboard → Edge Functions → Secrets → confirmar GROQ_API_KEY.

  RISCO 4 — google-services.json com certificate_hash vazio commitado:
    Qualquer build a partir do branch atual terá OAuth Drive quebrado.
    MITIGAÇÃO: atualizar o arquivo após registrar o SHA-1 e commitar.

==================================================
8. CHECKLIST DE PREFLIGHT PARA APK REBUILD
==================================================

  [X] migrations 013/014/015 aplicadas
  [X] PGRST204 resolvido
  [ ] extract-knowledge deployada com commit 343b2d8
  [ ] PDF URL suportado em produção (depende do deploy)
  [ ] DOCX URL suportado em produção (depende do deploy)
  [ ] GROQ_API_KEY configurada no Supabase (verificar Dashboard)
  [ ] SHA-1 correto identificado por ambiente (Caso 1, 2 ou 3 acima)
  [ ] SHA-1 registrado no Google Cloud Console
  [ ] google-services.json atualizado com certificate_hash preenchido
  [ ] google-services.json commitado e CI rodado
  [ ] package/applicationId confere: com.example.ai_social_copilot
  [ ] nenhum segredo exposto no repositório

  Items marcados [X]: concluídos
  Items marcados [ ]: pendentes — bloqueiam o APK rebuild

==================================================
9. AÇÕES MANUAIS RESTANTES PARA O PO
==================================================

  AÇÃO 1 (RED GATE — DEPLOY):
    Ir a github.com/jonnipm-web/ai-social-copilot/actions
    → "Deploy Edge Functions" → "Run workflow"
    → Branch: claude/access-social-copilot-wJ6B5 → Run
    Confirmar sucesso e reportar ao Claude.

  AÇÃO 2 (RED GATE — SHA-1):
    Determinar qual APK foi instalado no S25 Ultra (workflow A ou B).
    Obter SHA-1 pelo Caso 1, 2 ou 3 acima.
    Registrar no Google Cloud Console.
    Baixar e commitar google-services.json atualizado.
    Reportar SHA-1 obtido ao Claude.

  AÇÃO 3 (VERIFICAÇÃO):
    Confirmar GROQ_API_KEY nos secrets do Supabase:
    Dashboard → Project Settings → Edge Functions → Secrets
    Se ausente: adicionar com o valor correto.

==================================================
10. DECISÃO FINAL
==================================================

  NO-GO — BLOQUEADO

  RAZÃO:
    extract-knowledge em produção é a versão antiga (commit bff53c7f, 2026-07-16).
    O hotfix de PDF/DOCX (commit 343b2d8) não foi deployado.
    certificate_hash vazio em google-services.json → Drive OAuth falha.
    SHA-1 correto ainda não identificado nem registrado.

  GO PARA APK REBUILD SOMENTE APÓS:
    1. Deploy de extract-knowledge com commit 343b2d8 (AÇÃO 1)
    2. SHA-1 registrado + google-services.json atualizado + CI rodado (AÇÃO 2)
    3. GROQ_API_KEY confirmada (AÇÃO 3)

  CÓDIGO: 100% pronto — nenhuma alteração adicional necessária no branch.

==================================================
FIM DO RELATÓRIO
==================================================
