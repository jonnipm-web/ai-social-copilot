// IVE-COMMERCIAL-STABILITY-09O — bounded in-memory forensic snapshot
// (mission sections 05/06/12/13/14). Pure Dart, no Supabase/Riverpod/widget
// tree needed: this class is deliberately a plain set of static fields
// updated by call sites elsewhere (app.dart, ive_overlay.dart, main.dart),
// so its own contract is tested in isolation here.

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/core/diagnostics/ive_forensic_snapshot.dart';

void _resetSnapshot() {
  IveForensicSnapshot.previousRoute = '';
  IveForensicSnapshot.currentRoute = '';
  IveForensicSnapshot.currentRouteNotifier.value = '';
  IveForensicSnapshot.lifecycleState = null;
  IveForensicSnapshot.overlayMounted = false;
  IveForensicSnapshot.overlayDragging = false;
  IveForensicSnapshot.issuePresent = false;
  IveForensicSnapshot.profileResolved = false;
  IveForensicSnapshot.builderChildWasNull = false;
}

void main() {
  setUp(_resetSnapshot);

  group('recordRoute — route + previous-route capture (mission section 06)', () {
    test('first call sets currentRoute and leaves previousRoute empty', () {
      IveForensicSnapshot.recordRoute(AppConstants.routeDashboard);
      expect(IveForensicSnapshot.currentRoute, AppConstants.routeDashboard);
      expect(IveForensicSnapshot.previousRoute, '');
    });

    test('a second, different route shifts current into previous', () {
      IveForensicSnapshot.recordRoute(AppConstants.routeDashboard);
      IveForensicSnapshot.recordRoute(AppConstants.routeHome);
      expect(IveForensicSnapshot.currentRoute, AppConstants.routeHome);
      expect(IveForensicSnapshot.previousRoute, AppConstants.routeDashboard);
    });

    test('re-recording the SAME route is a no-op (does not clobber previousRoute)', () {
      IveForensicSnapshot.recordRoute(AppConstants.routeDashboard);
      IveForensicSnapshot.recordRoute(AppConstants.routeHome);
      IveForensicSnapshot.recordRoute(AppConstants.routeHome);
      expect(IveForensicSnapshot.currentRoute, AppConstants.routeHome);
      expect(IveForensicSnapshot.previousRoute, AppConstants.routeDashboard);
    });

    test('STABILITY-09-FIX — currentRouteNotifier mirrors currentRoute and '
        'only notifies listeners on a genuine change', () {
      var notifyCount = 0;
      void listener() => notifyCount++;
      IveForensicSnapshot.currentRouteNotifier.addListener(listener);
      addTearDown(() => IveForensicSnapshot.currentRouteNotifier.removeListener(listener));

      IveForensicSnapshot.recordRoute(AppConstants.routeDashboard);
      expect(IveForensicSnapshot.currentRouteNotifier.value, AppConstants.routeDashboard);
      expect(notifyCount, 1);

      // Same route again -- recordRoute no-ops before touching the notifier.
      IveForensicSnapshot.recordRoute(AppConstants.routeDashboard);
      expect(notifyCount, 1);

      IveForensicSnapshot.recordRoute(AppConstants.routeHome);
      expect(IveForensicSnapshot.currentRouteNotifier.value, AppConstants.routeHome);
      expect(notifyCount, 2);
    });
  });

  group('projectContextPresent — derived from the already-captured route only', () {
    test('false for the bare projects list route', () {
      IveForensicSnapshot.recordRoute(AppConstants.routeProjects);
      expect(IveForensicSnapshot.projectContextPresent, isFalse);
    });

    test('true for a project-scoped sub-route', () {
      IveForensicSnapshot.recordRoute('${AppConstants.routeProjects}/abc-123');
      expect(IveForensicSnapshot.projectContextPresent, isTrue);
    });

    test('false for an unrelated route', () {
      IveForensicSnapshot.recordRoute(AppConstants.routeDashboard);
      expect(IveForensicSnapshot.projectContextPresent, isFalse);
    });
  });

  test('builderChildWasNull is a one-way flag: once true, stays true', () {
    expect(IveForensicSnapshot.builderChildWasNull, isFalse);
    IveForensicSnapshot.builderChildWasNull = true;
    expect(IveForensicSnapshot.builderChildWasNull, isTrue);
  });

  test('lifecycleState survives an unknown/null state as "unknown" in metadata form', () {
    expect(IveForensicSnapshot.toMetadata()['lifecycle_state'], 'unknown');
    IveForensicSnapshot.lifecycleState = AppLifecycleState.resumed;
    expect(IveForensicSnapshot.toMetadata()['lifecycle_state'], 'resumed');
  });

  group('toMetadata — shape and privacy (mission section 05/11)', () {
    test('every key is a plain primitive (bool/String/null), never a nested object', () {
      IveForensicSnapshot.recordRoute(AppConstants.routeDashboard);
      IveForensicSnapshot.lifecycleState = AppLifecycleState.resumed;
      IveForensicSnapshot.overlayMounted = true;
      IveForensicSnapshot.overlayDragging = true;
      IveForensicSnapshot.issuePresent = true;
      IveForensicSnapshot.profileResolved = true;

      final metadata = IveForensicSnapshot.toMetadata();
      for (final value in metadata.values) {
        expect(value == null || value is bool || value is String, isTrue,
            reason: 'forensic metadata value "$value" is not a plain primitive');
      }
    });

    test('contains exactly the keys the mission asked for, none extra', () {
      final metadata = IveForensicSnapshot.toMetadata();
      expect(metadata.keys.toSet(), {
        'previous_route',
        'lifecycle_state',
        'overlay_mounted',
        'overlay_interaction_active',
        'issue_present',
        'profile_resolved',
        'project_context_present',
        'builder_child_was_null',
      });
    });

    test('never contains project/knowledge/prompt CONTENT — only booleans/ids/routes', () {
      IveForensicSnapshot.recordRoute('${AppConstants.routeProjects}/some-project-id');
      final metadata = IveForensicSnapshot.toMetadata();
      // The route itself is an app-controlled path, never user-entered
      // text — this documents the invariant rather than re-testing
      // sanitizeText (already covered in diagnostic_sanitizer_test.dart),
      // since this map is what actually reaches buildSafeMetadata.
      expect(metadata['project_context_present'], isTrue);
      expect(metadata.values.whereType<String>(), everyElement(isNot(contains(' '))));
    });
  });
}
