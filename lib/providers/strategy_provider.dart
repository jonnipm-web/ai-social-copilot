import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/knowledge_analysis.dart';
import '../data/models/knowledge_item.dart';
import '../data/models/knowledge_strategy.dart';
import '../data/services/strategy_service.dart';

final strategyServiceProvider =
    Provider<StrategyService>((_) => StrategyService());

final knowledgeStrategyProvider =
    FutureProvider.autoDispose.family<KnowledgeStrategy?, String>(
        (ref, itemId) {
  return ref.watch(strategyServiceProvider).fetchByItemId(itemId);
});

class StrategyNotifier
    extends StateNotifier<AsyncValue<KnowledgeStrategy?>> {
  StrategyNotifier(this._service) : super(const AsyncValue.data(null));

  final StrategyService _service;

  Future<KnowledgeStrategy?> generate(
    KnowledgeItem item,
    KnowledgeAnalysis analysis,
  ) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.generate(item, analysis);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final strategyNotifierProvider = StateNotifierProvider.autoDispose<
    StrategyNotifier, AsyncValue<KnowledgeStrategy?>>(
  (ref) => StrategyNotifier(ref.watch(strategyServiceProvider)),
);
