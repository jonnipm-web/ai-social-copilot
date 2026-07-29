# IDEA INTERVIEW ENGINE
## InsightValues Business OS — Motor de Entrevista de Ideias
### Data: 2026-07-29 | FASE 10H.1

---

## OBJETIVO

Quando uma ideia/projeto tem dados insuficientes (cobertura < 30%), a IVE deve conduzir uma entrevista
de 10 perguntas antes de gerar análises. Isso garante qualidade mínima de dados antes de executar
Opportunity Score, Market Intelligence, Decision Center, Action Engine.

---

## TRIGGER DE ATIVAÇÃO

```dart
// Critério de ativação
bool get shouldInterview =>
    coverage.score < 30 &&
    niche == 'Não definido' &&
    targetAudience == 'Não definido';
```

Quando `shouldInterview == true`, antes de gerar qualquer análise, exibir o Interview Dialog.

---

## AS 10 PERGUNTAS DA ENTREVISTA

| # | Categoria | Pergunta | Tipo de resposta |
|---|-----------|---------|-----------------|
| 1 | Problema | Qual problema específico este projeto resolve? | Texto livre |
| 2 | Público | Quem é o cliente ideal? (idade, cargo, situação) | Texto livre |
| 3 | Competição | Quais são os 3 principais concorrentes ou alternativas? | Texto livre |
| 4 | Monetização | Como o projeto vai gerar receita? (assinatura, venda única, ads, serviço) | Múltipla escolha |
| 5 | País/Idioma | Qual o mercado-alvo? (Brasil, EUA, global, outro) | Múltipla escolha |
| 6 | Estágio | Em que estágio está? (ideia, validando, MVP pronto, com clientes) | Múltipla escolha |
| 7 | MVP | O que seria o MVP mínimo para testar? | Texto livre |
| 8 | Clientes | Já tem clientes ou usuários? Quantos? | Texto + número |
| 9 | Link | Tem um site, app ou link para o projeto? (opcional) | URL (opcional) |
| 10 | Intenção | Qual o objetivo principal? (receita, aprendizado, impacto, vender a empresa) | Múltipla escolha |

---

## FLUXO DE IMPLEMENTAÇÃO

```
Usuário abre análise de projeto/ideia
    ↓
ProjectIntelligenceProfile.shouldInterview?
    ↓ SIM
Exibir IdeaInterviewDialog (modal fullscreen ou bottom sheet)
    ↓
Usuário responde as 10 perguntas (progress: 1/10, 2/10, ...)
    ↓
Ao concluir: salvar respostas como KnowledgeItem no projeto
    ↓
Re-executar análise com dados enriquecidos
    ↓
Liberar: Opportunity Score, MI, Decision Center, Action Engine
```

---

## COMPONENTES A CRIAR

### `IdeaInterviewDialog` (a ser implementado)

```dart
class IdeaInterviewDialog extends StatefulWidget {
  final Project project;
  final VoidCallback onCompleted;

  // Questões como const
  static const questions = [
    _Question(1, 'problema', 'Qual problema este projeto resolve?', _QuestionType.freeText),
    _Question(2, 'publico', 'Quem é o cliente ideal?', _QuestionType.freeText),
    // ...
  ];
}
```

### Saída: KnowledgeItem gerado pelas respostas

```json
{
  "title": "Entrevista de Ideia — [Nome do Projeto]",
  "content": "PROBLEMA: [resposta 1]\nPÚBLICO: [resposta 2]\n...",
  "source": "idea_interview",
  "project_id": "[id]"
}
```

---

## ESTADOS DAS IDEIAS/PROJETOS (BIDIRECTIONAL)

Uma ideia pode:
1. **Permanecer como ideia** — não vira projeto, alimenta a biblioteca de conhecimento
2. **Virar projeto** — promovida com base nas análises de MI e Opportunity Score
3. **Vincular-se a projeto existente** — ideia relacionada sem duplicar projeto
4. **Gerar oportunidade** — convertida em `OpportunityLabItem`
5. **Alimentar biblioteca** — conteúdo indexado no Knowledge Base
6. **Alimentar MI** — gerar análise de mercado no Market Intelligence Hub

### Relação Bidirecional Projeto ↔ Ideia

```
Projeto → mostra: ideias relacionadas (que geraram ou inspiraram o projeto)
Ideia → mostra: projetos relacionados (que foram gerados ou inspirados pela ideia)
```

---

## PRIORIDADE DE IMPLEMENTAÇÃO

- **Fase atual (10H.1)**: Documento de especificação (este arquivo)
- **Fase 11**: Implementar `IdeaInterviewDialog`
- **Fase 12**: Implementar relação bidirecional ideia↔projeto na UI

---

## CRITÉRIOS DE ACEITAÇÃO (QUANDO IMPLEMENTADO)

- [ ] Dialog abre automaticamente quando `shouldInterview == true`
- [ ] Progresso visível (1/10, 2/10, ...)
- [ ] Respostas salvas como KnowledgeItem no projeto
- [ ] Análises liberadas somente após conclusão
- [ ] Opção de pular entrevista com aviso de precisão reduzida
- [ ] Botão "Continuar sem entrevista" disponível (com warning)
