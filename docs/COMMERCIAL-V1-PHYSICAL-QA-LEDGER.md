# COMMERCIAL V1 — PHYSICAL QA LEDGER

Histórico de defeitos encontrados por teste FÍSICO do Owner em produção
(não por análise estática/automação). Regra deste documento: **nunca
apagar um achado depois de corrigido** — mover para "Fechados" com a
evidência de correção, não remover a linha. Evidência física tem
precedência sobre conclusões baseadas somente em análise estática/testes
(ver `docs/COMMERCIAL-V1-PHYSICAL-UX-BASELINE.md` para o histórico
anterior de R1-R15).

## Abertos

Nenhum no momento desta atualização (2026-09-29, missão COMMERCIAL V1
PHYSICAL QA RECOVERY + UX + I18N + FREE VALUE GATE).

## Fechados

### PQ-01 — MIXED LANGUAGE

**Achado físico**: produção em PT mostrava strings em inglês em Gap
Analysis, Content Cluster, Revenue Planner, e os valores
ASPIRATIONAL/DIRECT/INDIRECT (ver PQ-05).

**Causa raiz**: duas classes de defeito que nenhum grep estático anterior
pegava — (1) `analysisLabel` hardcoded passado para o diálogo de
confirmação de IA em 9 pontos (metade em inglês vazando pro PT, metade em
português vazando pro EN), incluindo o chat ambiente da IVE usado em
TODAS as telas; (2) `miGapTitle`/`miClusterTitle`/`miRevenueTitle` tinham
o valor em inglês copiado também na entrada PT do `.arb`. Ver
`docs/COMMERCIAL-V1-LOCALIZATION-LEDGER.md` para o detalhamento completo
com file:line de cada correção.

**Status**: CLOSED. Corrigido nesta missão, verificado por
`flutter analyze` (0 erros) e suíte de testes completa.

### PQ-02 — MARKET INTELLIGENCE GIANT CARDS

**Achado físico**: Hub de Market Intelligence com cards grandes/atalhos
mostrando só ícone+nome para Concorrentes, Gap Analysis, Oportunidades,
Nichos, Content Cluster, Revenue Planner.

**Causa raiz**: Concorrentes/Gap Analysis/Oportunidades já tinham cards
information-first reais (`_CompetitorRankingCard`/`_GapSummaryCard`/
`_OpportunitiesCard`, com tabela de dados reais + estado vazio explícito).
Nichos/Content Cluster/Revenue Planner não tinham NENHUM card dedicado —
só o `_ModuleNavGrid` genérico (ícone+label, grid 3 colunas), exatamente
o padrão "giant/low-info" que o Owner reportou.

**Correção**: 3 cards novos (`_NicheSummaryCard`, `_ContentClusterSummaryCard`,
`_RevenuePlannerSummaryCard`), mesmo padrão estrutural dos 3 já existentes
(header+view-all, loading, empty state explícito, dados reais — nunca
fabricados). `_ModuleNavGrid` removido (redundante, todos os 6 módulos já
têm CTA próprio). Testado sem overflow em 360/390/768/1920px.

**Status**: CLOSED. Corrigido nesta missão, verificado por
`flutter test test/features/market_intelligence/` (13/13 passando) e
`flutter analyze` (0 erros).

### PQ-03 — FREE QUOTA (5 → 15)

**Decisão do Owner**: FREE 5 → 15 análises de IA/mês, para permitir uma
jornada de valor significativa antes do upgrade.

**Implementação server-side (fonte autoritativa)**:
- `supabase/migrations/20261014000000_free_quota_15.sql` — `ALTER COLUMN
  monthly_limit SET DEFAULT 15` + backfill (`UPDATE ... WHERE role='free'
  AND monthly_limit=5`, escopo estrito, nunca toca pro/premium/beta_tester/
  admin) + `CREATE OR REPLACE FUNCTION prevent_self_privilege_escalation()`
  com o literal `5` trocado por `15` (achado crítico: sem esse segundo
  fix, TODO novo cadastro quebraria — `handle_new_user()` insere só
  `(id, email)`, herdando o novo default de 15, que não bateria mais com
  o "safe default" hardcoded do trigger de proteção contra escalação de
  privilégio).
- `supabase/functions/stripe-webhook/index.ts`'s `FREE_ROLE_LIMIT`: 5 → 15
  (usado ao reverter uma assinatura cancelada para FREE). 17/17 testes
  Deno passando após a mudança.
