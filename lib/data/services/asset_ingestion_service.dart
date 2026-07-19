import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../models/asset_import_proposal.dart';
import '../models/asset_import_result.dart';
import '../models/asset_resource.dart';
import '../models/ingestion_source.dart';
import '../models/parsed_content.dart';
import '../../core/constants/app_constants.dart';
import 'asset_classifier_service.dart';
import 'asset_duplicate_checker.dart';
import 'ingestion/asset_parser_interface.dart';
import 'ingestion/text_parser.dart';
import 'ingestion/url_parser.dart';
import 'ingestion/zip_ingestion_service.dart';

/// Orquestrador do fluxo completo de ingestão de ativos.
///
/// Fluxo:
///   SOURCE → PARSING → CLASSIFICATION → DUPLICATE CHECK → PROPOSAL
///   (usuário confirma)
///   PROPOSAL → CREATE / LINK → AssetImportResult
///
/// Nenhum dado é persistido antes da confirmação explícita do usuário.
abstract class AssetIngestionServiceInterface {
  Future<AssetImportProposal> ingestText({
    required String text,
    required String projectId,
    IngestionSource source = IngestionSource.text,
    String? title,
  });

  Future<AssetImportProposal> ingestUrl({
    required String url,
    required String projectId,
  });

  Future<AssetImportProposal> ingestBytes({
    required Uint8List      bytes,
    required IngestionSource source,
    required String         projectId,
    String? fileName,
  });

  Future<AssetImportResult> confirmProposal({
    required AssetImportProposal     proposal,
    required String                  confirmedTitle,
    required IngestionClassification confirmedClassification,
    String?           confirmedType,
    String?           targetAssetId,
    DuplicateDecision duplicateDecision = DuplicateDecision.createNew,
  });

  Future<void> cancelSession(String sessionId);
}

class AssetIngestionService implements AssetIngestionServiceInterface {
  AssetIngestionService({
    AssetClassifierService?  classifier,
    AssetDuplicateChecker?   duplicateChecker,
    TextParser?              textParser,
    UrlParser?               urlParser,
    ZipIngestionService?     zipService,
    AssetParserInterface?    edgeFunctionParser,
  }) :
    _classifier       = classifier       ?? const AssetClassifierService(),
    _duplicateChecker = duplicateChecker ?? const AssetDuplicateChecker(),
    _textParser       = textParser       ?? const TextParser(),
    _urlParser        = urlParser        ?? UrlParser(),
    _zipService       = zipService       ?? ZipIngestionService(),
    _edgeParser       = edgeFunctionParser;

  final AssetClassifierService  _classifier;
  final AssetDuplicateChecker   _duplicateChecker;
  final TextParser              _textParser;
  final UrlParser               _urlParser;
  final ZipIngestionService     _zipService;
  final AssetParserInterface?   _edgeParser;

  SupabaseClient get _client  => Supabase.instance.client;

  String get _currentUserId {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado');
    return uid;
  }

  @override
  Future<AssetImportProposal> ingestText({
    required String text,
    required String projectId,
    IngestionSource source = IngestionSource.text,
    String? title,
  }) async {
    final sessionId = _newSessionId();
    final content   = await _textParser.parseText(
      text,
      source: source,
      title:  title,
    );
    return _buildProposal(
      sessionId: sessionId,
      source:    source,
      content:   content,
      projectId: projectId,
    );
  }

  @override
  Future<AssetImportProposal> ingestUrl({
    required String url,
    required String projectId,
  }) async {
    final sessionId = _newSessionId();
    final content   = await _urlParser.parseText(
      url,
      source: IngestionSource.url,
    );
    return _buildProposal(
      sessionId: sessionId,
      source:    IngestionSource.url,
      content:   content,
      projectId: projectId,
    );
  }

  @override
  Future<AssetImportProposal> ingestBytes({
    required Uint8List      bytes,
    required IngestionSource source,
    required String         projectId,
    String? fileName,
  }) async {
    final sessionId = _newSessionId();

    ParsedContent content;
    List<AssetImportProposal> childProposals = [];

    switch (source) {
      case IngestionSource.txt:
        content = await _textParser.parseBytes(
          bytes,
          source:   source,
          fileName: fileName,
        );
      case IngestionSource.zip:
        content = await _zipService.parseBytes(
          bytes,
          source:   source,
          fileName: fileName,
        );
        childProposals = await _buildZipChildren(bytes, sessionId, projectId);
      default:
        if (_edgeParser != null) {
          content = await _edgeParser.parseBytes(
            bytes,
            source:   source,
            fileName: fileName,
          );
        } else {
          throw AssetParserException(
            'Parser não disponível para ${source.label}',
            source: source,
          );
        }
    }

    return _buildProposal(
      sessionId:     sessionId,
      source:        source,
      content:       content,
      projectId:     projectId,
      childProposals: childProposals,
    );
  }

