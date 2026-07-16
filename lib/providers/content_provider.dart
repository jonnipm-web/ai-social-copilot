import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/content_item.dart';
import '../data/services/content_service.dart';

final contentServiceProvider = Provider<ContentService>((_) => ContentService());

final contentItemsProvider = FutureProvider.autoDispose<List<ContentItem>>((ref) {
  return ref.watch(contentServiceProvider).fetchAll();
});

final contentItemsByProjectProvider =
    FutureProvider.autoDispose.family<List<ContentItem>, String>((ref, projectId) {
  return ref.watch(contentServiceProvider).fetchAll(projectId: projectId);
});

final contentItemByIdProvider =
    FutureProvider.autoDispose.family<ContentItem?, String>((ref, id) {
  return ref.watch(contentServiceProvider).fetchById(id);
});

class ContentNotifier extends StateNotifier<AsyncValue<ContentItem?>> {
  ContentNotifier(this._service) : super(const AsyncValue.data(null));

  final ContentService _service;

  Future<ContentItem?> create(ContentItem item) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _service.create(item));
    state = result;
    return result.valueOrNull;
  }

  Future<ContentItem?> update(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _service.update(id, data));
    state = result;
    return result.valueOrNull;
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.delete(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final contentNotifierProvider =
    StateNotifierProvider.autoDispose<ContentNotifier, AsyncValue<ContentItem?>>(
        (ref) => ContentNotifier(ref.watch(contentServiceProvider)));
