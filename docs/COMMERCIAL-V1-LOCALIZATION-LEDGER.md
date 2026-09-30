# COMMERCIAL V1 — LOCALIZATION LEDGER

Data: 2026-09-29 — criado durante a missão **COMMERCIAL V1 PHYSICAL QA
RECOVERY + UX + I18N + FREE VALUE GATE** (PQ-01/PQ-05), em resposta à
descoberta física do Owner de que produção em PT-BR mostrava strings em
inglês mesmo depois da sessão anterior ter declarado
`docs/COMMERCIAL-V1-PTEN-COVERAGE-MATRIX.md` como "27/28 telas 100%
localizadas". A causa raiz: aquele documento media **paridade de chaves
ARB** e **presença estática de `AppLocalizations.of(context)`**, não se o
valor efetivamente RENDERIZADO na tela é o texto localizado — uma tela
podia usar `AppLocalizations` para 90% do texto e ainda assim renderizar
um **valor canônico cru** (`competitor.type` → `"ASPIRATIONAL"`,
`analysisLabel: 'Gap Analysis'` hardcoded) sem que nenhum grep estático
pegasse isso. Este documento existe para nunca mais permitir essa
confusão: mede 4 métricas SEPARADAS (seção "Métricas de Cobertura"
abaixo), não uma.

## Achados desta missão (causa raiz)

Duas classes de defeito, ambas presentes em várias telas:

