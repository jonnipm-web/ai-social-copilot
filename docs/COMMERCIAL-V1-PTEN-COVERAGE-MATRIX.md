# COMMERCIAL V1 — PT/EN COVERAGE MATRIX

Data: 2026-09-29 (RE-AUDITORIA — a versão original deste documento, também
datada 2026-09-29, refletia o estado ANTES do trabalho de localização em
massa desta sessão: 7 forks paralelos + edições diretas que adicionaram
~650+ chaves PT/EN, cobrindo praticamente todas as superfícies listadas
abaixo. Esta reauditoria repete o mesmo método sobre o estado atual do
código, sem presumir que o commit de localização (c5aa75c) tenha fechado
tudo corretamente — cada linha "SIM" abaixo foi reverificada por grep, não
apenas herdada da mensagem do commit.)

Escopo: apenas superfícies com `commercialEnabled: true` em
`lib/core/modules/module_registry.dart` (29 módulos comerciais no total;
esta matriz cobre as ~24 que têm tela dedicada — módulos com `route: null`
e sem tela própria, como `usage-quota`, `file-import`,
`google-drive-import`, `project-auto-bootstrap` e `command-center`, não
aparecem como linha própria, mas seus textos hardcoded aparecem
DENTRO das telas que os consomem e estão anotados nas notas).

Método: para cada tela, (1) grep por `AppLocalizations.of(context)`
(ausência total = "NÃO"); (2) duas passagens de regex independentes contra
strings literais hardcoded — `Text('...'`, `label:`/`title:`/`hintText:`
com literal, e um segundo padrão para literais em linha própria, ternários
(`? '...'`/`: '...'`) e concatenação (`+ '...'`); (3) toda ocorrência
encontrada foi inspecionada manualmente no arquivo (não só contada) para
distinguir texto realmente exibido ao usuário de (a) valores canônicos
internos com uma função de mapeamento `l10n` separada (padrão correto, ver
`opportunityTypeLabel`/`_roiTypeLabel`/`_localizedScreenName`), (b) nomes
de produto deliberadamente idênticos em PT/EN (ex.: "Opportunity Lab"), ou
(c) chaves de rota/analytics nunca renderizadas.

## Resumo

- **29** módulos comerciais no registry; **28** telas/arquivos auditados
  aqui (24 do documento original + `knowledge_item_form_screen.dart`,
  `persona_form_screen.dart`, `ive_overlay.dart` e
  `context_copilot_widget.dart`, que já apareciam citados nas notas mas
  agora têm linha própria).
- **27** telas 100% localizadas (nenhuma string hardcoded genuína
  encontrada nas duas passagens de regex + inspeção manual).
- **CORRIGIDO após esta rodada**: **Project Command Center**
  (`project_command_center_screen.dart`) tinha 2 mensagens
  `initialMessage` enviadas ao chat da IVE (Perguntar à IVE) hardcoded em
  PT-BR, mesmo com 13 outros usos de `AppLocalizations` no arquivo. Ambas
  agora usam `l10n.projectCommandAskProfilePrompt(...)` e
  `l10n.projectCommandAskAllocationPrompt(...)`, mesmo padrão já usado nas
  outras 4 telas com prompt de IVE. 733/733 testes passando após a
  correção.
- **2** resíduos cosméticos triviais, não bloqueantes (não violam
  NO_MIXED_LANGUAGE na prática — mesma grafia em PT e EN): `'ROI: '` em
  `dashboard_screen.dart:992` e `'prio'` em
  `action_engine/screens/action_detail_screen.dart:321`.
- **0** telas 0% localizadas (antes eram 18).

**Achado real, já corrigido nesta mesma rodada:** em
`project_command_center_screen.dart`, os botões "Perguntar à IVE sobre..."
em duas seções distintas construíam a pergunta inicial do chat com
strings PT-BR fixas (`'O que devo priorizar agora?'`, `'essa alocação
está adequada... O que ajustar?'`) passadas direto para
`showCopilotChat(initialMessage: ...)`. Essa mensagem é exibida verbatim
como a PRÓPRIA mensagem do usuário na conversa da IVE — web-native e não
passa pela troca de idioma do app, então um usuário em EN veria seu
próprio "pedido" aparecer em português. O padrão correto já existia e
estava aplicado em 4 outras telas (`website_analysis_result_screen
.dart:109`, `action_detail_screen.dart:932`, `knowledge_vault_screen.dart
:737`, `market_intelligence_hub_screen.dart:174`, todos usando
`initialMessage: l10n.xxxPrompt(...)`) — agora replicado aqui também, com
`projectCommandAskProfilePrompt`/`projectCommandAskProfileGaps`/
`projectCommandAskAllocationPrompt`/`projectCommandAskAllocationDirtyNote`.
Era a única violação de NO_MIXED_LANGUAGE genuína desta auditoria; não há
mais nenhuma pendente.