- `lib/core/constants/app_constants.dart`'s `planLimits['free']`: 5 → 15.
  **Achado bônus durante a auditoria**: `planLimits['pro']` também estava
  desatualizado (100 em vez dos 300 reais) — mesmo mapa, mesma causa raiz
  (usado por `ProfileService.updateRole()`, o caminho de troca manual de
  papel pelo admin, que grava `monthly_limit` diretamente a partir deste
  mapa cliente). Ambos corrigidos juntos, com teste novo
  (`test/core/constants/app_constants_test.dart`) pinando os 5 valores.
- UI (diálogo de confirmação de IA, FAQ de upgrade, card de uso do
  Dashboard): já eram 100% dinâmicos via `{limit}`/`{remaining}` — nenhuma
  mudança de código necessária, vão refletir 15 automaticamente assim que
  a migração for aplicada.
- Inventário de operações que consomem quota (16 Edge Functions via
  `reserveQuota()`): analyze-website, competitor-discovery,
  content-cluster, context-copilot, decision-simulator, extract-knowledge,
  gap-analysis, generate-campaign, generate-project-actions,
  generate-project-opportunities, generate-strategy, improve-post,
  market-analysis, niche-discovery, opportunity-discovery,
  revenue-planner. Navegação/leitura (queries diretas do Flutter ao
  Supabase, sem passar por Edge Function) nunca consome quota — nenhuma
  mudança necessária, comportamento já correto.

**Status**: IMPLEMENTED (migração é LAB até ser aplicada/rehearsed —
ver `supabase/migration_manifest.tsv` — aplicação em produção é uma
etapa separada, fora do escopo desta sessão de implementação de código;
ver política de proteção de produção). PRO (300) e admin (99999)
verificados intocados.

### PQ-04 — SCROLL P1

**Resultado do teste físico do Owner**: scroll funciona normalmente com
mouse/trackpad real.

**Status**: CLOSED. `NOT_REPRODUCED_ON_PHYSICAL_CLIENT` /
`AUTOMATION_ARTIFACT`. Nenhuma alteração em Flutter/CanvasKit/scroll foi
feita nesta missão, conforme instrução explícita do Owner de não reabrir
sem nova evidência física.

### PQ-05 — COMPETITOR TYPE LOCALIZATION

**Achado físico**: tela de Concorrentes em PT mostrava ASPIRATIONAL/
DIRECT/INDIRECT (valores canônicos crus, não traduzidos).

**Causa raiz**: `_CompetitorCard` renderizava `competitor.type
.toUpperCase()` diretamente — o mesmo valor persistido no banco, sem
passar por nenhuma função de mapeamento de label.

**Correção**: `competitorTypeLabel()` (novo,
`lib/features/market_intelligence/competitor_type_labels.dart`), mesmo
padrão de `opportunityTypeLabel()`/`actionEngineTypeLabel()`. Valores
canônicos do banco (`'direct'`/`'indirect'`/`'aspirational'`) preservados
sem alteração — só a camada de apresentação mudou. PT: Direto/Indireto/
Aspiracional. EN: Direct/Indirect/Aspirational. Testado com renderização
real da tela em ambos os locales
(`test/features/market_intelligence/competitor_discovery_locale_test.dart`).

Durante a mesma investigação, a mesma classe de defeito foi encontrada e
corrigida em mais 2 lugares que o achado físico original não cobria:
`ActionQueueItem.actionType` (`action_detail_screen.dart`'s `_TypeBadge`)
e `OpportunityLabItem.status` no detail screen de Opportunity Lab
(`opportunity_detail_screen.dart`'s `_StatusBadge` — a lista já usava a
função correta, só o detail não).

**Status**: CLOSED.

## Novos PQ-* encontrados durante esta missão (não reportados fisicamente, mesma classe de defeito)

Registrados aqui por transparência, não por exigirem uma nova rodada de
teste físico — são a mesma causa raiz de PQ-01/PQ-05 (valor canônico
renderizado cru / `analysisLabel` hardcoded), encontrados pela auditoria
dirigida por essa classe de defeito, não por nova evidência física
independente:

- **PQ-06** — `action_detail_screen.dart`'s `_TypeBadge` (`actionType` cru). CLOSED.
- **PQ-07** — `opportunity_detail_screen.dart`'s `_StatusBadge` (`status` cru no detail, lista já correta). CLOSED.
- **PQ-08** — `knowledge_analysis_screen.dart` com 0% de infraestrutura `AppLocalizations` (29 strings hardcoded no total, nunca antes auditado). CLOSED.
- **PQ-09** — `strategy_screen.dart` com 0% de infraestrutura `AppLocalizations` (~35 strings). CLOSED.
