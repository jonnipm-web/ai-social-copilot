import 'package:ai_social_copilot/core/modules/module_registry.dart';
import 'package:ai_social_copilot/features/admin/screens/admin_panel_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// IV-IMPACT-I6-PHYSICAL-CLOSURE — PF-01 (physically found): an admin must be
/// able to REACH a non-commercial module screen from the Admin Panel.
void main() {
  test('UI-PF-01 the Impact module is openable from the admin module sheet', () {
    final impact = kModuleRegistry.firstWhere((m) => m.moduleId == 'impact');
    expect(moduleOpenRoute(impact), '/impact');
  });

  test('UI-PF-01b only non-commercial, adminClickable modules with a route get an open action', () {
    for (final m in kModuleRegistry) {
      final r = moduleOpenRoute(m);
      if (r != null) {
        expect(m.adminClickable, isTrue, reason: m.moduleId);
        expect(m.commercialEnabled, isFalse, reason: '${m.moduleId}: commercial modules are reachable from the drawer');
        expect(r, m.route, reason: m.moduleId);
      }
    }
  });
}
