# Auditoria — Análise de Projetos e Confiabilidade de Scores

**Data:** 2026-07-23
**Prioridade:** P0 / P1

---

## 1. Inventário (A1)

### Estrutura de Dados de um Projeto
Um projeto é considerado **com análise completa** quando tem:
- `market_analysis` vinculada (`project.market_analysis_id` ou `market_analysis.project_id = project.id`)
- `opportunity_lab` com pelo menos 1 item
- `action_queue` com pelo menos 1 item
- `revenue_plan` gerado

Um projeto é **sem análise** quando:
- Nenhum dos acima existe → `has_enough_data = false`
- `ecosystem_score` é calculado apenas com fallbacks de `priority_score` e `revenue_potential`

### Classificação de Estado
| Estado               | Critério                              | Recomendação UI     |
|----------------------|---------------------------------------|---------------------|
| Completo             | analysis + lab + actions              | ESCALAR/ACELERAR/etc.|
| Parcial              | apenas lab OU apenas actions          | Score é estimado     |
| Incompleto           | apenas project fields                 | ANÁLISE INCOMPLETA   |
| Novo                 | criado há menos de 7 dias, sem dados  | Aguardando análise   |

---

## 2. Causas de Projetos Sem Análise (A2)

### Causa A — AutoBootstrap não rodou
**Arquivo:** `providers/auto_bootstrap_provider.dart`
O `BootstrapNotifier` detecta projetos sem dados e chama as edge functions. Pode não ter rodado se:
- O usuário nunca abriu a tela principal após criar o projeto
- O AutoBootstrap falhou silenciosamente (edge function timeout)
- Feature flag `advisor_enabled` estava desativada

### Causa B — Projeto criado sem URL/descrição suficiente
As edge functions `market-analysis` e `generate-project-opportunities` precisam de `name` + `description`/`url`. Projetos com apenas `name` podem não gerar análise válida.

### Causa C — `market_analysis_id` desvinculado
O campo `project.market_analysis_id` pode ser null mesmo com uma `market_analysis` existente para o projeto (vinculada via `market_analysis.project_id`). O código usa ambas as FK directions — inconsistência pode causar não-detecção.

### Causa D — Dados de lab/actions sem `project_id`
Migrations 013–018 adicionaram `project_id` a várias tabelas e fizeram backfill. Registros anteriores às migrations podem ter `project_id = null`.

---

## 3. Processo de Backfill Seguro (A3)

**ATENÇÃO:** Backfill de análise NÃO deve ser feito via migration automática.

### Passo 1 — Identificar projetos sem dados
```sql
SELECT p.id, p.name, p.user_id,
  (SELECT COUNT(*) FROM market_analyses WHERE project_id = p.id) as analyses_count,
  (SELECT COUNT(*) FROM opportunity_lab WHERE project_id = p.id) as lab_count,
  (SELECT COUNT(*) FROM action_queue WHERE project_id = p.id) as actions_count
FROM projects p
ORDER BY analyses_count ASC, p.created_at DESC;
```

### Passo 2 — Reprocessar via AutoBootstrap
O caminho seguro é usar o `BootstrapNotifier` existente, que:
1. Chama `generate-project-opportunities` → 3 oportunidades
2. Chama `generate-project-actions` → 5 ações
3. Vincula tudo ao `project_id` correto

### Passo 3 — Verificar resultados
Após backfill, verificar que `has_enough_data = true` para os projetos reprocessados.

---

## 4. Auditoria de Scores (A4)

### Scores Confiáveis
Um score é **confiável** quando:
- `has_enough_data = true`
- `market_score > 0` (análise de mercado presente)
- `opportunity_score` NÃO derivado apenas de `priority_score`
- `roi_score > 0` (métricas de ROI ou revenue plan presente)

### Scores Não Confiáveis (A5)
Um score é **não confiável** quando qualquer condição:
- `market_score = 0`: sem análise de mercado → peso 25% do ecosystem_score zerado
- `roi_score = 0` sem revenue_plan: sem dados financeiros → peso 20% zerado
- `opportunity_score` < 20 com apenas fallback de project fields
- `ecosystem_score` calculado sem `has_enough_data`

### Detecção no Código
```dart
// EcosystemScore.hasEnoughData é calculado em:
bool _hasEnoughData(MarketAnalysis? analysis, RevenuePlan? plan,
    List<ActionQueueItem> actions, List<OpportunityLabItem> lab) =>
    analysis != null || plan != null || lab.isNotEmpty || actions.isNotEmpty;

// Para scores não confiáveis:
final isReliable = score.hasEnoughData && score.marketScore > 0;
```

---

## 5. Score Explicável (A6)

### Implementação Existente
`ScoreBreakdown` (em `lib/data/models/score_breakdown.dart`) e `intelligence_debug_provider.dart` já implementam explainability para o debug hub.

### Formato Proposto para UI
```dart
// Estrutura de score explicável
{
  "ecosystem_score": 67,
  "components": {
    "opportunity_score": {"value": 72, "weight": 0.25, "source": "market_analysis"},
    "strategic_fit":     {"value": 65, "weight": 0.25, "source": "calculated"},
    "synergy_score":     {"value": 60, "weight": 0.20, "source": "lab_items"},
    "roi_score":         {"value": 80, "weight": 0.20, "source": "roi_metrics"},
    "momentum_score":    {"value": 40, "weight": 0.10, "source": "recent_activity"}
  },
  "confidence": "HIGH",
  "has_enough_data": true,
  "missing_data": []
}
```

---

## 6. Score vs Confiança (A7)

Proposta de separação:
- **Score** (0–100): valor calculado pelas fórmulas atuais
- **Confidence** (HIGH/MEDIUM/LOW/INSUFFICIENT):
  - HIGH: `has_enough_data=true` + `market_score>0` + `roi_score>0`
  - MEDIUM: `has_enough_data=true` mas algum componente = 0
  - LOW: `has_enough_data=true` apenas via lab_items sem análise
  - INSUFFICIENT: `has_enough_data=false`

---

## 7. Completude de Dados (A8)

### Métrica Proposta
```
data_completeness = (
  (has_market_analysis ? 1 : 0) * 0.30 +
  (has_revenue_plan    ? 1 : 0) * 0.20 +
  (lab_count > 0       ? 1 : 0) * 0.25 +
  (action_count > 0    ? 1 : 0) * 0.15 +
  (roi_data            ? 1 : 0) * 0.10
) * 100
```

---

## 8. Recalcular Scores Apenas Após Correção (A10)

Sequência correta:
1. Inventariar projetos sem dados (A1)
2. Identificar causa (A2)
3. Corrigir causa (AutoBootstrap ou backfill manual)
4. Verificar que `has_enough_data = true`
5. Invalidar `ecosystemScoresProvider` → recalcula automaticamente via Riverpod
6. Exibir novo score com `confidence` atualizado

**NUNCA** recalcular com dados sintéticos ou valores padrão — só com dados reais.
