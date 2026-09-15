/// IVE-COMMERCIAL-EXPERIENCE-14, Codex Gate P0 remediation — tests the
/// ownership-verification predicate used by MarketIntelligenceScreen's
/// `_verifiedProjectId` getter (lib/features/market_intelligence/screens/
/// market_intelligence_screen.dart). Replicates only the predicate itself
/// (same pattern already used by test/features/projects/
/// project_command_center_logic_test.dart — pure logic, no widget pumping)
/// since the getter's own logic is a one-line `owned.any((p) => p.id == id)`
/// that needs no Flutter widget context to verify meaningfully.
///
/// The property under test: a client-supplied projectId (from GoRouter
/// `extra`, which is untrusted) must NEVER be accepted as authority to bind
/// a market analysis to a project unless it appears in the CURRENT user's
/// own (RLS-scoped) project list. "Client projectId is context, never
/// authority."
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/project.dart';

Project _p(String id) => Project(
      id:        id,
      userId:    'uid',
      name:      'Project $id',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Mirrors `_verifiedProjectId` exactly: accept `candidateId` only if it
/// appears in `owned` (the caller's own project list); `null` if the list
/// hasn't loaded yet (fail closed, not open).
String? _verify(String? candidateId, List<Project>? owned) {
  if (candidateId == null) return null;
  if (owned == null) return null;
  return owned.any((p) => p.id == candidateId) ? candidateId : null;
}

void main() {
  group('Idea Analysis — project-binding ownership verification', () {
    test('accepts a projectId that belongs to the current user', () {
      final owned = [_p('proj-a'), _p('proj-b')];
      expect(_verify('proj-a', owned), 'proj-a');
    });

    test('rejects a projectId not present in the current user\'s own project list', () {
      final owned = [_p('proj-a'), _p('proj-b')];
      // Simulates a tampered/forged route `extra` pointing at a project
      // the current user does not own.
      expect(_verify('someone-elses-project', owned), isNull);
    });

    test('rejects (fails closed) when the owned-projects list has not loaded yet', () {
      expect(_verify('proj-a', null), isNull);
    });

    test('null candidateId stays null (no project context requested)', () {
      final owned = [_p('proj-a')];
      expect(_verify(null, owned), isNull);
    });

    test('rejects when the owned list is loaded but empty', () {
      expect(_verify('proj-a', const []), isNull);
    });
  });
}
