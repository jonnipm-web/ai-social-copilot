# PROJECT COMMAND CENTER — CLICK MAP DETALHADO
## InsightValues Business OS — Mapa Completo de Clicabilidade
### Data: 2026-07-29 | FASE 10H.1

---

## VISÃO GERAL

**Arquivo**: `lib/features/projects/screens/project_command_center_screen.dart`
**Widget principal**: `_ProjectDetailSheet` (BottomSheet de detalhes do projeto)
**Status**: ✅ 16/16 elementos clicáveis implementados

---

## MAPA DE CLICABILIDADE

### 1. Header do Detail Sheet

| Elemento | Widget | Linha aprox. | IveDetailSheet abre com |
|----------|--------|-------------|------------------------|
| Eco Score (número 28px) | `GestureDetector` em torno do `Text('${s.ecosystemScore}')` | ~888 | Fórmula ponderada, 5 scores com pesos, ROI total, ações concluídas |
| Badge Recomendação IA | `GestureDetector` em torno do `Container` roxo | ~949 | Por que esta recomendação, scores envolvidos, contexto do portfólio |

### 2. Scores do Ecossistema

Todos usam `_ScoreRow(label, value, onTap: () => _showScoreExplain(...))`.

| Score | Peso | onTap chama | Conteúdo do painel |
|-------|------|-------------|-------------------|
| Oportunidade | 25% | `_showScoreExplain(...)` | Potencial de mercado, análise MI, link para Ver Análise |
| Fit Estratégico | 25% | `_showScoreExplain(...)` | Alinhamento de habilidades, projetos similares |
| Sinergia | 20% | `_showScoreExplain(...)` | Complementaridade entre projetos, recursos compartilháveis |
| ROI | 20% | `_showScoreExplain(...)` | Retorno sobre tempo, receita potencial, ROI Tracker |
| Momentum | 10% | `_showScoreExplain(...)` | Atividade dos últimos 7/30 dias, taxa de conclusão |
| Mercado | — | `_showScoreExplain(...)` | Atratividade do nicho, análise MI |
| Execução | — | `_showScoreExplain(...)` | Tarefas concluídas, oportunidades aprovadas |

### 3. Análise Qualitativa

Todos usam `_tappableBullets(context, items, color, prefix, emoji, kind, ...)`.

| Elemento | Prefixo | Conteúdo do painel |
|----------|---------|-------------------|
| Cada Ponto Forte | `✓ ` (verde) | Fonte dos dados, evidências, como ampliar |
| Cada Risco | `⚠ ` (vermelho) | Origem, histórico de execução, como mitigar |
| Cada Quick Win | `⚡ ` (amarelo) | Oportunidade de alto impacto, como enviar para Action Engine |

### 4. Perfil de Inteligência

| Elemento | Implementação | Conteúdo do painel |
|----------|--------------|-------------------|
| Badge de Maturidade | `GestureDetector` em torno do Container roxo | Linha do tempo de 4 estágios, cobertura, próximo marco |
| Cada Tópico (chip) | `GestureDetector` em torno de cada chip | Por que classificado, evidências, nicho, cobertura |
| Nicho | `GestureDetector` em torno de `_infoRow` | Como identificado, influência nos scores, como refinar |
| Público-Alvo | `GestureDetector` em torno de `_infoRow` | Segmentação, monetização, como refinar perfil |
| Monetização | `GestureDetector` em torno de `_infoRow` | Modelo identificado, impacto no ROI, como documentar |
| Cada Lacuna | `GestureDetector` em torno de cada linha `⚠` | Impacto da lacuna, cobertura atual, 3 ações: Doc + Análise + Action Engine |

---

## PADRÃO DE IMPLEMENTAÇÃO

### _ScoreRow com onTap

```dart
_ScoreRow('Oportunidade', s.opportunityScore, onTap: () => _showScoreExplain(
  context, '🎯', 'Oportunidade', s.opportunityScore, '25%',
  'Mede o potencial de oportunidade de mercado...',
  'Execute análise no MI e conecte ao projeto.',
  [IveAction(emoji: '📊', label: 'Ver Análise de Mercado', onTap: onAnalyze)],
))
```

### GestureDetector + MouseRegion padrão

```dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => IveDetailSheet.show(context, title: ..., emoji: ..., ...),
  child: MouseRegion(
    cursor: SystemMouseCursors.click,
    child: _infoRow('🎯 Nicho', p.niche),
  ),
),
```

### _tappableBullets

```dart
List<Widget> _tappableBullets(
  BuildContext context,
  List<String> items,
  Color color,
  String prefix,
  String emoji,
  String kind,
  String sourceExplanation,
  String howToImprove,
)
```

---

## REGRAS DE NÃO-REGRESSÃO

1. Nunca remover `onTap` de `_ScoreRow` sem substituir por comportamento equivalente
2. Sempre incluir `behavior: HitTestBehavior.opaque` nos `GestureDetector` de lacunas/identity
3. Sempre incluir info icon (`Icons.info_outline_rounded`) visível ao lado de elementos clicáveis
4. Sempre incluir pelo menos `IveEvidence` com o valor do elemento clicado
5. Botão "Perguntar à IVE" está no rodapé do `_intelligenceSection` — nunca remover
