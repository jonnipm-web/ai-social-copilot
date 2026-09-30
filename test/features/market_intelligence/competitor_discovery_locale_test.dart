import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/competitor.dart';
import 'package:ai_social_copilot/features/market_intelligence/screens/competitor_discovery_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/market_analysis_provider.dart';

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-05, section 10) -- rendered-surface
// regression test: proves the type badge shows the LOCALIZED label, not the
// raw canonical 'aspirational' value, in both locales the app ships.
Competitor _competitor(String type) => Competitor(
      id: 'c1',
      userId: 'u1',
      marketAnalysisId: 'a1',
      name: 'Acme Corp',
      url: 'https://acme.example',
      type: type,
      createdAt: DateTime(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester, Locale locale, String competitorType) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      competitorsByAnalysisProvider('a1').overrideWith((ref) async => [_competitor(competitorType)]),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CompetitorDiscoveryScreen(analysisId: 'a1'),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('PT locale: aspirational competitor shows "ASPIRACIONAL", never the raw English value', (tester) async {
    await _pump(tester, const Locale('pt'), 'aspirational');

    expect(find.text('ASPIRACIONAL'), findsOneWidget);
    expect(find.text('ASPIRATIONAL'), findsNothing);
  });

  testWidgets('EN locale: aspirational competitor shows "ASPIRATIONAL"', (tester) async {
    await _pump(tester, const Locale('en'), 'aspirational');

    expect(find.text('ASPIRATIONAL'), findsOneWidget);
  });

  testWidgets('PT locale: direct competitor shows "DIRETO", never the raw English value', (tester) async {
    await _pump(tester, const Locale('pt'), 'direct');

    expect(find.text('DIRETO'), findsOneWidget);
    expect(find.text('DIRECT'), findsNothing);
  });
}
