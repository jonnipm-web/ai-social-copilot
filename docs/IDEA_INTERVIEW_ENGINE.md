# IDEA INTERVIEW ENGINE
## InsightValues Business OS — Motor de Entrevista de Ideias
### Data: 2026-07-29 | FASE 11 (atualizado)

---

## OBJETIVO

Quando uma ideia/projeto tem dados insuficientes (cobertura < 30%), a IVE conduz uma entrevista
de 10 perguntas antes de gerar análises. Isso garante qualidade mínima de dados antes de executar
Opportunity Score, Market Intelligence, Decision Center, Action Engine.

---

## TRIGGER DE ATIVAÇÃO

```dart
// Getter em ProjectIntelligenceProfile
bool get shouldInterview =>
    coverage.score < 30 &&
    niche == 'Não definido' &&
    targetAudience == 'Não definido';
```

```dart
// Integração em _openDetail() no ProjectCommandCenterScreen
void _openDetail(Project project, EcosystemScore? score) {
  final profile = ref.read(projectIntelligenceProfilesProvider).valueOrNull
      ?.where((p) => p.project.id == project.id).firstOrNull;

  if (profile != null && profile.shouldInterview) {
    IdeaInterviewDialog.show(context, ref,
      project: project,
      onCompleted: () {
        ref.invalidate(projectIntelligenceProfilesProvider);
        _openDetailSheet(project, score, profile);
      },
    );
    return;
  }
  _openDetailSheet(project, score, profile);
}
```

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

## WIDGET IMPLEMENTADO

### `IdeaInterviewDialog` — `lib/features/projects/widgets/idea_interview_dialog.dart`

```dart
class IdeaInterviewDialog extends ConsumerStatefulWidget {
  final Project project;
  final VoidCallback onCompleted;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required Project project,
    required VoidCallback onCompleted,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IdeaInterviewDialog(project: project, onCompleted: onCompleted),
    );
  }
}
```

Características:
- Barra de progresso (1/10 → 10/10)
- Navegação Anterior / Próximo
- Chips de múltipla escolha para questões com `_QuestionType.multiChoice`
- TextField para `freeText`, `textAndNumber`, `urlOptional`
- Botão "Pular entrevista" → aviso: `⚠️ Entrevista pulada — precisão das análises será reduzida.`
- `barrierDismissible: false` — não fecha ao tocar fora

### Saída: KnowledgeItem gerado ao concluir

```dart
ref.read(knowledgeItemNotifierProvider.notifier).create({
  'project_id': project.id,
  'title': 'Entrevista de Ideia — ${project.name}',
  'content': _buildContent(),
  'source_type': 'manual',
  'source': 'idea_interview',
});
```

```json
{
  "title": "Entrevista de Ideia — [Nome do Projeto]",
  "content": "PROBLEMA: [resposta 1]\nPÚBLICO: [resposta 2]\nCOMPETIÇÃO: [resposta 3]\n...",
  "source_type": "manual",
  "source": "idea_interview",
  "project_id": "[id]"
}
```

### Evento emitido ao concluir

```dart
ref.read(projectEventNotifierProvider(project.id).notifier).emit(
  ProjectEventType.interviewCompleted,
  'Entrevista de Ideia concluída',
  description: '10 perguntas respondidas. Dados adicionados ao Knowledge Base.',
);
```

---

## OPÇÃO DE PULO

```dart
// Ao pressionar "Pular entrevista"
setState(() => _skipped = true);

// Banner exibido no dialog e no projeto após pular:
// ⚠️ Entrevista pulada — precisão das análises será reduzida.
```

---

## FLUXO COMPLETO

```
Usuário abre card do projeto
    ↓
ProjectIntelligenceProfile.shouldInterview?
    ↓ SIM
IdeaInterviewDialog.show() — barrierDismissible: false
    ↓
Usuário responde 10 perguntas (progress: 1/10, 2/10, ...)
    ↓
Ao concluir:
  → KnowledgeItem criado no projeto
  → ProjectEvent(interviewCompleted) emitido
  → projectIntelligenceProfilesProvider.invalidate()
  → _ProjectDetailSheet aberto com perfil atualizado
```

---

## RELAÇÃO BIDIRECIONAL PROJETO ↔ IDEIA (Fase 12)

Uma ideia pode:
1. **Permanecer como ideia** — alimenta a biblioteca de conhecimento
2. **Virar projeto** — promovida com base nas análises de MI e Opportunity Score
3. **Vincular-se a projeto existente** — ideia relacionada detectada pelo `ExecutiveRelationshipService`
4. **Gerar oportunidade** — convertida em `OpportunityLabItem`
5. **Alimentar biblioteca** — conteúdo indexado no Knowledge Base
6. **Alimentar MI** — gerar análise de mercado no Market Intelligence Hub

```
Projeto → mostra: ideias relacionadas (via ExecutiveRelationship)
Ideia → mostra: projetos relacionados (via ExecutiveRelationship)
```

Status: **pendente para Fase 12** — UI bidirecional não implementada.

---

## CRITÉRIOS DE ACEITAÇÃO

- [x] Dialog abre automaticamente quando `shouldInterview == true`
- [x] Progresso visível (1/10, 2/10, ...)
- [x] Respostas salvas como KnowledgeItem no projeto
- [x] `ProjectEvent(interviewCompleted)` emitido ao concluir
- [x] `projectIntelligenceProfilesProvider` invalidado após conclusão
- [x] Opção de pular entrevista com aviso de precisão reduzida
- [ ] Análises liberadas condicionalmente (pós-entrevista vs. pular) — controle de acesso pendente
- [ ] UI bidirecional ideia↔projeto — Fase 12
