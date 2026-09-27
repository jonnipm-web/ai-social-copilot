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
import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/services/action_queue_service.dart';

void main() {
  group('ActionQueueService.updateStatus (authority boundary)', () {
    test('refuses to write AEF-governed-only statuses directly', () {
      final svc = ActionQueueService();
      for (final status in ['executing', 'completed']) {
        expect(() => svc.updateStatus('a1', status), throwsA(isA<ArgumentError>()), reason: status);
      }
    });

    // Codex re-verification (Macro-03) — the first guard was an exact-string
    // Set.contains, so a case or whitespace variant of a governed-only
    // status would reach the raw Supabase update untouched.
    test('refuses case and whitespace variants of AEF-governed-only statuses', () {
      final svc = ActionQueueService();
      for (final status in ['Executing', 'COMPLETED', ' completed', 'completed ', 'ExEcUtInG']) {
        expect(() => svc.updateStatus('a1', status), throwsA(isA<ArgumentError>()), reason: status);
      }
    });

    test('does not refuse legitimate, non-governed statuses', () {
      final svc = ActionQueueService();
      // approve()/cancel() -- the only real callers -- must remain unaffected.
      // These still reach _client (a lazy getter) and would throw on the
      // network call itself in a plain test process; the point here is only
      // that they are NOT rejected by the guard before that.
      expect(() => svc.updateStatus('a1', 'approved'), throwsA(isNot(isA<ArgumentError>())));
      expect(() => svc.updateStatus('a1', 'cancelled'), throwsA(isNot(isA<ArgumentError>())));
    });

    // INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04 §26 -- the round-3
    // Codex audit's P3: trim()+toLowerCase() alone does not remove an
    // invisible Unicode format character, so 'completed​' (a zero-
    // width space appended) would not match the literal 'completed' and
    // could slip through. Fixed by stripping Unicode category Cf before
    // comparing.
    test('refuses invisible-Unicode-format-character variants (zero-width space/joiner, BOM)', () {
      final svc = ActionQueueService();
      final variants = [
        'completed​', // zero-width space
        '​completed',
        'compl​eted',
        'executing‌', // zero-width non-joiner
        'executing‍', // zero-width joiner
        '﻿completed', // byte-order mark / zero-width no-break space
        'completed⁠', // word joiner
      ];
      for (final status in variants) {
        expect(() => svc.updateStatus('a1', status), throwsA(isA<ArgumentError>()), reason: status.codeUnits.toString());
      }
    });

    test('a legitimate status with no invisible characters is still not refused after the Cf-stripping change', () {
      final svc = ActionQueueService();
      expect(() => svc.updateStatus('a1', 'approved'), throwsA(isNot(isA<ArgumentError>())));
    });
  });

  group('ActionQueueService.create (authority boundary)', () {
    test('refuses to insert an item already carrying an AEF-governed-only status', () {
      final svc = ActionQueueService();
      for (final status in ['executing', 'completed', 'Completed']) {
        final item = ActionQueueItem(id: '', userId: 'u1', title: 'x', status: status, createdAt: DateTime(2026, 1, 1));
        expect(() => svc.create(item), throwsA(isA<ArgumentError>()), reason: status);
      }
    });
  });
}
