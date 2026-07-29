import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_event.dart';
import 'executive_context_service.dart';
import 'project_event_service.dart';

/// Orquestrador central — reage a eventos relevantes e atualiza o ExecutiveContext.
///
/// Responsabilidades:
/// 1. Receber evento de projeto relevante
/// 2. Emitir evento na timeline (project_events)
/// 3. Atualizar last_activity_at no executive_contexts
/// 4. Invalidar providers afetados (via Ref)
///
/// NÃO recalcula ExecutiveHealth nem relações diretamente — esses cálculos
/// são feitos pelo ProjectIntelligenceService ao ser invalidado.
class ExecutiveContextOrchestrator {
  final ExecutiveContextService _contextSvc;
  final ProjectEventService _eventSvc;

  ExecutiveContextOrchestrator({
    ExecutiveContextService? contextSvc,
    ProjectEventService? eventSvc,
  })  : _contextSvc = contextSvc ?? ExecutiveContextService(),
        _eventSvc = eventSvc ?? ProjectEventService();

  // ── Eventos de projeto ─────────────────────────────────────────────────────

  Future<void> onProjectCreated({
    required String projectId,
    required String projectName,
  }) async {
    await _emitAndUpdate(
      projectId: projectId,
      type: ProjectEventType.projectCreated,
      title: 'Projeto "$projectName" criado',
      description: 'Projeto adicionado ao portfólio.',
      sourceModule: 'projects',
      metadata: {'project_name': projectName},
    );
  }

  Future<void> onStageChanged({
    required String projectId,
    required String projectName,
    required String newStatus,
  }) async {
    await _emitAndUpdate(
      projectId: projectId,
      type: ProjectEventType.stageChanged,
      title: 'Estágio alterado: $newStatus',
      description: 'Projeto "$projectName" mudou para o estágio "$newStatus".',
      sourceModule: 'projects',
      metadata: {'status': newStatus, 'project_name': projectName},
    );
  }

  Future<void> onAnalysisCompleted({
    required String projectId,
    required String? marketAnalysisId,
    required int opportunityScore,
  }) async {
    await _emitAndUpdate(
      projectId: projectId,
      type: ProjectEventType.analysisCompleted,
      title: 'Análise de mercado concluída',
      description: 'Opportunity Score: $opportunityScore/100.',
      sourceModule: 'market_intelligence',
      sourceEntityId: marketAnalysisId,
      idempotencyKey: marketAnalysisId != null
          ? '${projectId}_analysisCompleted_$marketAnalysisId'
          : null,
      metadata: {'opportunity_score': opportunityScore},
    );
    if (marketAnalysisId != null) {
      await _contextSvc.upsert({
        'project_id': projectId,
        'last_analysis_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> onOpportunityCreated({
    required String projectId,
    required String opportunityId,
    required String opportunityTitle,
  }) async {
    await _emitAndUpdate(
      projectId: projectId,
      type: ProjectEventType.opportunityCreated,
      title: 'Nova oportunidade: $opportunityTitle',
      description: 'Oportunidade adicionada ao Lab.',
      sourceModule: 'opportunity_lab',
      sourceEntityId: opportunityId,
      metadata: {'opportunity_title': opportunityTitle},
    );
  }

  Future<void> onDecisionTaken({
    required String projectId,
    required String opportunityId,
    required String opportunityTitle,
  }) async {
    await _emitAndUpdate(
      projectId: projectId,
      type: ProjectEventType.decisionTaken,
      title: 'Oportunidade aprovada: $opportunityTitle',
      description: 'Decisão executiva registrada.',
      sourceModule: 'opportunity_lab',
      sourceEntityId: opportunityId,
      idempotencyKey: '${projectId}_decisionTaken_$opportunityId',
      metadata: {'opportunity_title': opportunityTitle},
    );
  }

  Future<void> onDocumentAdded({
    required String projectId,
    required String knowledgeItemId,
    required String documentTitle,
  }) async {
    await _emitAndUpdate(
      projectId: projectId,
      type: ProjectEventType.documentAdded,
      title: 'Documento adicionado: $documentTitle',
      description: 'Novo item de conhecimento indexado.',
      sourceModule: 'knowledge_vault',
      sourceEntityId: knowledgeItemId,
      idempotencyKey: '${projectId}_documentAdded_$knowledgeItemId',
      metadata: {'title': documentTitle},
    );
  }

  Future<void> onActionCompleted({
    required String projectId,
    required String actionId,
    required String actionTitle,
  }) async {
    await _emitAndUpdate(
      projectId: projectId,
      type: ProjectEventType.actionCompleted,
      title: 'Ação concluída: $actionTitle',
      description: 'Progresso de execução atualizado.',
      sourceModule: 'action_engine',
      sourceEntityId: actionId,
      idempotencyKey: '${projectId}_actionCompleted_$actionId',
      metadata: {'action_title': actionTitle},
    );
  }

  Future<void> onCheckInCompleted({
    required String projectId,
    required String projectName,
  }) async {
    await _emitAndUpdate(
      projectId: projectId,
      type: ProjectEventType.checkIn,
      title: 'Check-In executivo realizado',
      description: 'Revisão de "$projectName" concluída.',
      sourceModule: 'executive_intelligence',
      metadata: {'project_name': projectName},
    );
    await _contextSvc.markCheckInCompleted(projectId);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _emitAndUpdate({
    required String projectId,
    required ProjectEventType type,
    required String title,
    String description = '',
    Map<String, dynamic> metadata = const {},
    String? sourceModule,
    String? sourceEntityId,
    String? idempotencyKey,
  }) async {
    // Emite evento na timeline persistida
    await _eventSvc.emit(
      projectId: projectId,
      type: type,
      title: title,
      description: description,
      metadata: metadata,
      sourceModule: sourceModule,
      sourceEntityId: sourceEntityId,
      idempotencyKey: idempotencyKey,
    );

    // Atualiza última atividade no contexto executivo (upsert seguro)
    await _contextSvc.updateLastActivity(projectId);
  }
}

// ── Providers globais ─────────────────────────────────────────────────────────

final executiveContextServiceProvider =
    Provider<ExecutiveContextService>((_) => ExecutiveContextService());

final executiveContextOrchestratorProvider =
    Provider<ExecutiveContextOrchestrator>(
        (ref) => ExecutiveContextOrchestrator(
              contextSvc: ref.read(executiveContextServiceProvider),
              eventSvc: ProjectEventService(),
            ));
