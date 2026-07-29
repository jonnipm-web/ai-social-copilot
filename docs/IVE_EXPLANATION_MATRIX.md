# IVE EXPLANATION MATRIX
## InsightValues Business OS — Matriz de Explicabilidade
### Data: 2026-07-28 | FASE 10H

---

## OBJETIVO

Mapeamento completo de cada score/badge/classificação da IVE com:
- A pergunta que o usuário faz ao clicar
- O conteúdo mínimo do painel de explicação
- O painel responsável

---

## MATRIZ COMPLETA

### SCORES DE ECOSSISTEMA

| Score | Pergunta do usuário | Conteúdo do painel | Painel |
|-------|--------------------|--------------------|--------|
| Eco Score (total) | "Por que meu projeto tem este score global?" | Fórmula ponderada, 5 sub-scores com pesos, histórico | IveDetailSheet |
| Oportunidade (25%) | "Por que esta oportunidade vale X?" | Potencial de mercado, nicho, público, concorrência | IveDetailSheet |
| Fit Estratégico (25%) | "Por que este projeto se encaixa no meu portfólio?" | Alinhamento de habilidades, projetos similares, lacunas | IveDetailSheet |
| Sinergia (20%) | "Como este projeto complementa os outros?" | Projetos com sobreposição, recursos compartilháveis | IveDetailSheet |
| ROI (20%) | "Qual o retorno esperado deste projeto?" | Horas investidas, receita potencial, prazo de retorno | IveDetailSheet |
| Momentum (10%) | "Por que o ritmo está assim?" | Atividade dos últimos 7/30 dias, comparação histórica | IveDetailSheet |
| Mercado | "O mercado está atrativo?" | Score MI, crescimento do setor, barreiras de entrada | IveDetailSheet |
| Execução | "Minha execução está boa?" | Tarefas concluídas, bloqueios, velocidade de sprint | IveDetailSheet |

---

### SCORES DE OPORTUNIDADE

| Score | Pergunta do usuário | Conteúdo do painel | Painel |
|-------|--------------------|--------------------|--------|
| Final Score (opportunity) | "Por que esta oportunidade tem X pontos?" | Composição de todos os sub-scores, recomendação IVE | IveDetailSheet |
| Mercado | "Por que o mercado foi avaliado assim?" | Tamanho, crescimento, sazonalidade, tendências | IveDetailSheet |
| Receita | "Qual o potencial de receita?" | Modelo de monetização, ticket médio, TAM estimado | IveDetailSheet |
| Competição | "Qual o nível de concorrência?" | Saturação, players, barreiras, janela de oportunidade | IveDetailSheet |
| Sinergia | "Como essa oportunidade se integra ao meu portfólio?" | Projetos complementares, habilidades aproveitadas | IveDetailSheet |
| Fit Estratégico | "Esse projeto se alinha com minha visão?" | Objetivos, habilidades, recursos disponíveis | IveDetailSheet |
| Confiança % | "Por que a IVE tem X% de confiança?" | Volume de dados, fontes utilizadas, data da análise | IveDetailSheet |

---

### SCORES DE MERCADO (Market Intelligence Hub)

| Score | Pergunta do usuário | Conteúdo do painel | Painel |
|-------|--------------------|--------------------|--------|
| Opportunity Score (total) | "Por que meu mercado tem este score?" | 4 sub-scores com pesos, receita estimada, prazo | IveDetailSheet |
| SEO Score | "Como está meu potencial de tráfego orgânico?" | Palavras-chave identificadas, volume, dificuldade | IveDetailSheet |
| Monetização Score | "Qual o potencial de receita neste nicho?" | Ticket médio, modelos de receita, TAM | IveDetailSheet |
| Concorrência Score | "Quão saturado está o mercado?" | Players identificados, nível de entrada, diferenciação | IveDetailSheet |
| Crescimento Score | "O mercado está crescendo?" | Tendência, YoY growth, previsão 12 meses | IveDetailSheet |

---

### BADGES DE STATUS

