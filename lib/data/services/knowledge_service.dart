import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/knowledge_analysis.dart';
import '../models/knowledge_item.dart';
import '../../core/services/ive_event_bus.dart';
import '../../data/models/ive_event.dart';
import 'content_service.dart';

class KnowledgeService {
  final _client = Supabase.instance.client;

  static const _tableItems    = 'knowledge_items';
  static const _tableAnalysis = 'knowledge_analysis';
  static const _edgeFunction  = 'extract-knowledge';

  // ── Items ────────────────────────────────────────────────────

  Future<List<KnowledgeItem>> fetchAll({String? projectId}) async {
    var query = _client.from(_tableItems).select();
    if (projectId != null) query = query.eq('project_id', projectId);
    final rows = await query.order('created_at', ascending: false);
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

    // Marca como processando e notifica IVE
    await update(item.id, {'status': 'processing'});
    IveEventBus.instance.emit(
      IveEvent.knowledgeAnalysisStarted(itemId: item.id, itemName: item.title),
    );

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
        scoreOpportunity:         _int(aiData['score_opportunity']),
        scoreHotmart:             _int(aiData['score_hotmart']),
        scoreShopify:             _int(aiData['score_shopify']),
        scoreDetails:             _map(aiData['score_details']),
        hotmartData:              _map(aiData['hotmart_data']),
        shopifyData:              _map(aiData['shopify_data']),
        personaTraining:          _map(aiData['persona_training']),
        createdAt:                DateTime.now(),
        updatedAt:                DateTime.now(),
      );

      final saved = await saveAnalysis(analysis);

      // Auto-sync to Library — não-fatal
      try {
        final detectedType = aiData['detected_type'] as String? ?? 'texto';
        await ContentService().upsertFromKnowledge(
          userId:           uid,
          projectId:        item.projectId,
          knowledgeItemId:  item.id,
          title:            (aiData['detected_title'] as String?)?.isNotEmpty == true
              ? aiData['detected_title'] as String
              : item.title,
          type:             _mapContentType(detectedType),
          description:      aiData['summary'] as String?,
          baseText:         item.content.isNotEmpty ? item.content : null,
          niche:            (aiData['detected_niche'] as String?)?.isNotEmpty == true
              ? aiData['detected_niche'] as String
              : item.niche,
          targetAudience:   (aiData['detected_audience'] as String?)?.isNotEmpty == true
              ? aiData['detected_audience'] as String
              : item.targetAudience,
          keywords:         _list(aiData['keywords_primary']),
          opportunityScore: _int(aiData['score_opportunity']),
          language:         item.language,
        );
      } catch (e) {
        IveEventBus.instance.emit(
          IveEvent.knowledgeAnalysisFailed(
            itemId:         item.id,
            itemName:       item.title,
            technicalError: 'Sync to Library failed: $e',
          ),
        );
      }

      // Marca como analisado — dentro do try para evitar inconsistência de status
      await update(item.id, {
        'status':            'analyzed',
        'opportunity_score': _int(aiData['score_opportunity']),
        'auto_title':        aiData['detected_title'],
        'auto_type':         aiData['detected_type'],
        'auto_niche':        aiData['detected_niche'],
        'auto_audience':     aiData['detected_audience'],
      });

      // Notifica IVE de conclusão
      IveEventBus.instance.emit(
        IveEvent.knowledgeAnalysisCompleted(
          itemId:           item.id,
          itemName:         item.title,
          opportunityScore: _int(aiData['score_opportunity']),
        ),
      );

      return saved;
    } catch (e) {
      await update(item.id, {'status': 'error'});

      // Notifica IVE do erro
      IveEventBus.instance.emit(
        IveEvent.knowledgeAnalysisFailed(
          itemId:         item.id,
          itemName:       item.title,
          technicalError: e.toString(),
        ),
      );

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

  static String _mapContentType(String detected) {
    const map = {
      'livro':   'livro',
      'ebook':   'ebook',
      'artigo':  'artigo',
      'post':    'post',
      'site':    'projeto',
      'produto': 'produto',
      'marca':   'marca',
      'projeto': 'projeto',
      'curso':   'produto',
      'texto':   'texto',
    };
    return map[detected.toLowerCase()] ?? 'texto';
  }
}
