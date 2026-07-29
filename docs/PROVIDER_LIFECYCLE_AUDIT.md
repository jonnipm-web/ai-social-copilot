# Provider Lifecycle Audit — Sprint P0

**Data:** 2026-07-29
**Problema raiz:** Providers `autoDispose` com operações assíncronas iniciadas no constructor podem completar após o notifier ser descartado.

---

## Padrão Correto: `mounted` Check

Todo `StateNotifier.autoDispose` com `await` deve verificar `mounted` antes de qualquer `state =`:

```dart
Future<void> load() async {
  if (!mounted) return;
  state = const AsyncValue.loading();
  try {
    final data = await _service.fetch();
    if (!mounted) return;      // ← crítico: o notifier pode ter sido descartado
    state = AsyncValue.data(data);
  } catch (e, st) {
    if (!mounted) return;
    state = AsyncValue.error(e, st);
  }
}
```

---

## P0-10: OpportunityLabNotifier

**Arquivo:** `lib/providers/opportunity_lab_provider.dart`

**Problema:** `load()` chamado via `ref.listen` ou directly causava `StateError: Bad state: Tried to use OpportunityLabNotifier after dispose()`.

**Causa:** `opportunityLabProvider` é `StateNotifierProvider.autoDispose`. Quando o widget que o observa é desmontado, o notifier é descartado. Se `load()` estava rodando, o `state = AsyncValue.data(list)` tentava modificar um notifier descartado.

**Correção:** Adicionado `if (!mounted) return;` antes de cada `state =` em `load()`, `add()`, `approve()`, `delete()`.

---

## Providers Auditados

| Provider | Tipo | `mounted` checks | Status |
|----------|------|-----------------|--------|
| `opportunityLabProvider` | StateNotifier.autoDispose | ✅ Adicionado | Corrigido |
| `marketAnalysisNotifierProvider` | StateNotifier.autoDispose | ✅ Já tinha try/catch sem state após await | OK |
| `contextCopilotProvider` | StateNotifier (sem autoDispose) | ✅ Sem risco (persiste enquanto app aberto) | OK |
| `projectsNotifierProvider` | StateNotifier.autoDispose | ✅ Operações síncronas ou já com guard | OK |
| `actionQueueProvider` | FutureProvider.autoDispose | ✅ FutureProvider gerencia lifecycle automaticamente | OK |
| `ecosystemScoresProvider` | FutureProvider.autoDispose | ✅ FutureProvider gerencia lifecycle automaticamente | OK |

---

## Regras para Novos Providers

1. **`FutureProvider.autoDispose`**: seguro por padrão — Riverpod cancela o Future quando o provider é descartado
2. **`StateNotifierProvider.autoDispose`**: **obrigatório** `if (!mounted) return;` antes de qualquer `state =` após `await`
3. **`StateNotifierProvider` (sem autoDispose)**: sem risco de dispose, mas considere `mounted` se o widget subjacente pode ser desmontado
4. Nunca inicie operações assíncronas no constructor de um `StateNotifier.autoDispose` sem verificar `mounted` após cada `await`

---

## Verificação

```
flutter analyze: 0 erros relativos a lifecycle
flutter test: 107/107 passando incluindo provider tests
```
