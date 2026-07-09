import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/performance_metrics.dart';
import '../data/services/performance_service.dart';

final performanceServiceProvider =
    Provider<PerformanceService>((_) => PerformanceService());

final performanceMetricsProvider =
    FutureProvider.autoDispose<List<PerformanceMetrics>>((ref) {
  return ref.watch(performanceServiceProvider).fetchAll();
});

class PerformanceNotifier
    extends StateNotifier<AsyncValue<PerformanceMetrics?>> {
  PerformanceNotifier(this._service) : super(const AsyncValue.data(null));

  final PerformanceService _service;

  Future<PerformanceMetrics?> create(PerformanceMetrics metrics) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.create(metrics);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
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

final performanceNotifierProvider = StateNotifierProvider.autoDispose<
    PerformanceNotifier, AsyncValue<PerformanceMetrics?>>(
  (ref) => PerformanceNotifier(ref.watch(performanceServiceProvider)),
);
