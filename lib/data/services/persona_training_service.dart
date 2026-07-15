import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/knowledge_analysis.dart';
import '../models/knowledge_item.dart';
import '../models/persona_training.dart';

class PersonaTrainingService {
  final _client = Supabase.instance.client;

  static const _table = 'persona_training';

  Future<List<PersonaTraining>> fetchAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((r) => PersonaTraining.fromMap(r)).toList();
  }

  Future<List<PersonaTraining>> fetchForPersona(String personaId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('persona_id', personaId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => PersonaTraining.fromMap(r)).toList();
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Future<PersonaTraining> trainFromAnalysis({
    required String personaId,
    required KnowledgeItem item,
    required KnowledgeAnalysis analysis,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final pt = analysis.personaTraining;
    final summary = 'Treinamento com: ${item.title}. '
        'Tom: ${pt['tone'] ?? '-'}. '
        'Estilo: ${pt['communication_style'] ?? '-'}.';

    List<String> vocab = [];
    if (pt['vocabulary'] is List) {
      vocab = (pt['vocabulary'] as List).map((e) => e.toString()).toList();
    }

    List<String> values = [];
    if (pt['values'] is List) {
      values = (pt['values'] as List).map((e) => e.toString()).toList();
    }

    final toneProfile = {
      'tone': pt['tone'] ?? '',
      'communication_style': pt['communication_style'] ?? '',
    };

    final row = await _client
        .from(_table)
        .insert({
          'user_id':            uid,
          'persona_id':         personaId,
          'knowledge_item_id':  item.id,
          'training_summary':   summary,
          'tone_profile_json':  toneProfile,
          'vocabulary_json':    vocab,
          'brand_values_json':  values,
          'positioning_json':   {
            'niche':    item.niche ?? '',
            'audience': item.targetAudience ?? '',
          },
          'audience_json':      {
            'target':   item.targetAudience ?? '',
            'language': item.language,
          },
          'examples_json':      analysis.postIdeas.take(3).toList(),
        })
        .select()
        .single();

    return PersonaTraining.fromMap(row);
  }
}
