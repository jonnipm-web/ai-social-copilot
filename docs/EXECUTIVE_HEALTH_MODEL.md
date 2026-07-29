# EXECUTIVE HEALTH MODEL
## InsightValues Business OS — Modelo de Saúde Executiva
### Data: 2026-07-29 | FASE 11

---

## VISÃO GERAL

A saúde de um projeto não é mais um único número.
São 8 pilares independentes, cada um clicável, explicável, comparável no tempo e com recomendações.

---

## OS 8 PILARES

| Pilar | Emoji | Descrição |
|-------|-------|-----------|
| Conhecimento | 📚 | Profundidade e qualidade da base de conhecimento |
| Mercado | 📊 | Atratividade e validação do mercado-alvo |
| Execução | ⚡ | Taxa de conclusão de ações e momentum |
| Monetização | 💰 | Viabilidade e clareza do modelo de receita |
| Validação | 🔬 | Evidências de mercado e usuários reais |
| Riscos | 🛡️ | Controle de riscos e fraquezas identificadas |
| Tecnologia | 🛠️ | Infraestrutura técnica e presença digital |
| Estratégia | 🎯 | Clareza estratégica e posicionamento |

---

## MODELO

```dart
class HealthPillar {
  final String name;
  final String emoji;
  final int score;           // 0-100
  final int previousScore;   // para trend
  final String status;       // 'forte' | 'atenção' | 'crítico'
  final List<String> strengths;
  final List<String> gaps;
  final String recommendation;

  int get trend => score - previousScore;  // positivo = melhorou
  String get trendEmoji => trend > 5 ? '📈' : trend < -5 ? '📉' : '➡️';
  String get statusEmoji => status == 'forte' ? '🟢' : status == 'atenção' ? '🟡' : '🔴';
}

class ExecutiveHealth {
  final HealthPillar knowledge, market, execution, monetization;
  final HealthPillar validation, risks, technology, strategy;
  final DateTime computedAt;

  List<HealthPillar> get pillars => [knowledge, market, execution, monetization,
                                     risks, validation, technology, strategy];
  int get overallScore => pillars.fold(0, (s, p) => s + p.score) ~/ pillars.length;
  HealthPillar get weakestPillar  => pillars.reduce((a, b) => a.score < b.score ? a : b);
  HealthPillar get strongestPillar => pillars.reduce((a, b) => a.score > b.score ? a : b);
}
```

---

## FÓRMULAS POR PILAR

### Conhecimento (📚)
```
score = coverage.score × 70% + min(knowledgeItemCount × 5, 30)
```

### Mercado (📊)
```
score = opportunityScore × 40% + scoreSeo × 20% + scoreGrowth × 20% + scoreCompetition × 20%
```
Se sem análise → score = 0

### Execução (⚡)
```
completionRate = completedActions / totalActions × 100
score = completionRate × 60% + min(totalActions × 5, 40)
```
Se sem ações → score = 0

### Monetização (💰)
```
score = scoreMonetization (direto da análise)
```
Se sem análise → score = 0

### Validação (🔬)
```
score = 30 (tem análise) + 25 (tem labItems) + 20 (tem url) + min(approvedItems × 10, 25)
```

### Riscos (🛡️)
```
score = 100 - min(risksCount × 10, 40) - min(cancelledActions × 5, 20) - 30 (sem análise)
```

### Tecnologia (🛠️)
```
score = 30 (tem url) + 20 (tipo website/saas) + 30 (tem docPoints) + min(oppPoints, 20)
```

### Estratégia (🎯)
```
score = 25 (tem valueProposition) + 20 (tem positioning) + 20 (tem labApproved)
      + 20 (opportunityScore >= 60) + min(coverage.score / 5, 15)
```

---

## STATUS POR SCORE

| Score | Status | Emoji |
|-------|--------|-------|
| ≥ 70  | forte  | 🟢 |
| 40-69 | atenção | 🟡 |
| < 40  | crítico | 🔴 |

---

## INTERFACE

Os 8 pilares são exibidos como chips coloridos no `_ProjectDetailSheet`:

```
📚 Conhecimento [72] 🟢   📊 Mercado [58] 🟡
⚡ Execução [40] 🟡        💰 Monetização [30] 🔴
```

Cada chip clicável → `IveDetailSheet` com score, status, strengths, gaps, recomendação.

---

## CRITÉRIOS DE ACEITAÇÃO

- [ ] 8 pilares computados para todos os projetos
- [ ] Cada pilar clicável com IveDetailSheet detalhado
- [ ] Status visual por cor (verde/amarelo/vermelho)
- [ ] Pilar mais fraco destacado no card do projeto
- [ ] Score geral exibido junto ao cabeçalho
