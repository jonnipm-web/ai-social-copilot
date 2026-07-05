import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/knowledge_analysis.dart';
import '../models/knowledge_item.dart';

class KnowledgeService {
  final _client = Supabase.instance.client;

  static const _tableItems    = 'knowledge_items';
  static const _tableAnalysis = 'knowledge_analysis';
  static const _edgeFunction  = 'extract-knowledge';

  // ── Items ────────────────────────────────────────────────────

  Future<List<KnowledgeItem>> fetchAll() async {
    final rows = await _client
        .from(_tableItems)
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((r) => KnowledgeItem.fromMap(r)).toList();
  }

  Future<KnowledgeItem?> fetchById(String id) async {
    final row = await _client
        .from(_tableItems)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : KnowledgeItem.fromMap(row);
  }

  Future<KnowledgeItem> create(KnowledgeItem item) async {
    final row = await _client
        .from(_tableItems)
        .insert(item.toInsertMap())
        .select()
        .single();
    return KnowledgeItem.fromMap(row);
  }

  Future<KnowledgeItem> update(String id, Map<String, dynamic> data) async {
    final row = await _client
        .from(_tableItems)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return KnowledgeItem.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(_tableItems).delete().eq('id', id);
  }

  // ── Analysis ─────────────────────────────────────────────────

  Future<KnowledgeAnalysis?> fetchAnalysis(String knowledgeItemId) async {
    final row = await _client
        .from(_tableAnalysis)
        .select()
        .eq('knowledge_item_id', knowledgeItemId)
        .maybeSingle();
    return row == null ? null : KnowledgeAnalysis.fromMap(row);
  }

  Future<KnowledgeAnalysis> saveAnalysis(KnowledgeAnalysis analysis) async {
    final row = await _client
        .from(_tableAnalysis)
        .upsert(
          analysis.toInsertMap(),
          onConflict: 'knowledge_item_id',
        )
        .select()
        .single();
    return KnowledgeAnalysis.fromMap(row);
  }

  // ── AI Extraction ────────────────────────────────────────────

  Future<Map<String, dynamic>> extractWithAI({
    required String content,
    String? sourceUrl,
    String? niche,
    String? targetAudience,
    String language = 'pt-BR',
  }) async {
    final response = await _client.functions.invoke(
      _edgeFunction,
      body: {
        'content':         content,
        'source_url':      sourceUrl,
        'niche':           niche,
        'target_audience': targetAudience,
        'language':        language,
      },
    );

    if (response.data == null) {
      throw Exception('Resposta vazia da função de extração.');
    }

    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) {
      throw Exception(data['error']);
    }

    return data;
  }

  // ── Full analyze flow ─────────────────────────────────────────

  Future<KnowledgeAnalysis> analyzeItem(KnowledgeItem item) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    // Marca como processando
    await update(item.id, {'status': 'processing'});

    try {
      final aiData = await extractWithAI(
        content:        item.content,
        sourceUrl:      item.sourceType == 'url' ? item.sourceUrl : null,
        niche:          item.niche,
        targetAudience: item.targetAudience,
        language:       item.language,
      );

      final analysis = KnowledgeAnalysis(
        id:                       '',
        knowledgeItemId:          item.id,
        userId:                   uid,
        summary:                  aiData['summary'] as String?,
        keywordsPrimary:          _list(aiData['keywords_primary']),
        keywordsSecondary:        _list(aiData['keywords_secondary']),
        keywordsLongtail:         _list(aiData['keywords_longtail']),
        entities:                 _list(aiData['entities']),
        topics:                   _list(aiData['topics']),
        contentPillars:           _list(aiData['content_pillars']),
        audiencePainPoints:       _list(aiData['audience_pain_points']),
        audienceDesires:          _list(aiData['audience_desires']),
        commercialAngles:         _list(aiData['commercial_angles']),
        ctas:                     _list(aiData['ctas']),
        campaignIdeas:            _list(aiData['campaign_ideas']),
        postIdeas:                _list(aiData['post_ideas']),
        articleIdeas:             _list(aiData['article_ideas']),
        seoOpportunities:         _list(aiData['seo_opportunities']),
        adsenseOpportunities:     _list(aiData['adsense_opportunities']),
        amazonKdpOpportunities:   _list(aiData['amazon_kdp_opportunities']),
        scoreSeo:                 _int(aiData['score_seo']),
        scoreAdsense:             _int(aiData['score_adsense']),
        scoreAmazonKdp:           _int(aiData['score_amazon_kdp']),
        scoreLinkedin:            _int(aiData['score_linkedin']),
        scoreSocial:              _int(aiData['score_social']),
        scoreDetails:             _map(aiData['score_details']),
        createdAt:                DateTime.now(),
        updatedAt:                DateTime.now(),
      );

      final saved = await saveAnalysis(analysis);

      // Marca como analisado
      await update(item.id, {'status': 'analyzed'});

      return saved;
    } catch (e) {
      await update(item.id, {'status': 'error'});
      rethrow;
    }
  }

  static List<String> _list(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.clamp(0, 100);
    if (v is double) return v.toInt().clamp(0, 100);
    return int.tryParse(v.toString()) ?? 0;
  }

  static Map<String, dynamic> _map(dynamic v) {
    if (v == null) return {};
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }
}
