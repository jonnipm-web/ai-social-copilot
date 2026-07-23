# Project Analysis Hotfix Report

**Data:** 2026-07-23
**Prioridade:** P0 / P1

---

```
RELATORIO DE HOTFIX - ANALISE DE PROJETOS E SCORES
====================================================

DATA: 2026-07-23
REFERENCIA: PART A (A1-A15) da missao de hotfix

-------------------------------------------------
DIAGNOSTICO GERAL
-------------------------------------------------

PROBLEMA CENTRAL:
  Projetos sem analise de mercado vinculada tem ecosystem_score
  calculado via fallback com dados imprecisos:
  - opportunity_score derivado de priority_score (arbitrario)
  - market_score = 0 (25% do ecosystem_score zerado)
  - roi_score = 0 se sem ROI metrics (20% zerado)
  - Resultado: score pode ser 0-30 mesmo para projetos viáveis

IMPACTO:
  - Recomendacoes PAUSAR ou ANALISE INCOMPLETA para projetos viáveis
  - Usuario pode tomar decisoes erradas com base em scores nao confiaveis
  - Dashboard de ecossistema impreciso

-------------------------------------------------
ROOT CAUSE ANALYSIS (A2)
-------------------------------------------------

CAUSA A - AutoBootstrap nao rodou:
  - providers/auto_bootstrap_provider.dart detecta projetos sem dados
  - Pode nao ter rodado se usuario nao abriu a tela principal apos criar projeto
  - Ou se a edge function falhou silenciosamente (timeout)

CAUSA B - Projeto sem URL/descricao:
  - market-analysis e generate-project-opportunities precisam de
    nome + descricao/url para gerar analise válida
  - Projetos criados sem esses campos nao geram analise útil

CAUSA C - FKs desvinculadas:
  - project.market_analysis_id pode ser null mesmo com analise existente
  - Inconsistencia historica de FK bidirecionais

CAUSA D - Backfill incompleto de project_id:
  - Migrations 013-018 fizeram backfill de project_id
  - Registros muito antigos podem ter ficado sem project_id

-------------------------------------------------
INVENTORY QUERY (A1) - USAR NO SUPABASE SQL EDITOR
-------------------------------------------------

SELECT
  p.id,
  p.name,
  p.user_id,
  p.created_at::date AS created,
  (SELECT COUNT(*) FROM market_analyses WHERE project_id = p.id) AS analyses,
  (SELECT COUNT(*) FROM opportunity_lab WHERE project_id = p.id) AS lab_items,
  (SELECT COUNT(*) FROM action_queue WHERE project_id = p.id) AS actions,
  (SELECT COUNT(*) FROM roi_metrics WHERE project_id = p.id) AS roi_entries,
  CASE
    WHEN (SELECT COUNT(*) FROM market_analyses WHERE project_id = p.id) > 0
      AND (SELECT COUNT(*) FROM opportunity_lab WHERE project_id = p.id) > 0
      AND (SELECT COUNT(*) FROM action_queue WHERE project_id = p.id) > 0
    THEN 'COMPLETO'
    WHEN (SELECT COUNT(*) FROM market_analyses WHERE project_id = p.id) > 0
      OR (SELECT COUNT(*) FROM opportunity_lab WHERE project_id = p.id) > 0
    THEN 'PARCIAL'
    ELSE 'SEM ANALISE'
  END AS status
FROM projects p
ORDER BY status DESC, p.created_at ASC;

-------------------------------------------------
SCORES CONFIAVEIS vs NAO CONFIAVEIS (A4-A5)
-------------------------------------------------

SCORE CONFIAVEL - todos os criterios atendidos:
  has_enough_data = true
  market_score > 0
  opportunity_score derivado de market_analysis
  roi_score > 0 OU revenue_plan presente

SCORE NAO CONFIAVEL - qualquer criterio faltando:
  has_enough_data = false → ANALISE INCOMPLETA
  market_score = 0 → 25% do ecosystem_score zerado
  opportunity_score < 10 via fallback de project fields
  roi_score = 0 sem revenue_plan

DETECCAO NO CODIGO:
  EcosystemScore.hasEnoughData → bool
  EcosystemScore.marketScore → int (0 = sem analise)
  Confidence proposta: HIGH/MEDIUM/LOW/INSUFFICIENT

-------------------------------------------------
FORMULA DE SCORING ATUAL (A9 - VERSAO 1.0)
-------------------------------------------------

ecosystem_score = (
  opportunity_score * 0.25 +  ← 25% oportunidade
  strategic_fit     * 0.25 +  ← 25% fit estrategico
  synergy_score     * 0.20 +  ← 20% sinergia
  roi_score         * 0.20 +  ← 20% ROI
  momentum_score    * 0.10    ← 10% momentum
).clamp(0, 100)

Arquivo: lib/data/services/ecosystem_intelligence_service.dart
Metodo: _weighted()
Versao documentada: SCORING_METHODOLOGY.md

-------------------------------------------------
PROCESSO DE BACKFILL SEGURO (A3)
-------------------------------------------------

PASSO 1: Executar query de inventario acima
PASSO 2: Para cada projeto SEM ANALISE com name+description preenchidos:
  - Abrir o projeto na UI → AutoBootstrap deve detectar e rodar
  - OU disparar manualmente via BootstrapNotifier.bootstrap(projectId)
PASSO 3: Verificar que has_enough_data = true no EcosystemScore
PASSO 4: Invalidar ecosystemScoresProvider (automatico via Riverpod)
PASSO 5: Verificar scores no dashboard

RESTRICAO: Nao criar migration para backfill - apenas DML via UI ou funcoes

-------------------------------------------------
MELHORIAS PROPOSTAS (A6-A8) - NAO IMPLEMENTADAS
-------------------------------------------------

A6 - SCORE EXPLICAVEL:
  Expor ScoreBreakdown existente na UI de projeto
  Mostrar componentes individuais do score
  Status: ScoreBreakdown ja existe, falta exposicao na UI

A7 - SEPARACAO SCORE/CONFIANCA:
  Adicionar campo confidence ao EcosystemScore
  HIGH: todos os dados presentes
  MEDIUM: dados parciais
  LOW: apenas lab_items sem analise
  INSUFFICIENT: has_enough_data = false
  Status: PROPOSTO, nao implementado

A8 - COMPLETUDE DE DADOS:
  Metrica data_completeness (0-100%)
  Pesos: analysis*30% + revenue_plan*20% + lab*25% + actions*15% + roi*10%
  Status: PROPOSTO, nao implementado

-------------------------------------------------
GOLDEN TEST SET (A11) - CASOS DE REFERENCIA
-------------------------------------------------

CASO 1 - Score alto confiavel:
  Projeto com: market_analysis + 3 lab_items + 5 actions + roi_metrics
  Esperado: ecosystem_score >= 60, has_enough_data=true, market_score>0

CASO 2 - Score medio com dados parciais:
  Projeto com: apenas lab_items (sem market_analysis)
  Esperado: has_enough_data=true, market_score via lab, confidence=LOW

CASO 3 - Score zero sem dados:
  Projeto novo sem analysis/lab/actions
  Esperado: has_enough_data=false, recommendation=ANALISE INCOMPLETA

CASO 4 - Score derivado de fallback:
  Projeto com priority_score=50, revenue_potential=10000, sem analise
  Esperado: opportunity_score calculado via fallback (approx 25-35)
  Identificar: market_score=0

-------------------------------------------------
INTEGRACAO IVE (A13)
-------------------------------------------------

A IVE ja tem acesso a EcosystemScore via IveContextData:
  - ecosystemScores: lista de scores por projeto
  - activeProjectScore: score do projeto ativo
  - sourceLimitations: limitacoes de dados identificadas

A IVE pode explicar scores quando o usuario perguntar:
  - "context-copilot" acessa o contexto no payload
  - "ive-agent-runner" tem acesso ao score_engine das ferramentas
  - Nao requer nova implementacao - apenas perguntar a IVE

-------------------------------------------------
UI DE CONFIABILIDADE (A14) - PROPOSTO
-------------------------------------------------

Indicadores visuais necessarios na tela de projeto:
  - Badge "Score Estimado" quando has_enough_data=false
  - Badge "Dados Insuficientes" quando market_score=0
  - Barra de completude (data_completeness %)
  - Botao "Analisar Projeto" quando sem dados

Status: NAO IMPLEMENTADO - requer trabalho de UI

-------------------------------------------------
ESTADOS CLAROS DE ANALISE (A15) - PROPOSTO
-------------------------------------------------

Estado atual do projeto (para IVE e UI):
  ANALISADO:   has_enough_data=true + market_score>0
  PARCIAL:     has_enough_data=true mas market_score=0
  PENDENTE:    nenhum dado, bootstrap nao rodou
  ERRO:        bootstrap falhou (edge function error)

Status: NAO IMPLEMENTADO - requer campo status na UI

-------------------------------------------------
VEREDICTO
-------------------------------------------------

VEREDICTO: ANALISE DOCUMENTADA - EXECUCAO PENDENTE

IMPLEMENTADO NESTA SESSAO:
  - Documentacao completa do problema e solucoes (A1-A15)
  - Formula de scoring documentada (A9 - SCORING_METHODOLOGY.md)
  - Query de inventario pronta para execucao (A1)
  - Processo de backfill seguro definido (A3)

PENDENTE DE IMPLEMENTACAO:
  - A6: UI de score explicavel (requer dev Flutter)
  - A7: Campo confidence no EcosystemScore (requer dev)
  - A8: Metrica data_completeness (requer dev)
  - A11: Golden test set formal (requer test suite)
  - A14: Indicadores visuais na UI (requer dev Flutter)
  - A15: Estados claros de analise (requer dev Flutter)

PROXIMO PASSO:
  1. Executar query de inventario no Supabase SQL Editor
  2. Identificar projetos SEM ANALISE
  3. Para cada projeto: rodar AutoBootstrap ou analisar manualmente
  4. Verificar melhora nos scores
  5. Com dados confiaveis: implementar A6-A8 (score explicavel)
```
