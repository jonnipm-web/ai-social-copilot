# Executive Timeline UI

## Visão Geral

A timeline executiva exibe todos os eventos de um projeto em ordem cronológica reversa, com filtros por categoria e detalhamento via `IveDetailSheet`.

## Localização

`lib/features/projects/widgets/executive_timeline_widget.dart`

## Componentes

### `ExecutiveTimelineWidget`

```dart
class ExecutiveTimelineWidget extends ConsumerStatefulWidget {
  final String projectId;
}
```

**Provider usado:** `projectEventsProvider(projectId)` — `FutureProvider.autoDispose.family`

**Filtros disponíveis:**
```
['Todos', 'Análises', 'Conhecimento', 'Decisões', 'Oportunidades', 'Ações', 'Projeto']
```

**Estados:**
- `loading` — `CircularProgressIndicator` centralizado
- `error` — Mensagem de aviso + botão "Tentar novamente" (invalida provider)
- `empty` — Emoji + mensagem contextual (diferencia "sem eventos" de "sem eventos do tipo X")
- `data` — Lista de `_EventTile`

### `_EventTile`

Tile individual com:
- Emoji do evento em caixa com linha vertical conectora
- Título (2 linhas máx.)
- Descrição (1 linha máx., se presente)
- Data relativa (ex: "5m", "2h", "3d", "15/01")
- Chip de filterGroup colorido
- Chevron de navegação
- `GestureDetector` + `MouseRegion` para interatividade

**Ao tocar:** Abre `IveDetailSheet` com:
- Título e emoji do evento
- Evidências: O que aconteceu, Detalhes, Módulo, Quando, + até 4 entradas de metadata
- expandedData: Tipo, Quando, Módulo

### `_FilterChip`

Chip colorido por categoria:

| filterGroup | Cor |
|-------------|-----|
| Análises | `#6C63FF` (roxo) |
| Conhecimento | `#00BCD4` (cyan) |
| Decisões | `#6BCB77` (verde) |
| Oportunidades | `#FFD93D` (amarelo) |
| Ações | `#FF9F43` (laranja) |
| Projeto | `#FF6B6B` (vermelho) |

## Integração na Tela

Posição na `_ProjectDetailSheet`:
1. Relations do Portfolio
2. **Timeline do Projeto** ← aqui
3. Botões de ação (Analisar, Status, Excluir)

## Dados de Origem

Tabela: `project_events`

Query: `SELECT * FROM project_events WHERE project_id = $1 ORDER BY created_at DESC LIMIT 50`

Filtro por grupo: aplicado em Dart via `ProjectEvent.filterGroup` getter (evita query adicional).

## Retry Flow

```
Error state
    │
    ├── Usuário clica "Tentar novamente"
    │
    └── ref.invalidate(projectEventsProvider(projectId))
            │
            └── FutureProvider recarrega automaticamente
```

## Formatação de Data

| Intervalo | Formato | Exemplo |
|-----------|---------|---------|
| < 1 min | "Agora mesmo" | — |
| < 60 min | "Há X min" | "Há 5 min" |
| < 24h | "Há Xh" | "Há 3h" |
| < 7 dias | "Há X dia(s)" | "Há 2 dias" |
| >= 7 dias | "DD/MM/YYYY" | "15/01/2026" |

Versão curta (no tile): `5m`, `3h`, `2d`, `15/1`
