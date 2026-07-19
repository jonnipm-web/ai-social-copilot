import 'ingestion_source.dart';

/// Registra a origem de qualquer dado extraído durante a ingestão.
/// Todo conteúdo importado deve carregar provenance para rastreabilidade.
class AssetProvenance {
  const AssetProvenance({
    required this.sourceType,
    required this.importedAt,
    required this.parserVersion,
    this.sourceId,
    this.sourceName,
    this.sourceUrl,
    this.confidence = 1.0,
  });

  final IngestionSource sourceType;
  final String?         sourceId;
  final String?         sourceName;
  final String?         sourceUrl;
  final DateTime        importedAt;
  final String          parserVersion;
  final double          confidence;

  Map<String, dynamic> toMap() => {
    'source_type':     sourceType.dbValue,
    'imported_at':     importedAt.toIso8601String(),
    'parser_version':  parserVersion,
    'confidence':      confidence,
    if (sourceId   != null) 'source_id':   sourceId,
    if (sourceName != null) 'source_name': sourceName,
    if (sourceUrl  != null) 'source_url':  sourceUrl,
  };

  factory AssetProvenance.fromMap(Map<String, dynamic> map) => AssetProvenance(
    sourceType:    IngestionSource.fromDb(map['source_type'] as String?),
    sourceId:      map['source_id']   as String?,
    sourceName:    map['source_name'] as String?,
    sourceUrl:     map['source_url']  as String?,
    importedAt:    DateTime.parse(map['imported_at'] as String),
    parserVersion: map['parser_version'] as String? ?? '1.0.0',
    confidence:    (map['confidence'] as num?)?.toDouble() ?? 1.0,
  );

  AssetProvenance copyWith({
    IngestionSource? sourceType,
    String?          sourceId,
    String?          sourceName,
    String?          sourceUrl,
    DateTime?        importedAt,
    String?          parserVersion,
    double?          confidence,
  }) => AssetProvenance(
    sourceType:    sourceType    ?? this.sourceType,
    sourceId:      sourceId      ?? this.sourceId,
    sourceName:    sourceName    ?? this.sourceName,
    sourceUrl:     sourceUrl     ?? this.sourceUrl,
    importedAt:    importedAt    ?? this.importedAt,
    parserVersion: parserVersion ?? this.parserVersion,
    confidence:    confidence    ?? this.confidence,
  );
}
