# Decision Center Context — Sprint P0 (P0-04 / P0-05)

**Data:** 2026-07-29
**Tela:** `executive_decision_center_screen.dart`

---

## P0-04: Origem das Recomendações

### Problema

`_RecCard` mostrava título, razão e impacto esperado de uma recomendação, mas não indicava de qual projeto ou oportunidade ela se originava. Com múltiplos projetos no portfólio, o usuário não sabia a qual projeto cada ação se referia.

### Solução

**No card de recomendação (`_RecCard.build()`):**

```dart
Text(rec.title, style: /* estilo título */),
if (rec.entityName != null && rec.entityName!.isNotEmpty) ...[
  const SizedBox(height: 2),
  Text('Projeto: ${rec.entityName}',
      style: const TextStyle(color: Colors.white54, fontSize: 10)),
],
```

**No detail sheet (`_RecCard._showDetail()`):**

```dart
evidence: [
  IveEvidence(emoji: '📊', label: 'Tipo', value: rec.typeLabel),
  IveEvidence(emoji: '🎯', label: 'Confiança', value: '${rec.confidence}%'),
  IveEvidence(emoji: '💡', label: 'Dados usados', value: rec.dataUsed),
  if (rec.entityName != null && rec.entityName!.isNotEmpty)
    IveEvidence(emoji: '📁', label: 'Projeto', value: rec.entityName!),
],
```

### Modelo de Dados

`PriorityRecommendation` já possuía `String? entityName` e `String? entityId`. Os campos estavam populados mas não sendo exibidos na UI.

---

## P0-05: Impacto do Desbloqueio

### Problema

`_ValidationGateCard` mostrava bloqueadores mas não explicava o benefício de resolver cada um. O usuário via "BLOQUEADO" sem saber o que ganharia ao desbloquear.

### Solução

Adicionada seção "Ao desbloquear:" após a lista de motivos:

```dart
const Divider(color: Colors.white12, height: 16),
const Row(
  children: [
    Icon(Icons.lock_open_rounded, size: 11, color: Color(0xFF4CAF50)),
    SizedBox(width: 6),
    Text('Ao desbloquear:',
        style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10)),
  ],
),
const SizedBox(height: 4),
Text(
  rec.expectedImpact.isNotEmpty
      ? rec.expectedImpact
      : 'A IVE poderá gerar esta recomendação com dados reais do seu projeto.',
  style: const TextStyle(color: Colors.white38, fontSize: 10),
),
```

### Fluxo Completo de uma Recomendação Bloqueada

```
_ValidationGateCard:
  ┌─────────────────────────────────────┐
  │ 🔒 BLOQUEADO  [tipo de rec]         │
  │ ~~rec.title~~                        │
  │ ⚠️ [blockMessage]                   │
  │  Cobertura de Conhecimento  [valor] │
  │  Índice de Aprendizado      [valor] │
  │  Perfil de Inteligência     [valor] │
  │  ─────────────────────────          │
  │  Motivos do bloqueio:               │
  │  • [bloqueio 1]                     │
  │  ─────────────────────────          │
  │  🔓 Ao desbloquear:                 │ ← NOVO (P0-05)
  │  [expectedImpact ou mensagem padrão]│
  └─────────────────────────────────────┘
```

---

## P0-12: Labels em Português na Validation Gate

Os labels da gate que estavam em inglês foram traduzidos para manter consistência com o restante da UI:

| Antes | Depois |
|-------|--------|
| Knowledge Coverage | Cobertura de Conhecimento |
| Learning Score | Índice de Aprendizado |
| Intelligence Profile | Perfil de Inteligência |

**Nota:** Os títulos dos IveDetailSheets (ex: `'Knowledge Coverage — 45%'`) foram mantidos para consistência com as explicações técnicas dentro das sheets, que já referenciam esses termos em inglês nas frases explicativas.
