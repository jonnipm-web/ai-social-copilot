import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/copilot_session.dart';
import '../data/services/copilot_service.dart';

final copilotServiceProvider =
    Provider<CopilotService>((_) => CopilotService());

final copilotSessionsProvider =
    FutureProvider.autoDispose<List<CopilotSession>>((ref) {
  return ref.read(copilotServiceProvider).fetchSessions();
});

final copilotMessagesProvider =
    FutureProvider.autoDispose.family<List<CopilotMessage>, String>(
  (ref, sessionId) =>
      ref.read(copilotServiceProvider).fetchMessages(sessionId),
);