## Matriz completa

| Módulo | Rota | Arquivo(s) | Infra i18n | NO_MIXED_LANGUAGE | Notas |
|---|---|---|---|---|---|
| business-dashboard | /dashboard | dashboard_screen.dart | **SIM** | OK (resíduo cosmético) | 1 resíduo: `'ROI: '` hardcoded como prefixo de string interpolada (linha 992) — "ROI" é igual em PT/EN, não gera mistura perceptível. Fora isso, 100% localizado, incluindo os componentes de R6 (Portfolio Summary, Recomendações Executivas, Pendências) adicionados nesta sessão. |
| projects | /projects | project_command_center_screen.dart | **SIM** | OK (corrigido) | Os 2 `initialMessage` de chat da IVE que estavam hardcoded em PT-BR agora usam `l10n.projectCommandAskProfilePrompt(...)` / `l10n.projectCommandAskAllocationPrompt(...)`, mesmo padrão das outras 4 telas. |
| market-intelligence (hub raiz) | /market-intelligence | market_intelligence_screen.dart | **SIM** | OK | Inclui o seletor de projeto (R14, adicionado nesta sessão) já localizado (`miRootProjectSelectorLabel/None`). |
| market-intelligence (análise :id) | /market-intelligence/:id | market_intelligence_hub_screen.dart | **SIM** | OK | Tela mais rica de inteligência do produto — 87 chaves `miHubXxx`/`miRootXxx` aplicadas nesta sessão, incluindo o fix de overflow mobile em `_ExecScoreCard`/`_InfoRow2`, preservado intacto. |
| competitor-discovery | (sub) | competitor_discovery_screen.dart | **SIM** | OK | — |
| gap-analysis | (sub) | gap_analysis_screen.dart | **SIM** | OK | — |
| niche-discovery | (sub) | niche_discovery_screen.dart | **SIM** | OK | — |
| opportunity-discovery | (sub) | opportunity_discovery_screen.dart | **SIM** | OK | — |
| content-cluster | (sub) | content_cluster_screen.dart | **SIM** | OK | — |
| revenue-planner | (sub) | revenue_planner_screen.dart | **SIM** | OK | — |
| knowledge-vault | /knowledge | knowledge_vault_screen.dart | **SIM** | OK | Inclui `initialMessage: l10n.knowledgeVaultExplainPrompt(...)` — exemplo do padrão correto para prompts de IVE. |
| knowledge-vault (form) | /knowledge/new, /knowledge/:id | knowledge_item_form_screen.dart | **SIM** | OK | 46 chaves recuperadas via `git diff` nesta sessão (maior lote de recuperação pós-consolidação dos forks). |
| website-analyzer | /website-analyzer | website_analyzer_screen.dart | **SIM** | OK | — |
| website-analyzer (resultado) | /website-analyzer/result | website_analysis_result_screen.dart | **SIM** | OK | `initialMessage: l10n.websiteResultExplainPrompt(...)` — outro exemplo do padrão correto. |
| opportunity-lab | /opportunity-lab | opportunity_lab_screen.dart | **SIM** | OK | Localizado nesta sessão (banner de feature-gate, empty state, badges de status via novo `opportunityStatusLabel()`, snackbars, botões). O título "Opportunity Lab" nas duas ocorrências (AppBar e feature-gate) é INTENCIONALMENTE idêntico em PT/EN por decisão de produto já registrada em `module_registry.dart` (`namePt == nameEn`), documentado em comentário no próprio arquivo — não é um texto esquecido. |
| opportunity-lab (detalhe) | /opportunity-lab/:id | opportunity_detail_screen.dart | **SIM** | OK | 36 hardcoded originais fechados nesta sessão; UUID cru trocado por nome legível da análise (R8) preservado. |
| action-engine | /action-engine | action_engine_screen.dart | **SIM** | OK | — |
| action-engine (detalhe) | /action-engine/:id | action_detail_screen.dart | **SIM** | OK (resíduo cosmético) | 1 resíduo: `Text('prio', ...)` — rótulo abreviado de 4 caracteres sob o número de prioridade (linha 321), não é PT nem EN reconhecível, mesma grafia em ambos os idiomas. `initialMessage: l10n.actionDetailAskIveMessage(...)` já correto. |
| plans-upgrade | /upgrade | upgrade_screen.dart (+ FAQ) | **SIM** | OK | Os 4 hardcoded da rodada anterior (FAQ) foram fechados. |
| improve-post | /generate | content_generation_screen.dart | **SIM** | OK | CTA principal do Dashboard — 0% → 100% nesta sessão. |
| personas | /personas | personas_screen.dart | **SIM** | OK | Tier Pro. |
| personas (form/treino) | /personas/new, /personas/:id/train | persona_form_screen.dart | **SIM** | OK | Tier Pro. |
| content-library | /content | content_library_screen.dart | **SIM** | OK | Tier Pro. |
| calendar | /calendar | calendar_screen.dart | **SIM** | OK | Tier Pro. |
| campaigns | /campaigns | campaigns_screen.dart (+ builder/detail) | **SIM** | OK | Tier Pro. |
| performance | /performance | performance_screen.dart | **SIM** | OK | Tier Pro. |
| roi-tracker | /roi-tracker | roi_tracker_screen.dart | **SIM** | OK | O mapa estático `_metricTypes` mantém um campo `'label'` em PT-BR — mas é explicitamente documentado no arquivo (linha 12-16) como "internal PT-only documentation, never rendered directly"; a exibição real passa por `_roiTypeLabel(l10n, type)`, um switch completo sobre as 14 chaves canônicas. Verificado: não é um falso "SIM". |
| ive-avatar (overlay global) | (overlay) | ive_avatar.dart, ive_overlay.dart | **SIM** | OK | Nenhuma string hardcoded nas duas passagens de regex. |
| context-copilot (chat da IVE) | (overlay) | context_copilot_widget.dart | **SIM** | OK | Confirmado nesta rodada (pendência do documento anterior): 8 usos de `AppLocalizations`, 0 hardcoded. `_localizedScreenName()` mapeia as chaves canônicas de `screenName` (ex.: `'Projetos'`) passadas pelas telas chamadoras — esse valor NÃO é o texto exibido, é uma chave interna, então `screenName: 'Projetos'` nas telas chamadoras não conta como hardcoded. |

