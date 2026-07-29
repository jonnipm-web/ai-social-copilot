# CLICKABLE INTELLIGENCE TESTS
## InsightValues Business OS — Testes de Inteligência Clicável
### Data: 2026-07-28 | FASE 10H

---

## OBJETIVO

Checklist de testes manuais para verificar que toda inteligência da IVE está
clicável, responsiva e exibe conteúdo correto no painel de explicação.

---

## CONVENÇÕES

- `[OK]` = testado e funcionando
- `[TODO]` = ainda não testado
- `[FAIL]` = testado e com problema

Testar sempre em 3 tamanhos:
- **M** = Mobile (<600px)
- **T** = Tablet (600-1023px)
- **D** = Desktop (≥1024px)

---

## 1. PROJECT COMMAND CENTER

**Arquivo**: `lib/features/projects/screens/project_command_center_screen.dart`

### 1.1 Eco Score global

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| PCC-01 | Clicar no número do Eco Score (28px) abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-02 | Painel exibe fórmula ponderada completa | [TODO] | [TODO] | [TODO] |
| PCC-03 | Painel exibe os 5 scores com seus pesos | [TODO] | [TODO] | [TODO] |
| PCC-04 | Painel tem botão "Perguntar à IVE" | [TODO] | [TODO] | [TODO] |

### 1.2 Badge de Recomendação IVE

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| PCC-05 | Clicar no badge de recomendação (Priorizar/Manter/Pausar/Arquivar) abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-06 | Painel explica por que esta recomendação foi feita | [TODO] | [TODO] | [TODO] |

### 1.3 Scores do Ecossistema

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| PCC-07 | Clicar em "Oportunidade" (25%) abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-08 | Clicar em "Fit Estratégico" (25%) abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-09 | Clicar em "Sinergia" (20%) abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-10 | Clicar em "ROI" (20%) abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-11 | Clicar em "Momentum" (10%) abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-12 | Clicar em "Mercado" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-13 | Clicar em "Execução" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-14 | Cada painel exibe a explicação do score específico | [TODO] | [TODO] | [TODO] |
| PCC-15 | Cada painel exibe o peso (ex: 25%) na evidência | [TODO] | [TODO] | [TODO] |
| PCC-16 | Cada painel tem botão "Como melhorar" | [TODO] | [TODO] | [TODO] |

### 1.4 Pontos Fortes

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| PCC-17 | Cada bullet de Ponto Forte é clicável individualmente | [TODO] | [TODO] | [TODO] |
| PCC-18 | Cursor muda para "pointer" ao hover (D) | [TODO] | N/A | [TODO] |
| PCC-19 | Painel explica a fonte do ponto forte | [TODO] | [TODO] | [TODO] |
| PCC-20 | Painel sugere como ampliar o ponto forte | [TODO] | [TODO] | [TODO] |

### 1.5 Riscos

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| PCC-21 | Cada bullet de Risco é clicável individualmente | [TODO] | [TODO] | [TODO] |
| PCC-22 | Painel exibe origem do risco | [TODO] | [TODO] | [TODO] |
| PCC-23 | Painel sugere como mitigar o risco | [TODO] | [TODO] | [TODO] |

### 1.6 Quick Wins

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| PCC-24 | Cada Quick Win é clicável individualmente | [TODO] | [TODO] | [TODO] |
| PCC-25 | Painel exibe impacto esperado e esforço | [TODO] | [TODO] | [TODO] |
| PCC-26 | Painel tem botão "Enviar para Action Engine" | [TODO] | [TODO] | [TODO] |

### 1.7 Badge de Maturidade

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| PCC-27 | Clicar no card de maturidade abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| PCC-28 | Painel exibe o nível atual + score de cobertura | [TODO] | [TODO] | [TODO] |
| PCC-29 | Painel exibe linha do tempo de 4 estágios | [TODO] | [TODO] | [TODO] |
| PCC-30 | Linha do tempo destaca o estágio atual | [TODO] | [TODO] | [TODO] |

### 1.8 Tópicos Identificados

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| PCC-31 | Cada chip de tópico é clicável individualmente | [TODO] | [TODO] | [TODO] |
| PCC-32 | Painel explica por que classificou como este tópico | [TODO] | [TODO] | [TODO] |

---

## 2. MARKET INTELLIGENCE HUB

**Arquivo**: `lib/features/market_intelligence/screens/market_intelligence_hub_screen.dart`

### 2.1 Executive Score Card

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| MIH-01 | Clicar no card inteiro abre IveDetailSheet com visão geral | [TODO] | [TODO] | [TODO] |
| MIH-02 | Painel exibe todos os 4 sub-scores | [TODO] | [TODO] | [TODO] |
| MIH-03 | Painel exibe receita estimada | [TODO] | [TODO] | [TODO] |

### 2.2 Score Bars individuais

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| MIH-04 | Clicar em "SEO" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| MIH-05 | Clicar em "Monetização" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| MIH-06 | Clicar em "Concorrência" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| MIH-07 | Clicar em "Crescimento" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| MIH-08 | Painel de Concorrência explica que score alto = menos concorrência | [TODO] | [TODO] | [TODO] |

