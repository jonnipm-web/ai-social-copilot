# IVE Avatar Operational State Engine
**Fase 11F | Branch:** `claude/ive-avatar-v2-production-integration`

## Visão geral

O `IveOperationalStateService` traduz eventos de negócio (análise de projeto,
geração de conteúdo, etc.) em estados visuais do avatar, com prioridade definida
para operações concorrentes.

## Estados e mapeamentos

| `IveAvatarStateV2` | Quando ativo |
|--------------------|-------------|
| `idle` | Nenhuma operação ativa |
| `listening` | Entrada de voz ativa |
| `thinking` | Preparando resposta contextual |
| `analyzing` | Análise de projeto, item ou oportunidade |
| `researching` | Ingestão, pesquisa ou verificação de fontes |
| `generating` | Geração de plano, conteúdo, ação ou relatório |
| `speaking` | Resposta por áudio ativa |
| `success` | Operação concluída com sucesso |
| `warning` | Dados insuficientes, bloqueio ou resultado parcial |
| `error` | Falha de operação |
| `offline` | Sem conectividade quando necessário |
| `disabled` | IVE desativada |
| `attention` | Insight, recomendação ou risco relevante |
| `waitingForUser` | Entrevista, confirmação ou dados adicionais necessários |

## Prioridade visual (maior prioridade primeiro)

```
error > warning > waitingForUser > analyzing/researching/generating
> attention > success > listening/thinking > speaking > idle
```

Quando múltiplas operações coexistem, vence o estado de maior prioridade.
`success` retorna para `idle` após 3 segundos (auto-dismiss).

## Mapeamento de `IveEventType` → `IveAvatarStateV2`

| Evento | Estado resultante | Duração |
|--------|-------------------|---------|
| `assetImportStarted` | `researching` | Até next event |
| `assetDownloadFailed` | `error` | 5s → idle |
| `assetAnalysisStarted` | `analyzing` | Até next event |
| `assetAnalysisCompleted` | `success` | 3s → idle |
| `assetAnalysisFailed` | `error` | 5s → idle |
| `scoreChanged` | `attention` | 4s → idle |
| `opportunityDetected` | `attention` | 4s → idle |
| `actionGenerated` | `success` | 3s → idle |
| `actionMutationFailed` | `error` | 5s → idle |
| `simulationCompleted` | `success` | 3s → idle |
| `projectCreated` | `success` | 3s → idle |
| `projectUpdated` | `attention` | 3s → idle |
| `projectStatusChanged` | `attention` | 3s → idle |
| `projectDeleted` | `idle` | imediato |

## Estrutura de operação

```dart
class IveOperation {
  final String          operationId;
  final String          operationType;
  final String?         projectId;
  final String?         entityId;
  final IveAvatarStateV2 state;
  final double?         progress;   // 0.0–1.0
  final String          message;
  final DateTime        startedAt;
  final DateTime?       completedAt;
  final String?         semanticError;
}
```

## Provider

```dart
final iveOperationalStateProvider =
    StateNotifierProvider<IveOperationalStateNotifier, IveAvatarStateV2>(...)
```

- Escuta `IveEventBus.instance.stream`
- Mantém fila de operações ativas
- Emite o estado de maior prioridade
- Gerencia auto-dismiss de success/error
