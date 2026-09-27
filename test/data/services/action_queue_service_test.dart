// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — Codex final audit (P1): before
// this guard, updateStatus() was a generic, public method that would happily
// write 'executing' or 'completed' for any caller, present or future,
// completely bypassing applyAefResult (and therefore the Human Gate/receipt)
// -- the exact "latent architectural gap" this mission set out to close.
//
// The guard runs before ActionQueueService ever touches Supabase.instance
// (the client is a lazy getter -- SupabaseClient get _client =>
// Supabase.instance.client), so the REAL class can be constructed and
// exercised directly here without a fake or a live Supabase instance.
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/services/action_queue_service.dart';

void main() {
  group('ActionQueueService.updateStatus (authority boundary)', () {
    test('refuses to write AEF-governed-only statuses directly', () {
      final svc = ActionQueueService();
      for (final status in ['executing', 'completed']) {
        expect(() => svc.updateStatus('a1', status), throwsA(isA<ArgumentError>()), reason: status);
      }
    });
  });
}
