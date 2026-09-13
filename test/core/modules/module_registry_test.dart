// IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — regression coverage for the
// catalog/navigation audit (mission section 02/08). lib/shared/widgets/
// app_drawer.dart renders a top-level drawer item for every module with
// `commercialEnabled: true` and a non-null `route`, with no awareness of
// GoRouter path parameters. 'strategy-generation' had a parameterized route
// (`/knowledge/:id/strategy`) with commercialEnabled:true, so it showed up
// as a top-level nav item whose literal ":id" segment GoRouter happily
// matched, opening a per-item screen for a non-existent item. Fixed by
// setting its route to null (matching context-copilot/file-import/
// google-drive-import/usage-quota's existing pattern for sub-flows without
// a standalone destination). This test locks in the invariant so no future
// registry entry reintroduces the same class of bug.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/modules/module_registry.dart';

void main() {
  test(
    'no commercially-enabled module exposes a parameterized route '
    '(app_drawer.dart would render it as a broken top-level nav item)',
    () {
      final offenders = kModuleRegistry.where((m) {
        final route = m.route;
        return m.commercialEnabled && route != null && route.contains(':');
      }).map((m) => m.moduleId).toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'app_drawer.dart only filters on `route == null`, not on whether the '
            'route is parameterized — any commercially-enabled module with a '
            '":id"-style route becomes a top-level drawer item that navigates to '
            'a literal, non-functional path. Offending module ids: $offenders',
      );
    },
  );
}
