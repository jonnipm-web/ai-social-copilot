import 'asset_import_proposal.dart';
import 'ingestion_source.dart';

/// Resultado final após o usuário confirmar a ingestão.
/// Gerado somente após persistência bem-sucedida.
class AssetImportResult {
  const AssetImportResult({
    required this.sessionId,
    required this.source,
    required this.classification,
    required this.createdAt,
    this.createdAssetId,
    this.linkedAssetId,
    this.createdResourceId,
    this.childResults = const [],
    this.warnings = const [],
  });

  final String                   sessionId;
  final IngestionSource          source;
  final IngestionClassification  classification;
  final DateTime                 createdAt;

  /// ID do asset criado (se classification == asset).
  final String? createdAssetId;

  /// ID do asset ao qual foi vinculado (se classification == resource/evidence).
  final String? linkedAssetId;

  /// ID do recurso criado (se classification == resource/evidence).
  final String? createdResourceId;

  /// Resultados dos filhos (para ZIP com múltiplos itens).
  final List<AssetImportResult> childResults;

  final List<String> warnings;

  bool get createdAsset    => createdAssetId    != null;
  bool get createdResource => createdResourceId != null;
  bool get hasChildren     => childResults.isNotEmpty;

  int get totalAssetsCreated =>
      (createdAsset ? 1 : 0) +
      childResults.fold(0, (sum, r) => sum + r.totalAssetsCreated);

  int get totalResourcesCreated =>
      (createdResource ? 1 : 0) +
      childResults.fold(0, (sum, r) => sum + r.totalResourcesCreated);
}

/// Estado da sessão de ingestão em andamento (para o provider).
class IngestionSession {
  const IngestionSession({
    required this.sessionId,
    required this.source,
    required this.status,
    this.proposal,
    this.result,
    this.error,
    this.progress = 0.0,
    this.progressLabel = '',
  });

  final String               sessionId;
  final IngestionSource      source;
  final IngestionStatus      status;
  final AssetImportProposal? proposal;
  final AssetImportResult?   result;
  final String?              error;
  final double               progress;
  final String               progressLabel;

  bool get isLoading    => status == IngestionStatus.importing ||
                           status == IngestionStatus.parsing   ||
                           status == IngestionStatus.classifying ||
                           status == IngestionStatus.checkingDuplicates ||
                           status == IngestionStatus.creating;
  bool get isDone       => status == IngestionStatus.completed ||
                           status == IngestionStatus.cancelled  ||
                           status == IngestionStatus.failed;
  bool get needsConfirmation => status == IngestionStatus.awaitingConfirmation;
  bool get hasError     => error != null;

  IngestionSession copyWith({
    String?               sessionId,
    IngestionSource?      source,
    IngestionStatus?      status,
    AssetImportProposal?  proposal,
    AssetImportResult?    result,
    String?               error,
    double?               progress,
    String?               progressLabel,
    bool                  clearError    = false,
    bool                  clearProposal = false,
    bool                  clearResult   = false,
  }) => IngestionSession(
    sessionId:     sessionId     ?? this.sessionId,
    source:        source        ?? this.source,
    status:        status        ?? this.status,
    proposal:      clearProposal ? null : (proposal ?? this.proposal),
    result:        clearResult   ? null : (result   ?? this.result),
    error:         clearError    ? null : (error    ?? this.error),
    progress:      progress      ?? this.progress,
    progressLabel: progressLabel ?? this.progressLabel,
  );
}

// Re-export IngestionStatus for convenience
export 'ingestion_source.dart' show IngestionStatus;
