import 'package:ai_social_copilot/features/impact/data/impact_lab_api.dart';
import 'package:ai_social_copilot/features/impact/screens/impact_claim_screen.dart';
import 'package:ai_social_copilot/features/impact/screens/impact_dossier_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'impact_domain_test.dart' show largeDossier;
import 'impact_test_support.dart';

/// IV-IMPACT-I6 — keyboard / focus closure (Codex I5G3-04 remainder).
void main() {
  const dossierScreen = ImpactDossierScreen(investigationId: kInvestigationId);
  const tall = Size(390, 9000);

  Rect focusedRect() => FocusManager.instance.primaryFocus!.rect;

  /// The focused node sits on [f] (buttons add tap-target padding around the
  /// focus node, so compare by containment, not rect equality).
  bool focusedOn(WidgetTester tester, Finder f) => tester.getRect(f).contains(focusedRect().center);

  Future<List<Rect>> tabThrough(WidgetTester tester, int n, {bool shift = false}) async {
    final rects = <Rect>[];
    for (var i = 0; i < n; i++) {
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      rects.add(focusedRect());
    }
    return rects;
  }

  testWidgets('UI-KB-01 Tab follows reading order (claims → Issue snapshot), Shift+Tab reverses it', (tester) async {
    await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: fixture('dossier_confirmed_en')), size: tall);
    final forward = await tabThrough(tester, 3);
    for (var i = 1; i < forward.length; i++) {
      expect(forward[i].top, greaterThan(forward[i - 1].top), reason: 'focus must move down the page');
    }
    expect(focusedOn(tester, find.widgetWithText(FilledButton, 'Issue snapshot')), isTrue);
    final back = await tabThrough(tester, 2, shift: true);
    expect(back.last, forward.first, reason: 'Shift+Tab returns to the first claim');
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets('UI-KB-02 ${key.keyLabel} activates a focused claim tile', (tester) async {
      await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: fixture('dossier_confirmed_en')), size: tall);
      await tabThrough(tester, 1);
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(find.byType(ImpactClaimScreen), findsOneWidget);
    });
  }

  testWidgets('UI-KB-03 export confirmation: focus moves into the dialog, Esc cancels, focus returns to the button', (tester) async {
    final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'), export: fixture('export_confirmed_en'));
    await pumpImpact(tester, dossierScreen, transport: tr, size: tall);
    final issue = find.widgetWithText(FilledButton, 'Issue snapshot');
    await tabThrough(tester, 3);
    expect(focusedOn(tester, issue), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final dialogRect = tester.getRect(find.byType(AlertDialog));
    for (final r in await tabThrough(tester, 3)) {
      expect(dialogRect.contains(r.center), isTrue, reason: 'focus stays inside the modal');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tr.calls.where((c) => c['action'] == 'export_dossier'), isEmpty, reason: 'Esc never issues');
    expect(focusedOn(tester, issue), isTrue, reason: 'focus returns to the control that opened the dialog');
  });

  testWidgets('UI-KB-04 keyboard confirm in the dialog issues exactly once', (tester) async {
    final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'), export: fixture('export_confirmed_en'));
    await pumpImpact(tester, dossierScreen, transport: tr, size: tall);
    await tabThrough(tester, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Issue');
    for (var i = 0; i < 6 && !focusedOn(tester, confirm); i++) {
      await tabThrough(tester, 1);
    }
    expect(focusedOn(tester, confirm), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tr.calls.where((c) => c['action'] == 'export_dossier'), hasLength(1));
    expect(find.text('Snapshot issued'), findsOneWidget);
  });

  testWidgets('UI-KB-05 "show more" is keyboard-reachable and activatable', (tester) async {
    await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: largeDossier(30)), size: const Size(390, 20000));
    final showMore = find.widgetWithText(TextButton, 'Show more (10)');
    var reached = false;
    for (var i = 0; i < 40 && !reached; i++) {
      await tabThrough(tester, 1);
      reached = focusedOn(tester, showMore);
    }
    expect(reached, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.textContaining('Show more'), findsNothing, reason: 'all 30 shown');
  });

  testWidgets('UI-KB-06 "try again" is keyboard-reachable; Space retries (no automatic retry)', (tester) async {
    final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'), error: const ImpactApiException(ImpactErrorKind.network));
    await pumpImpact(tester, dossierScreen, transport: tr);
    expect(tr.calls, hasLength(1));
    await tabThrough(tester, 1);
    expect(focusedOn(tester, find.widgetWithText(OutlinedButton, 'Try again')), isTrue);
    tr.error = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Live view'), findsOneWidget);
    expect(tr.calls, hasLength(2));
  });

  testWidgets('UI-KB-07 keyboard use switches to a visible focus highlight', (tester) async {
    await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: fixture('dossier_confirmed_en')), size: tall);
    await tabThrough(tester, 1);
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    final ctx = tester.element(find.byType(ImpactDossierBody));
    expect(Theme.of(ctx).focusColor.a, greaterThan(0), reason: 'the focus highlight colour is not transparent');
  });
}
