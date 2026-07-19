import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/asset_import_proposal.dart';
import '../data/models/asset_import_result.dart';
import '../data/models/ingestion_source.dart';
import '../data/services/asset_classifier_service.dart';
import '../data/services/asset_duplicate_checker.dart';
import '../data/services/asset_ingestion_service.dart';
import '../data/services/ingestion/text_parser.dart';
import '../data/services/ingestion/url_parser.dart';
import '../data/services/ingestion/zip_ingestion_service.dart';

// ── Service providers ────────────────────────────────────────────────────────

final assetClassifierServiceProvider =
    Provider<AssetClassifierService>((_) => const AssetClassifierService());

final assetDuplicateCheckerProvider =
    Provider<AssetDuplicateChecker>((_) => const AssetDuplicateChecker());

final textParserProvider =
    Provider<TextParser>((_) => const TextParser());

final urlParserProvider =
    Provider<UrlParser>((_) => UrlParser());

final zipIngestionServiceProvider =
    Provider<ZipIngestionService>((_) => ZipIngestionService());

final assetIngestionServiceProvider =
    Provider<AssetIngestionServiceInterface>((ref) => AssetIngestionService(
      classifier:      ref.read(assetClassifierServiceProvider),
      duplicateChecker: ref.read(assetDuplicateCheckerProvider),
      textParser:      ref.read(textParserProvider),
      urlParser:       ref.read(urlParserProvider),
      zipService:      ref.read(zipIngestionServiceProvider),
    ));

// ── Session notifier ─────────────────────────────────────────────────────────

class AssetIngestionNotifier extends StateNotifier<IngestionSession?> {
  AssetIngestionNotifier(this._svc) : super(null);

  final AssetIngestionServiceInterface _svc;

  Future<void> startWithText({
    required String text,
    required String projectId,
    IngestionSource source = IngestionSource.text,
    String? title,
  }) async {
    _setLoading(source, IngestionStatus.parsing);
    try {
      final proposal = await _svc.ingestText(
        text:      text,
        projectId: projectId,
        source:    source,
        title:     title,
      );
      _setProposal(proposal);
    } catch (e) {
      _setError(source, e.toString());
    }
  }

  Future<void> startWithUrl({
    required String url,
    required String projectId,
  }) async {
    _setLoading(IngestionSource.url, IngestionStatus.parsing);
    try {
      final proposal = await _svc.ingestUrl(url: url, projectId: projectId);
      _setProposal(proposal);
    } catch (e) {
      _setError(IngestionSource.url, e.toString());
    }
  }

  Future<void> startWithBytes({
    required Uint8List      bytes,
    required IngestionSource source,
    required String          projectId,
    String? fileName,
  }) async {
    _setLoading(source, IngestionStatus.parsing);
    try {
      final proposal = await _svc.ingestBytes(
        bytes:     bytes,
        source:    source,
        projectId: projectId,
        fileName:  fileName,
      );
      _setProposal(proposal);
    } catch (e) {
      _setError(source, e.toString());
    }
  }

  Future<void> confirm({
    required String                  confirmedTitle,
    required IngestionClassification confirmedClassification,
    String?           confirmedType,
    String?           targetAssetId,
    DuplicateDecision duplicateDecision = DuplicateDecision.createNew,
  }) async {
    final current = state;
    if (current == null || current.proposal == null) return;

    state = current.copyWith(status: IngestionStatus.creating, progress: 0.8, progressLabel: 'Criando...');
    try {
      final result = await _svc.confirmProposal(
        proposal:                current.proposal!,
        confirmedTitle:          confirmedTitle,
        confirmedClassification: confirmedClassification,
        confirmedType:           confirmedType,
        targetAssetId:           targetAssetId,
        duplicateDecision:       duplicateDecision,
      );
      state = current.copyWith(
        status:        IngestionStatus.completed,
        result:        result,
        progress:      1.0,
        progressLabel: 'Concluído',
        clearProposal: true,
      );
    } catch (e) {
      state = current.copyWith(
        status: IngestionStatus.failed,
        error:  e.toString(),
      );
    }
  }

  Future<void> cancel() async {
    final current = state;
    if (current == null) return;
    await _svc.cancelSession(current.sessionId);
    state = current.copyWith(status: IngestionStatus.cancelled, clearError: true);
  }

  void reset() => state = null;

  void updateProposal(AssetImportProposal updated) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(proposal: updated);
  }

  // ── Private ─────────────────────────────────────────────────────────────

  void _setLoading(IngestionSource src, IngestionStatus status) {
    final sessionId = 'ing_${DateTime.now().millisecondsSinceEpoch}';
    state = IngestionSession(
      sessionId:     sessionId,
      source:        src,
      status:        status,
      progress:      0.3,
      progressLabel: 'Processando...',
    );
  }

  void _setProposal(AssetImportProposal proposal) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
      status:        IngestionStatus.awaitingConfirmation,
      proposal:      proposal,
      progress:      0.7,
      progressLabel: 'Aguardando confirmação',
    );
  }

  void _setError(IngestionSource src, String error) {
    final sessionId = state?.sessionId ?? 'ing_error';
    state = IngestionSession(
      sessionId: sessionId,
      source:    src,
      status:    IngestionStatus.failed,
      error:     error,
    );
  }
}

final assetIngestionProvider = StateNotifierProvider.autoDispose<
    AssetIngestionNotifier, IngestionSession?>(
  (ref) => AssetIngestionNotifier(ref.read(assetIngestionServiceProvider)),
);