**Classe 1 — valor canônico renderizado cru.** Um campo do modelo de
dados guarda um valor estável em inglês (`'direct'`/`'indirect'`/
`'aspirational'`, `'task'`/`'opportunity'`) e a tela faz
`campo.toUpperCase()` ou `Text(campo)` direto, sem passar por uma função
de mapeamento `xxxLabel(canonical, l10n)`. Corrigido em:
- `Competitor.type` (`competitor_discovery_screen.dart`'s `_CompetitorCard`) — PQ-05, o achado físico original.
- `ActionQueueItem.actionType` (`action_detail_screen.dart`'s `_TypeBadge`) — achado nesta missão, mesma classe, nunca reportado fisicamente.
- `OpportunityLabItem.status` no **detail** screen (`opportunity_detail_screen.dart`'s `_StatusBadge`) — a lista já usava `opportunityStatusLabel()` corretamente (sessão anterior), mas o detail badge não; achado nesta missão.

**Classe 2 — `analysisLabel` hardcoded passado para o diálogo de
confirmação de IA.** `AiExecutionController.run()`/`.confirm()` recebe um
`analysisLabel` que aparece verbatim na frase `"X" vai consumir 1 das
suas análises mensais.` — 8 call sites tinham esse valor hardcoded, a
metade em inglês (vazando pro PT-BR: **PQ-01 exata**), a outra metade em
português (vazando pro EN, mesmo defeito, direção oposta):

| Arquivo | Antes | Depois |
|---|---|---|
| `gap_analysis_screen.dart` | `'Gap Analysis'` (EN hardcoded) | `l10n.miGapTitle` |
| `content_cluster_screen.dart` | `'Content Cluster'` (EN hardcoded) | `l10n.miClusterTitle` |
| `revenue_planner_screen.dart` | `'Revenue Planner'` (EN hardcoded) | `l10n.miRevenueTitle` |
| `competitor_discovery_screen.dart` | `'Descobrir Concorrentes'` (PT hardcoded) | `l10n.miCompetitorTitle` |
| `niche_discovery_screen.dart` | `'Descobrir Nichos'` (PT hardcoded) | `l10n.miNicheTitle` |
| `opportunity_discovery_screen.dart` | `'Descobrir Oportunidades'` (PT hardcoded) | `l10n.miOpportunityTitle` |
| `context_copilot_widget.dart` (chat ambiente da IVE, usado em TODAS as telas) | `'Perguntar à IVE'` (PT hardcoded) | `l10n.iveChatAskLabel` |
| `knowledge/screens/strategy_screen.dart` | `'Gerar Estratégia'` (PT hardcoded) | `l10n.knowledgeStrategyGenerateButton` |
| `knowledge/screens/knowledge_analysis_screen.dart` | `'Analisar com IA'` (PT hardcoded) | `l10n.knowledgeVaultAnalyzeWithAi` (chave reaproveitada) |

**Bônus, causa raiz idêntica à Classe 1, mas nos próprios TÍTULOS de
tela** (não só o `analysisLabel`): `miGapTitle`/`miClusterTitle`/
`miRevenueTitle` tinham o valor em **inglês copiado também na entrada
PT** do `.arb` (`"miGapTitle": "Gap Analysis"` dentro de `app_pt.arb`) —
alguém preencheu as duas chaves com o mesmo texto ao criar a tela, sem
traduzir. Corrigido usando os nomes já canônicos e corretos de
`lib/core/modules/module_registry.dart` (`namePt`/`nameEn` desses 3
módulos já estavam certos — só o `.arb` estava desatualizado):
`miGapTitle` PT → "Análise de Lacunas", `miClusterTitle` PT → "Cluster de
Conteúdo", `miRevenueTitle` PT → "Planejador de Receita".

## Descoberta grande, agora TOTALMENTE corrigida: `knowledge_analysis_screen.dart`

Ao investigar o `analysisLabel` hardcoded desse arquivo, descobri que a
tela inteira (1205 linhas) nunca importava `AppLocalizations` — 0% de
infraestrutura de i18n, apesar de nunca ter aparecido em nenhuma auditoria
anterior (não estava nem na lista de 24/28 telas do documento antigo).
Primeira passagem corrigiu o título da AppBar, os 2 tooltips, o
error/empty state, o botão "Analisar com IA" e os 2 snackbars de
"Copiado" (8 strings). Uma segunda passagem, na mesma missão, fechou o
gap restante: as 21 ocorrências de `_SectionTitle('...')`/
`_ChipSection('...', ...)` com strings PT hardcoded (Resumo, Pontuações
por Canal, Palavras-chave, Primárias/Secundárias/Long-tail, Dores/Desejos
da Audiência, Pilares de Conteúdo, Tópicos Principais, Ideias de
Posts/Campanhas/Artigos, Ângulos Comerciais, CTAs Sugeridas,
Oportunidades SEO/AdSense/Amazon KDP, Hotmart Engine, Shopify Engine,
Detalhes por Canal) — todas migradas para `knowledgeAnalysisSectionXxx`/
`knowledgeAnalysisKeywordsXxx` (21 novas chaves). `strategy_screen.dart`
(arquivo irmão, mesmo padrão) já tinha sido completamente localizado na
primeira passagem (~35 strings). Nenhum gap conhecido resta neste
arquivo.

## Métricas de Cobertura

- **ARB KEY COVERAGE**: 100% — `test/l10n/arb_parity_test.dart` (novo,
  nesta missão) garante isso automaticamente a partir de agora; antes não
  havia nenhuma verificação automática disso.
- **STATIC USER-FACING STRING COVERAGE** (grep por `Text('...'` literal,
  o que o documento antigo media): ~100% das superfícies comerciais
  auditadas nesta missão — ver `docs/COMMERCIAL-V1-PTEN-COVERAGE-MATRIX.md`,
  atualizado nesta missão. `knowledge_analysis_screen.dart`'s 21 strings
  residuais (ver acima) foram fechadas na mesma missão, não ficaram como
  gap.
- **RENDERED PT COVERAGE** / **RENDERED EN COVERAGE** (o valor que a UI
  efetivamente mostra em cada locale, incluindo campos de modelo
  renderizados crus — a métrica que faltava e que este documento existe
  para introduzir): **não é possível garantir exaustivamente sem rodar o
  app inteiro em ambos os idiomas e inspecionar cada tela fisicamente**
  (exatamente o que o Owner fez para achar PQ-01/PQ-05). O que ESTE
  documento garante é um spot-check dirigido pela classe de defeito
  encontrada: toda ocorrência de `.toUpperCase()` sobre um campo de
  modelo em `lib/` foi auditada (grep `\w+\.\w+\.toUpperCase\(\)`, 2
  ocorrências restantes: uma é o comentário desta própria correção, a
  outra é `intelligence_debug_hub_screen.dart` — ferramenta de debug
  interna, não superfície comercial, fora de escopo) e todo call site de
  `analysisLabel:` no app foi auditado (grep `analysisLabel:`, todos os
  hardcoded fechados). Isso cobre as duas classes de defeito conhecidas
  hoje — não há garantia de que não exista uma TERCEIRA classe ainda não
  descoberta. Recomendação mantida do documento anterior: nenhum
  substituto automatizado prova isso além de teste físico periódico.

## Testes de regressão adicionados

- `test/l10n/arb_parity_test.dart` — paridade estrutural de chaves.
- `test/features/market_intelligence/competitor_type_labels_test.dart` — exaustivo sobre `kCompetitorTypes`.
- `test/features/market_intelligence/competitor_discovery_locale_test.dart` — renderiza a tela REAL em PT e EN, prova que o badge mostra o label localizado, não o valor cru.
- `test/features/action_engine/action_engine_type_label_test.dart` — exaustivo sobre os `actionType` conhecidos.
- `test/features/opportunity_lab/opportunity_type_labels_test.dart` — já existia (sessão anterior), cobre `opportunityStatusLabel`/`opportunityTypeLabel`.

## Tabela de correções desta missão

| Tela | String | Fonte | PT esperado | EN esperado | Status |
|---|---|---|---|---|---|
| Competitor Discovery (card) | `competitor.type` badge | `competitorTypeLabel()` (novo) | Direto/Indireto/Aspiracional | Direct/Indirect/Aspirational | ✅ Corrigido |
| Gap/Cluster/Revenue/Competitor/Niche/Opportunity Discovery | `analysisLabel` do diálogo de confirmação | `l10n.miXxxTitle` | ver tabela acima | ver tabela acima | ✅ Corrigido |
| IVE chat ambiente | `analysisLabel` | `l10n.iveChatAskLabel` (novo) | Perguntar à IVE | Ask IVE | ✅ Corrigido |
| Knowledge → Strategy | tela inteira (~35 strings) | `knowledgeStrategyXxx` (novo, ~35 chaves) | — | — | ✅ Corrigido |
| Knowledge → Analysis | título/tooltips/erro/empty/snackbars (8 strings) | `knowledgeAnalysisXxx`/reaproveitadas | — | — | ✅ Corrigido (parcial — ver gap acima) |
| Action Engine (detail) | `actionType` badge | `actionEngineTypeLabel()` (novo) | Tarefa/Oportunidade | Task/Opportunity | ✅ Corrigido |
| Opportunity Lab (detail) | `status` badge | `opportunityStatusLabel()` (reaproveitada, já existia) | ver função existente | ver função existente | ✅ Corrigido |
| MI: 6 sub-módulos | empty state sem explicação do que a função analisa | `miXxxEmptyBody` (novo, 6 chaves) | ver .arb | ver .arb | ✅ Corrigido |
| `knowledge_analysis_screen.dart` | 21 `_SectionTitle`/`_ChipSection` hardcoded | `knowledgeAnalysisSectionXxx`/`knowledgeAnalysisKeywordsXxx` (novo, 21 chaves) | ver .arb | ver .arb | ✅ Corrigido |
