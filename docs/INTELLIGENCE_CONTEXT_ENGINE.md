# INTELLIGENCE CONTEXT ENGINE
## InsightValues Business OS — Motor de Contexto da IVE
### Data: 2026-07-29 | FASE 10H.1

---

## OBJETIVO

Definir como a IVE (Inteligência Virtual do Ecossistema) usa contexto para:
1. Gerar explicações personalizadas em cada IveDetailSheet
2. Conduzir conversas contextuais (Copilot Chat)
3. Garantir que cada painel reflete dados reais do usuário

---

## ARQUITETURA DE CONTEXTO

### Contexto Global (sempre disponível)
- Projetos do portfólio (`projectsNotifierProvider`)
- Ecosystem Scores (`ecosystemScoresProvider`)
- Análises de mercado ativas (`marketAnalysesProvider`)
- Oportunidades do Opportunity Lab (`opportunityLabProvider`)
- Weekly Briefing gerado (`weeklyBriefingProvider`)

### Contexto Local (por tela)
- Projeto atual (`ProjectIntelligenceProfile`)
- Análise de mercado aberta (`MarketAnalysis`)
- Oportunidade em análise (`OpportunityLabItem`)
- Decision Gate ativo (`DecisionValidation`)

---

## PADRÃO DE screenName

Todo `IveDetailSheet.show()` deve incluir `screenName` para rastrear o contexto:

| Tela | screenName |
|------|-----------|
| Project Command Center | `'Projetos'` |
| Market Intelligence Hub | `'Market Intelligence'` |
| Weekly Briefing | `'Briefing Semanal'` |
| Opportunity Detail | `'Opportunity Lab'` |
| Executive Decision Center | `'executive_decision_center'` |

---

## VOCABULÁRIO PADRÃO DA IVE (humanExplanation)

A IVE sempre fala na primeira pessoa:

```
Score ≥ 70 (Alto):
"Identifiquei [X] sinais positivos que indicam [resultado]."

Score 40-69 (Médio):
"Há oportunidade real, mas [X] ainda precisa ser desenvolvido."

Score < 40 (Baixo):
"Os dados mostram que [X] ainda é um desafio. Para melhorar..."

Recomendações:
"Com base em [evidências], recomendo [ação] porque [razão]."

Riscos:
"Este risco foi identificado a partir de [fonte] e pode impactar [área]."

Lacunas:
"Identifiquei uma lacuna em [área]. Esta lacuna limita [impacto]."
```

---

## ESTRUTURA MÍNIMA DE CADA IveDetailSheet

```dart
IveDetailSheet.show(
  context,
  title:            'Nome do elemento clicado',     // obrigatório
  emoji:            '📊',                           // obrigatório
  humanExplanation: 'Explicação em 1ª pessoa da IVE...', // obrigatório
  evidence: [                                        // mínimo: 1 item
    IveEvidence(emoji: '📊', label: 'Score atual', value: 'X/100'),
    // ...
  ],
  suggestedActions: [                                // mínimo: 1 ação
    IveAction(emoji: '⚡', label: 'Ação', description: '...'),
  ],
  expandedData: { 'Chave': 'Valor' },               // opcional
  screenName: 'Nome da tela',                       // obrigatório
);
```

---

## INTEGRAÇÃO COM COPILOT CHAT

O `showCopilotChat()` pode ser acionado a partir de qualquer IveDetailSheet via:

```dart
IveAction(
  emoji: '🧠',
  label: 'Perguntar à IVE',
  description: 'Abrir conversa com contexto desta análise',
  onTap: () {
    Navigator.of(context).pop();
    showCopilotChat(
      context,
      screenName: 'Projetos',
      initialMessage: 'Me explique mais sobre [elemento] do projeto [nome]...',
    );
  },
)
```

---

## RESPONSIVIDADE DOS PAINÉIS

| Breakpoint | Comportamento | DraggableScrollableSheet |
|-----------|--------------|------------------------|
| Mobile (<600px) | BottomSheet 60% altura, arrastar até 92% | initialSize: 0.60, max: 0.92 |
| Tablet (600-1023px) | BottomSheet 65% altura, arrastar até 92% | initialSize: 0.65, max: 0.92 |
| Desktop (≥1024px) | Painel lateral 300px OU BottomSheet centralizado | initialSize: 0.70, max: 0.95 |

---

## PERFORMANCE

- **IveDetailSheet.show()** é síncrono — abre imediatamente sem `await`
- Dados já estão em memória (carregados pelos providers ao montar a tela)
- Nenhuma chamada de rede ao abrir um painel de explicação
- `humanExplanation` e `evidence` são gerados a partir de dados locais no build

---

## REGRAS DE QUALIDADE DE CONTEÚDO

| Regra | Verificação |
|-------|------------|
| humanExplanation nunca vazio | Sempre tem fallback: "Análise pendente para este elemento." |
| Score 0 tem mensagem especial | "Análise ainda não executada para este projeto." |
| Valores null não aparecem | Usar `?.toString() ?? 'Não disponível'` |
| Pelo menos 1 IveEvidence | Obrigatório em todos os painéis |
| Pelo menos 1 IveAction | Obrigatório — mínimo: "Perguntar à IVE" |
| screenName sempre preenchido | Nunca omitir o parâmetro screenName |
