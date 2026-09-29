# R16 — Global End-to-End Language Consistency + AI Output Language — Final Report

Data: 2026-09-29 · Executor: Claude (primary executor) · Branch: `claude/r16-global-language-consistency` · PR: #104 (draft, **não mergear em `main`**)

## 24. Veredito final

**BLOCKED — WEB_DEPLOY_DISPATCH_REQUIRED** (backend 100% publicado; falta 1 clique no Deploy Web)

A implementação, os testes, a auditoria e o CI estão completos e verdes. A migration já foi aplicada em produção. O deploy das Edge Functions e do app web está bloqueado por um motivo técnico, não por um gate P0/P1: o token do GitHub desta sessão não tem permissão `actions:write` (erro `403 Resource not accessible by integration`). As rotas canônicas (`deploy-edge-functions.yml` e `deploy-web.yml`) são por `workflow_dispatch`. Depois que o Owner disparar os workflows (seção 20), a missão passa a **CONDITIONAL_PASS — OWNER_PHYSICAL_R16_GATE_PENDING** assim que a verificação do app publicado (seção 21) confirmar.

---

## 1. Recovery state

- A sessão anterior foi perdida. A investigação usou o `origin` como autoridade.
- **Achado crítico:** o app publicado **não** é construído a partir de `main`.
  - O `gh-pages` (`101ece3`, 2026-09-29 12:48 UTC) foi gerado por `workflow_dispatch` de `deploy-web.yml` na branch `claude/insightvalues-integration-macro-02` @ `875fb0c`.
  - Essa branch está 60 commits à frente de `main` e contém todas as outras branches recentes, exceto um commit só de documentação (`claude/sleepy-noether-ef89my`).
  - A primeira discovery, feita sobre `main` (`ff8ef34`), estava defasada e foi refeita sobre `875fb0c`.
- **Trabalho local da máquina do Owner:** não é observável deste ambiente em nuvem (não há link com o dispositivo). O estado publicado até 13:37 BST está todo no `origin`, e as chaves i18n do Dashboard estão em `875fb0c`.

## 2–4. SHAs e branch

| Item | Valor |
|---|---|
| Starting SHA (baseline publicada) | `875fb0ce` |
| Branch | `claude/r16-global-language-consistency` |
| Commits R16 | `6f51e7a` helpers → `86d36be` backend → `81a2173` client/i18n → `b6c5574` CI annotations → `16eb9b4` localização persistida → `d24283e` reconciliação da auditoria → (este relatório) |
| Final SHA | o HEAD da branch que contém este arquivo |

## 5. Causas-raiz (não era um bug localizado)

1. **Saída de IA sem política de idioma.**
   - 6 das 16 funções de IA ignoravam o idioma.
   - `context-copilot` (a IVE) e `decision-simulator` tinham "Responda sempre em Português do Brasil" fixo no prompt.
   - A diretiva das outras funções era fraca: estava dentro de system prompts em PT e perdia para o idioma da fonte.
2. **Idioma da fonte usado como idioma de saída.** `strategy_service`, `campaign_service` e `knowledge_service.extractWithAI` enviavam `item.language`, o idioma do documento. As chamadas de bootstrap, do Project Command Center, do decision simulator, do improve-post e do website analyzer não enviavam idioma nenhum.
3. **Texto determinístico em PT gerado em Dart.** "Seu ecossistema tem…", "MANTER", recomendações, briefing semanal, alocação de recursos, mensagens da IVE, alertas, validações e labels de modelos. Eram cerca de 150 frases em 11 serviços/providers, além de cerca de 330 literais de UI.
4. **Conteúdo histórico persistido em PT sem política de apresentação.**
   - Nenhuma tabela de saída de IA registra o idioma em que o conteúdo foi gerado.
   - O cliente ainda gravava frases em PT dentro de `opportunity_lab`/`action_queue` (`Impacto: …`, `[Lab]`).

## 6. Arquitetura antes / depois

- **Antes:** o locale da UI (`languageProvider`) só afetava parte das strings estáticas. A IA respondia no idioma do prompt ou da fonte, e o texto derivado era PT fixo.
- **Depois:** três idiomas explícitos (§7).
  - **SOURCE:** metadado do dado, nunca decide a saída.
  - **PRESENTATION:** `languageProvider`, fonte única de verdade.
  - **AI OUTPUT:** sempre derivado da apresentação.
