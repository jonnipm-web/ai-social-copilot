// IV-IVE-AEF-RUNTIME-INTEGRATION-01 — LAB Human Gate card + fail-closed model.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/aef_runtime.dart';
import 'package:ai_social_copilot/data/services/aef_runtime_service.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/shared/widgets/aef_action_card.dart';

const _op = '0c000000-0000-4000-8000-00000000000c';
const _gate = '0d000000-0000-4000-8000-00000000000d';
final _hash = 'a' * 64;

Map<String, dynamic> _reply(String phase, {bool completed = false, Map<String, dynamic>? receipt, bool gate = false}) => {
      'phase': phase,
      'completed': completed,
      'reconciliationRequired': phase == 'UNKNOWN_OUTCOME',
      'retryAllowed': false,
      'operationId': _op,
      'denialCode': null,
      'gate': gate ? {'gateId': _gate, 'bindingHash': _hash, 'expiresAt': '2026-01-01T00:00:00Z'} : null,
      'receipt': receipt,
      'replayed': false,
    };

class FakeApi implements AefRuntimeApi {
  FakeApi({this.executeReply});
  final List<String> calls = [];
  final List<Map<String, dynamic>> proposals = [];
  Map<String, dynamic>? executeReply;

  @override
  Future<AefRuntimeResult> propose(Map<String, dynamic> proposal) async {
    calls.add('propose');
    proposals.add(proposal);
    return AefRuntimeResult.fromMap(_reply('AWAITING_APPROVAL', gate: true));
  }

  @override
  Future<AefRuntimeResult> decide(AefGate gate, {required bool approve}) async {
    calls.add(approve ? 'approve' : 'reject');
    return AefRuntimeResult.fromMap(_reply(approve ? 'AUTHORIZED' : 'REJECTED'));
  }

  @override
  Future<AefRuntimeResult> execute(Map<String, dynamic> proposal) async {
    calls.add('execute');
    proposals.add(proposal);
    return AefRuntimeResult.fromMap(executeReply ?? _reply('SUCCEEDED', completed: true, receipt: {'receiptId': 'r-1', 'outcome': 'SUCCESS'}));
  }

  @override
  Future<AefRuntimeResult> status(String operationId) async => AefRuntimeResult.unreadable;
}

const _intent = IveActionIntentData(
  capabilityId: null,
  requestedAction: 'publish_content',
  projectId: null,
  riskClass: 'CONSEQUENTIAL',
  contextRef: '0b000000-0000-4000-8000-00000000000b',
);

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Future<void> _fill(WidgetTester t) async {
  await t.tap(find.byKey(const Key('aef-field-channel')));
  await t.pumpAndSettle();
  await t.tap(find.text('blog').last);
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('aef-field-text')), 'Lançamento');
  await t.pump();
}

