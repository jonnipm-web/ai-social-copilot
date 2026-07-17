import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/knowledge_analysis.dart';
import '../data/models/knowledge_item.dart';
import '../data/services/knowledge_service.dart';

final knowledgeServiceProvider =
    Provider<KnowledgeService>((_) => KnowledgeService());

final knowledgeItemsProvider =
    FutureProvider.autoDispose<List<KnowledgeItem>>((ref) {
  return ref.watch(knowledgeServiceProvider).fetchAll();
});

final knowledgeItemsByProjectProvider =
    FutureProvider.autoDispose.family<List<KnowledgeItem>, String>((ref, projectId) {
  return ref.watch(knowledgeServiceProvider).fetchAll(projectId: projectId);
});

final knowledgeItemByIdProvider =
    FutureProvider.autoDispose.family<KnowledgeItem?, String>((ref, id) {
  return ref.watch(knowledgeServiceProvider).fetchById(id);
});

final knowledgeAnalysisProvider =
    FutureProvider.autoDispose.family<KnowledgeAnalysis?, String>(
        (ref, itemId) {
  return ref.watch(knowledgeServiceProvider).fetchAnalysis(itemId);
});

final knowledgeAnalysisByProjectProvider =
    FutureProvider.autoDispose.family<List<KnowledgeAnalysis>, String>(
        (ref, projectId) {
  return ref.watch(knowledgeServiceProvider).fetchAnalysisByProject(projectId);
});

// ── Notifier for CRUD ────────────────────────────────────────

class KnowledgeItemNotifier extends StateNotifier<AsyncValue<KnowledgeItem?>> {
  KnowledgeItemNotifier(this._service) : super(const AsyncValue.data(null));

  final KnowledgeService _service;

  Future<KnowledgeItem?> create(KnowledgeItem item) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.create(item);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<KnowledgeItem?> update(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.update(id, data);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.delete(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final knowledgeItemNotifierProvider = StateNotifierProvider.autoDispose<
    KnowledgeItemNotifier, AsyncValue<KnowledgeItem?>>(
  (ref) => KnowledgeItemNotifier(ref.watch(knowledgeServiceProvider)),
);

// ── Notifier for AI analysis ─────────────────────────────────

class KnowledgeAnalysisNotifier
    extends StateNotifier<AsyncValue<KnowledgeAnalysis?>> {
  KnowledgeAnalysisNotifier(this._service)
      : super(const AsyncValue.data(null));

  final KnowledgeService _service;

  Future<KnowledgeAnalysis?> analyze(KnowledgeItem item) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.analyzeItem(item);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final knowledgeAnalysisNotifierProvider = StateNotifierProvider.autoDispose
    .family<KnowledgeAnalysisNotifier, AsyncValue<KnowledgeAnalysis?>, String>(
  (ref, itemId) => KnowledgeAnalysisNotifier(ref.watch(knowledgeServiceProvider)),
);