- A cadeia de ponta a ponta:
  - `languageProvider` alimenta `outputLanguageCodeProvider`, que vai no campo `language` de todas as chamadas.
  - No servidor, `resolveOutputLanguage` gera `outputLanguagePolicy`, enviada como mensagem `system` confiável.
  - `appL10nProvider` alimenta todo texto determinístico.
  - `rowLocalizerProvider` alimenta toda leitura de conteúdo persistido.

## 7. Fonte de verdade do Presentation Language

- A fonte é `lib/providers/language_provider.dart` (SharedPreferences, sobrevive a reload e navegação). O fallback é determinístico: device `en`, senão `pt`.
- Não há estado concorrente: `outputLanguageCodeProvider` e `appL10nProvider` (em `lib/core/utils/language_utils.dart`) são derivados do provider.
- Qualquer provider que produz texto observa esses derivados. Por isso a troca PT↔EN recalcula tudo, sem componentes defasados.
- **Limitação:** a preferência é por dispositivo, não é sincronizada no perfil. Aceito para a v1.

## 8. Propagação do AI Output Language

- **`_shared/language.ts`:**
  - `resolveOutputLanguage` lê `language` ou `locale`; `pt*` vira pt-BR, `en*` vira en-US, e o default é pt-BR.
  - `outputLanguagePolicy` é escrita no idioma de destino e diz: a fonte, a pergunta e os exemplos podem estar em outro idioma; preserve nomes próprios, marcas, URLs, códigos e citações; não altere números.
  - A política entra como mensagem `system` adicional, depois do system prompt e **fora** de qualquer delimitador de conteúdo não confiável.
- **Códigos canônicos** que o cliente compara são declarados `fixedValueFields` e nunca são traduzidos: `SIM/CONDICIONAL/NÃO`, `Alto/Médio/Baixo`, `alta/média`, `risk_level`, `action_type`, `opportunity_type`, `competitors[].type`, `search_intent`, `detected_language`.
- **Cliente:** as 16 funções recebem o idioma de apresentação, incluindo bootstrap, Project Command Center, IVE legada e decision simulator.

## 9. Cobertura de i18n estático

- 660 chaves novas PT/EN: de 1.347 para 2.007, com paridade garantida por `test/l10n/arb_parity_test.dart`.
- **Ecosystem** (3 telas + serviço): 189 chaves.
- **IVE/Dashboard/Home/Projects/modelos:** 193 chaves.
- **Demais telas comerciais, erros, enums de IA e textos persistidos:** 260 chaves.
- **Mapeadores de exibição:** `ecosystem_labels.dart` e `ai_enum_labels.dart`. Os códigos armazenados não mudaram.
- **Erros crus** de Supabase/Stripe/Google/Edge passam por `extractErrorMessage(e, l10n)`.
- **Fica em PT de propósito:** o Debug Hub interno (não é superfície comercial). Nomes de produto/marca (InsightValues, Opportunity Lab, Hotmart…) são nomes próprios.

## 10. Estratégia para IA histórica (decidida com evidência, §30)

| Evidência (produção) | Valor |
|---|---|
| Linhas de IA persistidas | ~300 (competitors 61, opportunity_lab 55, action_queue 43, opportunities 37, knowledge_analysis 26…), 5 usuários |
| Registro do idioma de geração | nenhum |
| Reabrir tela chama IA? | não (só `select`; confirmado em todos os providers) |
| Regeneração possível? | parcial; impossível para linhas de bootstrap; seria uma **nova análise** (conteúdo novo, consome quota) |

As alternativas foram avaliadas.
- **"Original + Regenerate":** foi descartada como padrão, porque muda o conteúdo, cobra quota e não cobre o bootstrap.
- **Migração destrutiva:** é proibida.

**Decisão: localização de apresentação, lazy e com cache.**
- Nova função `localize-content`, do tipo `PRESENTATION`, revisado.
- Nova tabela `content_localizations`.
- Cada linha é traduzida **no máximo uma vez por idioma**. O original nunca é alterado e **não há consumo de quota de análise**.
- Texto claramente já no idioma de destino é servido sem IA. É uma otimização conservadora; em caso de ambiguidade, o modelo decide.
- `TranslatedContentNotice` deixa a tradução explícita: "Traduzido automaticamente do português · Ver original" / "Ver tradução" (§9).

Classificação por classe de conteúdo:

