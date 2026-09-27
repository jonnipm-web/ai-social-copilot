import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/features/strategy_lab/strategy_lab_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';

Profile _profile({bool admin = true}) => Profile(
      id: 'aaaaaaaa-0000-4000-8000-00000000000a',
      email: 'admin@example.test',
      role: admin ? 'admin' : 'user',
      monthlyLimit: 10,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester, {bool admin = true, Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentProfileProvider.overrideWith((ref) => Future.value(_profile(admin: admin)))],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StrategyLabScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SL-01 admin sees the V10 reference strategy with its real reproduction numbers', (tester) async {
    await _pump(tester);
    expect(find.text('Strategy #001 — Paulo Trend Fibonacci V10 (Bidirectional Stepped)'), findsOneWidget);
    expect(find.textContaining('75 trades'), findsNWidgets(2));
    expect(find.textContaining('c19661f4dfc61193'), findsOneWidget);
    expect(find.textContaining('e79067f77120956d'), findsOneWidget);
  });

  testWidgets('SL-02 the RESEARCH-only / not-live disclaimer is always shown', (tester) async {
    await _pump(tester);
    expect(find.textContaining('NOT a proven profitable strategy'), findsOneWidget);
  });

  testWidgets('SL-03 a non-admin sees access-denied, never the strategy content', (tester) async {
    await _pump(tester, admin: false);
    expect(find.textContaining('do not have permission'), findsOneWidget);
    expect(find.text('Strategy #001 — Paulo Trend Fibonacci V10 (Bidirectional Stepped)'), findsNothing);
  });

  testWidgets('SL-04 PT locale renders the PT disclaimer, same underlying numbers', (tester) async {
    await _pump(tester, locale: const Locale('pt'));
    expect(find.textContaining('NÃO é uma estratégia com lucro comprovado'), findsOneWidget);
    expect(find.textContaining('c19661f4dfc61193'), findsOneWidget);
  });

  testWidgets('SL-05 the screen scrolls on a narrow (phone-width) viewport without overflow', (tester) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('strategyLabScroll')), findsOneWidget);
  });
}
