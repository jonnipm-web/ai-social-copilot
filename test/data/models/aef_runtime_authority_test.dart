// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — the Action Engine <-> AEF
// authority boundary (mission §5-6: "Do NOT preserve two competing
// execution authorities... Add tests proving the authority boundary").
//
// aefReceiptOutcomeToActionStatus is the single place action_queue's status
// is ever derived from an AEF result. These tests prove: (1) a non-terminal
// or unreceipted result is refused outright -- there is no path from "the
// user tapped execute" to a written status without AEF actually saying so --
// and (2) the written status always mirrors the receipt's real outcome,
// never a client invention.
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/aef_runtime.dart';

const _op = '0c000000-0000-4000-8000-00000000000c';
const _gate = '0d000000-0000-4000-8000-00000000000d';
final _hash = 'a' * 64;
const _rid = '0e000000-0000-4000-8000-00000000000e';
final _rh = 'c' * 64;

Map<String, dynamic> _reply(String phase, {bool completed = false, Map<String, dynamic>? receipt, String? operationId = _op}) => {
      'phase': phase,
      'completed': completed,
      'reconciliationRequired': phase == 'UNKNOWN_OUTCOME',
      'retryAllowed': false,
      'operationId': operationId,
      'denialCode': null,
      // AWAITING_APPROVAL parses only with a gate (AefRuntimeResult.fromMap) --
      // include one so the malformed cases below exercise the mapping's own
      // guard, not fromMap's earlier fail-closed rejection.
      'gate': phase == 'AWAITING_APPROVAL' ? {'gateId': _gate, 'bindingHash': _hash, 'expiresAt': '2026-01-01T00:00:00Z'} : null,
      'receipt': receipt,
      'replayed': false,
    };

AefRuntimeResult _withOutcome(String outcome) => AefRuntimeResult.fromMap(
      _reply('SUCCEEDED', completed: outcome == 'SUCCESS', receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': outcome}),
    );

void main() {
  group('aefReceiptOutcomeToActionStatus (authority boundary)', () {
    test('a real SUCCESS receipt maps to completed', () {
      expect(aefReceiptOutcomeToActionStatus(_withOutcome('SUCCESS')), 'completed');
    });

    test('FAILURE and NOT_EXECUTED revert to approved -- governance says nothing happened', () {
      for (final outcome in ['FAILURE', 'NOT_EXECUTED']) {
        final r = AefRuntimeResult.fromMap(_reply('FAILED', receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': outcome}));
        expect(aefReceiptOutcomeToActionStatus(r), 'approved', reason: outcome);
      }
    });

    test('PARTIAL and UNKNOWN_OUTCOME require reconciliation -- never shown as done or failed', () {
      final partial = AefRuntimeResult.fromMap(_reply('SUCCEEDED', completed: true, receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'PARTIAL'}));
      final unknown = AefRuntimeResult.fromMap(_reply('UNKNOWN_OUTCOME', receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'UNKNOWN_OUTCOME'}));
      expect(aefReceiptOutcomeToActionStatus(partial), 'executing');
      expect(aefReceiptOutcomeToActionStatus(unknown), 'executing');
    });

    test('refuses a result with no receipt at all, at any phase -- no status may be invented', () {
      for (final phase in ['AWAITING_APPROVAL', 'AUTHORIZED', 'EXECUTING', 'REJECTED', 'EXPIRED', 'CANCELLED', 'INVALIDATED', 'DENIED']) {
        final r = AefRuntimeResult.fromMap(_reply(phase));
        expect(
          () => aefReceiptOutcomeToActionStatus(r),
          throwsA(isA<ArgumentError>()),
          reason: phase,
        );
      }
    });

    test('refuses an unreadable/malformed reply -- a network blip is never a status write', () {
      expect(() => aefReceiptOutcomeToActionStatus(AefRuntimeResult.unreadable), throwsA(isA<ArgumentError>()));
      expect(() => aefReceiptOutcomeToActionStatus(AefRuntimeResult.denied('NETWORK_INTERRUPTED')), throwsA(isA<ArgumentError>()));
    });

    // Codex final audit (P1) -- these four are exactly the cases the
    // original guard (`!isCompleted && receiptOutcome == null`) let through:
    // AefRuntimeResult.fromMap never cross-checks phase against a receipt's
    // outcome, so a non-terminal phase or an inconsistent completed flag
    // could still carry a syntactically valid receipt and reach a status
    // write. None of these may ever be reachable now.
    test('a non-terminal phase (AWAITING_APPROVAL) carrying a SUCCESS receipt is refused, not treated as done', () {
      final r = AefRuntimeResult.fromMap(_reply('AWAITING_APPROVAL', receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'SUCCESS'}));
      expect(r.phase, AefPhase.awaitingApproval, reason: 'sanity: this reply must actually parse, not fall back to unreadable');
      expect(() => aefReceiptOutcomeToActionStatus(r), throwsA(isA<ArgumentError>()));
    });

    test('phase SUCCEEDED with a SUCCESS receipt but completed=false is refused (server never confirmed it ran)', () {
      final r = AefRuntimeResult.fromMap(_reply('SUCCEEDED', completed: false, receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'SUCCESS'}));
      expect(() => aefReceiptOutcomeToActionStatus(r), throwsA(isA<ArgumentError>()));
    });

    test('a terminal, receipted result with no operation id is refused -- provenance would be unrecordable', () {
      final r = AefRuntimeResult.fromMap(_reply('FAILED', operationId: null, receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'FAILURE'}));
      expect(() => aefReceiptOutcomeToActionStatus(r), throwsA(isA<ArgumentError>()));
    });

    test('mismatched phase/outcome (FAILED phase with a SUCCESS receipt) never maps to completed', () {
      final r = AefRuntimeResult.fromMap(_reply('FAILED', receipt: {'receiptId': _rid, 'receiptHash': _rh, 'outcome': 'SUCCESS'}));
      expect(() => aefReceiptOutcomeToActionStatus(r), throwsA(isA<ArgumentError>()));
    });
  });
}
