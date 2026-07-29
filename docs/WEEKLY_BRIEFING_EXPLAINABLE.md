# WEEKLY BRIEFING — EXPLAINABLE AI
## InsightValues Business OS — Explicabilidade do Briefing Semanal
### Data: 2026-07-29 | FASE 10H.1

---

## VISÃO GERAL

**Arquivo**: `lib/features/ecosystem/screens/weekly_briefing_screen.dart`
**Status**: ✅ 6/6 elementos clicáveis implementados

---

## MAPA DE CLICABILIDADE

### Header (`_Header`)

| Elemento | Widget | Conteúdo do IveDetailSheet |
|----------|--------|--------------------------|
| Health Score circular (ring) | `GestureDetector` em torno de `CircularProgressIndicator` | Score, status, componentes (projetos/análises/ações/oportunidades), meta, fórmula |
| Texto "Saúde Geral: X/100" | `GestureDetector` em torno do `Text` | Status detalhado, componentes, meta recomendada, gerado em |

### Sidebar — Desktop (`_HealthSideCard`)

| Elemento | Widget | Conteúdo do IveDetailSheet |
|----------|--------|--------------------------|
| Card inteiro | `GestureDetector` + `MouseRegion` em torno do Container | Composição do score, itens positivos, itens negativos, histórico |

### Data Origin Card (`_DataOriginCard`)

| Elemento | Widget | Conteúdo do IveDetailSheet |
|----------|--------|--------------------------|
| CountChip "Projetos" | `_CountChip(onTap: ...)` | Total de projetos, como alimentam o Health Score, link para PCC |
| CountChip "Análises" | `_CountChip(onTap: ...)` | Total de análises MI, quais scores alimentam, link para MI Hub |
| CountChip "Ações" | `_CountChip(onTap: ...)` | Total de ações, influência no Momentum/Execução, link para Action Engine |
| CountChip "Oportunidades" | `_CountChip(onTap: ...)` | Total de oportunidades, como foram geradas, link para Opportunity Lab |

### Seções Principais (`_Section` → `_BriefingRow`)

| Elemento | Widget | Conteúdo do IveDetailSheet |
|----------|--------|--------------------------|
| Cada BriefingRow (quando tem detalhe) | `GestureDetector` condicional | Título + detalhe completo do insight da semana |

---

## DETALHES DE IMPLEMENTAÇÃO

### _CountChip com onTap

```dart
class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,  // opcional — mantém compatibilidade com chips não-clicáveis
  });

  @override
  Widget build(BuildContext context) {
    final chip = Expanded(child: Container(...));
    if (onTap == null) return chip;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: chip),
    );
  }
}
```

### Texto "Saúde Geral: X/100" clicável

```dart
GestureDetector(
  onTap: () {
    final h = briefing.overallHealthScore;
    final label = h >= 70 ? 'Saudável 🟢' : h >= 45 ? 'Atenção 🟡' : 'Crítico 🔴';
    IveDetailSheet.show(context,
      title: 'Saúde Geral: $h/100',
      emoji: briefing.healthEmoji,
      humanExplanation: '...',
      evidence: [...],
      expandedData: { 'Meta recomendada': '>= 70', 'Fórmula': '...' },
      screenName: 'Briefing Semanal',
    );
  },
  child: MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Text(briefing.healthEmoji + '  Saúde Geral: $h/100', ...),
  ),
),
```

---

## MODELO DE DADOS: WeeklyBriefing

```dart
class WeeklyBriefing {
  final int overallHealthScore;     // 0-100
  final String healthEmoji;         // 🟢 🟡 🔴
  final int projectCount;           // projetos analisados
  final int analysisCount;          // análises de mercado
  final int actionsCount;           // ações no pipeline
  final int opportunitiesCount;     // oportunidades identificadas
  final List<String> analyzedProjectNames;
  final String executiveSummary;
  final List<BriefingItem> whatChanged;
  final List<BriefingItem> whatGrew;
  final List<BriefingItem> whatDeclined;
  final List<BriefingItem> topPriorities;
  final List<BriefingItem> toPause;
  final List<BriefingItem> newOpportunities;
  final List<BriefingItem> risks;
  final DateTime generatedAt;
}
```

---

## REGRAS DE NÃO-REGRESSÃO

1. `_CountChip` aceita `onTap` opcional — chips sem onTap continuam funcionando sem alterações
2. O texto "Saúde Geral: X/100" no header e o circular indicator são elementos distintos e independentes
3. `_HealthSideCard` usa o mesmo `_showHealthExplain` que o circular indicator
4. `_BriefingRow` só fica clicável se `item.detail.isNotEmpty`
