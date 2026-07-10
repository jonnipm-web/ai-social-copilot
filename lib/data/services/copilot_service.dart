import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/copilot_session.dart';
import '../../core/constants/app_constants.dart';

// Foundation only — AI activation gated behind 'copilot_enabled' feature flag
class CopilotService {
  final _client = Supabase.instance.client;

  // ── Sessions ────────────────────────────────────────────────

  Future<List<CopilotSession>> fetchSessions() async {
    final rows = await _client
        .from(AppConstants.tableCopilotSessions)
        .select()
        .eq('status', 'active')
        .order('updated_at', ascending: false);
    return (rows as List).map((r) => CopilotSession.fromMap(r)).toList();
  }

  Future<CopilotSession> createSession({String title = 'Nova Conversa'}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final row = await _client
        .from(AppConstants.tableCopilotSessions)
        .insert(CopilotSession(
          id:        '',
          userId:    uid,
          title:     title,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).toInsertMap())
        .select()
        .single();
    return CopilotSession.fromMap(row);
  }

  Future<void> closeSession(String sessionId) async {
    await _client
        .from(AppConstants.tableCopilotSessions)
        .update({'status': 'closed'})
        .eq('id', sessionId);
  }

  // ── Messages ─────────────────────────────────────────────────

  Future<List<CopilotMessage>> fetchMessages(String sessionId) async {
    final rows = await _client
        .from(AppConstants.tableCopilotMessages)
        .select()
        .eq('session_id', sessionId)
        .order('created_at', ascending: true);
    return (rows as List).map((r) => CopilotMessage.fromMap(r)).toList();
  }

  Future<CopilotMessage> addMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final row = await _client
        .from(AppConstants.tableCopilotMessages)
        .insert(CopilotMessage(
          id:        '',
          sessionId: sessionId,
          userId:    uid,
          role:      role,
          content:   content,
          createdAt: DateTime.now(),
        ).toInsertMap())
        .select()
        .single();

    await _client
        .from(AppConstants.tableCopilotSessions)
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', sessionId);

    return CopilotMessage.fromMap(row);
  }

  // ── Context (future use) ──────────────────────────────────────

  Future<void> saveContext({
    required String contextType,
    required Map<String, dynamic> contextData,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    await _client.from(AppConstants.tableCopilotContext).upsert(
      {
        'user_id':      uid,
        'context_type': contextType,
        'context_data': contextData,
        'updated_at':   DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,context_type',
    );
  }
}
