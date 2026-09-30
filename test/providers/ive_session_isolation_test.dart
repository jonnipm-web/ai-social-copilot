// IVE-INTELLIGENCE-CORE-01 (IVE-F01) — logout/login must not carry one
// user's IVE state (transcripts, device-local memory) into another user's
// session on the same device.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_social_copilot/data/models/copilot_turn.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:ai_social_copilot/providers/ive_memory_provider.dart';
import 'package:ai_social_copilot/providers/ive_session_isolation.dart';

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sign-out wipes transcripts and every device-local IVE key', () async {
    SharedPreferences.setMockInitialValues({
      'ive_recent_questions': ['user A private question'],
      'ive_last_project_name': 'A secret project',
      'ive_last_project_id': 'pa',
      'ive_memory_owner': 'user-a',
      'unrelated_setting': 'keep me',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(iveMemoryProvider.notifier); // create → starts the async load
    await _settle();
    expect(c.read(iveMemoryProvider).recentQuestions, ['user A private question']);

    const key = ('Decisões', null);
    c.read(contextCopilotProvider(key).notifier).state =
        CopilotState(turns: [CopilotTurn(role: 'user', content: 'A asked this', timestamp: DateTime(2026))]);
    expect(c.read(contextCopilotProvider(key)).turns, isNotEmpty);

    await resetIveSessionState(invalidate: c.invalidate, memory: c.read(iveMemoryProvider.notifier));

    expect(c.read(contextCopilotProvider(key)).turns, isEmpty, reason: 'transcript of user A must not survive');
    expect(c.read(iveMemoryProvider).recentQuestions, isEmpty);
    expect(c.read(iveMemoryProvider).lastProjectName, isNull);
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['ive_recent_questions', 'ive_last_project_name', 'ive_last_project_id', 'ive_memory_owner']) {
      expect(prefs.containsKey(k), isFalse, reason: k);
    }
    expect(prefs.getString('unrelated_setting'), 'keep me');
  });

  test('a DIFFERENT user signing in on the device gets a clean IVE; the same user keeps theirs', () async {
    SharedPreferences.setMockInitialValues({
      'ive_recent_questions': ['A question'],
      'ive_last_project_name': 'A project',
      'ive_memory_owner': 'user-a',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final memory = c.read(iveMemoryProvider.notifier);
    await _settle();

    await bindIveSessionToUser(userId: 'user-a', invalidate: c.invalidate, memory: memory);
    expect(c.read(iveMemoryProvider).recentQuestions, ['A question'], reason: 'same user keeps continuity');

    const key = ('Home', null);
    c.read(contextCopilotProvider(key).notifier).state =
        CopilotState(turns: [CopilotTurn(role: 'user', content: 'A asked', timestamp: DateTime(2026))]);

    await bindIveSessionToUser(userId: 'user-b', invalidate: c.invalidate, memory: memory);
    expect(c.read(iveMemoryProvider).recentQuestions, isEmpty);
    expect(c.read(iveMemoryProvider).lastProjectName, isNull);
    expect(c.read(contextCopilotProvider(key)).turns, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ive_memory_owner'), 'user-b');
  });

  test('a reset issued while the initial load is still in flight is not undone by that load (race)', () async {
    SharedPreferences.setMockInitialValues({'ive_recent_questions': ['previous user question'], 'ive_memory_owner': 'user-a'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // No settle: the reset races the constructor's async load.
    await resetIveSessionState(invalidate: c.invalidate, memory: c.read(iveMemoryProvider.notifier));
    await _settle();
    expect(c.read(iveMemoryProvider).recentQuestions, isEmpty);
  });

  test('legacy device memory without an owner is treated as foreign and wiped', () async {
    SharedPreferences.setMockInitialValues({'ive_recent_questions': ['from before this fix']});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle();
    await bindIveSessionToUser(userId: 'user-x', invalidate: c.invalidate, memory: c.read(iveMemoryProvider.notifier));
    expect(c.read(iveMemoryProvider).recentQuestions, isEmpty);
  });
}
