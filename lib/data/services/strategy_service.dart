import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/knowledge_item.dart';
import '../models/knowledge_analysis.dart';
import '../models/knowledge_strategy.dart';

class StrategyService {
  final _client = Supabase.instance.client;

  static const _table        = 'knowledge_strategies';
  static const _edgeFunction = 'generate-strategy';

  Future<KnowledgeStrategy?> fetchByItemId(String itemId) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('knowledge_item_id', itemId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : KnowledgeStrategy.fromMap(row);
  }

  Future<KnowledgeStrategy> save(KnowledgeStrategy strategy) async {
    final row = await _client
        .from(_table)
        .upsert(
          strategy.toInsertMap(),
          onConflict: 'knowledge_item_id',
        )
        .select()
        .single();
    return KnowledgeStrategy.fromMap(row);
  }

  Future<KnowledgeStrategy> generate(
    KnowledgeItem item,
    KnowledgeAnalysis analysis,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      _edgeFunction,
      body: {
        'title':             item.title,
        'content':           item.content.length > 3000
            ? item.content.substring(0, 3000)
            : item.content,
        'summary':           analysis.summary ?? '',
        'niche':             item.niche ?? '',
        'target_audience':   item.targetAudience ?? '',
        'language':          item.language,
        'keywords_primary':  analysis.keywordsPrimary,
        'pain_points':       analysis.audiencePainPoints,
        'desires':           analysis.audienceDesires,
        'topics':            analysis.topics,
      },
    );

    if (response.data == null) {
      throw Exception('Resposta vazia da função de estratégia.');
    }

    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final strategy = KnowledgeStrategy(
      id:               '',
      knowledgeItemId:  item.id,
      userId:           uid,
      strategyJson:     data,
      createdAt:        DateTime.now(),
      updatedAt:        DateTime.now(),
    );

    return save(strategy);
  }

  Future<void> delete(String itemId) async {
    await _client.from(_table).delete().eq('knowledge_item_id', itemId);
  }
}
