# LIVING PROJECT PROFILE
## InsightValues Business OS — Perfil Vivo do Projeto
### Data: 2026-07-29 | FASE 11

---

## CONCEITO

O Perfil Vivo do Projeto (`ProjectIntelligenceProfile`) é recalculado automaticamente sempre que:
- Um documento de conhecimento é adicionado
- Uma análise de mercado é concluída
- Uma oportunidade é criada ou aprovada
- Uma ação é completada
- O status do projeto muda

O usuário nunca precisa reconstruir o contexto manualmente.

---

## CAMPOS DO PERFIL VIVO (Fase 11)

```dart
class ProjectIntelligenceProfile {
  // Campos existentes (Fases anteriores)
  final Project project;
  final MarketAnalysis? analysis;
  final KnowledgeCoverage coverage;
  final String maturityStage;
  final List<String> relatedProjectNames;
  final List<String> identifiedTopics;
  final List<String> missingKnowledge;
  final String niche, targetAudience, monetizationModel, valueProposition;
  final DateTime computedAt;

  // NOVOS — Fase 11
  final ExecutiveHealth? executiveHealth;          // 8 pilares de saúde
  final List<ExecutiveRelationship> relationships; // relações com outros projetos
  final bool checkInDue;                           // 21+ dias sem atualização
  final DateTime? lastAnalysisAt;                  // data da última análise
  final int executivePriorityScore;                // prioridade dinâmica 0-100
}
```

---

## CAMPOS COMPUTADOS (getters)

```dart
bool get shouldInterview =>
    coverage.score < 30 &&
    niche == 'Não definido' &&
    targetAudience == 'Não definido';

List<ExecutiveRelationship> get criticalRelationships =>
    relationships.where((r) => r.requiresAttention).toList();

int get dynamicPriority {
  var score = (project.opportunityScore * 0.4).round();
  score += (coverage.score * 0.2).round();
  if (analysis != null) score += ((analysis!.scoreGrowth ?? 0) * 0.2).round();
  if (maturityStage == 'crescendo') score += 10;
  if (checkInDue) score -= 10;
  return score.clamp(0, 100);
}
```

---

## CICLO DE ATUALIZAÇÃO

```
Provider.watch(projectsProvider) | (knowledgeProvider) | (actionQueueProvider)
    ↓ qualquer mudança
projectIntelligenceProfilesProvider.invalidate()
    ↓
ProjectIntelligenceService.computeProfiles() re-executa
    ↓ inclui agora:
ExecutiveHealthService.compute()   → 8 pilares de saúde
_isCheckInDue()                   → check-in flag
_executivePriority()              → score dinâmico
    ↓
ProjectIntelligenceProfile atualizado automaticamente
    ↓
UI reativa (ConsumerWidget) re-renderiza
```

---

## SAÚDE EXECUTIVA (8 PILARES)

| Pilar | Emoji | Dados de Entrada |
|-------|-------|-----------------|
| Conhecimento | 📚 | KnowledgeCoverage.score + itemCount |
| Mercado | 📊 | opportunityScore + scoreSeo + scoreGrowth + scoreCompetition |
| Execução | ⚡ | actions completadas / total |
| Monetização | 💰 | scoreMonetization |
| Validação | 🔬 | analysis + labItems + project.url |
| Riscos | 🛡️ | weaknesses + cancelled actions |
| Tecnologia | 🛠️ | project.url + docPoints |
| Estratégia | 🎯 | valueProposition + positioning + opportunityScore |

---

## PRIORIDADE DINÂMICA (executivePriorityScore)

```
score = opportunityScore × 40%
      + coverage.score × 15%
      + maturity × 15%    (crescendo=15, validando=10, maduro=8, ideia=3)
      + momentum × 15%   (completedActions / totalActions)
      + market × 15%     (scoreGrowth × 10% + scoreMonetization × 5%)
      - 10 se checkInDue
```

Range: 0-100 | Recalculado a cada rebuild do provider.

---

## NÃO-REGRESSÃO

- Todos os campos existentes mantêm assinatura original
- Novos campos têm valores default (`null`, `[]`, `false`, `0`)
- Sem breaking changes para telas que não usam os campos novos
