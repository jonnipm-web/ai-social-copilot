import 'ive_issue.dart';

enum IveEventType {
  // Knowledge Vault
  assetImportStarted,
  assetDownloadFailed,
  assetAnalysisStarted,
  assetAnalysisCompleted,
  assetAnalysisFailed,
  // Ecosystem
  scoreChanged,
  opportunityDetected,
  actionGenerated,
  // Action Engine
  actionMutationFailed,
  // Decision Simulator
  simulationCompleted,
  // Projects
  projectCreated,
}

class IveEvent {
  final IveEventType         type;
  final String?              entityId;
  final String?              entityName;
  final IveIssue?            issue;
  final Map<String, dynamic> payload;
  final DateTime             timestamp;

  const IveEvent({
    required this.type,
    this.entityId,
    this.entityName,
    this.issue,
    this.payload  = const {},
    required this.timestamp,
  });

  factory IveEvent.knowledgeAnalysisStarted({
    required String itemId,
    required String itemName,
  }) =>
      IveEvent(
        type:       IveEventType.assetAnalysisStarted,
        entityId:   itemId,
        entityName: itemName,
        timestamp:  DateTime.now(),
      );

  factory IveEvent.knowledgeAnalysisCompleted({
    required String itemId,
    required String itemName,
    int opportunityScore = 0,
  }) =>
      IveEvent(
        type:       IveEventType.assetAnalysisCompleted,
        entityId:   itemId,
        entityName: itemName,
        payload:    {'opportunityScore': opportunityScore},
        timestamp:  DateTime.now(),
      );

  factory IveEvent.knowledgeAnalysisFailed({
    required String itemId,
    required String itemName,
    required String technicalError,
  }) =>
      IveEvent(
        type:      IveEventType.assetAnalysisFailed,
        entityId:  itemId,
        entityName: itemName,
        issue:     IveIssue.knowledgeAnalysisFailed(
          itemId:         itemId,
          itemName:       itemName,
          technicalError: technicalError,
        ),
        timestamp: DateTime.now(),
      );

  factory IveEvent.actionMutationFailed({
    required String actionTitle,
    required String technicalError,
  }) =>
      IveEvent(
        type:       IveEventType.actionMutationFailed,
        entityName: actionTitle,
        issue:      IveIssue.actionMutationFailed(
          actionTitle:    actionTitle,
          technicalError: technicalError,
        ),
        timestamp: DateTime.now(),
      );
}
