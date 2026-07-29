# INTELLIGENCE CLICK MAP
## InsightValues Business OS — Mapa de Clicabilidade da Inteligência
### Data: 2026-07-28 | FASE 10H

---

## LEGENDA

| Símbolo | Significado |
|---------|-------------|
| ✅ | Implementado e clicável |
| ⬜ | Ainda não implementado |
| 🔗 | Abre IveDetailSheet |
| 📍 | Localização no código |

---

## PROJECT COMMAND CENTER
**Arquivo**: `lib/features/projects/screens/project_command_center_screen.dart`

### Detail Sheet — Header

| Elemento | Clicável | Abre | Dados exibidos |
|----------|---------|------|----------------|
| Eco Score (número 28px) | ✅ 🔗 | IveDetailSheet | Fórmula completa, todos os 5 scores ponderados |
| Recomendação IA badge | ✅ 🔗 | IveDetailSheet | Por que esta recomendação, scores envolvidos |

### Detail Sheet — Scores do Ecossistema

| Elemento | Clicável | Peso | Explicação |
|----------|---------|------|-----------|
| Oportunidade | ✅ 🔗 | 25% | Potencial de mercado, análise MI |
| Fit Estratégico | ✅ 🔗 | 25% | Alinhamento com portfólio e habilidades |
| Sinergia | ✅ 🔗 | 20% | Complementaridade entre projetos |
| ROI | ✅ 🔗 | 20% | Retorno sobre investimento de tempo |
| Momentum | ✅ 🔗 | 10% | Velocidade e ritmo de progresso |
| Mercado | ✅ 🔗 | — | Atratividade do nicho |
| Execução | ✅ 🔗 | — | Qualidade e ritmo da execução |

### Detail Sheet — Análise Qualitativa

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Cada Ponto Forte | ✅ 🔗 | IveDetailSheet com fonte + como ampliar |
| Cada Risco | ✅ 🔗 | IveDetailSheet com origem + como mitigar |
| Cada Quick Win | ✅ 🔗 | IveDetailSheet com impacto + enviar para Action Engine |

### Perfil de Inteligência

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Badge de Maturidade | ✅ 🔗 | IveDetailSheet com linha do tempo de estágios |
| Cada tópico identificado | ✅ 🔗 | IveDetailSheet com por que foi classificado assim |
| Lacunas de conhecimento | ⬜ | — |
| Nicho / Público / Monetização | ⬜ | — |

---

## MARKET INTELLIGENCE HUB
**Arquivo**: `lib/features/market_intelligence/screens/market_intelligence_hub_screen.dart`

### M1 — Executive Score Card

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Opportunity Score (número 68px) | ✅ 🔗 | IveDetailSheet com todos os sub-scores |
| Score SEO | ✅ 🔗 | IveDetailSheet com explicação de tráfego orgânico |
| Score Monetização | ✅ 🔗 | IveDetailSheet com potencial de receita |
| Score Concorrência | ✅ 🔗 | IveDetailSheet com nível de saturação |
| Score Crescimento | ✅ 🔗 | IveDetailSheet com trajetória do mercado |

### M2 — Revenue Potential Card

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Receita potencial | ⬜ | — |
| Prazo | ⬜ | — |
| Confiança | ⬜ | — |

### M7 — Investment Card

| Elemento | Clicável | Tipo |
|----------|---------|------|
| SIM/NÃO/CONDICIONAL badge | ⬜ | — |
| Investment Score | ⬜ | — |

---

## WEEKLY BRIEFING
**Arquivo**: `lib/features/ecosystem/screens/weekly_briefing_screen.dart`

### Header

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Health Score circular | ✅ 🔗 | IveDetailSheet com composição do score |
| Texto "Saúde Geral: X/100" | ⬜ | — |

### Sidebar (desktop)

| Elemento | Clicável | Tipo |
|----------|---------|------|
| _HealthSideCard inteiro | ✅ 🔗 | IveDetailSheet com detalhes do health score |
| Barra de progresso | — | (integrado ao card) |

### Seções principais

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Cada _BriefingRow (com detalhe) | ✅ 🔗 | IveDetailSheet com título + detalhe |

---

## EXECUTIVE DECISION CENTER
**Arquivo**: `lib/features/ecosystem/screens/executive_decision_center_screen.dart`

> Nota: Este screen já usa IveDetailSheet extensivamente. Os itens abaixo são os que ainda faltam.

### Tab 2 — Ecossistema

| Elemento | Clicável | Tipo |
|----------|---------|------|
| _EcosystemCard score rows | ⬜ | Expandido inline (sem IveDetailSheet) |
| Validação Gate metrics | ⬜ | _GateMetricRow estático |

### _ValidationGateCard

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Knowledge Coverage % | ⬜ | — |
| Learning Score % | ⬜ | — |
| Profile Complete | ⬜ | — |
| Indexing Status | ⬜ | — |

---

## OPPORTUNITY DETAIL
**Arquivo**: `lib/features/opportunity_lab/screens/opportunity_detail_screen.dart`

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Final Score (ring chart) | ⬜ | — |
| Score Mercado | ⬜ | — |
| Score Receita | ⬜ | — |
| Score Competição | ⬜ | — |
| Score Sinergia | ⬜ | — |
| Score Fit Estratégico | ⬜ | — |
| Confiança % | ⬜ | — |

---

## RESUMO DE IMPLEMENTAÇÃO

| Área | Total | Implementado | Pendente |
|------|-------|-------------|---------|
| Project Command Center | 16 | 12 | 4 |
| Market Intelligence Hub | 7 | 5 | 2 |
| Weekly Briefing | 6 | 4 | 2 |
| Decision Center | 6 | 4 | 2 |
| Opportunity Detail | 6 | 0 | 6 |
| **TOTAL** | **41** | **25** | **16** |

---

## PRÓXIMAS IMPLEMENTAÇÕES (FASE 10H+)

1. `opportunity_detail_screen.dart` — score breakdown clicável (6 itens)
2. `executive_decision_center_screen.dart` — validation gate clicável (4 itens)
3. `weekly_briefing_screen.dart` — data origin counts clicáveis (2 itens)
4. `market_intelligence_hub_screen.dart` — investment card + revenue card (3 itens)
5. `project_command_center_screen.dart` — lacunas de conhecimento clicáveis (1 item)
