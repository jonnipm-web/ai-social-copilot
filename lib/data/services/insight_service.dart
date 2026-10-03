import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/opportunity_lab_item.dart';
import '../models/copilot_turn.dart';
import '../../core/constants/app_constants.dart';

class InsightService {
  final _client = Supabase.instance.client;

  Future<List<OpportunityLabItem>> fetchByProject(String projectId) async {
    final rows = await _client
        .from(AppConstants.tableOpportunityLab)
        .select()
        .eq('project_id', projectId)
        .eq('origin', AppConstants.originIveAnalysis)
        .order('created_at', ascending: false);
    return rows.map((r) => OpportunityLabItem.fromMap(r)).toList();
  }

  Future<int> countThisMonth(String projectId) async {
    final start = DateTime.now();
    final firstOfMonth = DateTime(start.year, start.month, 1).toIso8601String();
    final rows = await _client
        .from(AppConstants.tableOpportunityLab)
        .select('id')
        .eq('project_id', projectId)
        .eq('origin', AppConstants.originIveAnalysis)
        .gte('created_at', firstOfMonth);
    return (rows as List).length;
  }

  Future<OpportunityLabItem> saveFromTurn({
    required String projectId,
    required String question,
    required CopilotTurn turn,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final item = OpportunityLabItem(
      id:             '',
      userId:         uid,
      projectId:      projectId,
      title:          _titleFromQuestion(question),
      description:    turn.content,
      confidence:     turn.confidence,
      sources:        turn.sources,
      actionSteps:    _actionStepsFromSuggestion(turn.actionSuggestion),
      origin:         AppConstants.originIveAnalysis,
      createdAt:      turn.timestamp,
    );

    final map = item.toInsertMap();
    map['user_id'] = uid;

    final row = await _client
        .from(AppConstants.tableOpportunityLab)
        .insert(map)
        .select()
        .single();
    return OpportunityLabItem.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client
        .from(AppConstants.tableOpportunityLab)
        .delete()
        .eq('id', id);
  }

  String _titleFromQuestion(String question) {
    final trimmed = question.trim();
    if (trimmed.length <= 60) return trimmed;
    return '${trimmed.substring(0, 57)}…';
  }

  List<String> _actionStepsFromSuggestion(CopilotActionSuggestion? s) {
    if (s == null) return [];
    return [s.label];
  }
}
