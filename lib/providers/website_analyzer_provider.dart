import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/website_analysis.dart';
import '../data/services/website_analyzer_service.dart';

final websiteAnalyzerServiceProvider =
    Provider<WebsiteAnalyzerService>((_) => WebsiteAnalyzerService());

final websiteAnalysesProvider =
    FutureProvider.autoDispose<List<WebsiteAnalysis>>((ref) {
  return ref.watch(websiteAnalyzerServiceProvider).fetchAll();
});

class WebsiteAnalyzerNotifier
    extends StateNotifier<AsyncValue<WebsiteAnalysis?>> {
  WebsiteAnalyzerNotifier(this._service) : super(const AsyncValue.data(null));

  final WebsiteAnalyzerService _service;

  Future<WebsiteAnalysis?> analyze(String url) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.analyzeUrl(url);
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
  (ref) => WebsiteAnalyzerNotifier(ref.watch(websiteAnalyzerServiceProvider)),
);

final websiteAnalysisByIdProvider =
    FutureProvider.autoDispose.family<WebsiteAnalysis, String>((ref, id) async {
  final result = await ref.read(websiteAnalyzerServiceProvider).fetchById(id);
  if (result == null) throw Exception('Análise não encontrada');
  return result;
});