| Classe | Fonte de verdade | Apresentação | Persistência | Localização | Quota |
|---|---|---|---|---|---|
| A STATIC_UI | ARB | locale | — | ARB | nenhuma |
| B ORIGINAL_USER_CONTENT (`projects.description/details_json`) | coluna original | tradução lado a lado (`*_localized`), formulários editam o original | nunca sobrescrita | cache | nenhuma |
| C EXTERNAL_SOURCE (documentos, sites) | fonte | original (é a fonte) | intacta | — | — |
| D AI_TRANSIENT (IVE, simulador) | resposta | idioma de apresentação | — | política de saída | análise (já existente) |
| E AI_PERSISTED | linha original | tradução em cache + aviso | original intacto | cache por (usuário, linha, idioma, hash) | nenhuma; teto diário de custo |
| F DETERMINISTIC_DERIVED | dados e scores | `AppLocalizations` | — | recalculado na troca | nenhuma |

**Registros novos:**
- Oportunidades semeadas pelo Market Intelligence, memória de negócio e notas de ROI são gravadas no idioma de apresentação vigente, como qualquer geração nova.
- Uma ação criada a partir de uma oportunidade traduzida é derivada da linha **original**, relida sem localização.

## 11. Prova de preservação da fonte

- **Migração:** apenas aditiva, sem `UPDATE`/`DELETE` em tabelas existentes. Rollback: `supabase/rollbacks/20261015000000_r16_content_localizations.down.sql`.
- **`localize-content`:** só faz `select` nas tabelas fonte e escreve apenas em `content_localizations`.
- **Testes:**
  - R16-LC-4 verifica que o objeto fonte não é mutado.
  - `content_localization_merge_test.dart` verifica merge em cópia, `r16_original_*` preservado e `Project.description` original para edição.
- Escritas do app são por campo (status). O `ProjectsNotifier` edita `description` (original), nunca `descriptionLocalized`.

## 12. Módulos auditados

Auth, Dashboard, Home, Projects/Command Center, Knowledge Vault/Analysis/Strategy, Website Analyzer, Market Intelligence (Hub + 6 submódulos), Opportunity Lab, Action Engine, IVE (overlay, chat, contexto), ROI, Ecosystem/Decision Center/Briefing/Allocation, Campaigns, Content, Calendar, Personas, History/Result, Plans/Upgrade/Account/Settings/Support/About, Admin, Impact/Strategy Lab (só texto). O Quant não teve nenhuma lógica tocada.

## 13. Edge Functions auditadas

As 16 funções de IA e mais `localize-content` (nova). A tabela por função está no commit `86d36be`.
- **Auth e quota:** a ordem `resolveAuthenticatedUser`, depois `requireModuleAccess`, depois `reserveQuota` ficou inalterada.
- **Cache:** nenhuma função de IA tem cache de resposta, então não existe colisão de idioma.
- **`ive-intelligence`:** já tinha política própria por idioma; não está em deploy.

## 14. Matriz de testes / resultados

| Caso (§27) | Cobertura |
|---|---|
| A/B/C/D saída derivada segue a UI | política testada em `language_test.ts` (14), `extract-knowledge` (EK-R16-1/2: fonte PT + UI EN), `context-copilot` (ordem da mensagem, locale); cliente: `r16_ai_request_language_test.dart` |
| E original PT só identificado | `TranslatedContentNotice` + testes de merge (`localizedFrom`, `und`) |
| F troca PT→EN sem stale | providers derivados de `languageProvider`/`rowLocalizerProvider`; notifiers observam os serviços |
| G reload persiste | `LanguageNotifier` (SharedPreferences), sem alteração |
| H saída estruturada | `fixedValueFields` + `ai_enum_labels_test.dart` exaustivo |
| I scores invariantes | `ecosystem_language_invariance_test.dart` (mesmos scores, veredictos, ranking e alocação em PT/EN); `nicheOriginal` para lógica de sobreposição |
| J quota | localização não chama `reserveQuota`; reabrir tela não chama IA; LC-5 (cache = zero IA), LC-6 (teto), LC-7/7b (falha registrada e sem tempestade de retry) |
| K cross-user | LC-3 (só linhas do chamador); RLS da tabela sem grants de cliente |
| L/M IVE responde no idioma da UI | política `freeText` no system; teste de ordem de mensagem |

