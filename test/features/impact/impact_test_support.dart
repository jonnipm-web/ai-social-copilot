import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/features/impact/data/impact_lab_api.dart';
import 'package:ai_social_copilot/features/impact/providers/impact_providers.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';

/// IV-IMPACT-I5 — test support. Fixtures are produced by the REAL Lab
/// service (supabase/functions/_shared/impact/fixtures/ui_fixtures.ts) and
/// guarded against drift by UI-FIX-01, so these tests exercise the true I4
/// contract rather than a hand-written imitation.
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/impact/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// Deep copy, for tests that derive a variant from a real fixture.
Map<String, dynamic> copyOf(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

const kInvestigationId = '00000000-0000-4000-8000-000000000001';

class FakeImpactTransport implements ImpactTransport {
  FakeImpactTransport({this.dossier, this.list, this.export, this.verify, this.error});

  Map<String, dynamic>? dossier;
  Map<String, dynamic>? list;
  Map<String, dynamic>? export;
  Map<String, dynamic>? verify;

  /// When set, every call fails with it (after being recorded).
  ImpactApiException? error;

  final calls = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> body) async {
    calls.add(body);
    if (error != null) throw error!;
    final res = switch (body['action']) {
      'list_investigations' => list,
      'get_dossier' => dossier,
      'export_dossier' => export,
      'verify_dossier' => verify,
      _ => null,
    };
    if (res == null) throw const ImpactApiException(ImpactErrorKind.invalidRequest);
    return res;
  }
}

Profile profile({bool admin = true}) => Profile(
      id: 'aaaaaaaa-0000-4000-8000-00000000000a',
      email: 'admin@example.test',
      role: admin ? 'admin' : 'user',
      monthlyLimit: 10,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

/// Pumps [child] in a MaterialApp with the app's localizations, a fake
/// transport and a resolved profile.
Future<void> pumpImpact(
  WidgetTester tester,
  Widget child, {
  required FakeImpactTransport transport,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1.0,
  AsyncValue<Profile?>? profileState,
  bool admin = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        impactTransportProvider.overrideWithValue(transport),
        currentProfileProvider.overrideWith((ref) {
          final s = profileState;
          if (s == null) return Future.value(profile(admin: admin));
          if (s is AsyncError) return Future<Profile?>.error(s.error!);
          if (s is AsyncLoading) return Completer<Profile?>().future; // never resolves
          return Future.value(s.value);
        }),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: w!,
        ),
        home: child,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
