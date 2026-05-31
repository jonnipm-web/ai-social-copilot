import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/brand.dart';
import '../models/editorial_history_entry.dart';
import '../models/excerpt_result.dart';
import '../models/persona.dart';

class EditorialService {
  final _db = Supabase.instance.client;

  Future<ExcerptResult> extractExcerpts(String text, {Brand? brand}) async {
    final res = await _db.functions.invoke(
      'extract-excerpts',
      body: {
        'text': text,
        if (brand != null) 'brand_prompt': brand.brandPrompt,
        if (brand != null) 'brand_name': brand.name,
      },
    );
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Erro ao extrair trechos');
    }
    return ExcerptResult.fromMap(res.data as Map<String, dynamic>);
  }

  Future<RepurposedContent> repurposeContent(
    String text, {
    Brand? brand,
    Persona? persona,
    String platform = '',
    String objective = '',
  }) async {
    final res = await _db.functions.invoke(
      'repurpose-content',
      body: {
        'text': text,
        'platform': platform,
        'objective': objective,
        if (brand != null) 'brand_prompt': brand.brandPrompt,
        if (brand != null) 'brand_name': brand.name,
        if (persona != null) 'persona_prompt': persona.personaPrompt,
        if (persona != null) 'persona_name': persona.name,
      },
    );
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Erro ao reaproveitar conteúdo');
    }
    return RepurposedContent.fromMap(res.data as Map<String, dynamic>);
  }

  Future<CalendarPlan> generateCalendar({
    required Brand brand,
    Persona? persona,
    required String objective,
    required String platform,
    required int periodDays,
  }) async {
    final res = await _db.functions.invoke(
      'generate-calendar',
      body: {
        'brand_name': brand.name,
        'brand_prompt': brand.brandPrompt,
        'niche': brand.niche,
        'tone': brand.toneOfVoice,
        'objective': objective,
        'platform': platform,
        'period_days': periodDays,
        if (persona != null) 'persona_name': persona.name,
        if (persona != null) 'persona_prompt': persona.personaPrompt,
      },
    );
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Erro ao gerar calendário');
    }
    return CalendarPlan.fromMap(res.data as Map<String, dynamic>);
  }

  Future<void> saveToHistory({
    required String featureUsed,
    String? brandId,
    String? personaId,
    String platform = '',
    String objective = '',
    String contentType = '',
    required String inputText,
    required String outputText,
  }) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('editorial_history').insert({
      'user_id': uid,
      'brand_id': brandId,
      'persona_id': personaId,
      'feature_used': featureUsed,
      'platform': platform,
      'objective': objective,
      'content_type': contentType,
      'input_text': inputText,
      'output_text': outputText,
      'status': 'generated',
    });
  }

  Future<List<EditorialHistoryEntry>> fetchHistory({
    String? brandId,
    String? featureUsed,
    int limit = 50,
  }) async {
    var query = _db.from('editorial_history').select();
    if (brandId != null) query = query.eq('brand_id', brandId);
    if (featureUsed != null) query = query.eq('feature_used', featureUsed);
    final rows =
        await query.order('created_at', ascending: false).limit(limit);
    return rows.map(EditorialHistoryEntry.fromMap).toList();
  }

  Future<void> updateHistoryStatus(String id, String status) async {
    await _db
        .from('editorial_history')
        .update({'status': status})
        .eq('id', id);
  }
}
