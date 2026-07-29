# EXECUTIVE DECISION ENGINE
## InsightValues Business OS — Motor de Decisões Executivas
### Data: 2026-07-29 | FASE 11

---

## OBJETIVO

Toda recomendação importante deve responder 6 perguntas fundamentais:

1. O que fazer?
2. Por que fazer?
3. Qual impacto esperado?
4. Qual risco?
5. Quais evidências sustentam?
6. O que acontece se eu ignorar?

---

## MODELO EXTENDIDO: `PriorityRecommendation`

```dart
class PriorityRecommendation {
  // Campos existentes
  final String title;
  final String reason;          // Por que fazer?
  final String dataUsed;        // Quais evidências?
  final String expectedImpact;  // Qual impacto?
  final int confidence;         // Confiança 0-100
  final RecommendationType type;
  final String? entityId, entityName;

  // NOVOS — Fase 11
  final String costOfIgnoring;  // O que acontece se ignorar?
  final List<String> evidences; // Evidências estruturadas
  final String priority;        // 'alta' | 'média' | 'baixa'
}
```

---

## VOCABULÁRIO DA IVE PARA DECISÕES

### Alta Prioridade (priority = 'alta')
```
"Identifiquei que [projeto/oportunidade] está em condição crítica.
Se não agir nos próximos [prazo], o risco de [consequência] aumenta."
```

### Recomendação de Investimento
```
"Com base em [evidências], recomendo investir em [projeto] porque:
- Opportunity Score: [X]/100 (acima de 70 indica alto potencial)
- Crescimento do mercado: [X]% ao ano
- Concorrência favorável: Score [X]/100

Ignorar esta recomendação pode resultar em perda de [janela de mercado/timing]."
```

### Recomendação de Pausar
```
"[Projeto] está consumindo recursos sem progresso tangível.
Score de execução: [X]/100 | Ações concluídas: [X]%.
Recomendo pausar e redirecionar esforço para [outro projeto com maior ROI]."
```

---

## TIPOS DE RECOMENDAÇÃO

| Tipo | Label | Emoji | Quando gerar |
|------|-------|-------|-------------|
| investProject | Investir | 🚀 | EcosystemScore ≥ 70 com baixa execução |
| executeOpportunity | Executar | ⚡ | Oportunidade aprovada sem ação correspondente |
| runAction | Ação | ✅ | Ação de alto impacto pendente há >7 dias |
| pauseProject | Pausar | ⏸️ | EcosystemScore < 30 + execução < 20% |
| mitigateRisk | Risco | ⚠️ | Risk score < 40 |
| quickWin | Ganho Rápido | 💡 | Impact alto + effort baixo |
| waste | Desperdício | 🗑️ | Tempo/recurso em projeto estagnado |

---

## INTERFACE

### Decision Center — Aba Recomendações

Cada `PriorityRecommendation` renderiza um card expandível com:

```
┌─────────────────────────────────────────────────────┐
│ 🔴 ALTA  🚀 Investir — Projeto XYZ                  │
│ ─────────────────────────────────────────────────── │
│ Por que: Score 82/100 com tráfego orgânico em alta   │
│ Impacto: +40% de receita estimada em 6 meses        │
│ Evidências: scoreSeo=85, scoreGrowth=79             │
│ Se ignorar: janela de mercado pode fechar em 90 dias │
│ ─────────────────────────────────────────────────── │
│ [Criar Plano] [Perguntar à IVE] [Dispensar]         │
└─────────────────────────────────────────────────────┘
```

### IveDetailSheet para Recomendação

```dart
IveDetailSheet.show(context,
  title: rec.title,
  emoji: rec.type.emoji,
  humanExplanation: rec.reason,
  evidence: [
    IveEvidence('📊', 'Evidências', rec.dataUsed),
    IveEvidence('🎯', 'Impacto esperado', rec.expectedImpact),
    IveEvidence('⚠️', 'Se ignorar', rec.costOfIgnoring),
    IveEvidence('📈', 'Confiança', '${rec.confidence}%'),
    ...rec.evidences.map((e) => IveEvidence('📋', 'Dado', e)),
  ],
  expandedData: {
    'Prioridade': rec.priority,
    'Custo de ignorar': rec.costOfIgnoring,
  },
  suggestedActions: [
    IveAction('⚡', 'Criar Plano de Ação', description: 'Gera ações no Action Engine'),
    IveAction('🧠', 'Perguntar à IVE', description: 'Aprofunde a análise'),
  ],
  screenName: 'executive_decision_center',
);
```

---

## GERAÇÃO DE PLANOS

Botão "Criar Plano" em cada recomendação dispara `ActionQueueNotifier.addFromOpportunity()` ou abre o Action Engine pré-populado com o contexto da recomendação.

---

## CRITÉRIOS DE ACEITAÇÃO

- [ ] Todas as recomendações têm `costOfIgnoring` preenchido
- [ ] Evidências são dados reais (não frases genéricas)
- [ ] Prioridade ('alta'/'média'/'baixa') corretamente atribuída
- [ ] Botão "Criar Plano" funcional na interface
- [ ] IveDetailSheet abre com todas as 6 dimensões preenchidas