  @override
  Future<AssetImportResult> confirmProposal({
    required AssetImportProposal proposal,
    required String              confirmedTitle,
    required IngestionClassification confirmedClassification,
    String?           confirmedType,
    String?           targetAssetId,
    DuplicateDecision duplicateDecision = DuplicateDecision.createNew,
  }) async {
    final uid       = _currentUserId;
    final createdAt = DateTime.now();

    // Handle duplicate decision
    if (proposal.hasDuplicates &&
        duplicateDecision == DuplicateDecision.useExisting) {
      final existing = proposal.duplicateCandidates.first;
      return AssetImportResult(
        sessionId:     proposal.sessionId,
        source:        proposal.source,
        classification: confirmedClassification,
        createdAt:     createdAt,
        linkedAssetId: existing.existingId,
        warnings:      ['Usando ativo existente: ${existing.existingTitle}'],
      );
    }

    switch (confirmedClassification) {
      case IngestionClassification.asset:
        final assetId = await _createAsset(
          uid:         uid,
          proposal:    proposal,
          title:       confirmedTitle,
          assetType:   confirmedType ?? 'other',
          targetAssetId: targetAssetId,
        );
        final childResults = await _confirmChildren(
          proposal.childProposals,
          parentAssetId: assetId,
        );
        return AssetImportResult(
          sessionId:      proposal.sessionId,
          source:         proposal.source,
          classification: confirmedClassification,
          createdAt:      createdAt,
          createdAssetId: assetId,
          childResults:   childResults,
          warnings:       proposal.parsedContent.warnings,
        );

      case IngestionClassification.resource:
      case IngestionClassification.evidence:
        if (targetAssetId == null) {
          throw Exception('targetAssetId é obrigatório para resource/evidence');
        }
        final resourceId = await _createResource(
          uid:        uid,
          proposal:   proposal,
          title:      confirmedTitle,
          assetId:    targetAssetId,
          resourceType: confirmedClassification == IngestionClassification.evidence
              ? 'evidence' : 'resource',
        );
        return AssetImportResult(
          sessionId:       proposal.sessionId,
          source:          proposal.source,
          classification:  confirmedClassification,
          createdAt:       createdAt,
          linkedAssetId:   targetAssetId,
          createdResourceId: resourceId,
          warnings:        proposal.parsedContent.warnings,
        );

      case IngestionClassification.ignored:
        return AssetImportResult(
          sessionId:      proposal.sessionId,
          source:         proposal.source,
          classification: confirmedClassification,
          createdAt:      createdAt,
          warnings:       ['Item ignorado pelo usuário'],
        );
    }
  }

  @override
  Future<void> cancelSession(String sessionId) async {
    // Session state is in-memory only (provider) — nothing to clean in DB.
  }

  // ── Private ───────────────────────────────────────────────────────────────

  String _newSessionId() =>
      'ing_${DateTime.now().millisecondsSinceEpoch}';

  Future<AssetImportProposal> _buildProposal({
    required String          sessionId,
    required IngestionSource source,
    required ParsedContent   content,
    required String          projectId,
    List<AssetImportProposal> childProposals = const [],
  }) async {
    final classification = _classifier.classify(content, source: source);
    final existingAssets = await _fetchProjectAssets(projectId);
    final dupeCheck      = _duplicateChecker.check(
      content:        content,
      existingAssets: existingAssets,
    );

    return AssetImportProposal(
      sessionId:               sessionId,
      source:                  source,
      classification:          classification.classification,
      parsedContent:           content,
      suggestedTitle:          content.title ?? '',
      suggestedDescription:    content.description,
      suggestedType:           classification.suggestedType,
      duplicateCandidates:     dupeCheck.candidates,
      childProposals:          childProposals,
      warnings:                content.warnings,
      classificationConfidence: classification.confidence,
    );
  }

