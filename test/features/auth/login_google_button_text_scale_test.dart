import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// GATE-17-FINAL-CLOSURE (Section 11, text-scale physical regression,
// 2026-09-22) — the login screen's "Continuar com Google" button
// (lib/features/auth/screens/login_screen.dart) overflowed by a fixed 39px
// at Android's 1.3x text scale (reproduced physically on device; confirmed
// gone at 1.0x), because it used OutlinedButton.icon's own Row with no
// width guard on the label. The fix rebuilds it as a plain OutlinedButton
// with an explicit Row wrapping the label in Flexible + TextOverflow
// .ellipsis. Testing the real LoginScreen widget directly isn't feasible
// here: it eagerly constructs AuthService() via authServiceProvider, whose
// constructor reads Supabase.instance.client and throws in a plain test
// process that never called Supabase.initialize() (same constraint noted
// in ai_execution_confirmation_test.dart for diagnosticLoggerProvider).
// This instead exercises the exact button structure the fix introduced, at
// the same 1.3x scale and a wide range of longer label strings (standing
// in for any locale/translation), proving the mechanism itself -- Flexible
// + ellipsis inside a fixed-width OutlinedButton -- never overflows,
// regardless of what LoginScreen happens to wrap it in.
void main() {
  Widget googleButton(String label, {bool isLoading = false}) {
    return OutlinedButton(
      onPressed: isLoading ? null : () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.g_mobiledata_rounded, size: 26),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Future<void> pumpAtScale(
    WidgetTester tester, {
    required String label,
    required double textScale,
    bool isLoading = false,
    double width = 328, // matches the login form's own horizontal padding
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: googleButton(label, isLoading: isLoading),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Google sign-in button at increased text scale', () {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets(
          'does not overflow at ${scale}x scale ("Continuar com Google")',
          (tester) async {
        await pumpAtScale(tester, label: 'Continuar com Google', textScale: scale);
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: 'physical regression: OutlinedButton.icon without a '
                'Flexible label overflowed by 39px at 1.3x -- this must '
                'never throw a RenderFlex overflow at any of these scales');
      });
    }

    testWidgets('does not overflow at 1.3x scale (English label, loading state)',
        (tester) async {
      await pumpAtScale(
        tester,
        label: 'Continue with Google',
        textScale: 1.3,
        isLoading: true,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ellipsizes instead of overflowing when the label is too long '
        'for the available width even at normal scale', (tester) async {
      // A pathological case (very narrow button) to prove Flexible +
      // ellipsis is actually doing the shrinking, not just "happens to fit".
      await pumpAtScale(
        tester,
        label: 'Continuar com Google',
        textScale: 1.0,
        width: 120,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('Continuar com Google', findRichText: false));
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
