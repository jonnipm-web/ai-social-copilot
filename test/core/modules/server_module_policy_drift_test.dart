// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — client/server module policy drift.
//
// The Flutter registry (kModuleRegistry) and the server manifest
// (supabase/functions/_shared/module_policy.ts, JSON block between the
// BEGIN/END markers) must describe the same modules with the same lifecycle
// and minimum plan. Any divergence ("Flutter says ENABLED, server says
// UNKNOWN") fails CI here instead of surfacing as a broken screen or an
// unintended grant.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/modules/module_registry.dart';

Map<String, dynamic> _serverPolicy() {
  final src = File('supabase/functions/_shared/module_policy.ts').readAsStringSync();
  const begin = '// BEGIN_MODULE_POLICY_JSON';
  const end = '// END_MODULE_POLICY_JSON';
  final start = src.indexOf(begin);
  final stop = src.indexOf(end);
  if (start < 0 || stop <= start) {
    throw StateError('module_policy.ts is missing its JSON markers');
  }
  return jsonDecode(src.substring(src.indexOf('\n', start) + 1, stop)) as Map<String, dynamic>;
}

void main() {
  final policy = _serverPolicy();
  final serverModules = (policy['modules'] as Map).cast<String, dynamic>();
  final serverFunctions = (policy['edgeFunctions'] as Map).cast<String, dynamic>();

  test('same module ids on client and server', () {
    final client = kModuleRegistry.map((m) => m.moduleId).toSet();
    expect(client.difference(serverModules.keys.toSet()), isEmpty, reason: 'client-only modules');
    expect(serverModules.keys.toSet().difference(client), isEmpty, reason: 'server-only modules');
    expect(kModuleRegistry.length, client.length, reason: 'duplicate moduleId in kModuleRegistry');
  });

  test('lifecycle and minimum plan agree for every module', () {
    final drift = <String>[];
    for (final m in kModuleRegistry) {
      final s = (serverModules[m.moduleId] as Map).cast<String, dynamic>();
      if (s['lifecycle'] != m.lifecycle.wireName) {
        drift.add('${m.moduleId}: lifecycle client=${m.lifecycle.wireName} server=${s['lifecycle']}');
      }
      if (s['minimumPlan'] != m.minimumPlan.wireName) {
        drift.add('${m.moduleId}: minimumPlan client=${m.minimumPlan.wireName} server=${s['minimumPlan']}');
      }
    }
    expect(drift, isEmpty);
  });

  test('commercialEnabled on the client <=> COMMERCIAL on the server', () {
    for (final m in kModuleRegistry) {
      final serverCommercial = (serverModules[m.moduleId] as Map)['lifecycle'] == 'COMMERCIAL';
      expect(m.commercialEnabled, serverCommercial, reason: m.moduleId);
    }
  });

  test('every Edge Function the registry names is classified on the server', () {
    final named = kModuleRegistry.expand((m) => m.edgeFunctions).toSet();
    expect(named.difference(serverFunctions.keys.toSet()), isEmpty);
  });

  test('a module whose Edge Function is MODULE-kind is owned by a registry module', () {
    for (final entry in serverFunctions.entries) {
      final fn = (entry.value as Map).cast<String, dynamic>();
      if (fn['kind'] != 'MODULE') continue;
      expect(serverModules.containsKey(fn['moduleId']), isTrue, reason: entry.key);
    }
  });
}
