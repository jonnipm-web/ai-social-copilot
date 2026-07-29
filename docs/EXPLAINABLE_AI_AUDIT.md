# EXPLAINABLE AI AUDIT
## InsightValues Business OS — IVE Explainable Intelligence
### Data: 2026-07-28 | FASE 10H

---

## OBJETIVO

Garantir que toda informação produzida pela IVE seja explicável ao usuário:
1. O que significa?
2. Por que recebi este resultado?
3. Em quais evidências a IVE se baseou?
4. Como posso melhorar?
5. Qual ação posso executar agora?

---

## REGRA GERAL

> "Toda informação produzida pela IVE deve ser clicável."

Nenhum score, badge, status ou classificação pode ser apenas texto estático.

---

## INVENTÁRIO DE INTELIGÊNCIA EXPLICÁVEL

### 1. Maturidade do Projeto

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| maturityLevel | Project Command Center | ✅ Implementado |
| maturityScore | Project Command Center | ✅ Implementado |
| maturityLabel | Project Command Center | ✅ Implementado |

**Painel de Explicação: MaturityExplainPanel**
- Nível atual + score + confiança
- Por que? (checklist positivo/negativo)
- Evidências utilizadas (biblioteca, docs, projetos, pesquisas)
- Como evoluir (próximo nível + ações)
- Linha do tempo de maturidade
- Botão: Enviar ações para Action Engine
- Botão: Perguntar à IVE

---

### 2. Proposta de Valor

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| proposalSummary | Intelligence Profile | ✅ Implementado |
| problema | Proposal Detail | ✅ Implementado |
| solução | Proposal Detail | ✅ Implementado |

**Painel de Explicação: ProposalExplainPanel**
- Resumo executivo
- Seções editáveis: Problema, Solução, Mercado, Cliente, Proposta de Valor, Diferencial, Monetização, Roadmap, Riscos

---

### 3. Tópicos Identificados / Tags

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| topics | Intelligence Profile | ✅ Implementado |
| tags | Market Analysis | ✅ Implementado |

**Painel de Explicação: TopicExplainPanel**
- Por que classificou como [tag]?
- Evidências encontradas
- Confiança
- Projetos semelhantes
- Documentos relacionados
- Mercados relacionados

---

### 4. Opportunity Score

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| opportunityScore | Market Analysis | ✅ Implementado |
| opportunityScore | Opportunity Lab | ✅ Implementado |
| finalScore | Opportunity Lab | ✅ Implementado |

**Painel de Explicação: ScoreBreakdownPanel**
- Como calculei
- Peso de cada fator
- Fórmula
- Evidências
- Histórico
- Como aumentar

---

### 5. Strategic Fit

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| strategicFit | Opportunity Lab | ✅ Implementado |

**Painel de Explicação: ScoreBreakdownPanel (modo strategic_fit)**

---

### 6. ROI

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| roiGlobal | Project Intelligence | ✅ Implementado |
| revenue | ROI Tracker | ✅ Implementado |

**Painel de Explicação: ScoreBreakdownPanel (modo roi)**

---

### 7. Health Score

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| healthScore | Weekly Briefing | ✅ Implementado |
| healthScore | Executive Dashboard | ✅ Implementado |

**Painel de Explicação: HealthExplainPanel**
- Por que [score]?
- Itens positivos
- Itens negativos
- Comparação semana anterior
- Gráfico
- Plano de recuperação

---

### 8. Pontos Fortes

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| strengths | Intelligence Profile | ✅ Implementado |

**Painel de Explicação: StrengthExplainPanel**
- Por que foi identificado?
- Quais dados geraram isso?
- Quais documentos sustentam?
- Quando foi calculado?
- Como aumentar ainda mais?

---

### 9. Riscos

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| risks | Intelligence Profile | ✅ Implementado |
| risks | Weekly Briefing | ✅ Implementado |

**Painel de Explicação: RiskExplainPanel**
- Descrição
- Origem
- Impacto
- Probabilidade
- Confiança
- Documentos utilizados
- Como reduzir
- Botão: Criar plano de mitigação

---

### 10. Quick Wins

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| quickWins | Intelligence Profile | ✅ Implementado |

