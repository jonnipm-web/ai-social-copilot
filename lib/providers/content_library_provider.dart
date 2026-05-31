import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/content_item.dart';
import '../data/services/content_library_service.dart';

final contentLibraryServiceProvider =
    Provider<ContentLibraryService>((ref) => ContentLibraryService());

final contentLibraryProvider =
    FutureProvider.family<List<ContentItem>, String?>((ref, brandId) async {
  return ref.read(contentLibraryServiceProvider).fetchAll(brandId: brandId);
});

class ContentLibraryNotifier extends StateNotifier<AsyncValue<void>> {
  ContentLibraryNotifier(this._service, this._ref)
      : super(const AsyncValue.data(null));

  final ContentLibraryService _service;
  final Ref _ref;

  Future<ContentItem?> create(ContentItem item) async {
    state = const AsyncValue.loading();
    try {
      final created = await _service.create(item);
      _ref.invalidate(contentLibraryProvider);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<ContentItem?> update(String id, Map<String, dynamic> fields) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _service.update(id, fields);
      _ref.invalidate(contentLibraryProvider);
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> setStatus(String id, String status) async {
    await _service.setStatus(id, status);
    _ref.invalidate(contentLibraryProvider);
  }
}

final contentLibraryNotifierProvider =
    StateNotifierProvider<ContentLibraryNotifier, AsyncValue<void>>((ref) {
  return ContentLibraryNotifier(
      ref.read(contentLibraryServiceProvider), ref);
});