---

## 3. WEEKLY BRIEFING

**Arquivo**: `lib/features/ecosystem/screens/weekly_briefing_screen.dart`

### 3.1 Health Score

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| WB-01 | Clicar no indicador circular do Health Score abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| WB-02 | _HealthSideCard inteiro (desktop) é clicável | N/A | N/A | [TODO] |
| WB-03 | Painel exibe pontos positivos e negativos | [TODO] | [TODO] | [TODO] |
| WB-04 | Painel exibe contagem de projetos/análises/ações | [TODO] | [TODO] | [TODO] |

### 3.2 Briefing Rows

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| WB-05 | Cada BriefingRow com detalhe é clicável | [TODO] | [TODO] | [TODO] |
| WB-06 | Painel exibe título + detalhe completo | [TODO] | [TODO] | [TODO] |

---

## 4. OPPORTUNITY DETAIL

**Arquivo**: `lib/features/opportunity_lab/screens/opportunity_detail_screen.dart`

### 4.1 Final Score (ring)

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| OD-01 | Clicar no ring do Final Score abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| OD-02 | Painel exibe composição com todos os 5 sub-scores | [TODO] | [TODO] | [TODO] |
| OD-03 | Painel exibe recomendação IVE | [TODO] | [TODO] | [TODO] |

### 4.2 Score Breakdown bars

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| OD-04 | Clicar em "Mercado" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| OD-05 | Clicar em "Receita" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| OD-06 | Clicar em "Competição" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| OD-07 | Clicar em "Sinergia" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| OD-08 | Clicar em "Fit Estratégico" abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| OD-09 | Cada painel explica especificamente o score daquela dimensão | [TODO] | [TODO] | [TODO] |

### 4.3 Confidence Meter

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| OD-10 | Clicar no medidor de confiança abre IveDetailSheet | [TODO] | [TODO] | [TODO] |
| OD-11 | Painel explica por que a IVE tem X% de confiança | [TODO] | [TODO] | [TODO] |
| OD-12 | Painel explica as fontes e volume de dados utilizados | [TODO] | [TODO] | [TODO] |

---

## 5. EXECUTIVE DECISION CENTER

**Arquivo**: `lib/features/ecosystem/screens/executive_decision_center_screen.dart`

### 5.1 Validation Gate (pendente implementação)

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| EDC-01 | Knowledge Coverage % é clicável | [TODO] | [TODO] | [TODO] |
| EDC-02 | Learning Score % é clicável | [TODO] | [TODO] | [TODO] |
| EDC-03 | Profile Complete é clicável | [TODO] | [TODO] | [TODO] |
| EDC-04 | Indexing Status é clicável | [TODO] | [TODO] | [TODO] |

---

## 6. TESTES DE UX RESPONSIVA

| ID | Teste | M | T | D |
|----|-------|---|---|---|
| UX-01 | BottomSheet abre em mobile (70% altura) | [TODO] | N/A | N/A |
| UX-02 | BottomSheet expandido em tablet (85% altura) | N/A | [TODO] | N/A |
| UX-03 | Painel lateral em desktop (300px) | N/A | N/A | [TODO] |
| UX-04 | DraggableScrollableSheet permite arrastar | [TODO] | [TODO] | [TODO] |
| UX-05 | Botão "Perguntar à IVE" presente em todos os painéis | [TODO] | [TODO] | [TODO] |
| UX-06 | MouseRegion muda cursor para "click" no desktop | N/A | N/A | [TODO] |
| UX-07 | Todos os GestureDetector têm hitTestBehavior opaco | [TODO] | [TODO] | [TODO] |

---

## 7. TESTES DE CONTEÚDO

| ID | Teste | Status |
|----|-------|--------|
| CT-01 | humanExplanation usa primeira pessoa da IVE | [TODO] |
| CT-02 | Cada painel tem pelo menos 1 IveEvidence | [TODO] |
| CT-03 | Cada painel tem pelo menos 1 IveAction | [TODO] |
| CT-04 | screenName está preenchido em todos os IveDetailSheet.show() | [TODO] |
| CT-05 | Nenhum painel exibe texto "null" ou score "0" sem fallback | [TODO] |
| CT-06 | Scores com valor 0 exibem mensagem "Análise pendente" | [TODO] |

---

## RESUMO DE COBERTURA

| Área | Total de testes | Testados | Pendentes |
|------|----------------|---------|-----------|
| Project Command Center | 32 | 0 | 32 |
| Market Intelligence Hub | 8 | 0 | 8 |
| Weekly Briefing | 6 | 0 | 6 |
| Opportunity Detail | 12 | 0 | 12 |
| Executive Decision Center | 4 | 0 | 4 |
| UX Responsiva | 7 | 0 | 7 |
| Conteúdo | 6 | 0 | 6 |
| **TOTAL** | **75** | **0** | **75** |