  Future<List<Asset>> _fetchProjectAssets(String projectId) async {
    try {
      final uid  = _currentUserId;
      final rows = await _client
          .from(AppConstants.tableAssets)
          .select()
          .eq('user_id', uid)
          .eq('project_id', projectId);
      return (rows as List).map((r) => Asset.fromMap(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AssetImportProposal>> _buildZipChildren(
    Uint8List zipBytes,
    String sessionId,
    String projectId,
  ) async {
    try {
      final listing = await _zipService.listContents(zipBytes);
      final results = <AssetImportProposal>[];

      for (final item in listing.items.where((i) => i.isFile)) {
        try {
          final fileBytes = await _zipService.extractFile(zipBytes, item.relativePath);
          final src       = _sourceFromMime(item.mimeType);
          final content   = await _parseFileBytes(fileBytes, src, item.name);
          final classify  = _classifier.classify(content, source: src, fileName: item.name);
          final existing  = await _fetchProjectAssets(projectId);
          final dupeCheck = _duplicateChecker.check(content: content, existingAssets: existing);

          results.add(AssetImportProposal(
            sessionId:               '${sessionId}_${item.relativePath}',
            source:                  src,
            classification:          classify.classification,
            parsedContent:           content,
            suggestedTitle:          content.title ?? item.name,
            suggestedType:           classify.suggestedType,
            duplicateCandidates:     dupeCheck.candidates,
            classificationConfidence: classify.confidence,
          ));
        } catch (e) {
          // Non-fatal: skip this item and add a warning to parent
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  IngestionSource _sourceFromMime(String? mime) {
    if (mime == null) return IngestionSource.fileUpload;
    if (mime == 'application/pdf')  return IngestionSource.pdf;
    if (mime.startsWith('image/'))  return IngestionSource.image;
    if (mime == 'text/plain')       return IngestionSource.txt;
    if (mime == 'application/zip')  return IngestionSource.zip;
    return IngestionSource.fileUpload;
  }

  Future<ParsedContent> _parseFileBytes(
    Uint8List bytes,
    IngestionSource source,
    String? fileName,
  ) async {
    switch (source) {
      case IngestionSource.txt:
        return _textParser.parseBytes(bytes, source: source, fileName: fileName);
      default:
        if (_edgeParser != null) {
          return _edgeParser.parseBytes(bytes, source: source, fileName: fileName);
        }
        return _textParser.parseBytes(bytes, source: source, fileName: fileName);
    }
  }

  Future<String> _createAsset({
    required String               uid,
    required AssetImportProposal  proposal,
    required String               title,
    required String               assetType,
    String? targetAssetId,
  }) async {
    final content = proposal.parsedContent;
    final metadata = {
      ...content.metadata,
      'provenance': content.provenance.toMap(),
      if (content.fingerprint != null) 'fingerprint': content.fingerprint,
      if (content.structuredData != null) 'ingestion_data': content.structuredData,
    };

    final row = await _client
        .from(AppConstants.tableAssets)
        .insert({
          'user_id':         uid,
          'name':            title,
          'type':            assetType,
          'status':          'idea',
          'metadata':        metadata,
          if (proposal.suggestedDescription != null)
            'description': proposal.suggestedDescription,
          if (targetAssetId != null)
            'parent_asset_id': targetAssetId,
        })
        .select('id')
        .single();

    return row['id'] as String;
  }

  Future<String> _createResource({
    required String              uid,
    required AssetImportProposal proposal,
    required String              title,
    required String              assetId,
    required String              resourceType,
  }) async {
    final content   = proposal.parsedContent;
    final provenance = content.provenance;

    final resource = AssetResource(
      id:            '',
      assetId:       assetId,
      userId:        uid,
      resourceType:  resourceType,
      title:         title,
      description:   proposal.suggestedDescription,
      sourceType:    provenance.sourceType,
      sourceId:      provenance.sourceId,
      sourceUrl:     provenance.sourceUrl,
      rawText:       content.rawText.isNotEmpty ? content.rawText : null,
      structuredData: content.structuredData,
      mimeType:      content.mimeType,
      sizeBytes:     content.sizeBytes,
      fingerprint:   content.fingerprint,
      parserVersion: parserVersion,
      confidence:    provenance.confidence,
      createdAt:     DateTime.now(),
      metadata:      content.metadata,
    );

    final row = await _client
        .from(AppConstants.tableAssetResources)
        .insert(resource.toInsertMap())
        .select('id')
        .single();

    return row['id'] as String;
  }

  Future<List<AssetImportResult>> _confirmChildren(
    List<AssetImportProposal> children, {
    required String parentAssetId,
  }) async {
    final results = <AssetImportResult>[];
    for (final child in children) {
      try {
        final result = await confirmProposal(
          proposal:                child,
          confirmedTitle:          child.suggestedTitle,
          confirmedClassification: child.classification,
          confirmedType:           child.suggestedType,
          targetAssetId:           parentAssetId,
          duplicateDecision:       DuplicateDecision.createNew,
        );
        results.add(result);
      } catch (_) {
        // Non-fatal — continue with next child
      }
    }
    return results;
  }

  String get parserVersion => '1.0.0';
}
