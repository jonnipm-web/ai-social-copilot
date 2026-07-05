import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/calendar_item.dart';
import '../data/services/calendar_service.dart';

final calendarServiceProvider = Provider<CalendarService>((_) => CalendarService());

final calendarItemsProvider = FutureProvider.autoDispose<List<CalendarItem>>((ref) {
  return ref.watch(calendarServiceProvider).fetchAll();
});

class CalendarNotifier extends StateNotifier<AsyncValue<CalendarItem?>> {
  CalendarNotifier(this._service) : super(const AsyncValue.data(null));

  final CalendarService _service;

  Future<CalendarItem?> create(CalendarItem item) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _service.create(item));
    state = result;
    return result.valueOrNull;
  }

  Future<void> updateStatus(String id, String status) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _service.updateStatus(id, status);
    });
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.delete(id));
  }
}

final calendarNotifierProvider =
    StateNotifierProvider.autoDispose<CalendarNotifier, AsyncValue<CalendarItem?>>(
        (ref) => CalendarNotifier(ref.watch(calendarServiceProvider)));
