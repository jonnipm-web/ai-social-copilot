// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — the authority boundary at the
// integration point that matters most: the widget Action Engine actually
// opens for "execute". Proves (a) it drives the AEF Human Gate under the
// action-engine capability/tool, never IVE's, (b) it pre-fills the real
// action_queue item so the user reviews rather than retypes it, and (c) it
// persists to action_queue ONLY once AEF returns a real receipted result --
// a rejection or an in-flight decision writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/aef_runtime.dart';
import 'package:ai_social_copilot/data/services/action_queue_service.dart';
import 'package:ai_social_copilot/data/services/aef_runtime_service.dart';
import 'package:ai_social_copilot/features/action_engine/widgets/action_engine_execute_sheet.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/action_queue_provider.dart';

const _op = '0c000000-0000-4000-8000-00000000000c';
const _gate = '0d000000-0000-4000-8000-00000000000d';
final _hash = 'a' * 64;
const _rid = '0e000000-0000-4000-8000-00000000000e';
final _rh = 'c' * 64;

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
    return AefRuntimeResult.fromMap(
      executeReply ?? _reply('SUCCEEDED', completed: true, receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'SUCCESS'}),
    );
  }

  @override
  Future<AefRuntimeResult> status(String operationId) async => AefRuntimeResult.unreadable;
}

/// Same technique as action_queue_provider_test.dart: extend the real
/// service (there is no separate interface) but override every method this
/// widget's provider tree can reach, so Supabase.instance.client is never
/// touched.
class FakeActionQueueService extends ActionQueueService {
  final List<String> calls = [];

  @override
  Future<List<ActionQueueItem>> fetchAll({String? projectId, String? status}) async {
    calls.add('fetchAll');
    return [];
  }

  @override
  Future<ActionQueueItem> applyAefResult(String id, AefRuntimeResult result) async {
    calls.add('applyAefResult:${result.receiptOutcome}');
    return ActionQueueItem(id: id, userId: 'u1', title: 'Publicar post', status: 'completed', createdAt: DateTime(2026, 1, 1));
  }

  @override
  Future<ActionQueueItem> updateStatus(String id, String status) async {
    calls.add('updateStatus:$status');
    return ActionQueueItem(id: id, userId: 'u1', title: 'Publicar post', status: status, createdAt: DateTime(2026, 1, 1));
  }
}

final _item = ActionQueueItem(
  id: 'a1',
  userId: 'u1',
  projectId: null,
  title: 'Publicar post de lançamento',
  status: 'approved',
  createdAt: DateTime(2026, 1, 1),
);

Widget _app(Widget child, {required FakeApi api, required FakeActionQueueService svc}) => ProviderScope(
      overrides: [
        actionEngineRuntimeApiProvider.overrideWithValue(api),
        actionQueueServiceProvider.overrideWithValue(svc),
      ],
      child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // Mirrors action_engine_screen.dart, which keeps actionQueueNotifierProvider
        // (.autoDispose) alive for the whole screen lifetime via ref.watch. Without a
        // watcher, the sheet's own ref.read(...notifier) doesn't keep it alive and it
        // disposes mid-test -- a harness artifact, not a real-app scenario.
        home: Consumer(builder: (context, ref, _) {
          ref.watch(actionQueueNotifierProvider);
          return Scaffold(body: SingleChildScrollView(child: child));
        }),
      ),
    );

void main() {
  group('ActionEngineExecuteSheet (authority boundary)', () {
    testWidgets('drives the action-engine capability/tool, not IVE\'s -- and pre-fills the real item', (t) async {
      final api = FakeApi();
      final svc = FakeActionQueueService();
      await t.pumpWidget(_app(ActionEngineExecuteSheet(item: _item), api: api, svc: svc));
      await t.pumpAndSettle();

      // action_id/summary are pre-filled from the item, not retyped.
      expect(t.widget<TextField>(find.byKey(const Key('aef-field-action_id'))).controller!.text, 'a1');
      expect(t.widget<TextField>(find.byKey(const Key('aef-field-summary'))).controller!.text, _item.title);

      await t.tap(find.byKey(const Key('aef-request')));
      await t.pumpAndSettle();

      expect(api.calls, ['propose']);
      final proposal = api.proposals.single;
      expect(proposal['capabilityId'], 'action-engine');
      expect(proposal['requestedAction'], 'complete_action');
      expect(proposal['riskClass'], 'CONSEQUENTIAL');
      expect(proposal['contextRef'], 'a1');
    });

    testWidgets('a real SUCCESS receipt persists via applyAefResult, never a direct status write', (t) async {
      final api = FakeApi();
      final svc = FakeActionQueueService();
      await t.pumpWidget(_app(ActionEngineExecuteSheet(item: _item), api: api, svc: svc));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('aef-request')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('aef-approve')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('aef-execute')));
      await t.pumpAndSettle();

      expect(svc.calls, contains('applyAefResult:SUCCESS'));
      expect(svc.calls.any((c) => c.startsWith('updateStatus')), isFalse);
    });

    testWidgets('rejection persists nothing -- no receipt means no write at all', (t) async {
      final api = FakeApi();
      final svc = FakeActionQueueService();
      await t.pumpWidget(_app(ActionEngineExecuteSheet(item: _item), api: api, svc: svc));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('aef-request')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('aef-reject')));
      await t.pumpAndSettle();

      expect(svc.calls.any((c) => c.startsWith('applyAefResult') || c.startsWith('updateStatus')), isFalse);
    });

    testWidgets('an UNKNOWN_OUTCOME receipt still persists -- as executing, not silently dropped', (t) async {
      final api = FakeApi(executeReply: _reply('UNKNOWN_OUTCOME', receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'UNKNOWN_OUTCOME'}));
      final svc = FakeActionQueueService();
      await t.pumpWidget(_app(ActionEngineExecuteSheet(item: _item), api: api, svc: svc));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('aef-request')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('aef-approve')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('aef-execute')));
      await t.pumpAndSettle();

      expect(svc.calls, contains('applyAefResult:UNKNOWN_OUTCOME'));
    });
  });
}
