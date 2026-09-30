// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — client side of the shared
// entitlement decision vectors (contracts/entitlements/decision_vectors.v1.json).
// The server authority (supabase/functions/_shared/entitlement.ts) is tested
// against the same file, so the Flutter route guard (UX) and the server
// (security boundary) cannot silently disagree about who reaches what.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/modules/module_definition.dart';
import 'package:ai_social_copilot/core/modules/route_policy.dart';
import 'package:ai_social_copilot/data/models/profile.dart';

ModuleLifecycle _lifecycle(String wire) =>
    ModuleLifecycle.values.firstWhere((l) => l.wireName == wire);

ModulePlan _plan(String wire) =>
    ModulePlan.values.firstWhere((p) => p.wireName == wire);

ModuleDefinition _module(ModuleLifecycle lifecycle, ModulePlan plan) => ModuleDefinition(
      moduleId: 'vector',
      namePt: 'Vetor',
      nameEn: 'Vector',
      status: ModuleStatus.active,
      adminVisible: true,
      adminClickable: true,
      commercialEnabled: lifecycle == ModuleLifecycle.commercial,
      minimumPlan: plan,
      readinessPt: 'test',
      readinessEn: 'test',
      releaseClassification: ModuleReleaseClass.commercialV1,
      lifecycleOverride: lifecycle,
    );

Profile _profile(String role) => Profile(
      id: 'u',
      role: role,
      monthlyLimit: 0,
      isActive: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

String _expectedClientDecision(String serverExpected) => switch (serverExpected) {
      'ALLOW' => RouteDecision.allow.name,
      'PLAN_REQUIRED' => RouteDecision.redirectUpgrade.name,
      _ => RouteDecision.redirectDenied.name,
    };

void main() {
  final vectors = jsonDecode(
    File('contracts/entitlements/decision_vectors.v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (vectors['cases'] as List).cast<Map<String, dynamic>>();

  test('vectors cover every legacy role × lifecycle × plan', () {
    expect(cases.length, 105);
  });

  test('client route guard matches every server decision vector (legacy Profile getters)', () {
    final mismatches = <String>[];
    for (final c in cases) {
      final profile = _profile(c['legacyRole'] as String);
      final decision = decideForModule(
        module: _module(_lifecycle(c['lifecycle'] as String), _plan(c['minimumPlan'] as String)),
        isAlwaysAllowed: false,
        isAdmin: profile.isAdmin,
        isPro: profile.isPro,
        isPremium: profile.isPremium,
        isBetaTester: profile.isBetaTester,
        profileResolved: true,
      );
      final expected = _expectedClientDecision(c['expected'] as String);
      if (decision.name != expected) mismatches.add('$c -> ${decision.name}');
    }
    expect(mismatches, isEmpty);
  });

  test('forged local state cannot exceed the server: an unresolved profile never unlocks a paid or beta module', () {
    for (final lifecycle in ModuleLifecycle.values) {
      for (final plan in [ModulePlan.pro, ModulePlan.premium]) {
        final d = decideForModule(
          module: _module(lifecycle, plan),
          isAlwaysAllowed: false,
          isAdmin: false,
          isPro: true,
          isPremium: true,
          isBetaTester: true,
          profileResolved: false,
        );
        expect(d, isNot(RouteDecision.allow), reason: '$lifecycle/$plan');
      }
    }
  });
}
