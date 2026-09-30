import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/language_utils.dart';
import '../data/models/website_analysis.dart';
import '../data/services/website_analyzer_service.dart';
import '../data/services/content_localization_service.dart';

final websiteAnalyzerServiceProvider =
    Provider<WebsiteAnalyzerService>((ref) => WebsiteAnalyzerService(localizer: ref.watch(rowLocalizerProvider)));

final websiteAnalysesProvider =
    FutureProvider.autoDispose<List<WebsiteAnalysis>>((ref) {
  return ref.watch(websiteAnalyzerServiceProvider).fetchAll();
});

class WebsiteAnalyzerNotifier
    extends StateNotifier<AsyncValue<WebsiteAnalysis?>> {
  WebsiteAnalyzerNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  final WebsiteAnalyzerService _service;
  final Ref _ref;

  Future<WebsiteAnalysis?> analyze(String url, {String? idempotencyKey}) async {
    state = const AsyncValue.loading();
    try {
      // R16 — output language = presentation language.
      final result = await _service.analyzeUrl(
        url,
        outputLanguage: _ref.read(outputLanguageCodeProvider),
        idempotencyKey: idempotencyKey,
      );
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final websiteAnalyzerNotifierProvider = StateNotifierProvider.autoDispose<
    WebsiteAnalyzerNotifier, AsyncValue<WebsiteAnalysis?>>(
  (ref) => WebsiteAnalyzerNotifier(ref.watch(websiteAnalyzerServiceProvider), ref),
);

final websiteAnalysisByIdProvider =
    FutureProvider.autoDispose.family<WebsiteAnalysis, String>((ref, id) async {
  final result = await ref.watch(websiteAnalyzerServiceProvider).fetchById(id);
  if (result == null) throw Exception('Análise não encontrada');
  return result;
});
