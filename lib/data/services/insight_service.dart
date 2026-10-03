import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_queue_item.dart';
import '../models/opportunity_lab_item.dart';
import '../models/copilot_turn.dart';
import '../../core/constants/app_constants.dart';

class InsightService {
  final _client = Supabase.instance.client;

  Future<List<OpportunityLabItem>> fetchByProject(String projectId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from(AppConstants.tableOpportunityLab)
        .select()
        .eq('user_id', uid)
        .eq('project_id', projectId)
        .eq('origin', AppConstants.originIveAnalysis)
        .order('created_at', ascending: false);
    return rows.map((r) => OpportunityLabItem.fromMap(r)).toList();
  }

  Future<int> countThisMonth(String projectId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final start = DateTime.now();
    final firstOfMonth = DateTime(start.year, start.month, 1).toIso8601String();
    final rows = await _client
        .from(AppConstants.tableOpportunityLab)
        .select('id')
        .eq('user_id', uid)
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

  Future<List<OpportunityLabItem>> fetchRecent({int limit = 5}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from(AppConstants.tableOpportunityLab)
        .select()
        .eq('user_id', uid)
        .eq('origin', AppConstants.originIveAnalysis)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((r) => OpportunityLabItem.fromMap(r)).toList();
  }

  Future<void> delete(String id) async {
    await _client
        .from(AppConstants.tableOpportunityLab)
        .delete()
        .eq('id', id);
  }

  Future<ActionQueueItem> addToActions(OpportunityLabItem insight) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final action = ActionQueueItem(
      id:              '',
      userId:          uid,
      projectId:       insight.projectId,
      opportunityLabId: insight.id.isNotEmpty ? insight.id : null,
      actionType:      'task',
      title:           insight.title,
      description:     insight.description,
      confidence:      insight.confidence,
      sources:         insight.sources,
      plan:            insight.actionSteps,
      origin:          'ive_analysis',
      status:          'pending',
      createdAt:       DateTime.now(),
    );
    final map = action.toInsertMap();
    map['user_id'] = uid;

    final row = await _client
        .from(AppConstants.tableActionQueue)
        .insert(map)
        .select()
        .single();
    return ActionQueueItem.fromMap(row);
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
