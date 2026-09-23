// IVE-INTELLIGENCE-CORE-01 — the chat notifier's Intelligence Core path:
// minimal request (no client-built context, no device memory), project-scoped
// conversations (project switch), AEF and failure states.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/data/models/ive_intelligence.dart';
import 'package:ai_social_copilot/data/services/ive_intelligence_service.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';

class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

class _FakeService extends IveIntelligenceService {
  _FakeService(this.respond);
  final Future<IveIntelligenceResult> Function(IveIntelligenceRequest) respond;
  final requests = <IveIntelligenceRequest>[];
  @override
  Future<IveIntelligenceResult> ask(IveIntelligenceRequest request) {
    requests.add(request);
    return respond(request);
  }
}

IveIntelligenceResult _answer(String text, {bool aef = false, List<String> degraded = const []}) => IveIntelligenceResult(
      requiresAef: aef,
      answer: aef ? null : text,
      sourceLabels: const ['Alpha'],
      suggestedActions: const [],
      degraded: degraded,
      memoryCandidates: const [],
      correlationId: 'srv',
    );

CopilotContextData _ctx(String? projectId) => CopilotContextData(
      projectId: projectId,
      documents: const [{'title': 'screen-built doc', 'content_excerpt': 'CLIENT BUILT EXCERPT'}],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'ive_recent_questions': ['device-local question']}));

  ProviderContainer container(_FakeService svc) {
    final c = ProviderContainer(overrides: [
      iveIntelligenceCoreEnabledProvider.overrideWithValue(true),
      iveIntelligenceServiceProvider.overrideWithValue(svc),
      diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('sends only the minimal contract: project id, no client-built context, no device memory', () async {
    final svc = _FakeService((_) async => _answer('ok'));
    final c = container(svc);
    const key = ('Projeto', 'pa');
    await c.read(contextCopilotProvider(key).notifier).send(message: 'analise', screenName: 'Projeto', context: _ctx('pa'));
    final json = svc.requests.single.toJson();
    expect(json['project_id'], 'pa');
    expect(json.toString().contains('CLIENT BUILT EXCERPT'), isFalse);
    expect(json.toString().contains('device-local question'), isFalse);
    expect(c.read(contextCopilotProvider(key)).turns.last.content, 'ok');
  });

  test('project switch A → B: B starts a fresh conversation, nothing of A is resent', () async {
    final svc = _FakeService((r) async => _answer('answer for ${r.projectId}'));
    final c = container(svc);
    await c.read(contextCopilotProvider(('Projeto', 'pa')).notifier).send(message: 'pergunta sobre A', screenName: 'Projeto', context: _ctx('pa'));
    await c.read(contextCopilotProvider(('Projeto', 'pb')).notifier).send(message: 'pergunta sobre B', screenName: 'Projeto', context: _ctx('pb'));
    final second = svc.requests.last.toJson();
    expect(second['project_id'], 'pb');
    expect(second['conversation'], isNull, reason: 'no turns from project A');
    expect(second.toString().contains('pergunta sobre A'), isFalse);
  });

  test('same project: the visible transcript is resent as conversation (session continuity)', () async {
    final svc = _FakeService((_) async => _answer('r'));
    final c = container(svc);
    final n = c.read(contextCopilotProvider(('Projeto', 'pa')).notifier);
    await n.send(message: 'primeira', screenName: 'Projeto', context: _ctx('pa'));
    await n.send(message: 'segunda', screenName: 'Projeto', context: _ctx('pa'));
    final conv = (svc.requests.last.toJson()['conversation'] as List).cast<Map>();
    expect(conv.map((t) => t['content']), ['primeira', 'r']);
  });

  test('ACTION_REQUIRES_AEF becomes an AEF turn (no answer) and is not resent as history', () async {
    var n = 0;
    final svc = _FakeService((_) async => n++ == 0 ? _answer('', aef: true) : _answer('ok'));
    final c = container(svc);
    final notifier = c.read(contextCopilotProvider(('Home', null)).notifier);
    await notifier.send(message: 'publique o post', screenName: 'Home', context: _ctx(null));
    final aefTurn = c.read(contextCopilotProvider(('Home', null))).turns.last;
    expect(aefTurn.requiresAef, isTrue);
    expect(aefTurn.content, isEmpty);
    await notifier.send(message: 'outra', screenName: 'Home', context: _ctx(null));
    // Neither the consequential request nor the AEF notice is resent, so the
    // next unrelated question is not re-routed to AEF by the server.
    expect(svc.requests.last.toJson()['conversation'], isNull);
  });

  test('structured failures reach the state (no raw text); degraded context is flagged', () async {
    final failing = _FakeService((_) async => throw const IveIntelligenceException(IveFailure.projectForbidden));
    final c = container(failing);
    const key = ('Projeto', 'pb');
    await c.read(contextCopilotProvider(key).notifier).send(message: 'x', screenName: 'Projeto', context: _ctx('pb'));
    expect(c.read(contextCopilotProvider(key)).failure, IveFailure.projectForbidden);
    expect(c.read(contextCopilotProvider(key)).loading, isFalse);

    final degraded = _FakeService((_) async => _answer('partial', degraded: const ['knowledge']));
    final c2 = container(degraded);
    await c2.read(contextCopilotProvider(key).notifier).send(message: 'x', screenName: 'Projeto', context: _ctx('pb'));
    expect(c2.read(contextCopilotProvider(key)).turns.last.degradedContext, isTrue);
  });

  test('production default: the Intelligence Core path is disabled (compile-time flag off)', () async {
    final svc = _FakeService((_) async => _answer('ok'));
    final c = ProviderContainer(overrides: [iveIntelligenceServiceProvider.overrideWithValue(svc)]);
    addTearDown(c.dispose);
    expect(c.read(iveIntelligenceCoreEnabledProvider), isFalse);
    expect(kIveIntelligenceCoreEnabled, isFalse);
  });
}
