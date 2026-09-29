import '../../l10n/app_localizations.dart';

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

  /// R16 — display label in the presentation language, resolved from the
  /// stable [actionKey]. [label] is only a fallback for custom keys.
  String localizedLabel(AppLocalizations l10n) {
    switch (actionKey) {
      case 'retry':        return l10n.commonRetry;
      case 'view_details': return l10n.ctxIssueActionViewDetails;
      case 'update_link':  return l10n.ctxIssueActionUpdateLink;
      case 'send_file':    return l10n.ctxIssueActionSendFile;
      case 'dismiss':      return l10n.ctxIssueActionDismiss;
      default:             return label.isNotEmpty ? label : actionKey;
    }
  }
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
    required this.occurredAt,
  });

  /// R16 — user-facing message in the presentation language, resolved from
  /// the stable [errorCode] + [entityName]. [userMessage] is only a fallback
  /// for issues built with a custom (unmapped) code.
  String localizedMessage(AppLocalizations l10n) {
    final name = entityName ?? '';
    switch (errorCode) {
      case 'KNOWLEDGE_ANALYSIS_FAILED': return l10n.ctxIssueAnalysisFailed(name);
      case 'KNOWLEDGE_DOWNLOAD_FAILED': return l10n.ctxIssueDownloadFailed(name);
      case 'ACTION_MUTATION_FAILED':    return l10n.ctxIssueActionMutationFailed(name);
      default:                          return userMessage;
    }
  }

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
        userMessage:      '', // R16: localized via localizedMessage(l10n)
        technicalMessage: technicalError,
        entityId:         itemId,
        entityName:       itemName,
        occurredAt:       DateTime.now(),
        recommendedActions: const [
          IveIssueAction(label: '', actionKey: 'retry'),
          IveIssueAction(label: '', actionKey: 'view_details'),
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
        userMessage:      '', // R16: localized via localizedMessage(l10n)
        technicalMessage: technicalError,
        entityId:         itemId,
        entityName:       itemName,
        occurredAt:       DateTime.now(),
        recommendedActions: const [
          IveIssueAction(label: '', actionKey: 'retry'),
          IveIssueAction(label: '', actionKey: 'update_link'),
          IveIssueAction(label: '', actionKey: 'send_file'),
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
        userMessage:      '', // R16: localized via localizedMessage(l10n)
        technicalMessage: technicalError,
        entityName:       actionTitle,
        occurredAt:       DateTime.now(),
        recommendedActions: const [
          IveIssueAction(label: '', actionKey: 'retry'),
        ],
      );
}
