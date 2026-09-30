# Commercial V1 Physical UX Baseline

Data: 2026-09-29
Missão: COMMERCIAL-V1-UX-RECONCILIATION
Status: CANÔNICO — gate de regressão do frontend comercial

## Sobre este documento

Este documento reconcilia os 15 requisitos (R1–R15) definidos pelo Owner
na missão COMMERCIAL-V1-UX-RECONCILIATION contra evidência real do
repositório: a vistoria física original do Owner já foi convertida em
arquitetura canônica pela missão `COMMERCIAL-PRODUCT-ARCHITECTURE-10`
(commit `bcd7c49`, "converts the owner's physical commercial audit into
7 canonical architecture documents"), cujos artefatos primários são:

- `docs/commercial/COMMERCIAL_PRODUCT_ARCHITECTURE.md` — achados por
  módulo, fundamentados em leitura de código real.
- `docs/commercial/COMMERCIAL_UI_STANDARD.md` — padrões de UI derivados
  da vistoria (legibilidade, i18n, explicabilidade de scores, IDs
  brutos, seletor de projeto duplicado).
- `docs/commercial/COMMERCIAL_NAVIGATION_STANDARD.md`,
  `docs/commercial/MODULE_LIFECYCLE_MATRIX.md`,
  `docs/commercial/IMPLEMENTATION_ROADMAP.md`,
  `docs/commercial/PROJECT_CONTEXT_CONTRACT.md`,
  `docs/commercial/IVE_INTERACTION_AND_QUOTA_CONTRACT.md`.
- `docs/EXECUTIVE_UX_TEST_REPORT.md` (2026-07-28) — checklist físico
  anterior, específico do antigo Business OS / Executive Dashboard.

Cada requisito abaixo cita a evidência primária (documento/arquivo/linha)
e o estado ATUAL do código (verificado nesta rodada, não assumido).
Este documento passa a ser o gate de regressão do frontend comercial:
qualquer mudança relevante de UX deve ser conferida contra ele antes de
declarar uma superfície "pronta".

Estados possíveis: `RECOVERED` (requisito da vistoria física recuperado
e documentado aqui pela primeira vez), `IMPLEMENTED` (código atual
satisfaz o requisito, verificado), `IMPLEMENTED_NOT_DEPLOYED` (existe
implementação completa mas não está no caminho de roteamento/uso real),
`REGRESSED` (já esteve correto e não está mais), `MISSING` (nunca foi
implementado), `UNRECOVERED` (nenhuma evidência histórica encontrada
após busca exaustiva em git log, branches, docs, comentários e
module_registry).

---

## R1 — INFORMATION FIRST

**Requisito**: cada módulo/card relevante deve apresentar resumo útil,
estado/status e insight ANTES de exigir navegação/clique.

**Evidência primária**: `COMMERCIAL_UI_STANDARD.md` §1 (legibilidade),
combinado com o próprio texto da missão atual do Owner.

**Estado atual do código**:
- Dashboard (`dashboard_screen.dart`): `_ProShortcutCard` (implementado
  nesta sessão) já mostra nome + benefício + badge PRO + estado de
  acesso antes do clique para os 5 módulos Pro-gated. Os demais
  atalhos (Histórico, Cofre, Website Analyzer) são links diretos sem
  informação prévia — aceitável, pois não são módulos com "estado"
  próprio (não há inteligência a resumir antes do clique).
- Market Intelligence Hub (`market_intelligence_hub_screen.dart`): JÁ
  implementa o padrão pesadamente — `_ExecScoreCard`,
  `_RevenuePotentialCard`, `_CompetitorRankingCard`,
  `_GapSummaryCard`, `_OpportunitiesCard`, `_PriorityActionsCard`
  mostram dados/resumo diretamente na tela, sem exigir navegação
  adicional. Confirmado pela `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §4:
  "already confirmed well-structured... should be the pattern other
  refinements match, not replace."
- **CORRIGIDO em missão posterior (PHYSICAL-QA-RECOVERY, PQ-02)**: o
  `_ModuleNavGrid` genérico (ícone+label, sem resumo prévio) foi
  REMOVIDO. Owner testou fisicamente e confirmou que o resumo nos cards
  acima NÃO tornava o grid aceitável — Nichos/Content Cluster/Revenue
  Planner não tinham NENHUM resumo próprio, só esse grid genérico. Agora
  todos os 6 módulos de aprofundamento têm card information-first
  dedicado (`_CompetitorRankingCard`, `_GapSummaryCard`,
  `_OpportunitiesCard`, e os 3 novos `_NicheSummaryCard`/
  `_ContentClusterSummaryCard`/`_RevenuePlannerSummaryCard`), cada um com
  dados reais, estado vazio explícito e CTA de navegação — não mais
  ícone+nome apenas.
- Opportunity Lab (`opportunity_lab_screen.dart`, `_LabItemCard`) e
  Action Engine (`_ActionCard`): ambos agora mostram o nome do projeto
  vinculado no card (R14 fechado em missão posterior).
- Action Engine: `_ActionSummaryRow`/`_SummaryChip`
  (`action_engine_screen.dart:201-254` por
  `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §3.4) são contadores estáticos
  sem interatividade — mostram números mas não permitem navegar/filtrar
  a partir deles. Não abordado nesta rodada.

