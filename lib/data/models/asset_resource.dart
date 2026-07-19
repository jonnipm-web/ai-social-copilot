import 'asset_provenance.dart';
import 'ingestion_source.dart';
import '../../core/utils/date_parser.dart';

/// Recurso vinculado a um Asset (arquivo, URL, texto, imagem, etc.).
/// Um arquivo não é automaticamente um Asset — pode ser Resource ou Evidence.
class AssetResource {
  const AssetResource({
    required this.id,
    required this.assetId,
    required this.userId,
    required this.resourceType,
    required this.title,
    required this.createdAt,
    this.description,
    this.sourceType,
    this.sourceId,
    this.sourceUrl,
    this.storagePath,
    this.mimeType,
    this.sizeBytes,
    this.fingerprint,
    this.rawText,
    this.structuredData,
    this.parserVersion,
    this.confidence = 1.0,
    this.metadata = const {},
  });

  final String               id;
  final String               assetId;
  final String               userId;
  final String               resourceType;
  final String               title;
  final String?              description;
  final IngestionSource?     sourceType;
  final String?              sourceId;
  final String?              sourceUrl;
  final String?              storagePath;
  final String?              mimeType;
  final int?                 sizeBytes;
  final String?              fingerprint;
  final String?              rawText;
  final Map<String, dynamic>? structuredData;
  final String?              parserVersion;
  final double               confidence;
  final DateTime             createdAt;
  final Map<String, dynamic> metadata;

  factory AssetResource.fromMap(Map<String, dynamic> map) => AssetResource(
    id:             map['id']             as String,
    assetId:        map['asset_id']       as String,
    userId:         map['user_id']        as String,
    resourceType:   map['resource_type']  as String,
    title:          map['title']          as String,
    description:    map['description']    as String?,
    sourceType:     IngestionSource.fromDb(map['source_type'] as String?),
    sourceId:       map['source_id']      as String?,
    sourceUrl:      map['source_url']     as String?,
    storagePath:    map['storage_path']   as String?,
    mimeType:       map['mime_type']      as String?,
    sizeBytes:      map['size_bytes']     as int?,
    fingerprint:    map['fingerprint']    as String?,
    rawText:        map['raw_text']       as String?,
    structuredData: map['structured_data'] as Map<String, dynamic>?,
    parserVersion:  map['parser_version'] as String?,
    confidence:     (map['confidence']    as num?)?.toDouble() ?? 1.0,
    createdAt:      DateParser.parse(map['created_at'] as String?),
    metadata:       (map['metadata']      as Map<String, dynamic>?) ?? {},
  );

  Map<String, dynamic> toInsertMap() => {
    'asset_id':      assetId,
    'user_id':       userId,
    'resource_type': resourceType,
    'title':         title,
    'confidence':    confidence,
    'metadata':      metadata,
    if (description    != null) 'description':    description,
    if (sourceType     != null) 'source_type':    sourceType!.dbValue,
    if (sourceId       != null) 'source_id':      sourceId,
    if (sourceUrl      != null) 'source_url':     sourceUrl,
    if (storagePath    != null) 'storage_path':   storagePath,
    if (mimeType       != null) 'mime_type':      mimeType,
    if (sizeBytes      != null) 'size_bytes':     sizeBytes,
    if (fingerprint    != null) 'fingerprint':    fingerprint,
    if (rawText        != null) 'raw_text':       rawText,
    if (structuredData != null) 'structured_data': structuredData,
    if (parserVersion  != null) 'parser_version': parserVersion,
  };

  AssetResource copyWith({
    String?                id,
    String?                assetId,
    String?                userId,
    String?                resourceType,
    String?                title,
    String?                description,
    IngestionSource?       sourceType,
    String?                sourceId,
    String?                sourceUrl,
    String?                storagePath,
    String?                mimeType,
    int?                   sizeBytes,
    String?                fingerprint,
    String?                rawText,
    Map<String, dynamic>?  structuredData,
    String?                parserVersion,
    double?                confidence,
    DateTime?              createdAt,
    Map<String, dynamic>?  metadata,
  }) => AssetResource(
    id:             id             ?? this.id,
    assetId:        assetId        ?? this.assetId,
    userId:         userId         ?? this.userId,
    resourceType:   resourceType   ?? this.resourceType,
    title:          title          ?? this.title,
    description:    description    ?? this.description,
    sourceType:     sourceType     ?? this.sourceType,
    sourceId:       sourceId       ?? this.sourceId,
    sourceUrl:      sourceUrl      ?? this.sourceUrl,
    storagePath:    storagePath    ?? this.storagePath,
    mimeType:       mimeType       ?? this.mimeType,
    sizeBytes:      sizeBytes      ?? this.sizeBytes,
    fingerprint:    fingerprint    ?? this.fingerprint,
    rawText:        rawText        ?? this.rawText,
    structuredData: structuredData ?? this.structuredData,
    parserVersion:  parserVersion  ?? this.parserVersion,
    confidence:     confidence     ?? this.confidence,
    createdAt:      createdAt      ?? this.createdAt,
    metadata:       metadata       ?? this.metadata,
  );

  AssetProvenance get provenance => AssetProvenance(
    sourceType:    sourceType    ?? IngestionSource.manual,
    sourceId:      sourceId,
    sourceName:    title,
    sourceUrl:     sourceUrl,
    importedAt:    createdAt,
    parserVersion: parserVersion ?? '1.0.0',
    confidence:    confidence,
  );
}
