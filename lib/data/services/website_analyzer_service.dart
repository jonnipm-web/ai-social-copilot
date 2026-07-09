import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/website_analysis.dart';

class WebsiteAnalyzerService {
  final _client = Supabase.instance.client;

  static const _table = 'website_analyses';
  static const _edgeFunction = 'analyze-website';

  Future<List<WebsiteAnalysis>> fetchAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((r) => WebsiteAnalysis.fromMap(r)).toList();
  }

  Future<WebsiteAnalysis?> fetchById(String id) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : WebsiteAnalysis.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Future<WebsiteAnalysis> analyzeUrl(String url) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final response = await _client.functions.invoke(
      _edgeFunction,
      body: {'url': url},
    );

    if (response.data == null) {
      throw Exception('Resposta vazia da função de análise.');
    }

    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final int scoreWebsite = _int(data['score_website']);
    final int scoreAdsense = _int(data['score_adsense']);
    final int scoreSeo     = _int(data['score_seo']);
    final int scoreMonetization = _int(data['score_monetization']);

    final row = await _client
        .from(_table)
        .insert({
          'user_id':            uid,
          'url':                url,
          'title':              data['title'] as String?,
          'description':        data['description'] as String?,
          'score_website':      scoreWebsite,
          'score_adsense':      scoreAdsense,
          'score_seo':          scoreSeo,
          'score_monetization': scoreMonetization,
          'analysis_json':      data,
        })
        .select()
        .single();

    return WebsiteAnalysis.fromMap(row);
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.clamp(0, 100);
    if (v is double) return v.toInt().clamp(0, 100);
    return int.tryParse(v.toString()) ?? 0;
  }
}
