# MARKET INTELLIGENCE HUB — EXPLAINABLE AI
## InsightValues Business OS — Explicabilidade do MI Hub
### Data: 2026-07-29 | FASE 10H.1

---

## VISÃO GERAL

**Arquivo**: `lib/features/market_intelligence/screens/market_intelligence_hub_screen.dart`
**Status**: ✅ 7/7 elementos clicáveis implementados

---

## MAPA DE CLICABILIDADE

### M1 — Executive Score Card (`_ExecScoreCard`)

| Elemento | Widget | Conteúdo do IveDetailSheet |
|----------|--------|--------------------------|
| Card inteiro | `GestureDetector` em torno do `Container` | Opportunity Score total, 4 sub-scores, nicho, receita estimada, fórmula, recomendação |
| Score SEO | `_ScoreBar(onTap: ...)` | Score SEO, potencial de tráfego orgânico, palavras-chave |
| Score Monetização | `_ScoreBar(onTap: ...)` | Potencial de receita, modelos disponíveis, estimativa mensal |
| Score Concorrência | `_ScoreBar(onTap: ...)` | Saturação do mercado, nota: score alto = menos concorrência |
| Score Crescimento | `_ScoreBar(onTap: ...)` | Tendência YoY, previsão 12 meses, maturidade do nicho |

### M2 — Revenue Potential Card (`_RevenuePotentialCard`)

| Elemento | Widget | Conteúdo do IveDetailSheet |
|----------|--------|--------------------------|
| Card inteiro | `GestureDetector` em torno do `MouseRegion` | Receita min/max, prazo, confiança, score monetização, premissas, Revenue Planner |

### M7 — Investment Card (`_InvestmentCard`)

| Elemento | Widget | Conteúdo do IveDetailSheet |
|----------|--------|--------------------------|
| Card inteiro | `GestureDetector` em torno do `MouseRegion` | Recomendação SIM/NÃO/CONDICIONAL, justificativa, 3 cenários, scores envolvidos |

---

## DETALHES DE IMPLEMENTAÇÃO

### _ScoreBar

```dart
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.score, this.onTap});
  final String label;
  final int score;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bar = Expanded(child: Column(...));
    if (onTap == null) return bar;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: bar),
    );
  }
}
```

### _RevenuePotentialCard — IveDetailSheet

```dart
IveDetailSheet.show(context,
  title: 'Revenue Potential',
  emoji: '💰',
  humanExplanation: hasData
    ? 'Receita de ${_formatBRL(minVal)} a ${_formatBRL(maxVal)}/mês...'
    : 'Sem dados suficientes. Execute o Revenue Planner.',
  evidence: [
    IveEvidence('💰', 'Receita mínima', _formatBRL(minVal)),
    IveEvidence('🚀', 'Receita máxima', _formatBRL(maxVal)),
    IveEvidence('⏱️', 'Prazo estimado', '$months meses'),
    IveEvidence('📊', 'Confiança', '$conf%'),
    IveEvidence('💡', 'Score Monetização', '${analysis.scoreMonetization}/100'),
  ],
  expandedData: { ... },
  suggestedActions: [ Revenue Planner, Documentar premissas ],
);
```

### _InvestmentCard — IveDetailSheet

```dart
IveDetailSheet.show(context,
  title: 'Vale a Pena Investir? $rec',
  emoji: recEmoji,
  humanExplanation: 'A IVE recomenda: $rec...',
  evidence: [
    IveEvidence(recEmoji, 'Recomendação', rec),
    IveEvidence('📊', 'Investment Score', '$score/100'),
    IveEvidence('💰', 'Monetização', '${analysis.scoreMonetization}/100'),
    IveEvidence('📈', 'Crescimento', '${analysis.scoreGrowth}/100'),
    IveEvidence('🥊', 'Concorrência', '${analysis.scoreCompetition}/100'),
  ],
  expandedData: {
    'Cenário Otimista': '...',
    'Cenário Conservador': '...',
    'Cenário Pessimista': '...',
  },
  suggestedActions: [...],
);
```

---

## IMPORTANTE: INVERSÃO DO SCORE DE CONCORRÊNCIA

O Score de Concorrência é INVERTIDO:
- **Score alto (≥80) = pouca concorrência = oportunidade maior**
- **Score baixo (<60) = mercado saturado = barreira de entrada alta**

O painel de IveDetailSheet do Score Concorrência inclui esta explicação explicitamente:
> "Score alto = menos concorrência = mais oportunidade."

---

## MODELOS DE DADOS UTILIZADOS

```dart
// MarketAnalysis getters utilizados
analysis.opportunityScore   // Score geral
analysis.scoreSeo           // SEO
analysis.scoreMonetization  // Monetização
analysis.scoreCompetition   // Concorrência
analysis.scoreGrowth        // Crescimento
analysis.revenueMonthlyMin  // Receita mínima
analysis.revenueMonthlyMax  // Receita máxima
analysis.monthsToRevenue    // Prazo
analysis.revenueConfidence  // Confiança
analysis.investmentRecommendation  // SIM/NÃO/CONDICIONAL
analysis.investmentScore    // Score de investimento
analysis.investmentJustification   // Justificativa
analysis.niche              // Nicho identificado
analysis.input              // Input original do usuário
```
