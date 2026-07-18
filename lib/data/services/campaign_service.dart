import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/campaign.dart';
import '../models/knowledge_item.dart';
import '../models/knowledge_analysis.dart';
import '../models/knowledge_strategy.dart';

class CampaignService {
  final _client = Supabase.instance.client;

  static const _tableCampaigns = 'campaigns';
  static const _edgeFunction   = 'generate-campaign';

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    return uid;
  }

  Future<List<Campaign>> fetchAll() async {
    final uid = _requireUid();
    final rows = await _client
        .from(_tableCampaigns)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Campaign.fromMap(r)).toList();
  }

  Future<Campaign?> fetchById(String id) async {
    final uid = _requireUid();
    final row = await _client
        .from(_tableCampaigns)
        .select()
        .eq('id', id)
        .eq('user_id', uid)
        .maybeSingle();
    return row == null ? null : Campaign.fromMap(row);
  }

  Future<List<Campaign>> fetchByItemId(String itemId) async {
    final uid = _requireUid();
    final rows = await _client
        .from(_tableCampaigns)
        .select()
        .eq('knowledge_item_id', itemId)
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Campaign.fromMap(r)).toList();
  }

  Future<void> delete(String id) async {
    await _client.from(_tableCampaigns).delete().eq('id', id);
  }

  Future<Campaign> generate({
    required KnowledgeItem item,
    required KnowledgeAnalysis analysis,
    KnowledgeStrategy? strategy,
    required String objective,
    required int durationDays,
    required List<String> channels,
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
        'language':          item.language,
        'summary':           analysis.summary ?? '',
        'value_proposition': strategy?.valueProposition ?? '',
        'keywords':          analysis.keywordsPrimary,
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