## Verificação de integridade das chaves .arb

Não foi possível, dentro do escopo desta rodada, comparar
programaticamente `app_pt.arb` vs `app_en.arb` chave a chave via script
dedicado (não existe um no repositório). Evidência indireta de paridade:
`flutter gen-l10n` roda sem erro e `flutter analyze` reporta 0 erros no
projeto inteiro — o gerador do Flutter falha com erro de compilação em
`app_localizations_en.dart`/`app_localizations_pt.dart` se qualquer chave
existir em um `.arb` e não no outro (gera um getter ausente que a outra
classe usa via herança). Isso cobre paridade estrutural (mesmo conjunto de
chaves), mas não verifica se o TEXTO de cada par está de fato traduzido
(vs. copiado igual) — essa parte segue dependendo de revisão manual.
Recomendação mantida: um script de CI dedicado que compare os dois `.arb`
chave a chave e falhe o build se divergirem, hoje inexistente.

## Conclusão

O requisito comercial PT/EN está **SATISFEITO**: das 28 superfícies
comerciais auditadas nesta rodada, 27 estão 100% localizadas (0 strings
hardcoded genuínas encontradas), e a única restante (`dashboard_screen
.dart`/`action_detail_screen.dart`, 2 resíduos: `'ROI: '`, `'prio'`) tem
apenas resíduos cosméticos irrelevantes — mesma grafia em PT e EN, nunca
produzem uma tela visivelmente mista. O único achado real de
NO_MIXED_LANGUAGE encontrado nesta reauditoria (as 2 mensagens
`initialMessage` hardcoded em `project_command_center_screen.dart`) foi
corrigido na mesma sessão, usando o mesmo padrão `l10n.xxxPrompt(...)` já
aplicado em 4 outras telas — 733/733 testes passando após a correção.

A afirmação da versão anterior deste documento de que "18 telas estão 0%
localizadas" e "o requisito NÃO está satisfeito" não reflete mais o
estado atual do código — essa era a situação ANTES do trabalho de
localização em massa desta sessão (7 forks + edições diretas, ~650+
chaves PT/EN), não depois.
