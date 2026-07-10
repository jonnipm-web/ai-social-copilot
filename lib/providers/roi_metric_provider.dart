import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/roi_metric.dart';
import '../data/services/roi_metric_service.dart';

final roiMetricServiceProvider = Provider<RoiMetricService>((_) => RoiMetricService());

final roiMetricsProvider = FutureProvider.autoDispose<List<RoiMetric>>((ref) {
  return ref.read(roiMetricServiceProvider).fetchAll();
});

final roiSummaryProvider = FutureProvider.autoDispose<Map<String, double>>((ref) {
  return ref.read(roiMetricServiceProvider).summary();
});

class RoiMetricsNotifier extends StateNotifier<AsyncValue<List<RoiMetric>>> {
  RoiMetricsNotifier(this._service) : super(const AsyncValue.loading()) {
    load();
  }

  final RoiMetricService _service;

  Future<void> load({String? projectId}) async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.fetchAll(projectId: projectId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add({
    required String metricType,
    required double metricValue,
    String? projectId,
    String? notes,
  }) async {
    await _service.create(
      metricType: metricType,
      metricValue: metricValue,
      projectId: projectId,
      notes: notes,
    );
    await load();
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    await load();
  }
}

final roiMetricsNotifierProvider =
    StateNotifierProvider.autoDispose<RoiMetricsNotifier, AsyncValue<List<RoiMetric>>>(
  (ref) => RoiMetricsNotifier(ref.read(roiMetricServiceProvider)),
);
