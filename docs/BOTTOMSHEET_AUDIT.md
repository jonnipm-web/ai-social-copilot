# BottomSheet Audit — Sprint P0

**Data:** 2026-07-29
**Problema:** BottomSheets truncando conteúdo em Samsung S25 Ultra (tela 6.9", edge display com navegação gestual).

---

## Padrão Correto

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,   // obrigatório para DraggableScrollableSheet
  useSafeArea: true,           // evita corte por navigationBar / notch
  backgroundColor: Colors.transparent,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.65,    // mínimo 60% para conteúdo visível
    minChildSize: 0.35,
    maxChildSize: 0.95,
    expand: false,
    builder: (_, scrollCtrl) => Container(
      // ...
      child: Column(
        children: [
          // conteúdo fixo (header, handle)
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,   // conecta ao DraggableScrollableSheet
              child: /* conteúdo */,
            ),
          ),
        ],
      ),
    ),
  ),
);
```

---

## Sheets Auditadas

| Arquivo | `useSafeArea` | `DraggableScrollableSheet` | `initialChildSize` | Status |
|---------|--------------|--------------------------|-------------------|--------|
| `ive_detail_sheet.dart` | ✅ Adicionado | ✅ Já tinha | 0.60 → 0.75 | ✅ Corrigido |
| `context_copilot_widget.dart` (showCopilotChat) | ✅ Adicionado | ✅ Já tinha | 0.55 | ✅ OK |
| `context_copilot_widget.dart` (ContextCopilotButton) | ✅ Adicionado | ✅ Já tinha | 0.55 | ✅ OK |
| `knowledge_vault_screen.dart` (_ProjectPickerSheet) | ✅ Adicionado | ✅ Adicionado | 0.55 | ✅ Corrigido |

---

## Configurações Recomendadas por Tipo de Conteúdo

| Tipo de conteúdo | `initialChildSize` | `maxChildSize` |
|------------------|--------------------|----------------|
| Chat / conversação | 0.55 | 0.92 |
| Detalhe com scroll | 0.65–0.75 | 0.95 |
| Picker (lista curta) | 0.45–0.55 | 0.85 |
| Formulário complexo | 0.75 | 0.95 |

---

## Por que `useSafeArea: true` é Obrigatório

Em dispositivos com navegação gestural (Samsung S25 Ultra, iPhones recentes), o `WindowInsets.navigationBars` ocupa espaço na base da tela. Sem `useSafeArea: true`, o conteúdo do BottomSheet pode ficar oculto atrás da barra de navegação.

Com `useSafeArea: true`, o Flutter aplica automaticamente o padding do `MediaQuery.padding.bottom`, garantindo que o conteúdo seja visível acima da área de segurança.
