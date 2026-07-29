# Market Intelligence Fix — Sprint P0 (P0-07)

**Data:** 2026-07-29
**Problema:** "Tela preta" percebida no Market Intelligence durante loading ou erro.

---

## Causa Raiz Identificada

### 1. Loading Infinito (market_intelligence_hub_screen.dart)

`marketAnalysisByIdProvider` não tinha timeout. Se o Supabase não respondesse (lentidão de rede, edge function fria), o body da tela ficava em `CircularProgressIndicator` indefinidamente sobre fundo escuro (`_kBg = Color(0xFF0F0F1A)`).

O usuário via: tela escura + spinner → "tela preta".

**Correção:** Adicionado `.timeout(Duration(seconds: 15))` no `fetchById()`:

```dart
final result = await ref
    .read(marketAnalysisServiceProvider)
    .fetchById(id)
    .timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
if (result == null) throw Exception(
    'Análise não encontrada ou tempo de carregamento excedido. Tente novamente.');
```

Após o timeout, `analysisAsync.when(error:...)` exibe mensagem legível ao usuário.

### 2. Erro Bruto em `analyses.when()` (market_intelligence_screen.dart)

```dart
// ANTES (bug):
error: (e, _) => Text('Erro: $e', style: TextStyle(color: Colors.redAccent)),

// DEPOIS (fix):
error: (e, _) => Text(
    _friendlyError(e.toString()),
    style: TextStyle(color: Colors.redAccent, fontSize: 12)),
```

O texto vermelho pequeno em fundo escuro era quase invisível → aparência de tela em branco.

---

## Outros Estados de Loading

Os sub-providers (competidores, gap, oportunidades, plano de receita) já usam `.value ?? []` como fallback, portanto não bloqueiam a renderização do `data:` do `analysisAsync`. Apenas o provider principal de análise foi afetado.

---

## Teste de Validação

Para testar o timeout:
1. Desconecte o Supabase (modo avião)
2. Navegue para Market Intelligence Hub
3. Em até 15 segundos deve aparecer a mensagem de erro amigável

Para testar o erro de análise:
1. Force um erro no provider com ID inválido
2. Confirme que `_friendlyError()` retorna mensagem em PT

---

## Estado Atual

| Cenário | Comportamento antes | Comportamento depois |
|---------|--------------------|--------------------|
| Supabase lento | Loading infinito (tela preta) | Timeout 15s → mensagem de erro |
| Erro de rede | `Erro: Exception(...)` invisível | Mensagem amigável em PT |
| Análise não encontrada | `Exception: Análise não encontrada` bruto | Mensagem: "Análise não encontrada ou tempo excedido" |
