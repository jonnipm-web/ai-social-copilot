# EXECUTIVE RELATIONSHIP ENGINE
## InsightValues Business OS — Motor de Relações Executivas
### Data: 2026-07-29 | FASE 11

---

## OBJETIVO

Detectar automaticamente relações entre projetos e ideias do portfólio, identificando:
- Duplicatas (>90% de contexto igual)
- Conflitos internos (>80% de sobreposição de nicho)
- Sinergias (40-80% de sobreposição — se complementam)
- Público compartilhado (audiência semelhante, nicho diferente)
- Projetos complementares (20-40% de sobreposição)

---

## MODELO

```dart
enum RelationshipType {
  sharedNiche,        // compartilham nicho (>60% sobreposição)
  sharedAudience,     // compartilham público-alvo
  complementary,      // se complementam
  conflicting,        // concorrentes internos (>80% sobreposição)
  synergistic,        // sinergia explícita
  duplicate,          // possível duplicata (>90% contexto)
}

class ExecutiveRelationship {
  final String projectAId, projectAName;
  final String projectBId, projectBName;
  final RelationshipType type;
  final double similarity;           // 0.0-1.0
  final String description;
  final List<String> sharedTopics;
  final List<String> synergies;
  final List<String> conflicts;
  final String recommendation;
}
```

---

## ALGORITMO DE DETECÇÃO

O `ExecutiveRelationshipService` executa puro Dart (sem I/O):

```
Para cada par (projectA, projectB):
    1. Busca análises de mercado de cada projeto
    2. Calcula nicheOverlap (palavras compartilhadas no nicho)
    3. Calcula audienceOverlap (palavras compartilhadas no público)
    4. Calcula modelOverlap (palavras compartilhadas no modelo de monetização)
    5. Calcula contextOverlap = (nicheOverlap + audienceOverlap + modelOverlap) / 3

    contextOverlap >= 0.90 → DUPLICATE
    nicheOverlap >= 0.80   → CONFLICTING
    nicheOverlap >= 0.40   → SYNERGISTIC
    audienceOverlap >= 0.50 → SHARED_AUDIENCE
    (20-40% + audiência) → COMPLEMENTARY
```

---

## PROVIDERS

```dart
// Todas as relações do portfólio
final executiveRelationshipsProvider = FutureProvider.autoDispose<List<ExecutiveRelationship>>;

// Relações de um projeto específico
final projectRelationshipsProvider = FutureProvider.autoDispose.family<List<ExecutiveRelationship>, String>;

// Apenas duplicatas e conflitos
final criticalRelationshipsProvider = FutureProvider.autoDispose<List<ExecutiveRelationship>>;
```

---

## PRIORIDADE DE EXIBIÇÃO

| Prioridade | Tipo | Cor |
|-----------|------|-----|
| 0 | duplicate | 🔴 vermelho |
| 1 | conflicting | 🟠 laranja |
| 2 | synergistic | 🟡 amarelo |
| 3 | sharedNiche | 🔵 azul |
| 4 | sharedAudience | 🔵 azul |
| 5 | complementary | 🟢 verde |

---

## INTERFACE (Project Command Center)

Seção "Relações do Portfólio" aparece no `_ProjectDetailSheet`:
- Cada relação é clicável → abre `IveDetailSheet` com descrição, sinergias, conflitos e recomendação
- Relações críticas (duplicata/conflito) têm borda vermelha
- Máximo de 3 relações exibidas no card (expandível via IVE)

---

## EXEMPLO DE SAÍDA

```
"InsightValues" e "BusinessOS" compartilham 92% do contexto.
→ DUPLICATE: Considere consolidar em um único projeto.

"Blog Finanças" e "Newsletter Invest" compartilham audiência de investidores.
→ SHARED_AUDIENCE: Cross-sell para mesma base de leitores.

"RCBO App" e "InsightValues" operam em nichos relacionados (65% overlap).
→ SYNERGISTIC: Conhecimento de nicho pode ser reutilizado.
```

---

## LIMITAÇÕES

- Requer análise de mercado em pelo menos um dos projetos para detectar relação
- Overlap é calculado por palavras (não semântica) — falsos positivos em nichos similares com vocabulário diferente
- Fase 12: adicionar embedding semântico via Edge Function para maior precisão
