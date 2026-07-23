# Metodologia de Scoring — AI Social Copilot

**Versão:** 1.0
**Implementação:** `lib/data/services/ecosystem_intelligence_service.dart`
**Data:** 2026-07-23

---

## 1. Ecosystem Score (Score Principal)

Fórmula final — weighted sum de 5 dimensões:

```
ecosystem_score = (
  opportunity_score * 0.25 +
  strategic_fit     * 0.25 +
  synergy_score     * 0.20 +
  roi_score         * 0.20 +
  momentum_score    * 0.10
).clamp(0, 100)
```

---

## 2. Dimensões

### 2.1 Opportunity Score
Fonte de dados (por prioridade):
1. `market_analysis.opportunity_score` (se análise vinculada)
2. Média dos `opportunity_lab.final_score` + bônus por quantidade (max +10)
3. Fallback: `project.revenue_potential/2000*50 + priority_score*0.30 + bônus prazo`

### 2.2 Market Score
```
SE analysis != null:
  market_score = (
    score_growth        * 0.30 +
    score_monetization  * 0.25 +
    (100-score_competition) * 0.20 +
    score_seo           * 0.10 +
    opportunity_score   * 0.15
  )

SE apenas lab_items:
  market_score = (
    avg(market_score)   * 0.45 +
    avg(revenue_score)  * 0.30 +
    avg(strategic_fit)  * 0.25
  )

SEM dados: market_score = 0
```

### 2.3 Strategic Fit
```
strategic_fit = (
  market_score    * 0.35 +
  priority_score  * 0.20 +
  roi_score       * 0.25 +
  execution_score * 0.20
).clamp(0, 100)
```

### 2.4 Synergy Score
```
synergy = 0
+ 25   (se análise de mercado vinculada)
+ min(30, lab_items.count * 8)
+ min(20, approved_opps.count * 10)
+ min(15, actions.count * 3)
.clamp(0, 100)
```

### 2.5 ROI Score
```
SE roi_metrics presentes:
  roi_score = min(100, total_roi / 2000 * 100)
  (R$2.000 = 100pts; R$1.000 = 50pts)

SE apenas revenue_plan:
  roi_score = min(100, monthly_moderate / 100)
  (R$10.000/mês = 100pts; R$5.000 = 50pts)

SEM dados: roi_score = 0
```

### 2.6 Momentum Score
```
baseline = 15 (se há ações ou lab_items, senão 0)
momentum = min(100,
  baseline +
  recent_actions_30d * 12 +
  recent_lab_30d     * 8 +
  completed_actions  * 5
)
```

### 2.7 Execution Score (dimensão auxiliar)
```
comp_pts = (completed/total_actions) * 50    -- max 50
app_pts  = min(30, approved_opps * 10)       -- max 30
road_pts = 20 (se projeto tem roadmap)        -- max 20
execution_score = (comp_pts + app_pts + road_pts).clamp(0, 100)
```

---

## 3. Recomendação de Ação

| Ecosystem Score | Dados Suficientes | Recomendação     |
|-----------------|-------------------|------------------|
| >= 80           | sim               | ESCALAR          |
| 60–79           | sim               | ACELERAR         |
| 40–59           | sim               | MANTER           |
| 20–39           | sim               | VALIDAR          |
| < 20            | sim               | PAUSAR           |
| qualquer        | não               | ANÁLISE INCOMPLETA|

**Dados suficientes** = market_analysis OU revenue_plan OU lab_items OU actions

---

## 4. Scores de Oportunidade Individual (OpportunityLabItem)

| Campo         | Escala | Fonte                  |
|---------------|--------|------------------------|
| market_score  | 0–100  | AI (generate-project-opportunities) |
| revenue_score | 0–100  | AI                     |
| competition_score | 0–100 | AI                  |
| synergy_score | 0–100  | AI                     |
| strategic_fit | 0–100  | AI                     |
| final_score   | 0–100  | Calculado (média ponderada) |

---

## 5. Asset Score

| Dimensão      | Peso |
|---------------|------|
| potential_score   | 0.30 |
| maturity_score    | 0.25 |
| strategic_score   | 0.25 |
| roi_score         | 0.10 |
| velocity_score    | 0.10 |

`asset_score = soma ponderada.clamp(0, 100)`

---

## 6. Confiabilidade dos Scores

Um score é considerado **não confiável** quando:
- `has_enough_data = false` (sem análise, sem plan, sem lab, sem actions)
- `market_score = 0` (sem análise de mercado)
- `opportunity_score` derivado apenas de `priority_score` do projeto (fallback)
- `roi_score = 0` sem registro de ROI real

**Indicador de confiança:** campo `hasEnoughData` no `EcosystemScore`

---

## 7. Versioning

| Versão | Data       | Mudanças                               |
|--------|------------|----------------------------------------|
| 1.0    | 2026-07-23 | Versão inicial documentada             |
| -      | Phase 10I  | Fix opportunity_score via lab fallback |
| -      | Phase 10I  | Decision Engine 2.0 (hasEnoughData)    |
| -      | Phase 10I  | Strategic Fit 2.0 (4 componentes)      |
