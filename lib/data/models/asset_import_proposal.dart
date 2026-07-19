import 'ingestion_source.dart';
import 'parsed_content.dart';

/// Proposta de criação/vínculo gerada após parsing e classificação.
/// Apresentada ao usuário ANTES da confirmação — nenhum dado é persistido ainda.
class AssetImportProposal {
  const AssetImportProposal({
    required this.sessionId,
    required this.source,
    required this.classification,
    required this.parsedContent,
    required this.suggestedTitle,
    this.suggestedDescription,
    this.suggestedType,
    this.targetAssetId,
    this.duplicateCandidates = const [],
    this.childProposals = const [],
    this.warnings = const [],
    this.classificationConfidence = 1.0,
  });

  /// ID único da sessão de ingestão (não persistido).
  final String sessionId;

  /// Fonte de onde veio o conteúdo.
  final IngestionSource source;

  /// Classificação sugerida (pode ser sobrescrita pelo usuário).
  final IngestionClassification classification;

  /// Conteúdo parseado com provenance.
  final ParsedContent parsedContent;

  /// Título sugerido (editável pelo usuário na UI).
  final String suggestedTitle;

  /// Descrição sugerida.
  final String? suggestedDescription;

  /// Tipo de asset sugerido (ex: 'book', 'product').
  final String? suggestedType;

  /// Se classification == resource ou evidence, qual asset recebe o vínculo.
  final String? targetAssetId;

  /// Possíveis duplicatas detectadas (para o usuário decidir).
  final List<DuplicateCandidate> duplicateCandidates;

  /// Sub-propostas (ex: itens dentro de um ZIP).
  final List<AssetImportProposal> childProposals;

  /// Avisos para o usuário (não bloqueiam, mas devem ser exibidos).
  final List<String> warnings;

  /// Confiança na classificação automática (0.0–1.0).
  final double classificationConfidence;

  bool get hasDuplicates   => duplicateCandidates.isNotEmpty;
  bool get hasChildren     => childProposals.isNotEmpty;
  bool get hasWarnings     => warnings.isNotEmpty;
  bool get isHighConfidence => classificationConfidence >= 0.8;

  AssetImportProposal copyWith({
    String?                    sessionId,
    IngestionSource?           source,
    IngestionClassification?   classification,
    ParsedContent?             parsedContent,
    String?                    suggestedTitle,
    String?                    suggestedDescription,
    String?                    suggestedType,
    String?                    targetAssetId,
    List<DuplicateCandidate>?  duplicateCandidates,
    List<AssetImportProposal>? childProposals,
    List<String>?              warnings,
    double?                    classificationConfidence,
    bool                       clearTargetAsset = false,
    bool                       clearDescription = false,
  }) => AssetImportProposal(
    sessionId:               sessionId               ?? this.sessionId,
    source:                  source                  ?? this.source,
    classification:          classification          ?? this.classification,
    parsedContent:           parsedContent           ?? this.parsedContent,
    suggestedTitle:          suggestedTitle          ?? this.suggestedTitle,
    suggestedDescription:    clearDescription ? null : (suggestedDescription ?? this.suggestedDescription),
    suggestedType:           suggestedType           ?? this.suggestedType,
    targetAssetId:           clearTargetAsset ? null : (targetAssetId ?? this.targetAssetId),
    duplicateCandidates:     duplicateCandidates     ?? this.duplicateCandidates,
    childProposals:          childProposals          ?? this.childProposals,
    warnings:                warnings                ?? this.warnings,
    classificationConfidence: classificationConfidence ?? this.classificationConfidence,
  );
}

/// Candidato a duplicata detectado durante o duplicate check.
class DuplicateCandidate {
  const DuplicateCandidate({
    required this.existingId,
    required this.existingTitle,
    required this.matchReason,
    required this.confidence,
    this.existingType,
  });

  final String  existingId;
  final String  existingTitle;
  final String? existingType;
  final String  matchReason;
  final double  confidence;

  String get confidenceLabel {
    if (confidence >= 0.9) return 'Alta';
    if (confidence >= 0.7) return 'Média';
    return 'Baixa';
  }
}

/// Decisão do usuário sobre uma duplicata detectada.
enum DuplicateDecision {
  useExisting,
  updateExisting,
  createNew,
}
