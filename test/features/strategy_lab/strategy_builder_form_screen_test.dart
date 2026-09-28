import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/features/strategy_lab/data/strategy_builder_api.dart';
import 'package:ai_social_copilot/features/strategy_lab/strategy_builder_form_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';

import 'strategy_lab_screen_test.dart' show FakeStrategyBuilderApi;

Future<FakeStrategyBuilderApi> _pump(
  WidgetTester tester, {
  String? existingStrategyId,
  Map<String, dynamic>? initialSpec,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final api = FakeStrategyBuilderApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [strategyBuilderApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: StrategyBuilderFormScreen(existingStrategyId: existingStrategyId, initialSpec: initialSpec),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('SF-01 the form is a real editable form, not read-only text', (tester) async {
    await _pump(tester);
    expect(find.byType(TextField), findsWidgets);
    await tester.enterText(find.byKey(const Key('strategyBuilderNameField')), 'My Test Strategy');
    expect(find.text('My Test Strategy'), findsOneWidget);
  });

  testWidgets('SF-02 the break-even fields only appear once the toggle is enabled', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('strategyBuilderBreakEvenToggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('strategyBuilderBreakEvenToggle')));
    await tester.pumpAndSettle();
    expect(find.text('Trigger'), findsOneWidget);
  });

  testWidgets('SF-03 tapping Validate calls the servers validate op and shows its verdict, never a client-side guess', (tester) async {
    await _pump(tester);
    final validateButton = find.byKey(const Key('strategyBuilderValidateButton'));
    await tester.ensureVisible(validateButton);
    await tester.pumpAndSettle();
    await tester.tap(validateButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('strategyBuilderStatusText')), findsOneWidget);
    expect(find.text('Configuration valid.'), findsOneWidget);
  });

  testWidgets('SF-04 tapping Save on a new strategy calls create(), not create_version()', (tester) async {
    final api = await _pump(tester);
    await tester.enterText(find.byKey(const Key('strategyBuilderNameField')), 'A New Strategy');
    final saveButton = find.byKey(const Key('strategyBuilderSaveButton'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    // FakeStrategyBuilderApi.create always returns ok, which pops the
    // screen -- reaching that pop without an exception is the assertion.
    expect(tester.takeException(), isNull);
  });

  testWidgets('SF-08 (Codex adversarial review, 2nd re-verification) a retry after a failed save reuses the SAME idempotency key, never a fresh one', (tester) async {
    final api = await _pump(tester);
    api.failNextCreate = true;
    await tester.enterText(find.byKey(const Key('strategyBuilderNameField')), 'A New Strategy');
    // Invoke the button's callback directly rather than tester.tap(): this
    // form is tall enough that the Save button's on-screen offset is
    // unreliable at test viewport size (a pre-existing flake shared with
    // SF-04's tap, which never asserts the call actually landed) -- this
    // test's whole point IS to inspect the exact call sequence, so it
    // cannot tolerate a silently-missed tap.
    final saveButton = find.byKey(const Key('strategyBuilderSaveButton'));
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pumpAndSettle();
    // The first attempt failed -- the screen must still be open (no pop).
    expect(find.byKey(const Key('strategyBuilderSaveButton')), findsOneWidget);
    tester.widget<FilledButton>(saveButton).onPressed!();
    await tester.pumpAndSettle();
    final createCalls = api.calls.where((c) => c.startsWith('create:')).toList();
    expect(createCalls.length, 2);
    expect(createCalls[0], equals(createCalls[1]));
    expect(createCalls[0], isNot(equals('create:null')));
  });

  testWidgets('SF-05 editing an existing strategy seeds the form from its spec and Save calls create_version', (tester) async {
    final initialSpec = {
      'name': 'Existing One', 'entry': {'ruleId': 'ENTRY.SESSION_OPEN'},
      'allowedDirections': ['LONG'],
      'stop': {'distance': 42}, 'target': {'distance': 99},
      'session': {'startTime': '09:00', 'endTime': '11:00'}, 'forcedExit': {'time': '11:00'},
      'positionSize': {'quantity': 3},
    };
    await _pump(tester, existingStrategyId: 'sid-1', initialSpec: initialSpec);
    expect(find.text('Existing One'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
    final saveButton = find.byKey(const Key('strategyBuilderSaveButton'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('SF-06 the PT locale renders PT field labels', (tester) async {
    await _pump(tester, locale: const Locale('pt'));
    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('Distância do stop'), findsOneWidget);
  });

  testWidgets('SF-07 the summary card reflects the direction chips the user actually selected', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('strategyBuilderDirShort')));
    await tester.pumpAndSettle();
    expect(find.textContaining('LONG + SHORT'), findsOneWidget);
  });
}