**Status**: `IMPLEMENTED` — Dashboard (Pro cards), Market Intelligence
Hub (agora com os 6 módulos information-first, não só 3), Opportunity
Lab e Action Engine (nome do projeto nos cards). Único resíduo: os
contadores do Action Engine ainda não são clicáveis/filtráveis.

**Gap**: contadores do Action Engine não filtram a lista ao toque.

**Ação necessária**: conectar `_SummaryChip` (Action Engine) a um
filtro local de status.

**Teste/critério de aceitação**: widget test tocando um `_SummaryChip`
e verificando que a lista abaixo filtra para o status correspondente.

---

## R2 — EXPLAINABLE UI

**Requisito**: cards/indicadores relevantes devem permitir
aprofundamento e explicação (via IVE quando aplicável).

**Evidência primária**: `COMMERCIAL_UI_STANDARD.md` §6 (score
explainability).

**Estado atual do código**:
- `competitor_discovery_screen.dart`'s `_ScoreItem` ainda renderiza
  `similarityScore`/`authorityScore`/`relevanceScore`/`overallScore`
  como inteiros crus, SEM tooltip, explicação ou entrada para IVE
  explicar. Confirmado nesta rodada — nenhum `onTap`/`GestureDetector`/
  `showCopilotChat` encontrado em `competitor_discovery_screen.dart`.
- **CORRIGIDO nesta sessão**: `competitor.weaknesses` agora renderiza
  simetricamente a `strengths` em `_CompetitorCard`
  (`competitor_discovery_screen.dart`).
- Em contraste, `Decision Center` (`_ProjectCard`, citado em
  `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §8) e várias telas de MI (via
  `iveContextDataProvider`) JÁ têm afordance de explicação contextual.

**Status**: `IMPLEMENTED` (parcial) — `weaknesses` corrigido; scores
ainda opacos sem tooltip/explicação (não corrigido nesta sessão).

**Ação necessária (restante)**: adicionar explicação de score (tooltip
mínimo ou entrada "Perguntar à IVE sobre este score") em
`_CompetitorCard`.

**Teste/critério de aceitação**: teste de widget confirmando que
`weaknesses` aparece na tela quando não-vazio; teste de acessibilidade
confirmando que cada `_ScoreItem` tem um `Semantics`/tooltip explicando
o que o número significa.

---

## R3 — ACTION SECOND

**Requisito**: ações devem estar associadas à inteligência que as
originou; evitar grandes botões vazios de módulo sem contexto.

**Evidência primária**: princípio geral da missão + padrão observado em
`COMMERCIAL_PRODUCT_ARCHITECTURE.md` §3 (Opportunity Lab → Action
Engine).

**Estado atual do código**:
- Fluxo Market Intelligence → Opportunity Lab → Action Engine já é
  rastreável via FKs reais (`opportunity_lab_id`, `market_analysis_id`
  em `action_queue`) — confirmado em sessão anterior via a tela
  "Detalhe da Ação" mostrando "Análise de mercado: Market
  #1d2386ae...". Ações NASCEM de oportunidades, não são criadas
  soltas.
- Dashboard: antes desta sessão, os 5 cards Pro eram "grandes botões
  vazios" sem contexto (apenas ícone+label). Corrigido nesta sessão
  (`_ProShortcutCard`) — agora cada card comunica o valor/contexto do
  módulo antes do clique.
- Personas/Biblioteca/Calendário continuam sendo, em si, módulos de
  ação genérica sem uma "inteligência de origem" direta — isso é
  esperado (não são módulos analíticos), não é uma violação de R3.

**Status**: `IMPLEMENTED` para o fluxo MI → Opportunity → Action
(rastreável via FK) e para o Dashboard (corrigido nesta sessão).

**Gap**: nenhum gap adicional confirmado nesta rodada além do já
coberto por R1/R10.

---

## R4 — IVE CONTEXTUAL

**Requisito**: IVE deve compreender tela/projeto/card/item quando
tecnicamente suportado.

**Evidência primária**: `PROJECT_CONTEXT_CONTRACT.md`,
`IVE_INTERACTION_AND_QUOTA_CONTRACT.md`, Fase A do
`IMPLEMENTATION_ROADMAP.md` (já implementada — ver commits
`commercial-foundation-11-phase-a`).

**Estado atual do código**:
- `iveContextDataProvider` é `FutureProvider.autoDispose.family<
  IveContextData, String?>`, keyed por `projectId` — exatamente o
  contrato final após a correção do Codex round 1 (chave por projectId
  sozinho, não pelo objeto de interação inteiro).
- `showCopilotChat` é chamado com contexto real (projectId,
  sourceModule, sourceEntityType, sourceEntityId) em pelo menos 20
  pontos de entrada diferentes no código (confirmado via grep nesta
  sessão e na sessão anterior).
- 2 botões "Perguntar à IVE" que originalmente só faziam
  `context.go()` de volta à própria lista (`opportunity_detail_screen.
  dart:925-929`, `action_detail_screen.dart:876`, por
  `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §3.6) — CONFIRMADOS CORRIGIDOS
  em sessão anterior (mencionado explicitamente no resumo desta missão:
  "Fixed 2 confirmed-broken 'Ask IVE' buttons").

