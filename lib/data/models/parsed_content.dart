import 'asset_provenance.dart';
import 'ingestion_source.dart';

/// Conteúdo parseado de qualquer fonte de ingestão.
/// Mantém o conteúdo original e o estruturado separados.
class ParsedContent {
  const ParsedContent({
    required this.rawText,
    required this.provenance,
    this.structuredData,
    this.title,
    this.description,
    this.mimeType,
    this.sizeBytes,
    this.fingerprint,
    this.encoding,
    this.metadata = const {},
    this.warnings = const [],
  });

  /// Texto extraído sem processamento (preservação do original).
  final String rawText;

  /// Dados estruturados extraídos (título, autor, URLs, etc.).
  final Map<String, dynamic>? structuredData;

  /// Título detectado automaticamente (pode ser sobrescrito pelo usuário).
  final String? title;

  /// Descrição/resumo extraído.
  final String? description;

  /// MIME type real detectado (não confiado da extensão).
  final String? mimeType;

  /// Tamanho em bytes do conteúdo original.
  final int? sizeBytes;

  /// SHA-256 do conteúdo original para de-duplicação.
  final String? fingerprint;

  /// Encoding detectado (ex: utf-8, latin-1).
  final String? encoding;

  /// Metadados extras (ex: número de páginas, autor, data de criação).
  final Map<String, dynamic> metadata;

  /// Avisos não fatais durante o parsing.
  final List<String> warnings;

  /// Rastreabilidade da origem.
  final AssetProvenance provenance;

  bool get hasStructuredData => structuredData != null && structuredData!.isNotEmpty;
  bool get hasFingerprint    => fingerprint != null && fingerprint!.isNotEmpty;
  bool get hasWarnings       => warnings.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'raw_text':        rawText,
    'provenance':      provenance.toMap(),
    'metadata':        metadata,
    'warnings':        warnings,
    if (structuredData != null) 'structured_data': structuredData,
    if (title          != null) 'title':           title,
    if (description    != null) 'description':     description,
    if (mimeType       != null) 'mime_type':       mimeType,
    if (sizeBytes      != null) 'size_bytes':      sizeBytes,
    if (fingerprint    != null) 'fingerprint':     fingerprint,
    if (encoding       != null) 'encoding':        encoding,
  };

  ParsedContent copyWith({
    String?                  rawText,
    Map<String, dynamic>?    structuredData,
    String?                  title,
    String?                  description,
    String?                  mimeType,
    int?                     sizeBytes,
    String?                  fingerprint,
    String?                  encoding,
    Map<String, dynamic>?    metadata,
    List<String>?            warnings,
    AssetProvenance?         provenance,
  }) => ParsedContent(
    rawText:        rawText        ?? this.rawText,
    structuredData: structuredData ?? this.structuredData,
    title:          title          ?? this.title,
    description:    description    ?? this.description,
    mimeType:       mimeType       ?? this.mimeType,
    sizeBytes:      sizeBytes      ?? this.sizeBytes,
    fingerprint:    fingerprint    ?? this.fingerprint,
    encoding:       encoding       ?? this.encoding,
    metadata:       metadata       ?? this.metadata,
    warnings:       warnings       ?? this.warnings,
    provenance:     provenance     ?? this.provenance,
  );
}

/// Um item detectado dentro de um container (ex: arquivo dentro de ZIP).
class DetectedItem {
  const DetectedItem({
    required this.name,
    required this.relativePath,
    required this.source,
    required this.content,
    this.suggestedClassification,
  });

  final String                   name;
  final String                   relativePath;
  final IngestionSource          source;
  final ParsedContent            content;
  final IngestionClassification? suggestedClassification;
}
