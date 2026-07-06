import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/campaign.dart';
import '../data/models/knowledge_analysis.dart';
import '../data/models/knowledge_item.dart';
import '../data/models/knowledge_strategy.dart';
import '../data/services/campaign_service.dart';

final campaignServiceProvider =
    Provider<CampaignService>((_) => CampaignService());

final campaignsProvider =
    FutureProvider.autoDispose<List<Campaign>>((ref) {
  return ref.watch(campaignServiceProvider).fetchAll();
});

final campaignsByItemProvider =
    FutureProvider.autoDispose.family<List<Campaign>, String>((ref, itemId) {
  return ref.watch(campaignServiceProvider).fetchByItemId(itemId);
});

final campaignByIdProvider =
    FutureProvider.autoDispose.family<Campaign?, String>((ref, id) {
  return ref.watch(campaignServiceProvider).fetchById(id);
});

class CampaignNotifier extends StateNotifier<AsyncValue<Campaign?>> {
  CampaignNotifier(this._service) : super(const AsyncValue.data(null));

  final CampaignService _service;

  Future<Campaign?> generate({
    required KnowledgeItem item,
    required KnowledgeAnalysis analysis,
    KnowledgeStrategy? strategy,
    required String objective,
    required int durationDays,
    required List<String> channels,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.generate(
        item:          item,
        analysis:      analysis,
        strategy:      strategy,
        objective:     objective,
        durationDays:  durationDays,
        channels:      channels,
      );
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

final campaignNotifierProvider = StateNotifierProvider.autoDispose<
    CampaignNotifier, AsyncValue<Campaign?>>(
  (ref) => CampaignNotifier(ref.watch(campaignServiceProvider)),
);