| Badge | Pergunta do usuário | Conteúdo do painel | Painel |
|-------|--------------------|--------------------|--------|
| Maturidade (Ideia/Validando/Crescendo/Maduro) | "Por que meu projeto está neste estágio?" | Checklist do estágio, evidências, próximos marcos | IveDetailSheet |
| Recomendação IVE (Priorizar/Manter/Pausar/Arquivar) | "Por que a IVE recomenda isso?" | Scores envolvidos, contexto do portfólio, alternativas | IveDetailSheet |
| Investment Recommendation (SIM/NÃO/CONDICIONAL) | "Por que a IVE recomenda isso para investimento?" | Criteria avaliados, score de investimento, condições | IveDetailSheet |

---

### QUALITATIVO

| Elemento | Pergunta do usuário | Conteúdo do painel | Painel |
|----------|--------------------|--------------------|--------|
| Cada Ponto Forte | "Por que isso foi identificado como ponto forte?" | Fonte dos dados, evidências, documentos, como ampliar | IveDetailSheet |
| Cada Risco | "Como este risco pode impactar meu projeto?" | Origem, impacto, probabilidade, como mitigar, plano | IveDetailSheet |
| Cada Quick Win | "Como executar este Quick Win?" | Esforço, impacto, ROI esperado, prazo, dependências | IveDetailSheet |
| Cada Tópico/Tag | "Por que classificou como este tópico?" | Evidências textuais, confiança, documentos, similares | IveDetailSheet |

---

### HEALTH E PERFORMANCE

| Elemento | Pergunta do usuário | Conteúdo do painel | Painel |
|----------|--------------------|--------------------|--------|
| Health Score | "Por que o ecossistema está com saúde X?" | Itens positivos, itens negativos, histórico, plano | IveDetailSheet |
| Knowledge Coverage % | "Quantos projetos a IVE conhece bem?" | Projetos cobertos, lacunas, documentos faltantes | IveDetailSheet |
| Learning Score % | "O que a IVE já aprendeu?" | Bibliotecas treinadas, projetos analisados, progresso | IveDetailSheet |
| Cada Bloqueio | "O que está impedindo este projeto?" | Causa raiz, dados faltantes, como desbloquear | IveDetailSheet |

---

## PADRÃO DE CONTEÚDO POR PAINEL

### Estrutura Mínima de Todo IveDetailSheet

```
1. Título + emoji + score/valor + data da análise
2. "POR QUÊ?" — explicação em linguagem humana (2-3 frases)
3. "EVIDÊNCIAS" — lista de fontes com emoji + label + valor
4. "COMO MELHORAR?" — 2-3 ações concretas
5. "AÇÕES" — botões Action Engine + "Perguntar à IVE"
```

### Vocabulário Padrão (humanExplanation)

Sempre usar a primeira pessoa da IVE:

- Scores altos (≥70): "Identifiquei [X] sinais positivos..."
- Scores médios (40-69): "Há oportunidade real, mas [X] ainda precisa..."
- Scores baixos (<40): "Os dados mostram que [X] ainda é um desafio..."
- Recomendações: "Com base em [evidências], recomendo [ação] porque [razão]"
- Riscos: "Este risco foi identificado a partir de [fonte] e pode impactar [área]"

---

## REGRAS DE NÃO-REGRESSÃO

1. **Nunca remover** um elemento já clicável sem adicionar outro comportamento
2. **Nunca simplificar** um painel que já existe para versão mais pobre
3. **Sempre preservar** o botão "Perguntar à IVE" em todos os painéis
4. **Sempre incluir** pelo menos uma `IveEvidence` por painel
5. **Sempre incluir** pelo menos uma `IveAction` por painel
6. **Responsividade**: testar em 3 breakpoints antes de commitar

---

## FONTE DE DADOS POR SCORE

| Score | Fonte principal | Fonte secundária |
|-------|----------------|-----------------|
| Oportunidade | `ProjectIntelligenceProfile.opportunityScore` | `MarketAnalysis.opportunityScore` |
| Fit Estratégico | `EcosystemScore.strategicFit` | `OpportunityMatch.strategicFit` |
| Sinergia | `EcosystemScore.synergy` | Análise cruzada de projetos |
| ROI | `EcosystemScore.roi` | `RoiTracker` |
| Momentum | `EcosystemScore.momentum` | Histórico de atividade |
| Health Score | `EcosystemBriefing.healthScore` | `ProjectIntelligenceProfile` |
| Opportunity Score MI | `MarketAnalysis.opportunityScore` | `SearchResult` |
