// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — proves ActionQueueNotifier routes
// the governed execute/complete transition through ActionQueueService's
// AEF-derived write path (applyAefResult) and NEVER through the old,
// ungoverned direct status write (updateStatus). That is the authority
// boundary at the provider layer: nothing between the UI and the database
// may invent a status for this transition.
//
// FakeActionQueueService extends the real ActionQueueService (there is no
// separate interface for it) but overrides every method actually exercised
// here, so the real Supabase-backed methods -- which eagerly read
// Supabase.instance.client -- are never called. See action_queue_service.dart
// (SupabaseClient get _client => Supabase.instance.client;), the same lazy
// pattern already used by AefRuntimeService/IveIntelligenceService for
// exactly this reason.
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/aef_runtime.dart';
import 'package:ai_social_copilot/data/services/action_queue_service.dart';
import 'package:ai_social_copilot/providers/action_queue_provider.dart';

const _rid = '0e000000-0000-4000-8000-00000000000e';
final _rh = 'c' * 64;

Map<String, dynamic> _reply(String phase, {bool completed = false, Map<String, dynamic>? receipt}) => {
      'phase': phase,
      'completed': completed,
      'reconciliationRequired': phase == 'UNKNOWN_OUTCOME',
      'retryAllowed': false,
      'operationId': '0c000000-0000-4000-8000-00000000000c',
      'denialCode': null,
      'gate': null,
      'receipt': receipt,
      'replayed': false,
    };

AefRuntimeResult _succeeded() => AefRuntimeResult.fromMap(
      _reply('SUCCEEDED', completed: true, receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'SUCCESS'}),
    );

ActionQueueItem _item(String status) => ActionQueueItem(
      id: 'a1',
      userId: 'u1',
      title: 'Publicar post',
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

class FakeActionQueueService extends ActionQueueService {
  final List<String> calls = [];
  String currentStatus = 'approved';

  @override
  Future<List<ActionQueueItem>> fetchAll({String? projectId, String? status}) async {
    calls.add('fetchAll');
    return [_item(currentStatus)];
  }

  @override
  Future<ActionQueueItem> updateStatus(String id, String status) async {
    calls.add('updateStatus:$status');
    currentStatus = status;
    return _item(status);
  }

  @override
  Future<ActionQueueItem> applyAefResult(String id, AefRuntimeResult result) async {
    calls.add('applyAefResult:${result.receiptOutcome}');
    // Real invariant preserved even in the fake: no status without a receipt.
    currentStatus = aefReceiptOutcomeToActionStatus(result);
    return _item(currentStatus);
  }
}

void main() {
  group('ActionQueueNotifier.applyGovernedResult (authority boundary)', () {
    test('a receipted SUCCESS goes through applyAefResult, never updateStatus', () async {
      final svc = FakeActionQueueService();
      final notifier = ActionQueueNotifier(svc);
      await Future<void>.delayed(Duration.zero); // let the initial load() settle

      await notifier.applyGovernedResult('a1', _succeeded());

      expect(svc.calls, ['fetchAll', 'applyAefResult:SUCCESS', 'fetchAll']);
      expect(svc.calls.any((c) => c.startsWith('updateStatus')), isFalse);
      expect(notifier.state.value!.single.status, 'completed');
    });

    test('a non-receipted result is refused before it ever reaches the service (fail closed)', () async {
      final svc = FakeActionQueueService();
      final notifier = ActionQueueNotifier(svc);
      await Future<void>.delayed(Duration.zero);

      final awaiting = AefRuntimeResult.fromMap(_reply('AWAITING_APPROVAL'));
      await expectLater(
        () => notifier.applyGovernedResult('a1', awaiting),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('approve() and cancel() remain direct status writes -- unrelated to AEF governance', () async {
      final svc = FakeActionQueueService();
      final notifier = ActionQueueNotifier(svc);
      await Future<void>.delayed(Duration.zero);

      await notifier.approve('a1');
      expect(svc.calls.last, 'fetchAll');
      expect(svc.calls, contains('updateStatus:approved'));
    });
  });
}
