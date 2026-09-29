import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/campaign.dart';
import '../models/knowledge_item.dart';
import '../models/knowledge_analysis.dart';
import '../models/knowledge_strategy.dart';
import 'content_localization_service.dart';

class CampaignService {
  CampaignService({RowLocalizer? localizer}) : _localizer = localizer ?? identityLocalizer;

  // R16 — presentation localization of persisted content (never modifies the
  // stored row; see content_localization_service.dart).
  final RowLocalizer _localizer;

  Future<List<Map<String, dynamic>>> _loc(String table, dynamic rows) =>
      _localizer(table, (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList());

  Future<Map<String, dynamic>> _locOne(String table, Map<String, dynamic> row) async =>
      (await _localizer(table, [row])).first;

  final _client = Supabase.instance.client;

  static const _tableCampaigns = 'campaigns';
  static const _edgeFunction   = 'generate-campaign';

  Future<List<Campaign>> fetchAll() async {
    final rows = await _client
        .from(_tableCampaigns)
        .select()
        .order('created_at', ascending: false);
    return (await _loc('campaigns', rows)).map((r) => Campaign.fromMap(r)).toList();
  }

  Future<Campaign?> fetchById(String id) async {
    final row = await _client
        .from(_tableCampaigns)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Campaign.fromMap(await _locOne('campaigns', row));
  }

  Future<List<Campaign>> fetchByItemId(String itemId) async {
    final rows = await _client
        .from(_tableCampaigns)
        .select()
        .eq('knowledge_item_id', itemId)
        .order('created_at', ascending: false);
    return (await _loc('campaigns', rows)).map((r) => Campaign.fromMap(r)).toList();
  }

  Future<void> delete(String id) async {
    await _client.from(_tableCampaigns).delete().eq('id', id);
  }

  /// R16 — [outputLanguage] is the PRESENTATION language ('pt-BR'/'en-US');
  /// `item.language` is source metadata and never decides the output.
  Future<Campaign> generate({
    required KnowledgeItem item,
    required KnowledgeAnalysis analysis,
    KnowledgeStrategy? strategy,
    required String objective,
    required int durationDays,
    required List<String> channels,
    required String outputLanguage,
    String? idempotencyKey,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      _edgeFunction,
      body: {
        'title':             item.title,
        'objective':         objective,
        'duration_days':     durationDays,
        'channels':          channels,
        'niche':             item.niche ?? '',
        'target_audience':   item.targetAudience ?? '',
        'language':          outputLanguage,
        'summary':           analysis.summary ?? '',
        'value_proposition': strategy?.valueProposition ?? '',
        'keywords':          analysis.keywordsPrimary,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );

    if (response.data == null) {
      throw Exception('Resposta vazia da função de campanha.');
    }

    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final campaignName = data['campaign_name'] as String? ?? item.title;

    final row = await _client
        .from(_tableCampaigns)
        .insert({
          'user_id':           uid,
          'knowledge_item_id': item.id,
          'title':             campaignName,
          'objective':         objective,
          'duration_days':     durationDays,
          'channels':          channels,
          'campaign_json':     data,
        })
        .select()
        .single();

    return Campaign.fromMap(row);
  }
}
