import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/market_analysis.dart';
import '../models/competitor.dart';
import '../models/gap_analysis.dart';
import '../models/opportunity.dart';
import '../models/niche_ranking.dart';
import '../models/content_cluster.dart';
import '../models/revenue_plan.dart';
import '../../core/constants/app_constants.dart';

class MarketAnalysisService {
  final _client = Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    return uid;
  }

  Future<List<MarketAnalysis>> fetchAll({String? projectId}) async {
    final uid = _requireUid();
    var query = _client
        .from(AppConstants.tableMarketAnalyses)
        .select()
        .eq('user_id', uid);
    if (projectId != null) query = query.eq('project_id', projectId);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => MarketAnalysis.fromMap(r)).toList();
  }

  Future<MarketAnalysis?> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tableMarketAnalyses)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : MarketAnalysis.fromMap(row);
  }

  Future<MarketAnalysis> analyze(
    String input, {
    String inputType = 'url',
    String? projectId,
  }) async {
    final uid = _requireUid();

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionMarket,
      body: {'input': input, 'input_type': inputType},
    );

    if (response.data == null) throw Exception('Resposta vazia da análise de mercado.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final row = await _client
        .from(AppConstants.tableMarketAnalyses)
        .insert({
          'user_id':            uid,
          if (projectId != null) 'project_id': projectId,
          'input':              input,
          'input_type':         inputType,
          'niche':              data['niche'] as String?,
          'sub_niche':          data['sub_niche'] as String?,
          'target_audience':    data['target_audience'] as String?,
          'business_type':      data['business_type'] as String?,
          'value_proposition':  data['value_proposition'] as String?,
          'positioning':        data['positioning'] as String?,
          'monetization_model': data['monetization_model'] as String?,
          'opportunity_score':  _int(data['opportunity_score']),
          'status':             'completed',
          'analysis_json':      data,
        })
        .select()
        .single();

    return MarketAnalysis.fromMap(row);
  }

  Future<void> delete(String id) async {
    final uid = _requireUid();
    // Verifica propriedade antes de deletar
    final existing = await _client
        .from(AppConstants.tableMarketAnalyses)
        .select('id')
        .eq('id', id)
        .eq('user_id', uid)
        .maybeSingle();
    if (existing == null) throw Exception('Análise não encontrada ou não autorizada');
    await _client.from(AppConstants.tableMarketAnalyses).delete().eq('id', id);
  }

  // Competitors
  Future<List<Competitor>> fetchCompetitors(String marketAnalysisId) async {
    _requireUid();
    final rows = await _client
        .from(AppConstants.tableCompetitors)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('relevance_score', ascending: false);
    return (rows as List).map((r) => Competitor.fromMap(r)).toList();
  }

  Future<List<Competitor>> discoverCompetitors(String marketAnalysisId, String input) async {
    final uid = _requireUid();

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionCompetitor,
      body: {'market_analysis_id': marketAnalysisId, 'input': input},
    );

    if (response.data == null) throw Exception('Resposta vazia da descoberta de concorrentes.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final competitorsList = data['competitors'] as List? ?? [];
    final inserted = <Competitor>[];
    for (final c in competitorsList) {
      final m = c as Map<String, dynamic>;
      final row = await _client
          .from(AppConstants.tableCompetitors)
          .insert({
            'user_id':            uid,
            'market_analysis_id': marketAnalysisId,
            'name':               m['name'] as String? ?? '',
            'url':                m['url'] as String? ?? '',
            'type':               m['type'] as String? ?? 'direct',
            'similarity_score':   _int(m['similarity_score']),
            'authority_score':    _int(m['authority_score']),
            'relevance_score':    _int(m['relevance_score']),
            'details_json':       m,
          })
          .select()
          .single();
      inserted.add(Competitor.fromMap(row));
    }
    return inserted;
  }

  // Gap Analysis
  Future<GapAnalysis?> fetchGapAnalysis(String marketAnalysisId) async {
    _requireUid();
    final row = await _client
        .from(AppConstants.tableGapAnalyses)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .maybeSingle();
    return row == null ? null : GapAnalysis.fromMap(row);
  }

  Future<GapAnalysis> runGapAnalysis(String marketAnalysisId, String input) async {
    final uid = _requireUid();

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionGap,
      body: {'market_analysis_id': marketAnalysisId, 'input': input},
    );

    if (response.data == null) throw Exception('Resposta vazia da análise de gaps.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final row = await _client
        .from(AppConstants.tableGapAnalyses)
        .insert({
          'user_id':            uid,
          'market_analysis_id': marketAnalysisId,
          'content_gaps':       data['content_gaps'] ?? [],
          'seo_gaps':           data['seo_gaps'] ?? [],
          'authority_gaps':     data['authority_gaps'] ?? [],
          'monetization_gaps':  data['monetization_gaps'] ?? [],
          'product_gaps':       data['product_gaps'] ?? [],
          'analysis_json':      data,
        })
        .select()
        .single();

    return GapAnalysis.fromMap(row);
  }

  // Opportunities
  Future<List<Opportunity>> fetchOpportunities(String marketAnalysisId) async {
    _requireUid();
    final rows = await _client
        .from(AppConstants.tableOpportunities)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('opportunity_score', ascending: false);
    return (rows as List).map((r) => Opportunity.fromMap(r)).toList();
  }

  Future<List<Opportunity>> discoverOpportunities(String marketAnalysisId, String input) async {
    final uid = _requireUid();

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionOpportunity,
      body: {'market_analysis_id': marketAnalysisId, 'input': input},
    );

    if (response.data == null) throw Exception('Resposta vazia da descoberta de oportunidades.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final list = data['opportunities'] as List? ?? [];
    final inserted = <Opportunity>[];
    for (final o in list) {
      final m = o as Map<String, dynamic>;
      final row = await _client
          .from(AppConstants.tableOpportunities)
          .insert({
            'user_id':            uid,
            'market_analysis_id': marketAnalysisId,
            'title':              m['title'] as String? ?? '',
            'type':               m['type'] as String? ?? 'content',
            'description':        m['description'] as String? ?? '',
            'opportunity_score':  _int(m['opportunity_score']),
            'market_score':       _int(m['market_score']),
            'growth_score':       _int(m['growth_score']),
            'competition_score':  _int(m['competition_score']),
            'monetization_score': _int(m['monetization_score']),
            'difficulty_score':   _int(m['difficulty_score']),
            'details_json':       m,
          })
          .select()
          .single();
      inserted.add(Opportunity.fromMap(row));
    }
    return inserted;
  }

  // Niche Rankings
  Future<List<NicheRanking>> fetchNiches(String marketAnalysisId) async {
    _requireUid();
    final rows = await _client
        .from(AppConstants.tableNicheRankings)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('overall_score', ascending: false);
    return (rows as List).map((r) => NicheRanking.fromMap(r)).toList();
  }

  Future<List<NicheRanking>> discoverNiches(String marketAnalysisId, String input) async {
    final uid = _requireUid();

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionNiche,
      body: {'market_analysis_id': marketAnalysisId, 'input': input},
    );

    if (response.data == null) throw Exception('Resposta vazia da descoberta de nichos.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final list = data['niches'] as List? ?? [];
    final inserted = <NicheRanking>[];
    for (final n in list) {
      final m = n as Map<String, dynamic>;
      final row = await _client
          .from(AppConstants.tableNicheRankings)
          .insert({
            'user_id':            uid,
            'market_analysis_id': marketAnalysisId,
            'name':               m['name'] as String? ?? '',
            'level':              m['level'] as String? ?? 'niche',
            'description':        m['description'] as String? ?? '',
            'competition_score':  _int(m['competition_score']),
            'potential_score':    _int(m['potential_score']),
            'growth_score':       _int(m['growth_score']),
            'monetization_score': _int(m['monetization_score']),
            'difficulty_score':   _int(m['difficulty_score']),
            'trend_score':        _int(m['trend_score']),
            'overall_score':      _int(m['overall_score']),
            'details_json':       m,
          })
          .select()
          .single();
      inserted.add(NicheRanking.fromMap(row));
    }
    return inserted;
  }

  // Content Cluster
  Future<ContentCluster?> fetchContentCluster(String marketAnalysisId) async {
    _requireUid();
    final row = await _client
        .from(AppConstants.tableContentClusters)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .maybeSingle();
    return row == null ? null : ContentCluster.fromMap(row);
  }

  Future<ContentCluster> buildContentCluster(String marketAnalysisId, String input, String mainKeyword) async {
    final uid = _requireUid();

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionCluster,
      body: {'market_analysis_id': marketAnalysisId, 'input': input, 'main_keyword': mainKeyword},
    );

    if (response.data == null) throw Exception('Resposta vazia do Content Cluster.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final row = await _client
        .from(AppConstants.tableContentClusters)
        .insert({
          'user_id':            uid,
          'market_analysis_id': marketAnalysisId,
          'main_keyword':       mainKeyword,
          'clusters':           data['clusters'] ?? [],
          'silos':              data['silos'] ?? [],
          'articles':           data['articles'] ?? [],
          'editorial_roadmap':  data['editorial_roadmap'] ?? [],
          'seo_structure':      data['seo_structure'] ?? {},
        })
        .select()
        .single();

    return ContentCluster.fromMap(row);
  }

  // All Revenue Plans (for ecosystem scoring)
  Future<List<RevenuePlan>> fetchAllRevenuePlans({String? projectId}) async {
    final uid = _requireUid();
    var query = _client.from(AppConstants.tableRevenuePlans).select().eq('user_id', uid);
    if (projectId != null) query = query.eq('project_id', projectId);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => RevenuePlan.fromMap(r)).toList();
  }

  // Revenue Plan
  Future<RevenuePlan?> fetchRevenuePlan(String marketAnalysisId) async {
    _requireUid();
    final row = await _client
        .from(AppConstants.tableRevenuePlans)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .maybeSingle();
    return row == null ? null : RevenuePlan.fromMap(row);
  }

  Future<RevenuePlan> buildRevenuePlan(
    String marketAnalysisId,
    String input,
    String projectName, {
    String? projectId,
  }) async {
    final uid = _requireUid();

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionRevenue,
      body: {'market_analysis_id': marketAnalysisId, 'input': input, 'project_name': projectName},
    );

    if (response.data == null) throw Exception('Resposta vazia do Revenue Planner.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    double _d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final row = await _client
        .from(AppConstants.tableRevenuePlans)
        .insert({
          'user_id':              uid,
          if (projectId != null) 'project_id': projectId,
          'market_analysis_id':   marketAnalysisId,
          'project_name':         projectName,
          'monthly_conservative': _d(data['monthly_conservative']),
          'monthly_moderate':     _d(data['monthly_moderate']),
          'monthly_aggressive':   _d(data['monthly_aggressive']),
          'annual_conservative':  _d(data['annual_conservative']),
          'annual_moderate':      _d(data['annual_moderate']),
          'annual_aggressive':    _d(data['annual_aggressive']),
          'plan_json':            data,
        })
        .select()
        .single();

    return RevenuePlan.fromMap(row);
  }

  static int _int(dynamic v) {
    if (v is int) return v.clamp(0, 100);
    if (v is double) return v.toInt().clamp(0, 100);
    return int.tryParse(v.toString()) ?? 0;
  }
}