**Status**: `IMPLEMENTED`.

**Gap**: nenhum gap novo confirmado nesta rodada.

---

## R5 — HUMAN-READABLE INTELLIGENCE

**Requisito**: scores/estatísticas precisam de interpretação textual,
não apenas números crus.

**Evidência primária**: `COMMERCIAL_UI_STANDARD.md` §6 (mesmo achado de
R2, mas focado em INTERPRETAÇÃO, não em profundidade de explicação).

**Estado atual do código**:
- Market Intelligence Hub: `_ExecScoreCard._desc()`/`_rec()` já
  traduzem o score numérico em texto interpretativo ("Alto potencial de
  crescimento...", "🚀 Prioridade Alta") — `IMPLEMENTED`.
- `_scoreLabel()` (usado em várias telas do Hub) já converte score em
  "Alto"/"Médio"/"Baixo" — `IMPLEMENTED`.
- Competitor Discovery: scores ainda CRUS (mesmo achado do R2) — sem
  nenhuma camada de interpretação textual. `MISSING`.
- Dashboard: quota (`_UsageCard`) já é human-readable ("X de Y gerações
  restantes", "Limite atingido") — `IMPLEMENTED`.

**Status**: `IMPLEMENTED` na maior parte do Hub de MI e Dashboard;
`MISSING` em Competitor Discovery (mesmo item de R2, raiz comum).

**Ação necessária**: mesma de R2 — ao corrigir a explicabilidade de
scores em Competitor Discovery, adicionar também um rótulo
interpretativo (ex.: "Autoridade Alta", "Similaridade Moderada").

---

## R6 — EXECUTIVE DASHBOARD

**Requisito**: Dashboard deve agregar situação, inteligência,
oportunidades, prioridades e ações.

**Evidência primária**: `docs/EXECUTIVE_UX_TEST_REPORT.md` (2026-07-28)
— checklist físico do antigo "Business OS — Executive Dashboard"
("Nenhum card vazio — todos os módulos exibem dados ou empty state
claro", "Empty state com ação recomendada quando módulo sem dados").
`module_registry.dart` linha 522-536 (entrada `executive-dashboard`):
"ABSORVIDO em Business Dashboard (INSIGHTVALUES-COMMERCIAL-MACRO-01)...
widget mantido no código para referência histórica; pode ser removido
em limpeza futura." Entrada `home` (linha ~35): mesmo padrão, "Widget
HomeScreen mantido no código... pode ser removido em limpeza futura."

**Estado atual do código**:
- `lib/features/dashboard/screens/executive_dashboard_screen.dart`
  (895 linhas) existe, compila, e agrega: `projectsProvider`,
  `marketAnalysesProvider`, `roiSummaryProvider`,
  `pendingActionsProvider`, `featureFlagsProvider`,
  `opportunityLabProvider` — EXATAMENTE os componentes que R6 pede
  (prioridades, oportunidades, situação de projetos, ações pendentes,
  inteligência resumida). NÃO referenciado em nenhuma rota de
  `app.dart`.
- `lib/features/home/screens/home_screen.dart` (876 linhas): mesmo
  padrão, órfão.
- `lib/features/dashboard/screens/dashboard_screen.dart` (o Business
  Dashboard atual, canônico): hoje é apenas quota + atalhos de módulo
  (mesmo após a melhoria de UX desta sessão) — NÃO agrega
  prioridades/oportunidades/ações.

**DECISÃO DO OWNER JÁ EMITIDA NESTA MISSÃO (Opção C)**: manter o
Business Dashboard atual como superfície canônica; NÃO reativar a
arquitetura antiga; enriquecê-lo seletivamente reutilizando
componentes do `ExecutiveDashboardScreen`/`HomeScreen` que atendam ao
baseline.

**IMPLEMENTADO nesta sessão** (após este fork ter sido lançado):
`dashboard_screen.dart` agora observa `projectsProvider`,
`marketAnalysesProvider` e `pendingActionsProvider` (mesmos providers
do `ExecutiveDashboardScreen`) e renderiza, na ordem INFORMATION →
INTERPRETATION/PRIORITY → PRIORITY → ACTION:
`_PortfolioSummaryRow` (projetos ativos/análises/score médio, só
quando há projetos), `_ExecutiveRecommendationsCard` (portado de
`_ExecutiveRecommendations`, recomendações condicionadas a dados reais
— zero fabricação, R8 preservado) e `_DashboardPendingActionsCard`
(portado de `_PendingActionsCard`, ações pendentes reais do Action
Engine). `ExecutiveDashboardScreen`/`HomeScreen` permanecem órfãos
(não reativados, conforme a decisão). Teste de regressão `DASH-02`
(`test/features/dashboard/dashboard_screen_test.dart`) cobre o caso
com dados reais. Overflow real encontrado e corrigido durante a
implementação (header "Recomendações Executivas" sem `Flexible`).

**Status**: `IMPLEMENTED` (portado e integrado ao Dashboard canônico
nesta sessão — não mais apenas `IMPLEMENTED_NOT_DEPLOYED`).

---

## R7 — CONNECTED MODULES

**Requisito**: Knowledge → Project → Market Intelligence → Opportunity
→ Action → Dashboard/ROI → IVE devem estar conectados/rastreáveis.

**Evidência primária**: `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §0 ("the
data and service layer is usually already more capable than the UI
exposes") e §3.5 (project identity gaps).

**Estado atual do código**:
- Confirmado em sessão anterior (teste ao vivo): Market Intelligence
  analysis → Opportunity Lab (`addFromOpportunityItem`) → Action Engine
  (`action_queue` row com `opportunity_lab_id`/`market_analysis_id`) —
  rastreável de ponta a ponta via tela "Detalhe da Ação".
- `ContentItem.knowledgeItemId` existe como FK mas é **NÃO USADO** em
  `content_library_screen.dart`/`content_form_screen.dart` — Knowledge
  → Content Library não está conectado na UI apesar do dado existir.
  Confirmado como gap ainda aberto (não há evidência de correção nos
  commits posteriores a `bcd7c49` sobre este ponto específico).
- ROI Tracker: `_RoiIntegrationCard` no Hub de MI já persiste
  `opportunity_score`/`avg_opportunity_score`/`revenue_potential` no
  ROI Tracker — conectado.

**Status**: `IMPLEMENTED` para MI→Opportunity→Action→ROI.
`MISSING` para Knowledge→Content Library (FK existe, UI não usa).

**Ação necessária**: adicionar ação "Abrir Fonte Original" em
`content_library_screen.dart` usando `ContentItem.knowledgeItemId`
(item explicitamente descrito em `COMMERCIAL_PRODUCT_ARCHITECTURE.md`
§7, nunca implementado).

**Teste/critério de aceitação**: teste de widget confirmando que um
`ContentItem` com `knowledgeItemId` não-nulo mostra o botão/link, e que
o tap navega para o item de Knowledge Vault correto.

---

## R8 — EVIDENCE BEFORE DECISION

**Requisito**: não fabricar inteligência quando os dados forem
insuficientes; mostrar estado vazio/insuficiência de forma útil.

**Evidência primária**: `docs/EXECUTIVE_UX_TEST_REPORT.md` ("Valores
financeiros: R$0 → 'Ainda não estimado'", "Score null → '—' (não 0/100
ou 0)"), `COMMERCIAL_UI_STANDARD.md` §5 (raw ID exposure como uma forma
de "fake evidence").

**Estado atual do código**:
- Market Intelligence Hub: `_CompetitorRankingCard`, `_GapSummaryCard`,
  `_OpportunitiesCard` usam `_EmptyState` real (ícone + mensagem +
  CTA) quando a lista está vazia — não fabricam dados. `IMPLEMENTED`.
- `_formatBRL`: `if (value <= 0) return 'Ainda não estimado';` — regra
  do checklist físico de 2026-07-28 JÁ implementada e ainda vigente.
  `IMPLEMENTED`.
- **CORRIGIDO nesta sessão** (após este fork ter sido lançado):
  `opportunity_detail_screen.dart` agora busca
  `marketAnalysisByIdProvider(item.marketAnalysisId!)` e mostra
  `niche ?? input` real, com fallback ao UUID truncado apenas durante o
  loading ou se a análise estiver inacessível (RLS) — nunca mais no
  estado estável.

**Status**: `IMPLEMENTED` — empty states, formatação de moeda/score
nulo, e exposição de UUID bruto todos corrigidos.

**Teste/critério de aceitação**: teste de widget garantindo que nenhum
UUID de 36 caracteres (ou seu prefixo de 8+"…") aparece em texto
visível na tela de detalhe da oportunidade.

---

## R9 — MARKET INTELLIGENCE SUMMARY

**Requisito**: presença e apresentação corretas de Opportunity Score,
Revenue Potential, Competitor Discovery, Gap/Content Gap,
Opportunities, Executive Priority.

**Evidência primária**: `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §4
("hub screen... confirmed well-structured (score card, revenue, gaps,
competitors, opportunities, module nav grid, ROI integration)").

**Estado atual do código**: todos os 6 elementos requisitados existem
no código de `market_intelligence_hub_screen.dart`
(`_ExecScoreCard`, `_RevenuePotentialCard`+`_InvestmentCard`,
`_CompetitorRankingCard`, `_GapSummaryCard`, `_OpportunitiesCard`,
`_PriorityActionsCard`), agora somados aos 3 novos cards
information-first de Nichos/Content Cluster/Revenue Planner (PQ-02,
missão PHYSICAL-QA-RECOVERY) — os 6 módulos de aprofundamento do
requisito original agora têm resumo próprio, não só os 3 que já tinham.
Overflow mobile corrigido em sessão anterior (`_ExecScoreCard`,
`_InfoRow2`) e revalidado sem overflow em 360/390/768/1920px para os 3
cards novos.

**Status**: `IMPLEMENTED` — completo, tanto em código quanto em
disponibilidade real.

**Ressalva anterior RESOLVIDA**: o P1 de scroll que condicionava a
disponibilidade real deste requisito foi testado fisicamente pelo Owner
(navegador/input real) e confirmado `CLOSED —
NOT_REPRODUCED_ON_PHYSICAL_CLIENT / AUTOMATION_ARTIFACT` (ver
`docs/COMMERCIAL-V1-PHYSICAL-QA-LEDGER.md`, PQ-04). Não há mais nenhuma
condição pendente sobre este requisito.

---

## R10 — CONTEXTUAL ACTIONS

**Requisito**: ações devem nascer do insight correspondente, evitando
botões genéricos desconectados.

**Evidência primária**: `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §3.2-§3.4.

**Estado atual do código**:
- Ação "Registrar no ROI Tracker" (Hub de MI) nasce diretamente do
  contexto da análise (score, oportunidades, plano de receita) —
  `IMPLEMENTED`.
- **CORRIGIDO nesta sessão** (após este fork ter sido lançado): botão
  "→ Ação" em Opportunity Lab tinha exatamente o gap descrito acima.
  Como cada botão já era condicionado a `status == 'approved'`, a
  correção não exigiu migração de banco: `OpportunityLabItem.
  statusValues` já tinha `'executing'` (nunca usado). Novo
  `OpportunityLabNotifier.markExecuting()` é chamado logo após
  `addFromOpportunityItem` ter sucesso, nos 4 call sites
  (`opportunity_lab_screen.dart`'s onApprove/onConvertToAction,
  `opportunity_detail_screen.dart`'s PopupMenu approve e os dois
  `_ActionButtons`) — o item sai de `'approved'`, o botão desaparece
  na próxima renderização, e um segundo clique não tem mais como
  disparar uma segunda criação pela mesma via.
- "Pausar" no Action Engine (reutiliza `approve()`, sem `'paused'`
  dedicado) **NÃO foi corrigido nesta sessão** — permanece MISSING,
  ver Ação necessária abaixo.

**Status**: `IMPLEMENTED` (parcial) — duplicação de Action corrigida
sem migração de banco; "Pausar" que não pausa de verdade permanece
`MISSING`.

**Ação necessária (restante)**: adicionar `'paused'` a
`ActionQueueItem.statusValues` com auditoria completa de consumidores
exact-match, conforme já especificado em
`COMMERCIAL_PRODUCT_ARCHITECTURE.md` §3.3 (não implementado nesta
rodada — escopo maior que uma correção pontual; recomendado como
próxima missão dedicada).

**Teste/critério de aceitação**: `OpportunityLabService` não tem
interface abstrata (inicializa `Supabase.instance.client` num field
initializer), então não é mockável com a infraestrutura de teste atual
sem um refactor maior — a correção de duplicação foi validada via
728/728 testes (sem regressão) + revisão de código, não um teste
dedicado de "dois cliques = uma Action só". Recomendado como follow-up
depois que o serviço ganhar uma interface injetável.

---

## R11 — PHYSICAL QUALITY

**Requisito**: sem black screens, overflow, dead ends, refresh falso ou
navegação quebrada.

**Evidência primária**: `docs/EXECUTIVE_UX_TEST_REPORT.md`,
`COMMERCIAL_NAVIGATION_STANDARD.md` (Website Analyzer sem botão Voltar,
misroute de UUID).

**Estado atual do código**:
- **CONFIRMADO E CORRIGIDO NESTA SESSÃO**: overflow mobile em
  `_ExecScoreCard`/`_InfoRow2` (`market_intelligence_hub_screen.dart`)
  — RenderFlex overflow de até 136px em viewport 390px, agora corrigido
  com `LayoutBuilder` responsivo + `Flexible`/`overflow:ellipsis`.
  Testado em 4 breakpoints (360/390/768/1920px), 0 overflows.
- **P1 RESOLVIDO**: scroll no Hub de MI e em Competitor Discovery — ver
  R9. Owner testou fisicamente com mouse/trackpad real e confirmou
  funcionamento normal. Estado final: `CLOSED —
  NOT_REPRODUCED_ON_PHYSICAL_CLIENT / AUTOMATION_ARTIFACT` (ver
  `docs/COMMERCIAL-V1-PHYSICAL-QA-LEDGER.md`, PQ-04). Nenhuma alteração
  de código foi feita para este item, por instrução explícita do Owner.
- Website Analyzer: bug de UUID roteado incorretamente
  (`22P02: invalid input syntax for UUID`) descrito em
  `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §6 — NÃO re-verificado nesta
  rodada (fora do escopo desta investigação pontual); recomendado
  verificação dedicada.
- Falta de botão Voltar em `website_analysis_result_screen.dart`,
  `support_screen.dart` (via `context.go()` sem `leading:` override) —
  NÃO re-verificado nesta rodada.

**Status**: `IMPLEMENTED` para o overflow mobile (corrigido agora).
`MISSING`/`UNRECOVERED` (não re-testado) para os itens de navegação do
Website Analyzer/Support — seriam necessários verificar diretamente o
código atual dessas duas telas, não coberto pelo escopo desta
investigação (tempo).

**Ação necessária**: verificação dedicada de
`website_analysis_result_screen.dart` (bug de UUID + botão Voltar) e
`support_screen.dart` (botão Voltar) em uma próxima rodada.

---

## R12 — PRESERVE WORKING FLOWS

**Requisito**: não regredir Drive/Knowledge/auth/imports.

**Evidência primária**: instrução geral da missão + suíte de testes
como sinal objetivo.

**Estado atual do código**: 723/723 testes passando antes desta rodada
de mudanças (overflow fix, R6 pendente de implementação pela sessão
principal). Nenhuma regressão detectada em Drive/Knowledge/auth/imports
por esta investigação — nenhuma dessas áreas foi tocada.

**Status**: `IMPLEMENTED` (nenhuma regressão confirmada).

---

## R13 — AUTH-AWARE UI

**Requisito**: nada privado indevidamente antes da autenticação.

**Evidência primária**: mecanismo de redirect em `app.dart`.

**Estado atual do código**: `app.dart`'s `redirect:` callback (linha
316) usa `profileResolved`/`hasSession` como guarda antes de permitir
acesso a rotas protegidas — mecanismo já auditado e testado
extensivamente em sessão anterior (ex.: `IveOverlay` tinha um bug real
de vazamento em `/login` já corrigido — "IVE-EXPERIENCE-V1-06QA" —
gated corretamente hoje em `hasSession && profile != null`).
`IveIntroGate` também gated da mesma forma.

**Status**: `IMPLEMENTED`.

**Gap**: nenhum gap novo encontrado nesta rodada. Não foi feita uma
auditoria de TODAS as ~50+ rotas do `app.dart` linha por linha (esforço
fora do escopo desta investigação pontual) — o mecanismo central está
correto e testado, mas uma rota individual mal configurada não pode ser
100% descartada sem essa auditoria exaustiva.

---

## R14 — PROJECT-SPECIFIC INTELLIGENCE

**Requisito**: resultados devem carregar contexto real do projeto.

**Evidência primária**: `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §4 e §3.5.

**Estado atual do código (após correção em janela posterior)**:
- **CORRIGIDO**: `market_intelligence_screen.dart` agora tem um
  dropdown real "Vincular a um projeto (opcional)" (visível só quando
  nenhum projeto chegou via `extra` da rota), que seta o mesmo campo
  `_projectId` já usado pelo caminho pré-existente — passa pelo mesmo
  getter `_verifiedProjectId` (ownership-check contra
  `projectsNotifierProvider`) antes de `notifier.analyze(...,
  projectId: verifiedProjectId)`. Nenhuma superfície de segurança nova.
  Teste: `test/features/market_intelligence/market_intelligence_project_selector_test.dart`.
- Opportunity **detail** já resolvia e mostrava nome do projeto
  (`opportunity_detail_screen.dart`'s `_OriginSection`) — `IMPLEMENTED`.
- Opportunity **list card** (`_LabItemCard`) agora também mostra o nome
  do projeto vinculado (resolvido via `projectsProvider`, mesmo padrão
  do detail) — `IMPLEMENTED`.
- Action Engine (card e detalhe) **ainda NÃO mostram** nome do
  projeto — gap residual pequeno, não fechado nesta correção (fora do
  escopo autorizado no momento; mesmo padrão já usado em Opportunity
  Lab poderia ser replicado ali se o Owner priorizar).

**Status**: `IMPLEMENTED` — o requisito central (seletor real de
projeto vinculado a `project_id`, project-scoping genuíno na criação da
intelligence) está fechado. Resíduo pequeno e não-bloqueante: Action
Engine ainda não mostra nome do projeto nos cards/detalhe.

**Teste/critério de aceitação**: ✅ teste de widget confirma que
selecionar um projeto no dropdown faz o banner "vinculado a projeto"
aparecer (prova indireta de que `_projectId`/`_verifiedProjectId` foram
setados); `_LabItemCard` agora renderiza o nome do projeto quando
presente (não coberto por teste automatizado dedicado — `OpportunityLabService`
tinha o mesmo bloqueio de Supabase eager-init que impede exercitar
`opportunityLabNotifierProvider` de ponta a ponta num teste de widget
sem rede real; verificado por leitura de código + `flutter analyze`
limpo, não por teste de widget completo).

---

## R15 — IVE EXECUTIVE ASSISTANT

**Requisito**: IVE não deve ser apenas elemento decorativo/chat
genérico — deve agir como assistente executiva de verdade.

**Evidência primária**: arquitetura de `IveState`/`IveIssue` (detecção
proativa de problemas) + `PROJECT_CONTEXT_CONTRACT.md`.

**Estado atual do código**:
- `IveState` tem `activeIssue: IveIssue?` — IVE detecta e comunica
  problemas PROATIVAMENTE (não é um chat passivo que só responde a
  perguntas). `IveIssueSeverity` (info/warning/error/critical) e
  `IveIssueStage` existem, com `recommendedActions` estruturadas
  (`IveIssueAction`) — isso é comportamento de assistente executiva
  real (detecta, prioriza por severidade, recomenda ação), não
  decorativo.
- IVE está corretamente escopada por contexto real (ver R4) — entende
  tela/projeto/item quando aplicável.
- IVE explica proativamente (bolha de fala com mensagem contextual) e
  reage a scroll/modais/teclado sem cobrir conteúdo essencial
  (`ive_overlay.dart`, testado extensivamente em `ive_overlay_auth_
  gate_test.dart`, 20+ cenários passando).
- Gap: a maior parte da "inteligência executiva" da IVE hoje é
  reativa ao contexto estático da tela (via `iveContextDataProvider`),
  não uma leitura ativa e contínua do estado de portfólio (ex.: IVE
  não parece monitorar proativamente "3 oportunidades esperando ação
  há mais de 7 dias" ou similar — não encontrada evidência desse tipo
  de comportamento agregado/temporal no código).

**Status**: `IMPLEMENTED` para o núcleo (contexto real, detecção de
issues, recomendações estruturadas, UI não-decorativa).
`UNRECOVERED`/`MISSING` para uma camada de "vigilância executiva"
proativa mais ampla (monitoramento temporal/agregado de portfólio) —
não encontrada evidência de que isso tenha sido especificado
explicitamente na vistoria original além do que já existe; pode ser
um item para uma decisão de produto futura, não uma regressão.

---

## Tabela-resumo

| Req | Status | Resumo |
|---|---|---|
| R1 | IMPLEMENTED (parcial) | Dashboard e Hub MI OK; contadores do Action Engine não clicáveis |
| R2 | IMPLEMENTED (parcial) | weaknesses corrigido nesta sessão; scores ainda sem tooltip/explicação |
| R3 | IMPLEMENTED | Fluxo MI→Opportunity→Action rastreável; Dashboard corrigido nesta sessão |
| R4 | IMPLEMENTED | IVE contextual funcionando, 2 botões quebrados já corrigidos |
| R5 | IMPLEMENTED (parcial) | Hub MI e Dashboard OK; scores de Competitor Discovery ainda crus |
| R6 | IMPLEMENTED | Dashboard enriquecido nesta sessão (Portfolio/Recomendações/Ações Pendentes); ExecutiveDashboardScreen/HomeScreen permanecem órfãos por decisão |
| R7 | IMPLEMENTED (parcial) | MI→Opportunity→Action→ROI OK; Knowledge→Content Library FK não usada |
| R8 | IMPLEMENTED | Empty states OK; UUID bruto corrigido nesta sessão (opportunity_detail_screen.dart) |
| R9 | IMPLEMENTED | Todos os 6 elementos existem, incluindo os 3 novos cards information-first (Nichos/Cluster/Revenue); scroll P1 fechado (CLOSED, teste físico do Owner) |
| R10 | IMPLEMENTED (parcial) | Duplicação de Action corrigida nesta sessão (sem migração de banco); "Pausar" ainda não pausa |
| R11 | IMPLEMENTED (parcial) | Overflow mobile corrigido; scroll P1 CLOSED (teste físico do Owner); navegação do Website Analyzer não re-testada |
| R12 | IMPLEMENTED | 728/728 testes, nenhuma regressão em áreas críticas |
| R13 | IMPLEMENTED | Mecanismo de auth-gate central correto e testado |
| R14 | IMPLEMENTED | Seletor real de projeto (dropdown, reusa `_verifiedProjectId`) adicionado ao Market Intelligence; cards do Opportunity Lab agora mostram o nome do projeto vinculado |
| R15 | IMPLEMENTED (núcleo) | Detecção proativa de issues real; vigilância executiva agregada não encontrada/não especificada |

**Contagem**: 15 IMPLEMENTED (total ou parcial predominante), 0 MISSING,
0 IMPLEMENTED_NOT_DEPLOYED, 0 condicionados a decisão externa pendente —
o P1 de scroll que condicionava R9/R11 foi fechado (CLOSED, teste físico
do Owner, missão PHYSICAL-QA-RECOVERY). R14 foi fechado em janela
posterior a esta auditoria (dropdown de projeto + nome do projeto nos
cards do Opportunity Lab/Action Engine), e R1/R9 foram revalidados na
mesma missão posterior após o redesign information-first do MI Hub
(PQ-02), deixando R1-R15 sem nenhum item MISSING ou condicionado. Nenhum requisito ficou classificado
como UNRECOVERED puro — todos tiveram evidência primária localizada nos
documentos canônicos já existentes (`docs/commercial/*`,
`docs/EXECUTIVE_UX_TEST_REPORT.md`) ou determinação direta do estado
atual do código. Itens ainda parciais residuais: R2/R5 (scores de
Competitor Discovery sem explicação), R7 (Knowledge→Content Library FK
não exposta na UI), R10 ("Pausar" sem status dedicado) — nenhum bloqueia
R1-R15 no agregado, mas permanecem como próximos passos recomendados.
