// IV-QUANT-REAL-DATA-READINESS-03 — physical finding: INTERNAL labs had no
// in-app entry point on Android. The admin module sheet now offers "Open
// module" for clickable modules with a route; access is still decided by the
// route guard and the server.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/core/modules/module_registry.dart';
import 'package:ai_social_copilot/features/admin/screens/admin_panel_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';

Widget _host(Widget sheet, {double textScale = 1.0, Locale locale = const Locale('pt')}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: sheet)),
    GoRoute(path: AppConstants.routeQuantLab, builder: (_, __) => const Scaffold(body: Text('QUANT_LAB_OPENED'))),
  ]);
  return MaterialApp.router(
    routerConfig: router,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  );
}

void main() {
  final quant = kModuleRegistry.firstWhere((m) => m.moduleId == 'quant-analytics');
  final watchlists = kModuleRegistry.firstWhere((m) => m.moduleId == 'quant-watchlists');

  testWidgets('quant-analytics sheet offers "Abrir módulo" and navigates to /quant-lab', (tester) async {
    await tester.pumpWidget(_host(Builder(
      builder: (context) => TextButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => AdminModuleDetailSheet(module: quant, isEnglish: false),
        ),
        child: const Text('open-sheet'),
      ),
    )));
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('adminModuleOpen')));
    expect(find.text('Abrir módulo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('adminModuleOpen')));
    await tester.pumpAndSettle();
    expect(find.text('QUANT_LAB_OPENED'), findsOneWidget);
  });

  testWidgets('modules without a route (or not clickable) get no Open button', (tester) async {
    await tester.pumpWidget(_host(AdminModuleDetailSheet(module: watchlists, isEnglish: true)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adminModuleOpen')), findsNothing);
  });

  testWidgets('sheet scrolls at text scale 2.0 on a 360px phone (no overflow)', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(AdminModuleDetailSheet(module: quant, isEnglish: false), textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('adminModuleOpen')));
    expect(tester.getSize(find.byKey(const Key('adminModuleOpen'))).height, greaterThanOrEqualTo(48));
  });
}
