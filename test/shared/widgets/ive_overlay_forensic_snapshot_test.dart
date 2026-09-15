// IVE-COMMERCIAL-STABILITY-09O — proves IveOverlay's forensic-snapshot
// wiring (mounted/dispose/dragging/profile-resolved/issue-present) actually
// fires inside a real widget tree, not just that the one-line call sites
// compile. Same harness pattern as ive_overlay_auth_gate_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/core/diagnostics/ive_forensic_snapshot.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/providers/auth_provider.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart';

class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

class MockSession extends Mock implements Session {}

Profile _fakeProfile() => Profile(
      id: 'user-1',
      role: 'free',
      monthlyLimit: 5,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

AuthState _authState({Session? session}) =>
    AuthState(session != null ? AuthChangeEvent.signedIn : AuthChangeEvent.signedOut, session);

void main() {
  setUp(() {
    IveForensicSnapshot.overlayMounted = false;
    IveForensicSnapshot.overlayDragging = false;
    IveForensicSnapshot.issuePresent = false;
    IveForensicSnapshot.profileResolved = false;
  });

  Widget harness() => ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SizedBox.expand(child: ColoredBox(color: Colors.black)),
                IveOverlay(),
              ],
            ),
          ),
        ),
      );

  testWidgets('mounting the overlay sets overlayMounted; unmounting clears it', (tester) async {
    expect(IveForensicSnapshot.overlayMounted, isFalse);
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(IveForensicSnapshot.overlayMounted, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(IveForensicSnapshot.overlayMounted, isFalse);
  });

  testWidgets('an authenticated, resolved profile sets profileResolved', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(IveForensicSnapshot.profileResolved, isTrue);
  });

  testWidgets('dragging the avatar sets overlayDragging true, then false on release', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final avatarFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
    );
    expect(avatarFinder, findsOneWidget);
    expect(IveForensicSnapshot.overlayDragging, isFalse);

    final gesture = await tester.startGesture(tester.getCenter(avatarFinder));
    await tester.pump();
    await gesture.moveBy(const Offset(-10, -10));
    await tester.pump();
    expect(IveForensicSnapshot.overlayDragging, isTrue);

    await gesture.up();
    await tester.pump();
    expect(IveForensicSnapshot.overlayDragging, isFalse);
  });
}