**Painel de Explicação: QuickWinExplainPanel**
- Impacto esperado
- Esforço
- ROI esperado
- Dependências
- Prazo
- Evidências
- Projetos relacionados
- Botão: Enviar para Action Engine

---

### 11. Knowledge Coverage

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| knowledgeCoverage | Project Intelligence | ✅ Implementado |

**Painel de Explicação: KnowledgeCoveragePanel**
- Projetos cobertos
- Projetos sem conhecimento
- Documentos faltantes
- Análises pendentes
- Botão: Completar cobertura

---

### 12. Learning Score

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| learningScore | IVE Analytics | ✅ Implementado |

**Painel de Explicação: LearningScorePanel**
- O que a IVE já aprendeu
- O que ainda falta aprender
- Bibliotecas utilizadas
- Projetos treinados
- Próximos treinamentos

---

### 13. Bloqueios

| Campo | Tela | Status Explicável |
|-------|------|------------------|
| blockers | Action Engine | ✅ Implementado |
| blockers | Intelligence Profile | ✅ Implementado |

**Painel de Explicação: BlockerExplainPanel**
- O que bloqueou
- Por quê
- Qual regra
- Quais dados faltam
- Como desbloquear
- Botão: Resolver automaticamente

---

## ARQUITETURA DA EXPLICABILIDADE

### Componente Base: IveExplainSheet

```
IveExplainSheet.show(
  context,
  title: 'Maturidade: Ideia',
  icon: '💡',
  panel: MaturityExplainPanel(...),
)
```

### Padrão de Layout

- **Desktop (≥1024px)**: Painel lateral deslizante (300px)
- **Tablet (600-1023px)**: BottomSheet expandido (85% da altura)
- **Mobile (<600px)**: BottomSheet padrão (70% da altura)

### Estrutura de Todo Painel

1. Header: título + ícone + score + confiança + data
2. POR QUE? — checklist de evidências positivas e negativas
3. EVIDÊNCIAS — lista clicável de fontes
4. COMO MELHORAR — próximo nível + ações
5. AÇÕES — botões para Action Engine, IVE Chat, etc.

---

## STATUS DE IMPLEMENTAÇÃO

| Componente | Arquivo | Status |
|-----------|---------|--------|
| IveExplainSheet | shared/widgets/ive_explain_sheet.dart | ✅ |
| MaturityExplainPanel | shared/widgets/explain_panels/maturity_panel.dart | ✅ |
| ProposalExplainPanel | shared/widgets/explain_panels/proposal_panel.dart | ✅ |
| TopicExplainPanel | shared/widgets/explain_panels/topic_panel.dart | ✅ |
| ScoreBreakdownPanel | shared/widgets/explain_panels/score_breakdown_panel.dart | ✅ |
| HealthExplainPanel | shared/widgets/explain_panels/health_panel.dart | ✅ |
| StrengthExplainPanel | shared/widgets/explain_panels/strength_panel.dart | ✅ |
| RiskExplainPanel | shared/widgets/explain_panels/risk_panel.dart | ✅ |
| QuickWinExplainPanel | shared/widgets/explain_panels/quick_win_panel.dart | ✅ |
| KnowledgeCoveragePanel | shared/widgets/explain_panels/knowledge_panel.dart | ✅ |
| LearningScorePanel | shared/widgets/explain_panels/learning_panel.dart | ✅ |
| BlockerExplainPanel | shared/widgets/explain_panels/blocker_panel.dart | ✅ |

---

## CHECKLIST DE VALIDAÇÃO

```
[ ] Maturidade clicável no Project Command Center
[ ] Proposta clicável no Intelligence Profile
[ ] Cada tópico/tag clicável individualmente
[ ] Cada Ponto Forte clicável
[ ] Cada Risco clicável com plano de mitigação
[ ] Cada Quick Win clicável com envio para Action Engine
[ ] Todos os scores com breakdown clicável
[ ] Health Score clicável no Briefing Semanal
[ ] Knowledge Coverage clicável
[ ] Learning Score clicável
[ ] Bloqueios clicáveis com resolução automática
[ ] Todos os painéis têm "Perguntar à IVE"
[ ] Desktop: painel lateral funcionando
[ ] Mobile: BottomSheet funcionando
[ ] Tablet: BottomSheet expandido funcionando
```
