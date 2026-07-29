# EXECUTIVE PRIORITIZATION
## InsightValues Business OS — Priorização Executiva Dinâmica
### Data: 2026-07-29 | FASE 11

---

## OBJETIVO

Todos os projetos possuem prioridade dinâmica calculada automaticamente.
A IVE recalcula sem precisar de ordenação manual.

---

## FÓRMULA

```
executivePriorityScore (0-100) =
    opportunityScore   × 40%   (potencial de mercado)
  + maturityBonus      × 15%   (crescendo=15, validando=10, maduro=8, ideia=3)
  + momentumScore      × 15%   (completedActions / totalActions × 15)
  + coverage.score     × 15%   (qualidade dos dados)
  + scoreGrowth        × 10%   (crescimento do mercado)
  + scoreMonetization  × 5%    (viabilidade de monetização)
  - 10 (penalidade se checkInDue = true)
```

---

## FATORES

| Fator | Peso | Fonte |
|-------|------|-------|
| Oportunidade | 40% | `project.opportunityScore` |
| Maturidade | 15% | `maturityStage` |
| Execução/Momentum | 15% | `completedActions / totalActions` |
| Cobertura de dados | 15% | `coverage.score` |
| Crescimento de mercado | 10% | `analysis.scoreGrowth` |
| Monetização | 5% | `analysis.scoreMonetization` |
| Penalidade check-in | -10 | `checkInDue == true` |

---

## INTEGRAÇÃO

### Project Command Center

O `_buildProjectList()` ordena por `executivePriorityScore` quando disponível,
fallback para `project.priorityScore` (campo Supabase estático).

```dart
final sorted = [...projects]..sort((a, b) {
  final profileA = profiles.where((p) => p.project.id == a.id).firstOrNull;
  final profileB = profiles.where((p) => p.project.id == b.id).firstOrNull;
  final sa = profileA?.executivePriorityScore ?? scoresMap[a.id]?.ecosystemScore ?? a.priorityScore;
  final sb = profileB?.executivePriorityScore ?? scoresMap[b.id]?.ecosystemScore ?? b.priorityScore;
  return sb.compareTo(sa);
});
```

### Decision Center

A aba TOP 5 usa `priorityRecommendationsProvider` que considera `executivePriorityScore`
para priorizar projetos com maior potencial e menor cobertura.

---

## CASOS ESPECIAIS

| Situação | Impacto na Prioridade |
|----------|----------------------|
| Projeto sem análise | Oportunidade = 0, -20 pontos |
| Projeto paused | Momentum = 0 |
| Projeto com check-in due | -10 pontos |
| Projeto com conflito/duplicata | Anotado no recommendations, sem penalidade automática |
| Ideia sem entrevista | shouldInterview = true → penalidade de visibilidade |

---

## PRÓXIMAS FASES

### Fase 12 — Urgência e Alinhamento Estratégico

Adicionar ao cálculo:
- `urgencyBonus`: projetos com oportunidades de mercado sazonais
- `strategicAlignmentBonus`: projetos que se alinham com OKRs do usuário

```
score += urgencyBonus      × 5%   (detectado via tendências de mercado)
       + strategicAlignment × 10%  (baseado em goals definidos pelo usuário)
```

---

## CRITÉRIOS DE ACEITAÇÃO

- [ ] `executivePriorityScore` calculado para todos os projetos ao abrir o PCC
- [ ] Ordenação no PCC usa o score dinâmico
- [ ] Score visível no card do projeto (opcional — badge discreto)
- [ ] Check-in due aplica penalidade automática
- [ ] Explicável via IveDetailSheet: "Por que este projeto está em #1?"
