import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../constants/app_constants.dart';

/// IVE-COMMERCIAL-STABILITY-09O — bounded, in-memory-only forensic context
/// for the NEXT uncaught null-crash (mission sections 05/06/12/13/14).
///
/// Nothing here is ever sent anywhere by itself. It is read exactly once, at
/// the uncaught-error boundary in main.dart, and folded into that single
/// diagnostic event's already-allowlisted/sanitized metadata
/// (diagnostic_sanitizer.dart's buildSafeMetadata). Every field is a cheap
/// static boolean/enum/string updated only by state changes that were
/// ALREADY happening elsewhere (a router redirect that already runs on every
/// navigation attempt, a provider watch inside a build() that already runs,
/// an app-lifecycle callback that already fires) — this class adds no new
/// listener, timer, or per-frame/per-gesture write of its own, per mission
/// section 12 ("do NOT add breadcrumbs on every frame/gesture/rebuild").
///
/// Static/global by design, matching iveRouteNotifier's own existing pattern
/// in ive_overlay.dart: this needs to be reachable from main.dart's
/// `_logUncaughtError`, which runs with no BuildContext and no ProviderScope
/// reachable (see main.dart's own comment on why FlutterError.onError/
/// runZonedGuarded can't use `ref`).
class IveForensicSnapshot {
  IveForensicSnapshot._();

  static String previousRoute = '';
  static String currentRoute = '';

  /// STABILITY-09-FIX (Codex Gate round 3, P1) — DELIBERATELY separate from
  /// [currentRoute]/[recordRoute]. Those fire on every navigation ATTEMPT
  /// (the GoRouter `redirect` callback records the path it is EVALUATING,
  /// before the redirect decision is known), so a request for `/login` by
  /// an already-authenticated user briefly makes [currentRoute] equal
  /// `/login` even though GoRouter immediately redirects it to `/dashboard`
  /// — round 2's `currentRoute != routeSplash` check could not tell that
  /// apart from a genuine, settled `/login` visit. [settledRouteNotifier]
  /// is written ONLY via [recordSettledRoute], which app.dart's `redirect`
  /// callback calls AFTER its own redirect decision resolves to null (no
  /// further redirect needed — GoRouter has accepted this exact path) and
  /// the path is neither Splash nor Login, i.e. a genuinely arrived-at,
  /// authenticated destination. [currentRoute]'s existing forensic
  /// semantics (attempted path, used by [toMetadata]/[projectContextPresent]
  /// and existing tests) are completely unchanged.
  static final ValueNotifier<String> settledRouteNotifier = ValueNotifier<String>('');
  static String get settledRoute => settledRouteNotifier.value;
  static AppLifecycleState? lifecycleState;
  static bool overlayMounted = false;
  static bool overlayDragging = false;
  static bool issuePresent = false;
  static bool profileResolved = false;

  /// MaterialApp.router's `builder` receives a nullable `child` per the
  /// framework's own signature; app.dart's builder has always asserted it
  /// non-null (`child!`) without ever observing a null one. A one-way flag
  /// (set, never cleared) rather than a logged event: recording whether this
  /// was EVER null this session is cheap evidence toward or against the
  /// `child!` candidate (STABILITY-09R section 17) the next time a crash's
  /// metadata is inspected, without instrumenting every rebuild with a
  /// write.
  static bool builderChildWasNull = false;

  /// Called from the GoRouter `redirect` callback in app.dart, which already
  /// runs on every navigation ATTEMPT (see app.dart's own comment on
  /// `_resolveEntitlementRedirect`: "every context.go/push call already
  /// re-invokes `redirect`") — no new listener added, and no change to what
  /// redirect decides or returns.
  static void recordRoute(String path) {
    if (path == currentRoute) return;
    previousRoute = currentRoute;
    currentRoute = path;
  }

  /// STABILITY-09-FIX (Codex Gate round 3) — see [settledRouteNotifier].
  /// Callers are responsible for only calling this with a genuinely settled,
  /// non-Splash, non-Login path (app.dart's `redirect` callback does this
  /// after its own redirect decision is null).
  static void recordSettledRoute(String path) {
    if (path == settledRouteNotifier.value) return;
    settledRouteNotifier.value = path;
  }

  /// Derived, not stored: true only for a specific project-scoped route
  /// (e.g. `/projects/<id>`), not the bare `/projects` list. Cheap string
  /// check on data already captured by [recordRoute] — no new provider
  /// dependency, since there is no single global "current project" provider
  /// today (project scoping is a per-screen FutureProvider.family
  /// parameter, not ambient app state).
  static bool get projectContextPresent =>
      currentRoute.startsWith(AppConstants.routeProjects) &&
      currentRoute.length > AppConstants.routeProjects.length;

  static Map<String, Object?> toMetadata() => {
        'previous_route': previousRoute.isEmpty ? null : previousRoute,
        'lifecycle_state': lifecycleState?.name ?? 'unknown',
        'overlay_mounted': overlayMounted,
        'overlay_interaction_active': overlayDragging,
        'issue_present': issuePresent,
        'profile_resolved': profileResolved,
        'project_context_present': projectContextPresent,
        'builder_child_was_null': builderChildWasNull,
      };
}
