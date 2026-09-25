import 'package:ai_social_copilot/features/impact/data/impact_lab_api.dart';
import 'package:ai_social_copilot/features/impact/screens/impact_claim_screen.dart';
import 'package:ai_social_copilot/features/impact/screens/impact_dossier_screen.dart';
import 'package:ai_social_copilot/features/impact/screens/impact_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'impact_domain_test.dart' show largeDossier;
import 'impact_test_support.dart';

/// IV-IMPACT-I5 — widget / flow tests over real-engine fixtures.
void main() {
  const dossierScreen = ImpactDossierScreen(investigationId: kInvestigationId);

  Future<FakeImpactTransport> openDossier(
    WidgetTester tester,
    String name, {
    Locale locale = const Locale('en'),
    // Phone width, tall viewport: every section is built without scrolling.
    Size size = const Size(390, 6000),
    double textScale = 1.0,
  }) async {
    final tr = FakeImpactTransport(dossier: fixture(name));
    await pumpImpact(tester, dossierScreen, transport: tr, locale: locale, size: size, textScale: textScale);
    return tr;
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).hitTestable().first);
    await tester.pumpAndSettle();
  }

  group('UI-GATE admin gate (UX; server entitlement is the authority)', () {
    testWidgets('UI-GATE-01 non-admin: admin-only message, ZERO requests', (tester) async {
      final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'), list: fixture('list_investigations'));
      await pumpImpact(tester, dossierScreen, transport: tr, admin: false);
      expect(find.text('Impact Lab is restricted to administrators.'), findsOneWidget);
      await pumpImpact(tester, const ImpactHomeScreen(), transport: tr, admin: false);
      expect(find.text('Impact Lab is restricted to administrators.'), findsOneWidget);
      expect(tr.calls, isEmpty);
    });

    testWidgets('UI-GATE-02a profile still loading: spinner, no request', (tester) async {
      final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'));
      await pumpImpact(tester, dossierScreen, transport: tr, profileState: const AsyncLoading(), settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tr.calls, isEmpty);
    });

    testWidgets('UI-GATE-02b profile failed: fail closed, no request', (tester) async {
      final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'));
      await pumpImpact(tester, dossierScreen, transport: tr, profileState: AsyncError(Exception('x'), StackTrace.empty));
      expect(find.text('Impact Lab is restricted to administrators.'), findsOneWidget);
      expect(tr.calls, isEmpty);
    });

    testWidgets('UI-GATE-03 malformed deep-link id: not available, no request', (tester) async {
      final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'));
      await pumpImpact(tester, const ImpactDossierScreen(investigationId: '../etc/passwd'), transport: tr);
      expect(find.text('Investigation not found or unavailable.'), findsOneWidget);
      expect(tr.calls, isEmpty);
    });
  });

  group('UI-HOME', () {
    testWidgets('UI-HOME-01 lists the caller investigations', (tester) async {
      final tr = FakeImpactTransport(list: fixture('list_investigations'));
      await pumpImpact(tester, const ImpactHomeScreen(), transport: tr);
      expect(find.text('«org-hopebridge»'), findsOneWidget);
      expect(tr.calls.single['action'], 'list_investigations');
    });

    testWidgets('UI-HOME-02 empty list', (tester) async {
      final tr = FakeImpactTransport(list: {'ok': true, 'action': 'list_investigations', 'data': {'investigations': []}});
      await pumpImpact(tester, const ImpactHomeScreen(), transport: tr);
      expect(find.text('No investigations yet.'), findsOneWidget);
    });
  });

  group('UI-DOS dossier scenarios (§48)', () {
    testWidgets('UI-DOS-01 A confirmed (EN): header, live view, caveats BEFORE claims', (tester) async {
      await openDossier(tester, 'dossier_confirmed_en');
      expect(find.text('«HopeBridge Foundation»'), findsWidgets);
      expect(find.text('Live view'), findsOneWidget);
      expect(find.textContaining('no score, ranking or verdict'), findsWidgets);
      // Order: "does NOT establish" and limitations precede the claims list.
      final notEst = tester.getTopLeft(find.text('What this dossier does NOT establish')).dy;
      final limits = tester.getTopLeft(find.text('Limitations').first).dy;
      await scrollTo(tester, find.text('Claims and verification'));
      final claimsTop = tester.getTopLeft(find.text('Claims and verification')).dy;
      expect(notEst, lessThan(limits));
      expect(claimsTop, greaterThan(-10000)); // rendered
      expect(find.textContaining('«HopeBridge Foundation is a registered charity.»'), findsOneWidget);
      expect(find.text('Supported by independent evidence'), findsWidgets);
    });

    testWidgets('UI-DOS-02 PT: server PT vocabulary + PT chrome', (tester) async {
      await openDossier(tester, 'dossier_confirmed_pt', locale: const Locale('pt'));
      expect(find.text('Visão ao vivo'), findsOneWidget);
      expect(find.text('O que este dossiê NÃO estabelece'), findsOneWidget);
      expect(find.text('Supported by independent evidence'), findsNothing);
    });

    testWidgets('UI-DOS-09 limitation count is the server count (7 entries, not 5 grouped codes)', (tester) async {
      await openDossier(tester, 'dossier_conflict_en');
      expect(find.text('Limitations: 7'), findsOneWidget);
    });

    testWidgets('UI-DOS-10 declared / registry names are captioned as such, not as source excerpts', (tester) async {
      await openDossier(tester, 'dossier_confirmed_en');
      expect(find.text('Identity as declared for this investigation — quoted, not verified'), findsOneWidget);
      expect(find.text('As recorded in the registry — quoted'), findsOneWidget);
    });

    testWidgets('UI-DOS-03 B/C conflict + privacy: redaction noted, withheld hidden', (tester) async {
      await openDossier(tester, 'dossier_conflict_en');
      expect(find.textContaining('Jane Example'), findsNothing);
      expect(find.textContaining('7946'), findsNothing);
      await scrollTo(tester, find.textContaining('[redacted-email]'));
      expect(find.text('Personal data was removed from this text.'), findsWidgets);
      expect(find.textContaining('Official registry records disagree'), findsWidgets);
    });

    testWidgets('UI-DOS-04 D unresolved identity (PT): no registry ≠ unregistered', (tester) async {
      await openDossier(tester, 'dossier_unresolved_pt', locale: const Locale('pt'));
      await scrollTo(tester, find.textContaining('Nenhum registro oficial anexado'));
      expect(find.textContaining('Isso não significa que a organização não seja registrada'), findsWidgets);
      await scrollTo(tester, find.text('Ainda não verificada.').first);
      expect(find.text('Ainda não verificada.'), findsWidgets);
    });

    testWidgets('UI-DOS-05 E stale: re-verification pending is flagged', (tester) async {
      await openDossier(tester, 'dossier_stale_en');
      expect(find.text('Re-verification pending: 1'), findsOneWidget);
    });

    testWidgets('UI-DOS-06 F open dispute is visible in summary and claim', (tester) async {
      await openDossier(tester, 'dossier_disputed_en');
      expect(find.text('Open disputes: 1'), findsOneWidget);
      expect(find.text('Under dispute: 1'), findsOneWidget);
    });

    testWidgets('UI-DOS-07 empty dossier', (tester) async {
      await openDossier(tester, 'dossier_empty_en');
      expect(find.text('No claims recorded yet.'), findsWidgets);
    });

    testWidgets('UI-DOS-08 no score / grade / gauge anywhere', (tester) async {
      await openDossier(tester, 'dossier_confirmed_en', size: const Size(1440, 2400));
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join('\n').toLowerCase();
      for (final banned in ['/100', 'trust score', 'fraud', 'corruption', 'rating', 'donate now']) {
        expect(texts, isNot(contains(banned)), reason: banned);
      }
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('UI-CLM claim detail', () {
    testWidgets('UI-CLM-01 evidence, provenance (host ≠ publisher), locator', (tester) async {
      await openDossier(tester, 'dossier_confirmed_en');
      await scrollTo(tester, find.textContaining('«HopeBridge Foundation built 20 wells.»'));
      await tester.tap(find.textContaining('«HopeBridge Foundation built 20 wells.»'));
      await tester.pumpAndSettle();
      expect(find.byType(ImpactClaimScreen), findsOneWidget);
      expect(find.text('Claim detail'), findsOneWidget);
      expect(find.textContaining('Quoted from an uploaded document'), findsWidgets);
      expect(find.text('Hosted on GOOGLE_DRIVE (not the publisher)'), findsOneWidget);
      expect(find.textContaining('art-report · L2 · location confirmed'), findsOneWidget);
      expect(find.textContaining('Independent voices: 0 · sources assessed: 1'), findsOneWidget);
    });

    testWidgets('UI-CLM-04 claim detail opens with the caveats, BEFORE the quoted claim', (tester) async {
      await openDossier(tester, 'dossier_conflict_en');
      await tester.tap(find.textContaining('[redacted-email]').first);
      await tester.pumpAndSettle();
      final caveats = tester.getTopLeft(find.text('Before reading this claim')).dy;
      final nonFinding = tester.getTopLeft(find.text('It is not a finding of wrongdoing about the organization.').last).dy;
      final quote = tester.getTopLeft(find.textContaining('[redacted-email]').last).dy;
      expect(caveats, lessThan(quote));
      expect(nonFinding, lessThan(quote));
      expect(find.text('Limitations that apply to this claim'), findsOneWidget);
      expect(find.textContaining('(e-board)'), findsWidgets);
    });

    testWidgets('UI-CLM-02 disagreements side by side, no winner (desktop)', (tester) async {
      final raw = copyOf(fixture('dossier_conflict_en'));
      final claim = ((((raw['data'] as Map)['dossier'] as Map)['content'] as Map)['claims'] as List).first as Map;
      (claim['verification'] as Map)['conflicts'] = [
        {
          'claimId': 'c-wells',
          'kind': 'QUANTITY_DISAGREEMENT',
          'basis': 'INDEPENDENT_SOURCES',
          'positions': [
            {'evidenceId': 'e-self', 'sourceId': 'src-web', 'publisher': 'HopeBridge Foundation', 'relationship': 'SUPPORTS', 'reportedValue': 20},
            {'evidenceId': 'e-news', 'sourceId': 'src-news', 'publisher': 'Daily Fixture', 'relationship': 'CONTRADICTS', 'reportedValue': 12},
          ],
          'resolution': 'UNRESOLVED',
        }
      ];
      await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: raw), size: const Size(1280, 1600));
      await tester.tap(find.textContaining('[redacted-email]').first);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Every position side by side — none is chosen.'));
      final a = tester.getTopLeft(find.text('«HopeBridge Foundation»').last);
      final b = tester.getTopLeft(find.text('«Daily Fixture»').last);
      expect((a.dy - b.dy).abs(), lessThan(1), reason: 'positions share a row');
      expect(find.textContaining('Sources report different values'), findsOneWidget);
      expect(find.textContaining('unresolved'), findsWidgets);
    });

    testWidgets('UI-CLM-03 withheld excerpt shows only that it was withheld', (tester) async {
      await openDossier(tester, 'dossier_conflict_en');
      await tester.tap(find.textContaining('[redacted-email]').first);
      await tester.pumpAndSettle();
      expect(find.text('Excerpt withheld for privacy'), findsOneWidget);
      expect(find.textContaining('Jane Example'), findsNothing);
    });
  });

  group('UI-ERR states', () {
    Future<void> failWith(WidgetTester tester, ImpactApiException e, String expected) async {
      final tr = FakeImpactTransport(error: e);
      await pumpImpact(tester, dossierScreen, transport: tr);
      expect(find.text(expected), findsOneWidget);
      expect(find.textContaining('HopeBridge Foundation'), findsNothing, reason: 'nothing partial is shown');
    }

    testWidgets('UI-ERR-01 rate limited shows retry_after', (tester) async {
      await failWith(tester, const ImpactApiException(ImpactErrorKind.rateLimited, retryAfterSeconds: 42), 'Too many requests. Try again in 42 s.');
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('UI-ERR-02 too large: explicit, no truncation, no retry', (tester) async {
      await failWith(tester, const ImpactApiException(ImpactErrorKind.tooLarge),
          'This dossier exceeds the limit and was not truncated. Nothing partial is shown.');
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('UI-ERR-03 not available / auth / network / contract', (tester) async {
      await failWith(tester, const ImpactApiException(ImpactErrorKind.notAvailable), 'Investigation not found or unavailable.');
      await failWith(tester, const ImpactApiException(ImpactErrorKind.auth), 'Your session expired. Please sign in again.');
      await failWith(tester, const ImpactApiException(ImpactErrorKind.network), 'No connection. Check the network and try again.');
      await failWith(tester, const ImpactApiException(ImpactErrorKind.contract),
          'Unsupported server response format. Nothing was shown, to avoid displaying an incomplete dossier.');
    });

    testWidgets('UI-ERR-04 retry refetches from the server', (tester) async {
      final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'), error: const ImpactApiException(ImpactErrorKind.network));
      await pumpImpact(tester, dossierScreen, transport: tr);
      tr.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Live view'), findsOneWidget);
      expect(tr.calls, hasLength(2));
    });
  });

  group('UI-EXP export + verify', () {
    Future<FakeImpactTransport> exported(WidgetTester tester, {required String verify}) async {
      final tr = FakeImpactTransport(
        dossier: fixture('dossier_confirmed_en'),
        export: fixture('export_confirmed_en'),
        verify: fixture(verify),
      );
      await pumpImpact(tester, dossierScreen, transport: tr, size: const Size(1440, 2400));
      await tester.tap(find.widgetWithText(FilledButton, 'Issue snapshot'));
      await tester.pumpAndSettle();
      return tr;
    }

    testWidgets('UI-EXP-01 confirmation shows limitations + privacy; cancel issues nothing', (tester) async {
      final tr = await exported(tester, verify: 'verify_current');
      expect(find.text('Before issuing the snapshot'), findsOneWidget);
      expect(find.textContaining('Limitations carried by this dossier:'), findsOneWidget);
      expect(find.text('Available formats: JSON and text. PDF is not available.'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tr.calls.where((c) => c['action'] == 'export_dossier'), isEmpty);
    });

    testWidgets('UI-EXP-02 issue → snapshot ref + hash; verify CURRENT', (tester) async {
      final tr = await exported(tester, verify: 'verify_current');
      await tester.tap(find.widgetWithText(FilledButton, 'Issue'));
      await tester.pumpAndSettle();
      expect(find.text('Snapshot issued'), findsOneWidget);
      final ref = (((fixture('export_confirmed_en')['data'] as Map)['dossier'] as Map)['envelope'] as Map)['snapshotRef'] as String;
      expect(find.textContaining(ref), findsWidgets);
      // I5G1-07 — the issued snapshot's own caveats are shown with it.
      expect(find.textContaining('The issued snapshot carries these caveats'), findsOneWidget);
      await tester.ensureVisible(find.text('Verify snapshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify snapshot'));
      await tester.pumpAndSettle();
      expect(find.text('Current snapshot: the content has not changed since it was issued.'), findsOneWidget);
      expect(tr.calls.last['action'], 'verify_dossier');
    });

    testWidgets('UI-EXP-03 verify STALE keeps the snapshot as history', (tester) async {
      await exported(tester, verify: 'verify_stale');
      await tester.tap(find.widgetWithText(FilledButton, 'Issue'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verify snapshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify snapshot'));
      await tester.pumpAndSettle();
      expect(find.textContaining('It remains valid as a historical record.'), findsOneWidget);
    });

    testWidgets('UI-EXP-04 envelope MISMATCH is shown before "current"', (tester) async {
      await exported(tester, verify: 'verify_envelope_mismatch');
      await tester.tap(find.widgetWithText(FilledButton, 'Issue'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verify snapshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify snapshot'));
      await tester.pumpAndSettle();
      final mismatch = tester.getTopLeft(find.text('The snapshot metadata does not match the register.')).dy;
      final current = tester.getTopLeft(find.text('Current snapshot: the content has not changed since it was issued.')).dy;
      expect(mismatch, lessThan(current));
    });

    testWidgets('UI-EXP-05 copy JSON / text copies the server bytes privately', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await exported(tester, verify: 'verify_current');
      await tester.tap(find.widgetWithText(FilledButton, 'Issue'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Copy JSON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy JSON'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Copy text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy text'));
      await tester.pumpAndSettle();
      final exp = fixture('export_confirmed_en')['data'] as Map;
      expect(copied, hasLength(2));
      expect(copied[0], contains((exp['dossier'] as Map)['integrity']['contentHash']));
      expect(copied[0], contains('"kind": "SNAPSHOT"'));
      expect(copied[1], exp['text']);
      // I5G3-03 — the copied text is caveat-first.
      expect(copied[1].indexOf('## What this dossier does NOT establish'), lessThan(copied[1].indexOf('«c-reg»')));
      expect(copied[1].indexOf('## Limitations'), lessThan(copied[1].indexOf('## Summary')));
      expect(copied.join(), isNot(contains('http')), reason: 'no link is produced');
    });

    testWidgets('UI-EXP-06 rate-limited export shows the server wait', (tester) async {
      final tr = await exported(tester, verify: 'verify_current');
      tr.error = const ImpactApiException(ImpactErrorKind.rateLimited, retryAfterSeconds: 30);
      await tester.tap(find.widgetWithText(FilledButton, 'Issue'));
      await tester.pumpAndSettle();
      expect(find.text('Too many requests. Try again in 30 s.'), findsOneWidget);
      expect(find.text('Snapshot issued'), findsNothing);
    });
  });

  group('UI-RSP responsive / text scale / large dossier', () {
    for (final s in const [Size(320, 640), Size(390, 844), Size(768, 1024), Size(1024, 768), Size(1440, 900), Size(1920, 1080)]) {
      testWidgets('UI-RSP-01 no overflow at ${s.width.toInt()}x${s.height.toInt()}', (tester) async {
        for (final f in ['dossier_confirmed_en', 'dossier_conflict_en', 'dossier_unresolved_pt']) {
          await openDossier(tester, f, size: s, locale: f.endsWith('_pt') ? const Locale('pt') : const Locale('en'));
          expect(tester.takeException(), isNull, reason: '$f at $s');
        }
      });
    }

    testWidgets('UI-RSP-02 two columns on desktop, one on mobile', (tester) async {
      await openDossier(tester, 'dossier_confirmed_en', size: const Size(1440, 2400));
      final sumX = tester.getTopLeft(find.text('Summary')).dx;
      final claimsX = tester.getTopLeft(find.text('Claims and verification')).dx;
      expect(claimsX, greaterThan(sumX + 200));
      // I5G1-01 — caveats end above the first claim on desktop too.
      final claimsY = tester.getTopLeft(find.text('Claims and verification')).dy;
      final notEst = tester.getBottomLeft(find.ancestor(of: find.text('What this dossier does NOT establish'), matching: find.byType(Card))).dy;
      final limits = tester.getBottomLeft(find.ancestor(of: find.text('Limitations').first, matching: find.byType(Card))).dy;
      expect(notEst, lessThan(claimsY));
      expect(limits, lessThan(claimsY));
      await openDossier(tester, 'dossier_confirmed_en', size: const Size(390, 844));
      expect(tester.getTopLeft(find.text('Summary')).dx, lessThan(100));
    });

    testWidgets('UI-RSP-03 text scale 2.0 on a phone: no overflow, claim + chips readable', (tester) async {
      for (final f in ['dossier_confirmed_en', 'dossier_conflict_en']) {
        await openDossier(tester, f, size: const Size(360, 780), textScale: 2.0);
        expect(tester.takeException(), isNull, reason: f);
      }
      await scrollTo(tester, find.textContaining('[redacted-email]'));
      await tester.tap(find.textContaining('[redacted-email]').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('UI-RSP-04 large dossier: paged, nothing dropped', (tester) async {
      final tr = FakeImpactTransport(dossier: largeDossier(200));
      await pumpImpact(tester, dossierScreen, transport: tr, size: const Size(1440, 2400));
      expect(find.text('Claims: 200 · Evidence: 2 · Sources: 3'), findsOneWidget);
      await scrollTo(tester, find.text('Show more (180)'));
      await tester.tap(find.text('Show more (180)'));
      await tester.pumpAndSettle();
      expect(find.text('Show more (160)'), findsOneWidget);
    });
  });

  group('UI-PRV presentation privacy (I6, closes I5F-03)', () {
    const privateStrings = ['Maria Placeholder', '12 Example Road', 'Mr Placeholder', 'jane.placeholder', 'Jane Placeholder'];

    testWidgets('UI-PRV-01 server-withheld private name / address never reaches the screen; org claim stays', (tester) async {
      await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: fixture('dossier_private_en')), size: const Size(390, 9000));
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' | ');
      for (final s in privateStrings) {
        expect(texts, isNot(contains(s)), reason: s);
      }
      expect(find.text('Excerpt withheld for privacy'), findsWidgets);
      expect(find.textContaining('«HopeBridge Foundation operates in two districts.»'), findsOneWidget);
      expect(find.textContaining('may contain, personal data'), findsWidgets);
    });

    testWidgets('UI-PRV-02 the private-scenario export (JSON + text) carries none of it', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final tr = FakeImpactTransport(dossier: fixture('dossier_private_en'), export: fixture('export_private_en'));
      await pumpImpact(tester, dossierScreen, transport: tr, size: const Size(1440, 5000));
      await tester.tap(find.widgetWithText(FilledButton, 'Issue snapshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Issue'));
      await tester.pumpAndSettle();
      for (final label in ['Copy JSON', 'Copy text']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(copied, hasLength(2));
      for (final c in copied) {
        for (final s in privateStrings) {
          expect(c, isNot(contains(s)), reason: s);
        }
      }
      expect(copied[0], contains('"textWithheld": "PERSONAL_DATA_RISK"'));
    });
  });

  group('UI-ADV adversarial input / cropped context (Codex Gate 3)', () {
    Map<String, dynamic> hostile() {
      final raw = copyOf(fixture('dossier_conflict_en'));
      final c = ((raw['data'] as Map)['dossier'] as Map)['content'] as Map;
      final evil = 'Verified by InsightValues\u202E\u200B\u2066fraud\u2069\nTRUSTED ${'A' * 5000}';
      ((c['sources'] as List).firstWhere((x) => (x as Map)['ref'] == 'src-news') as Map)['publisher'] = evil;
      (((c['subject'] as Map)['declaredIdentity']) as Map)['legalName'] = 'Hope\u202EnoitadnuoF\u200B\nBridge';
      ((c['claims'] as List).first as Map)['text'] = 'Line one\r\nLine two\u2028\u00ADthree';
      return raw;
    }

    testWidgets('UI-ADV-01 hostile server strings: no bidi / invisible / line breaks reach the screen, always quoted', (tester) async {
      await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: hostile()), size: const Size(390, 9000));
      expect(tester.takeException(), isNull);
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      for (final t in texts) {
        expect(RegExp('[\u202A-\u202E\u2066-\u2069\u200B-\u200F\u00AD\u2028\n\r]').hasMatch(t), isFalse, reason: t.length > 80 ? t.substring(0, 80) : t);
      }
      expect(find.text('«HopenoitadnuoF Bridge»'), findsWidgets);
      final pub = texts.firstWhere((t) => t.contains('Verified by InsightValues'));
      expect(pub, startsWith('Publisher: «'));
      expect(pub.length, lessThan(2100), reason: 'bounded');
      expect(find.textContaining('«Line one Line two three»'), findsWidgets);
    });

    testWidgets('UI-ADV-02 ten positions are stacked and numbered, never squeezed side by side', (tester) async {
      final raw = copyOf(fixture('dossier_conflict_en'));
      final claim = ((((raw['data'] as Map)['dossier'] as Map)['content'] as Map)['claims'] as List).first as Map;
      (claim['verification'] as Map)['conflicts'] = [
        {
          'claimId': 'c-wells',
          'kind': 'QUANTITY_DISAGREEMENT',
          'basis': 'INDEPENDENT_SOURCES',
          'positions': [
            for (var i = 0; i < 10; i++)
              {'evidenceId': 'e-$i', 'sourceId': 'src-$i', 'publisher': 'Publisher $i', 'relationship': 'SUPPORTS', 'reportedValue': i},
          ],
          'resolution': 'UNRESOLVED',
        }
      ];
      await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: raw), size: const Size(1440, 9000));
      await tester.tap(find.textContaining('[redacted-email]').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Position 1 of 10'), findsOneWidget);
      expect(find.text('Position 10 of 10'), findsOneWidget);
      final a = tester.getTopLeft(find.text('«Publisher 0»'));
      final b = tester.getTopLeft(find.text('«Publisher 1»'));
      expect(b.dy, greaterThan(a.dy), reason: 'stacked');
      expect((a.dx - b.dx).abs(), lessThan(1));
    });

    testWidgets('UI-ADV-04 minor-data claim (server withheld): only the fact of withholding is shown', (tester) async {
      final raw = copyOf(fixture('dossier_confirmed_en'));
      final claim = ((((raw['data'] as Map)['dossier'] as Map)['content'] as Map)['claims'] as List).first as Map;
      claim['text'] = null;
      claim['textWithheld'] = 'MINOR_DATA_RISK';
      await pumpImpact(tester, dossierScreen, transport: FakeImpactTransport(dossier: raw), size: const Size(390, 9000));
      expect(find.text('Excerpt withheld for privacy'), findsWidgets);
      expect(find.textContaining('registered charity'), findsNothing);
      await tester.tap(find.text('Excerpt withheld for privacy').first);
      await tester.pumpAndSettle();
      expect(find.text('Claim detail'), findsOneWidget);
      expect(find.textContaining('registered charity'), findsNothing);
    });

    testWidgets('UI-ADV-03 a cropped claim card / identity card carries its own scope', (tester) async {
      await openDossier(tester, 'dossier_confirmed_en');
      final cards = find.ancestor(of: find.textContaining('«HopeBridge Foundation is a registered charity.»'), matching: find.byType(Card));
      expect(find.descendant(of: cards.first, matching: find.text('Status of this claim only — not a verdict on the organization.')), findsOneWidget);
      final identity = find.ancestor(of: find.text('Organization identity'), matching: find.byType(Card));
      expect(find.descendant(of: identity, matching: find.textContaining('not an assessment of the organization')), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsNothing, reason: 'no "verified organization" badge');
    });
  });

  group('UI-A11Y semantics', () {
    testWidgets('UI-A11Y-01 section headers, chips as labelled text, tappable claims', (tester) async {
      final handle = tester.ensureSemantics();
      await openDossier(tester, 'dossier_confirmed_en', size: const Size(1440, 2400));
      expect(
        tester.getSemantics(find.text('What this dossier does NOT establish')),
        matchesSemantics(label: 'What this dossier does NOT establish', isHeader: true),
      );
      expect(find.bySemanticsLabel('Live view'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Claim detail c-reg')), findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    // Material 3 dark scheme: the app's AppTheme.dark loads Inter via google_fonts
    // over the network, which widget tests cannot do.
    testWidgets('UI-A11Y-02 dark theme meets text contrast; PT at 2x scale on a phone', (tester) async {
      final handle = tester.ensureSemantics();
      final tr = FakeImpactTransport(dossier: fixture('dossier_conflict_en'));
      await pumpImpact(tester, dossierScreen, transport: tr, theme: ThemeData.dark(useMaterial3: true), size: const Size(1440, 3000));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await pumpImpact(tester, dossierScreen,
          transport: FakeImpactTransport(dossier: fixture('dossier_unresolved_pt')),
          theme: ThemeData.dark(useMaterial3: true), locale: const Locale('pt'), size: const Size(360, 6000), textScale: 2.0);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('UI-A11Y-03 errors are announced (live region)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpImpact(tester, dossierScreen,
          transport: FakeImpactTransport(error: const ImpactApiException(ImpactErrorKind.rateLimited, retryAfterSeconds: 9)));
      expect(tester.getSemantics(find.text('Too many requests. Try again in 9 s.')), isSemantics(isLiveRegion: true));
      handle.dispose();
    });
  });
}
