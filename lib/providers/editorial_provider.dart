import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/editorial_history_entry.dart';
import '../data/models/excerpt_result.dart';
import '../data/services/editorial_service.dart';

final editorialServiceProvider =
    Provider<EditorialService>((ref) => EditorialService());

final editorialHistoryProvider =
    FutureProvider<List<EditorialHistoryEntry>>((ref) async {
  return ref.read(editorialServiceProvider).fetchHistory();
});

class ExcerptNotifier extends StateNotifier<AsyncValue<ExcerptResult?>> {
  ExcerptNotifier(this._service) : super(const AsyncValue.data(null));
  final EditorialService _service;

  Future<void> extract(String text, {dynamic brand}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.extractExcerpts(text, brand: brand);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() => state = const AsyncValue.data(null);
}

final excerptNotifierProvider =
    StateNotifierProvider.autoDispose<ExcerptNotifier, AsyncValue<ExcerptResult?>>(
        (ref) => ExcerptNotifier(ref.read(editorialServiceProvider)));

class RepurposingNotifier
    extends StateNotifier<AsyncValue<RepurposedContent?>> {
  RepurposingNotifier(this._service) : super(const AsyncValue.data(null));
  final EditorialService _service;

  Future<void> repurpose(
    String text, {
    dynamic brand,
    dynamic persona,
    String platform = '',
    String objective = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.repurposeContent(
        text,
        brand: brand,
        persona: persona,
        platform: platform,
        objective: objective,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() => state = const AsyncValue.data(null);
}

final repurposingNotifierProvider = StateNotifierProvider.autoDispose<
    RepurposingNotifier, AsyncValue<RepurposedContent?>>(
  (ref) => RepurposingNotifier(ref.read(editorialServiceProvider)),
);

class CalendarNotifier extends StateNotifier<AsyncValue<CalendarPlan?>> {
  CalendarNotifier(this._service) : super(const AsyncValue.data(null));
  final EditorialService _service;

  Future<void> generate({
    required dynamic brand,
    dynamic persona,
    required String objective,
    required String platform,
    required int periodDays,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.generateCalendar(
        brand: brand,
        persona: persona,
        objective: objective,
        platform: platform,
        periodDays: periodDays,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() => state = const AsyncValue.data(null);
}

final calendarNotifierProvider = StateNotifierProvider.autoDispose<
    CalendarNotifier, AsyncValue<CalendarPlan?>>(
  (ref) => CalendarNotifier(ref.read(editorialServiceProvider)),
);
