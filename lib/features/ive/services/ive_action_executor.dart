import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/action_queue_item.dart';
import '../../../data/services/action_queue_service.dart';
import '../../../data/services/project_service.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/project_provider.dart';
import '../domain/ive_action_proposal.dart';

class IveActionExecutionResult {
  final String proposalId;
  final String operationId;
  final String idempotencyKey;
  final String correlationId;
  final ActionQueueItem action;
  final bool recoveredExisting;

  const IveActionExecutionResult({
    required this.proposalId,
    required this.operationId,
    required this.idempotencyKey,
    required this.correlationId,
    required this.action,
    this.recoveredExisting = false,
  });
}

abstract interface class IveActionExecutor {
  Future<IveActionExecutionResult> execute(IveActionProposal proposal);
}

final iveActionExecutorProvider = Provider<IveActionExecutor>((ref) {
  return ServiceBackedIveActionExecutor(
    actionService: ref.read(actionQueueServiceProvider),
    projectService: ref.read(projectServiceProvider),
  );
});

class ServiceBackedIveActionExecutor implements IveActionExecutor {
  final ActionQueueService actionService;
  final ProjectServiceInterface projectService;
  final Set<String> _inFlight = <String>{};
  final Map<String, IveActionExecutionResult> _completed = {};

  ServiceBackedIveActionExecutor({
    required this.actionService,
    required this.projectService,
  });

  // Idempotência local e de retry. O marcador persistido reduz duplicações
  // após falhas, mas não oferece transação atômica entre dispositivos.

  @override
  Future<IveActionExecutionResult> execute(IveActionProposal proposal) async {
    final cached = _completed[proposal.idempotencyKey];
    if (cached != null) return cached;
    if (!_inFlight.add(proposal.idempotencyKey)) {
      throw StateError('Esta proposta já está sendo executada.');
    }

    try {
      if (proposal.isExpired) {
        throw StateError('A proposta expirou. Gere uma nova recomendação.');
      }

      final uid = actionService.currentUserId;
      if (uid != proposal.userId) {
        throw StateError('A sessão mudou. Gere uma nova proposta.');
      }

      final project = await projectService.fetchById(proposal.projectId);
      if (project == null || project.userId != uid) {
        throw StateError('Projeto inválido para o usuário autenticado.');
      }

      final existing = await _findByMarker(proposal);
      if (existing != null) {
        final result = _validatedResult(
          proposal,
          existing,
          recoveredExisting: true,
        );
        _completed[proposal.idempotencyKey] = result;
        return result;
      }

      final plan = <String>[
        if (proposal.suggestedDueDate != null)
          'Prazo sugerido: ${proposal.suggestedDueDate!.toIso8601String()}',
      ];
      final created = await actionService.create(ActionQueueItem(
        id: '',
        userId: uid,
        projectId: proposal.projectId,
        opportunityLabId: proposal.opportunityId,
        actionType: 'task',
        title: proposal.title,
        priority: proposal.priority,
        impactScore: proposal.impact,
        effortScore: proposal.effort,
        status: 'pending',
        createdAt: DateTime.now().toUtc(),
        description: proposal.description.isEmpty ? null : proposal.description,
        origin: proposal.origin,
        sources: [
          proposal.persistenceMarker,
          'IVE Executive Assistant',
          if (proposal.correlationId.isNotEmpty)
            'ive_correlation:${proposal.correlationId}',
        ],
        rationale: proposal.rationale,
        plan: plan,
      ));

      final persisted = await actionService.fetchById(created.id);
      if (persisted == null) {
        throw StateError('A ação não pôde ser validada após a persistência.');
      }

      final result = _validatedResult(proposal, persisted);
      _completed[proposal.idempotencyKey] = result;
      return result;
    } finally {
      _inFlight.remove(proposal.idempotencyKey);
    }
  }

  Future<ActionQueueItem?> _findByMarker(IveActionProposal proposal) async {
    final actions = await actionService.fetchAll(projectId: proposal.projectId);
    for (final ActionQueueItem action in actions) {
      if (action.sources.contains(proposal.persistenceMarker)) return action;
    }
    return null;
  }

  IveActionExecutionResult _validatedResult(
    IveActionProposal proposal,
    ActionQueueItem action, {
    bool recoveredExisting = false,
  }) {
    if (action.userId != proposal.userId ||
        action.projectId != proposal.projectId ||
        action.title != proposal.title ||
        action.status != 'pending') {
      throw StateError(
          'A ação persistida não corresponde à proposta confirmada.');
    }
    return IveActionExecutionResult(
      proposalId: proposal.proposalId,
      operationId: proposal.operationId,
      idempotencyKey: proposal.idempotencyKey,
      correlationId: proposal.correlationId,
      action: action,
      recoveredExisting: recoveredExisting,
    );
  }
}
