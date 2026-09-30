import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_memory.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_exceptions.dart';
import '../../l10n/app_localizations.dart';

class BusinessMemoryService {
  final _client = Supabase.instance.client;

  Future<List<BusinessMemory>> fetchAll({String? projectId, String? memoryType}) async {
    var filterBuilder = _client
        .from(AppConstants.tableBusinessMemory)
        .select();

    if (projectId != null) {
      filterBuilder = filterBuilder.eq('project_id', projectId);
    }
    if (memoryType != null) {
      filterBuilder = filterBuilder.eq('memory_type', memoryType);
    }

    final rows = await filterBuilder.order('created_at', ascending: false);
    return rows.map((r) => BusinessMemory.fromMap(r)).toList();
  }

  Future<BusinessMemory> create({
    required String memoryType,
    required String title,
    String content = '',
    int confidenceScore = 50,
    String source = '',
    String? projectId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const NotAuthenticatedException();

    final row = await _client
        .from(AppConstants.tableBusinessMemory)
        .insert(BusinessMemory(
          id:              '',
          userId:          uid,
          projectId:       projectId,
          memoryType:      memoryType,
          title:           title,
          content:         content,
          confidenceScore: confidenceScore,
          source:          source,
          createdAt:       DateTime.now(),
        ).toInsertMap())
        .select()
        .single();
    return BusinessMemory.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableBusinessMemory).delete().eq('id', id);
  }

  Future<Map<String, int>> summary() async {
    final list = await fetchAll();
    final map = <String, int>{};
    for (final m in list) {
      map[m.memoryType] = (map[m.memoryType] ?? 0) + 1;
    }
    return map;
  }

  Future<void> recordOpportunity({
    required String title,
    String content = '',
    String? projectId,
    String status = 'generated',
  }) async {
    await create(
      memoryType:      'opportunity',
      title:           title,
      content:         content,
      confidenceScore: 70,
      source:          'opportunity_discovery',
      projectId:       projectId,
    );
  }

  /// R16 — [l10n] must be the user's CURRENT UI-language localizations
  /// (e.g. `ref.read(appL10nProvider)`): the content is persisted.
  Future<void> recordCampaign({
    required String title,
    required bool success,
    required AppLocalizations l10n,
    String? projectId,
  }) async {
    await create(
      memoryType:      success ? 'success' : 'failure',
      title:           title,
      content:         success
          ? l10n.uxMemoryCampaignSucceeded
          : l10n.uxMemoryCampaignFailed,
      confidenceScore: 80,
      source:          'campaigns',
      projectId:       projectId,
    );
  }

  /// R16 — [l10n] must be the user's CURRENT UI-language localizations:
  /// the title is persisted.
  Future<void> recordRoi({
    required double roiValue,
    required String description,
    required AppLocalizations l10n,
    String? projectId,
  }) async {
    await create(
      memoryType:      'revenue',
      title:           l10n.uxMemoryRoiTitle(roiValue.toStringAsFixed(2)),
      content:         description,
      confidenceScore: 90,
      source:          'roi_tracker',
      projectId:       projectId,
    );
  }
}