**CI (PR #104, commit `d24283e`):**
- **Flutter Validation: SUCCESS** (analyze `--fatal-warnings`, `flutter test` completo, build web release, build APK).
- **Edge Function Tests:**
  - PASS: job novo "R16 language consistency", Migrations + RLS em Postgres 17 descartável (aplica a migração nova), Quant, Impact, AEF, context-copilot.
  - FAIL (pré-existentes, idênticos na baseline `875fb0c`, provado pelo PR de baseline #105): "Server-side entitlement + Promotion Gate" (IC-02/08/10/11) e "Strategy Builder Edge Function tests".
- **Pré-existente corrigido:** um warning do analyzer que já existia na baseline (`strategy_builder_form_screen_test.dart`) impedia `flutter test` de rodar no CI.

## 15. Codex findings / reconciliação

- **O Codex não está disponível neste ambiente.** A auditoria independente foi feita por um agente separado, somente leitura, que não participou da implementação.
- **Recomendação:** rodar o gate Codex sobre o PR #104 antes do merge na linha de integração.
- **Resultado da auditoria:** 0 P0.
  - P1-1 (IA para linhas já no idioma certo): corrigido com skip conservador.
  - P1-2 (teto burlável): corrigido. Falhas contam no teto, há limite de 250 segmentos/30k caracteres por linha e retry só após 24h.
  - P1-3 (ação criada de oportunidade traduzida): corrigido, a ação é derivada do original.
  - P1-4 (memo defasado após re-run): corrigido com fingerprint do conteúdo.
  - P2-1 (notifiers defasados), P2-4 (lógica de nicho dependente do idioma), P2-5 (details_json/persona_training), P2-6 (conta desativada), P2-7/8 (erros crus, fallback PT): corrigidos.
- **Aceitos e documentados:**
  - Treino de persona e resumo do AEF passam a usar o texto no idioma de apresentação do momento, como qualquer registro novo.
  - Traduções órfãs de linhas apagadas permanecem até a conta ser removida. Isso é inofensivo: `ON DELETE CASCADE` por usuário.

## 16. Regressão de segurança

- **Inalterados:** RLS, `getUser`, isolamento, role/plan/quota server-authoritative e webhook Stripe.
- **Idioma é só preferência:** allowlist `pt-BR`/`en-US`, nunca interpolado cru.
- **`localize-content`:**
  - `verify_jwt=true` + `resolveAuthenticatedUser`.
  - Checagem de `profiles.is_active` com fail-closed, igual ao `requireModuleAccess`.
  - Allowlist de tabelas/colunas no servidor e filtro `user_id` em toda leitura.
  - Conteúdo das linhas tratado como dado dentro de delimitador.
- **Classificação de governança:**
  - O kind `PRESENTATION` foi adicionado explicitamente ao allowlist revisado de não-módulos (MP-10) e a `MODULE_ARCHITECTURE.md` §13.6.
  - `deploy-allowlist.tsv` e `config.toml` foram atualizados.
  - `check_deploy_governance.sh`: OK.

## 17. Quota / custo

- FREE/PRO inalterados por esta missão. Stripe LIVE intocado.
- Localização = apresentação, não análise, então não consome quota.
- **Custo máximo:** 1 tradução por linha e por idioma durante toda a vida da linha, além de um teto de 300 tentativas por usuário por 24h e de ≤250 segmentos por linha.
- **Com o volume atual (~300 linhas):** a primeira visualização em EN do portfólio inteiro custa algumas centenas de chamadas pequenas uma única vez; depois, zero.

## 18. Performance

- **Primeira visualização de uma lista não traduzida:** 1 chamada por tabela (≤25 IDs), concorrência limitada a 4 no servidor. Na UI aparece primeiro o conteúdo original e depois o traduzido.
- **Em seguida:** servido do cache, com memo de sessão por fingerprint e requisições em voo compartilhadas.
- **Nenhuma chamada de IA por widget ou por render.**

## 19. Build

`flutter build web --release` e `flutter build apk --debug`: PASS no CI (PR #104, `d24283e`).

## 20. Deploy — o que foi feito e o que falta

| Etapa | Estado |
|---|---|
| Migration `20261015000000_r16_content_localizations` | **APLICADA em produção** (Supabase `nzngvbajrnruknpzzjbf`); verificado: RLS on, 0 policies, sem SELECT para anon/authenticated. No manifest permanece `LAB` (convenção do preflight AEF) |
| Edge Functions (16 de IA + `localize-content`) | **PUBLICADAS em 2026-09-29 ~21:17 UTC**, todas com `verify_jwt=true` (mesma política do `deploy-allowlist.tsv`) |
| App web (GitHub Pages) | **PENDENTE: 1 clique do Owner** em *Actions → Deploy Web → Run workflow*, na branch `claude/r16-global-language-consistency` |

**Rota de deploy das funções (exceção autorizada pelo Owner em 2026-09-29 22:1x BST):**
- **Por que não a rota canônica:** o token da sessão recebe 403 em `workflow_dispatch`.
- **Rota usada:** o Owner escolheu que eu publicasse pelo conector Supabase.
- **Como cada função foi publicada:** como um *shim* de uma linha que importa o `index.ts` commitado, fixado no commit imutável `aafe28441bda64e55ae006fdee243ddb36f65d2f` via `raw.githubusercontent.com`. O bundler do Supabase empacota o grafo remoto no deploy, então nada é buscado em runtime. O código em produção é exatamente o código auditado do commit, sem transcrição manual.
- **Verificação local antes do deploy:** o mesmo shim sobe em Deno e responde `401` sem sessão para localize-content, context-copilot, decision-simulator, market-analysis, extract-knowledge e analyze-website.
- **Retorno à rota canônica:** o próximo `deploy-edge-functions.yml` de qualquer função a substitui pelo bundle normal do CLI.

**Versões publicadas:**
- `localize-content` v1 (nova)
- `decision-simulator` v11
- `generate-project-actions` v11
- `generate-project-opportunities` v12
- `improve-post` v19
- `analyze-website` v13
- `competitor-discovery` v12
- `niche-discovery` v12
- `gap-analysis` v12
- `opportunity-discovery` v12
- `content-cluster` v12
- `revenue-planner` v12
- `generate-strategy` v14
- `generate-campaign` v14
- `extract-knowledge` v20
- `market-analysis` v12
- `context-copilot` v16

**Compatibilidade:** o app publicado hoje funciona com as funções novas, porque o idioma ausente cai no default pt-BR. Por isso a publicação do app pode acontecer depois.

## 21. Verificação do app publicado

Pendente do deploy. Assim que o Owner disparar os workflows, executo o smoke em EN e PT (Dashboard, Projects, Knowledge, Website Analyzer, MI, Strategy, Opportunity, Action Engine, IVE, Plans/Quota, Settings; PT→EN, EN→PT, reload, navegação, logout/login) e atualizo este relatório.

## 22. Limitações conhecidas

- A preferência de idioma é por dispositivo (não é sincronizada no perfil).
- Palavras-chave de SEO, entidades, nomes de concorrentes, URLs e nomes de projeto **não** são traduzidos, de propósito: são termos de busca do mercado de origem ou nomes próprios.
- A primeira visualização de uma lista histórica mostra o original por alguns segundos antes da tradução.
- **Achado fora do escopo, pré-existente:**
  - A branch publicada contém `fec9668` "FREE quota 5 → 15" com a migração `20261014000000_free_quota_15.sql` marcada LAB, **não aplicada em produção**.
  - Cliente (15) e servidor (5) podem divergir. A missão proíbe alterar FREE/PRO, então não mexi. Recomendo decisão do Agente Martins.
- O PR #105 (baseline de CI) foi fechado. A branch temporária `claude/r16-baseline-ci` não pôde ser apagada pelo token (403) e pode ser removida manualmente.

## 23. Checklist físico do Owner (após o deploy)

1. Account → selecionar **English** → recarregar a página.
2. Dashboard: Executive Briefing, Recommendations e Priorities 100% em inglês.
3. Abrir um projeto originalmente PT (ex.: RCBO Brasil): descrição em inglês com o aviso "Automatically translated from Portuguese · View original".
4. Knowledge originalmente PT → Analysis em inglês (palavras-chave de SEO permanecem no idioma do mercado).
5. Market Intelligence de um projeto → Hub e submódulos em inglês.
6. Opportunity Lab e detalhe de uma oportunidade.
7. Action Engine e detalhe de uma ação.
8. IVE: perguntar em português → resposta em inglês.
9. Navegar entre projetos de nichos diferentes: experiência continua em inglês.
10. Clicar "View original": o conteúdo volta ao PT, identificado; clicar "View translation" para retornar.
11. Voltar para Português: tudo converge para PT (conteúdo EN gerado agora é traduzido para PT na apresentação).
12. Conferir em Plans/Usage que o contador de análises **não** mudou com a navegação.
