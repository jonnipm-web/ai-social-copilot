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

  Future<List<MarketAnalysis>> fetchAll({String? projectId}) async {
    var query = _client
        .from(AppConstants.tableMarketAnalyses)
        .select();
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

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableMarketAnalyses).delete().eq('id', id);
  }

  Future<MarketAnalysis> analyze(
    String input, {
    String inputType = 'url',
    String? projectId,
    String language = 'pt-BR',
    String? idempotencyKey,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionMarket,
      body: {
        'input': input,
        'input_type': inputType,
        'language': language,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
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

  // Competitors
  Future<List<Competitor>> fetchCompetitors(String marketAnalysisId) async {
    final rows = await _client
        .from(AppConstants.tableCompetitors)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('relevance_score', ascending: false);
    return (rows as List).map((r) => Competitor.fromMap(r)).toList();
  }

  Future<List<Competitor>> discoverCompetitors(
    String marketAnalysisId,
    String input, {
    String language = 'pt-BR',
    String? idempotencyKey,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionCompetitor,
      body: {
        'market_analysis_id': marketAnalysisId,
        'input': input,
        'language': language,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
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
  //
  // IVE-COMMERCIAL-STABILITY-08 — this relationship is a CURRENT-STATE one
  // (confirmed by product semantics: gap_analysis_screen.dart's "Analisar"
  // action stays enabled even after a result already exists, i.e. running
  // it again is meant to REPLACE the current result, not add history), so
  // there should only ever be one row per market_analysis_id. In practice
  // a race (double-tap, or a retry after a slow response) could still
  // create a second row before the DB-level uniqueness fix
  // (20260916000000_market_intelligence_current_state.sql) is applied —
  // COMMERCIAL-E2E-001 physically reproduced exactly that
  // (PostgrestException 406 "Results contain 2 rows"). Ordering by
  // created_at desc + limit(1) makes this read deterministic and safe
  // regardless of whether that migration has been applied yet: it always
  // returns the most recent (== canonical) row instead of erroring.
  Future<GapAnalysis?> fetchGapAnalysis(String marketAnalysisId) async {
    final rows = await _client
        .from(AppConstants.tableGapAnalyses)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List;
    return list.isEmpty ? null : GapAnalysis.fromMap(list.first as Map<String, dynamic>);
  }

  Future<GapAnalysis> runGapAnalysis(
    String marketAnalysisId,
    String input, {
    String language = 'pt-BR',
    String? idempotencyKey,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionGap,
      body: {
        'market_analysis_id': marketAnalysisId,
        'input': input,
        'language': language,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );

    if (response.data == null) throw Exception('Resposta vazia da análise de gaps.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    // IVE-COMMERCIAL-STABILITY-08 — upsert on the current-state key instead
    // of a plain insert, so re-running this analysis REPLACES the existing
    // row instead of creating a second one (mission section: PROVEN bug,
    // COMMERCIAL-E2E-001). REQUIRES the
    // gap_analyses_one_per_market_analysis unique index
    // (20260916000000_market_intelligence_current_state.sql) to already
    // exist in the target database — onConflict has nothing to match
    // against otherwise. That migration must be applied before this code
    // ships, never after (same deploy-ordering rule already established
    // for 07A/07B's own migrations).
    final row = await _client
        .from(AppConstants.tableGapAnalyses)
        .upsert({
          'user_id':            uid,
          'market_analysis_id': marketAnalysisId,
          'content_gaps':       data['content_gaps'] ?? [],
          'seo_gaps':           data['seo_gaps'] ?? [],
          'authority_gaps':     data['authority_gaps'] ?? [],
          'monetization_gaps':  data['monetization_gaps'] ?? [],
          'product_gaps':       data['product_gaps'] ?? [],
          'analysis_json':      data,
        }, onConflict: 'market_analysis_id')
        .select()
        .single();

    return GapAnalysis.fromMap(row);
  }

  // Opportunities
  Future<List<Opportunity>> fetchOpportunities(String marketAnalysisId) async {
    final rows = await _client
        .from(AppConstants.tableOpportunities)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('opportunity_score', ascending: false);
    return (rows as List).map((r) => Opportunity.fromMap(r)).toList();
  }

  Future<List<Opportunity>> discoverOpportunities(
    String marketAnalysisId,
    String input, {
    String language = 'pt-BR',
    String? idempotencyKey,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionOpportunity,
      body: {
        'market_analysis_id': marketAnalysisId,
        'input': input,
        'language': language,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
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
    final rows = await _client
        .from(AppConstants.tableNicheRankings)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('overall_score', ascending: false);
    return (rows as List).map((r) => NicheRanking.fromMap(r)).toList();
  }

  Future<List<NicheRanking>> discoverNiches(
    String marketAnalysisId,
    String input, {
    String language = 'pt-BR',
    String? idempotencyKey,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionNiche,
      body: {
        'market_analysis_id': marketAnalysisId,
        'input': input,
        'language': language,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
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

  // Content Cluster — same current-state reasoning as fetchGapAnalysis above.
  Future<ContentCluster?> fetchContentCluster(String marketAnalysisId) async {
    final rows = await _client
        .from(AppConstants.tableContentClusters)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List;
    return list.isEmpty ? null : ContentCluster.fromMap(list.first as Map<String, dynamic>);
  }

  Future<ContentCluster> buildContentCluster(
    String marketAnalysisId,
    String input,
    String mainKeyword, {
    String language = 'pt-BR',
    String? idempotencyKey,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionCluster,
      body: {
        'market_analysis_id': marketAnalysisId,
        'input': input,
        'main_keyword': mainKeyword,
        'language': language,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );

    if (response.data == null) throw Exception('Resposta vazia do Content Cluster.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    // IVE-COMMERCIAL-STABILITY-08 — same upsert-on-current-state-key
    // reasoning as runGapAnalysis above. REQUIRES
    // content_clusters_one_per_market_analysis to already exist.
    final row = await _client
        .from(AppConstants.tableContentClusters)
        .upsert({
          'user_id':            uid,
          'market_analysis_id': marketAnalysisId,
          'main_keyword':       mainKeyword,
          'clusters':           data['clusters'] ?? [],
          'silos':              data['silos'] ?? [],
          'articles':           data['articles'] ?? [],
          'editorial_roadmap':  data['editorial_roadmap'] ?? [],
          'seo_structure':      data['seo_structure'] ?? {},
        }, onConflict: 'market_analysis_id')
        .select()
        .single();

    return ContentCluster.fromMap(row);
  }

  // All Revenue Plans (for ecosystem scoring)
  Future<List<RevenuePlan>> fetchAllRevenuePlans({String? projectId}) async {
    var query = _client.from(AppConstants.tableRevenuePlans).select();
    if (projectId != null) query = query.eq('project_id', projectId);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => RevenuePlan.fromMap(r)).toList();
  }

  // Revenue Plan — same current-state reasoning as fetchGapAnalysis above.
  Future<RevenuePlan?> fetchRevenuePlan(String marketAnalysisId) async {
    final rows = await _client
        .from(AppConstants.tableRevenuePlans)
        .select()
        .eq('market_analysis_id', marketAnalysisId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List;
    return list.isEmpty ? null : RevenuePlan.fromMap(list.first as Map<String, dynamic>);
  }

  Future<RevenuePlan> buildRevenuePlan(
    String marketAnalysisId,
    String input,
    String projectName, {
    String? projectId,
    String language = 'pt-BR',
    String? idempotencyKey,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionRevenue,
      body: {
        'market_analysis_id': marketAnalysisId,
        'input': input,
        'project_name': projectName,
        'language': language,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );

    if (response.data == null) throw Exception('Resposta vazia do Revenue Planner.');
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    double _d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    // IVE-COMMERCIAL-STABILITY-08 — same upsert-on-current-state-key
    // reasoning as runGapAnalysis above. Only applies to the
    // market-analysis-linked flow (market_analysis_id NOT NULL) — the
    // separate project-only revenue plan flow (market_analysis_id IS
    // NULL, see idx_revenue_plans_project_name) is untouched, its own
    // uniqueness is keyed on (user_id, project_name) instead. REQUIRES
    // revenue_plans_one_per_market_analysis to already exist.
    final row = await _client
        .from(AppConstants.tableRevenuePlans)
        .upsert({
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
        }, onConflict: 'market_analysis_id')
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