void main() {
  group('AefRuntimeResult (fail closed)', () {
    test('done only for SUCCEEDED + server completed + SUCCESS receipt', () {
      expect(AefRuntimeResult.fromMap(_reply('SUCCEEDED', completed: true, receipt: {'receiptId': 'r', 'outcome': 'SUCCESS'})).isCompleted, isTrue);
      expect(AefRuntimeResult.fromMap(_reply('SUCCEEDED', completed: false, receipt: {'receiptId': 'r', 'outcome': 'SUCCESS'})).isCompleted, isFalse);
      expect(AefRuntimeResult.fromMap(_reply('SUCCEEDED', completed: true)).isCompleted, isFalse);
      expect(AefRuntimeResult.fromMap(_reply('SUCCEEDED', completed: true, receipt: {'receiptId': 'r', 'outcome': 'FAILURE'})).isCompleted, isFalse);
      for (final p in ['AUTHORIZED', 'EXECUTING', 'FAILED', 'UNKNOWN_OUTCOME', 'REJECTED', 'EXPIRED', 'CANCELLED', 'INVALIDATED']) {
        expect(AefRuntimeResult.fromMap(_reply(p, completed: true, receipt: {'receiptId': 'r', 'outcome': 'SUCCESS'})).isCompleted, isFalse, reason: p);
      }
    });

    test('unknown phase, malformed ids or gate, and non-maps are unreadable (never progress)', () {
      for (final raw in <Object?>[
        null, 'SUCCEEDED', [], {'phase': 'DONE'}, {'phase': 'succeeded'},
        {..._reply('SUCCEEDED'), 'operationId': 'not-a-uuid'},
        {..._reply('AWAITING_APPROVAL'), 'gate': null},
        {..._reply('AWAITING_APPROVAL', gate: true), 'gate': {'gateId': _gate, 'bindingHash': 'short', 'expiresAt': 'x'}},
        {..._reply('SUCCEEDED'), 'receipt': 'forged'},
      ]) {
        final r = AefRuntimeResult.fromMap(raw);
        expect(r.phase, AefPhase.denied, reason: '$raw');
        expect(r.isCompleted, isFalse);
      }
    });

    test('UNKNOWN_OUTCOME always requires reconciliation', () {
      expect(AefRuntimeResult.fromMap({..._reply('UNKNOWN_OUTCOME'), 'reconciliationRequired': false}).reconciliationRequired, isTrue);
    });

    test('intent parsing is strict; the proposal carries only the six intent keys', () {
      expect(IveActionIntentData.tryParse({'requestedAction': 'publish_content', 'contextRef': 'x', 'riskClass': 'CONSEQUENTIAL'}), isNull);
      expect(IveActionIntentData.tryParse({'requestedAction': 'Publish Content', 'contextRef': _op, 'riskClass': 'CONSEQUENTIAL'}), isNull);
      final p = _intent.toProposal({'channel': 'blog', 'text': 'x'});
      expect(p.keys.toSet(), {'capabilityId', 'requestedAction', 'projectId', 'riskClass', 'contextRef', 'parameters'});
    });
  });

  group('AefActionCard', () {
    testWidgets('nothing runs without an explicit approval; approve and run are separate clicks', (t) async {
      final api = FakeApi();
      await t.pumpWidget(_app(AefActionCard(intent: _intent, api: api)));
      expect(find.textContaining('Nada foi executado'), findsWidgets);
      expect(find.byKey(const Key('aef-approve')), findsNothing);
      // Request is disabled until every field is valid.
      expect(t.widget<ElevatedButton>(find.byKey(const Key('aef-request'))).onPressed, isNull);
      await _fill(t);
      await t.tap(find.byKey(const Key('aef-request')));
      await t.pumpAndSettle();
      expect(api.calls, ['propose']);
      expect(find.byKey(const Key('aef-approve')), findsOneWidget);
      expect(find.byKey(const Key('aef-reject')), findsOneWidget);
      // Waiting does not approve anything.
      await t.pump(const Duration(minutes: 30));
      expect(api.calls, ['propose']);
      await t.tap(find.byKey(const Key('aef-approve')));
      await t.pumpAndSettle();
      expect(api.calls, ['propose', 'approve']);
      expect(find.textContaining('ainda não executada'), findsOneWidget);
      await t.tap(find.byKey(const Key('aef-execute')));
      await t.pumpAndSettle();
      expect(api.calls, ['propose', 'approve', 'execute']);
      expect(find.textContaining('Concluída'), findsOneWidget);
      // The executed payload is exactly the one proposed (locked after the proposal).
      expect(api.proposals.last['parameters'], api.proposals.first['parameters']);
    });

    testWidgets('fields are locked once proposed (approval binds that exact payload)', (t) async {
      final api = FakeApi();
      await t.pumpWidget(_app(AefActionCard(intent: _intent, api: api)));
      await _fill(t);
      await t.tap(find.byKey(const Key('aef-request')));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(find.byKey(const Key('aef-field-text'))).enabled, isFalse);
    });

    testWidgets('reject is terminal and never executes', (t) async {
      final api = FakeApi();
      await t.pumpWidget(_app(AefActionCard(intent: _intent, api: api)));
      await _fill(t);
      await t.tap(find.byKey(const Key('aef-request')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('aef-reject')));
      await t.pumpAndSettle();
      expect(api.calls, ['propose', 'reject']);
      expect(find.textContaining('Rejeitada'), findsOneWidget);
      expect(find.byKey(const Key('aef-execute')), findsNothing);
      expect(find.textContaining('Concluída'), findsNothing);
    });

    testWidgets('UNKNOWN_OUTCOME is distinct from FAILED, never "done", and offers no retry', (t) async {
      for (final (reply, text, icon) in [
        (_reply('UNKNOWN_OUTCOME', receipt: {'receiptId': 'r', 'outcome': 'UNKNOWN_OUTCOME'}), 'Resultado desconhecido', Icons.help),
        (_reply('FAILED', receipt: {'receiptId': 'r', 'outcome': 'FAILURE'}), 'Falhou', Icons.error),
        (_reply('SUCCEEDED', completed: false), 'não confirmada', Icons.hourglass_top),
      ]) {
        final api = FakeApi(executeReply: reply);
        await t.pumpWidget(_app(AefActionCard(key: UniqueKey(), intent: _intent, api: api)));
        await _fill(t);
        await t.tap(find.byKey(const Key('aef-request')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('aef-approve')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('aef-execute')));
        await t.pumpAndSettle();
        expect(find.textContaining(text), findsOneWidget, reason: text);
        expect(find.byIcon(icon), findsOneWidget, reason: text);
        expect(find.textContaining('Concluída'), findsNothing, reason: text);
        expect(find.byKey(const Key('aef-execute')), findsNothing, reason: 'no retry after $text');
      }
    });

    testWidgets('a network interruption is shown as unconfirmed, never as progress', (t) async {
      final api = _NetworkDownApi();
      await t.pumpWidget(_app(AefActionCard(intent: _intent, api: api)));
      await _fill(t);
      await t.tap(find.byKey(const Key('aef-request')));
      await t.pumpAndSettle();
      expect(find.textContaining('Sem resposta confiável'), findsOneWidget);
      expect(find.byKey(const Key('aef-approve')), findsNothing);
    });
  });
}

class _NetworkDownApi extends FakeApi {
  @override
  Future<AefRuntimeResult> propose(Map<String, dynamic> proposal) async => AefRuntimeResult.denied('NETWORK_INTERRUPTED');
}
