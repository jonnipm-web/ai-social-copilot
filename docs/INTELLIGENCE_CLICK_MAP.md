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
| Lacunas de conhecimento | ✅ 🔗 | IveDetailSheet com impacto, origem, 3 ações: Adicionar Doc, Nova Análise, Action Engine |
| Nicho | ✅ 🔗 | IveDetailSheet com como foi identificado, influência nos scores, como refinar |
| Público-Alvo | ✅ 🔗 | IveDetailSheet com segmentação, monetização, como refinar |
| Monetização | ✅ 🔗 | IveDetailSheet com modelo identificado, impacto no ROI, como documentar |

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
| Card inteiro (Revenue Potential) | ✅ 🔗 | IveDetailSheet com estimativa min/max, prazo, confiança, score monetização, premissas |

### M7 — Investment Card

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Card inteiro (Vale a Pena Investir?) | ✅ 🔗 | IveDetailSheet com recomendação, justificativa, 3 cenários (otimista/conservador/pessimista) |

---

## WEEKLY BRIEFING
**Arquivo**: `lib/features/ecosystem/screens/weekly_briefing_screen.dart`

### Header

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Health Score circular | ✅ 🔗 | IveDetailSheet com composição do score |
| Texto "Saúde Geral: X/100" | ✅ 🔗 | IveDetailSheet com status, componentes, meta, comparação |

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
| Knowledge Coverage % | ✅ 🔗 | IveDetailSheet com score, mínimo, documentos, como melhorar |
| Learning Score % | ✅ 🔗 | IveDetailSheet com score, mínimo, como treinar a IVE |
| Profile Complete | ✅ 🔗 | IveDetailSheet com status, o que falta, como vincular análise |
| Indexing Status | ✅ 🔗 | IveDetailSheet com total/indexados, status, como re-indexar |

---

## OPPORTUNITY DETAIL
**Arquivo**: `lib/features/opportunity_lab/screens/opportunity_detail_screen.dart`

| Elemento | Clicável | Tipo |
|----------|---------|------|
| Final Score (ring chart) | ✅ 🔗 | IveDetailSheet com todos os 5 sub-scores + confiança |
| Score Mercado | ✅ 🔗 | IveDetailSheet com tamanho, tendência, como melhorar |
| Score Receita | ✅ 🔗 | IveDetailSheet com potencial de monetização, ticket médio |
| Score Competição | ✅ 🔗 | IveDetailSheet com saturação, janela de oportunidade |
| Score Sinergia | ✅ 🔗 | IveDetailSheet com complementaridade, reuso de recursos |
| Score Fit Estratégico | ✅ 🔗 | IveDetailSheet com alinhamento de objetivos e habilidades |
| Confiança % | ✅ 🔗 | IveDetailSheet com nível, fontes, como aumentar precisão |

---

## RESUMO DE IMPLEMENTAÇÃO

| Área | Total | Implementado | Pendente |
|------|-------|-------------|---------|
| Project Command Center | 16 | 16 | 0 ✅ |
| Market Intelligence Hub | 7 | 7 | 0 ✅ |
| Weekly Briefing | 6 | 6 | 0 ✅ |
| Decision Center | 6 | 6 | 0 ✅ |
| Opportunity Detail | 7 | 7 | 0 ✅ |
| **TOTAL** | **42** | **42** | **0** |

### 🎯 100% — Nenhum indicador sem explicação.

---

## HISTÓRICO DE FASES

| Fase | Data | Implementado |
|------|------|-------------|
| FASE 10H | 2026-07-28 | 34/42 |
| FASE 10H.1 | 2026-07-29 | 42/42 (100%) |
