enum IveIssueSeverity { info, warning, error, critical }

enum IveIssueStage {
  download,
  processing,
  analysis,
  sync,
  network,
  auth,
  unknown,
}

class IveIssueAction {
  final String label;
  final String actionKey; // 'retry' | 'update_link' | 'send_file' | 'view_details' | 'dismiss'

  const IveIssueAction({required this.label, required this.actionKey});
}

class IveIssue {
  final String             errorCode;
  final IveIssueStage      stage;
  final IveIssueSeverity   severity;
  final bool               recoverable;
  final String             userMessage;
  final String             technicalMessage;
  final List<IveIssueAction> recommendedActions;
  final String?            entityId;
  final String?            entityName;
  // 'knowledge_item' | 'action' | null — usado para rotear o retry ao serviço correto
  final String?            entityType;
  final DateTime           occurredAt;

  const IveIssue({
    required this.errorCode,
    required this.stage,
    required this.severity,
    required this.recoverable,
    required this.userMessage,
    required this.technicalMessage,
    this.recommendedActions = const [],
    this.entityId,
    this.entityName,
    this.entityType,
    required this.occurredAt,
  });

  factory IveIssue.knowledgeAnalysisFailed({
    required String itemId,
    required String itemName,
    required String technicalError,
  }) =>
      IveIssue(
        errorCode:        'KNOWLEDGE_ANALYSIS_FAILED',
        stage:            IveIssueStage.analysis,
        severity:         IveIssueSeverity.error,
        recoverable:      true,
        userMessage:      'Não consegui analisar "$itemName".\n'
                          'A falha ocorreu durante o processamento pela IA.\n'
                          'Você pode tentar novamente.',
        technicalMessage: technicalError,
        entityId:         itemId,
        entityName:       itemName,
        entityType:       'knowledge_item',
        occurredAt:       DateTime.now(),
        recommendedActions: const [
          IveIssueAction(label: 'Tentar novamente', actionKey: 'retry'),
          IveIssueAction(label: 'Ver detalhes',     actionKey: 'view_details'),
        ],
      );

  factory IveIssue.knowledgeDownloadFailed({
    required String itemId,
    required String itemName,
    required String technicalError,
  }) =>
      IveIssue(
        errorCode:        'KNOWLEDGE_DOWNLOAD_FAILED',
        stage:            IveIssueStage.download,
        severity:         IveIssueSeverity.error,
        recoverable:      true,
        userMessage:      'Não consegui importar "$itemName".\n'
                          'A falha ocorreu durante o download do arquivo.\n'
                          'O conteúdo ainda não foi analisado.',
        technicalMessage: technicalError,
        entityId:         itemId,
        entityName:       itemName,
        entityType:       'knowledge_item',
        occurredAt:       DateTime.now(),
        recommendedActions: const [
          IveIssueAction(label: 'Tentar novamente', actionKey: 'retry'),
          IveIssueAction(label: 'Atualizar link',   actionKey: 'update_link'),
          IveIssueAction(label: 'Enviar arquivo',   actionKey: 'send_file'),
        ],
      );

  factory IveIssue.actionMutationFailed({
    required String actionTitle,
    required String technicalError,
  }) =>
      IveIssue(
        errorCode:        'ACTION_MUTATION_FAILED',
        stage:            IveIssueStage.network,
        severity:         IveIssueSeverity.warning,
        recoverable:      true,
        userMessage:      'Não consegui atualizar "$actionTitle".\n'
                          'Verifique sua conexão e tente novamente.',
        technicalMessage: technicalError,
        entityName:       actionTitle,
        entityType:       'action',
        occurredAt:       DateTime.now(),
        recommendedActions: const [
          IveIssueAction(label: 'Tentar novamente', actionKey: 'retry'),
          IveIssueAction(label: 'Ver detalhes',     actionKey: 'view_details'),
        ],
      );
}
