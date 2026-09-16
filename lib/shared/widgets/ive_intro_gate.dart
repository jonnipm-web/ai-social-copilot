import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/diagnostics/ive_forensic_snapshot.dart';
import '../../data/models/profile.dart';
import '../../providers/ive_intro_provider.dart';
import '../../providers/profile_provider.dart';
import 'ive_intro_sheet.dart';

// IVE-EXPERIENCE-V1-06 (Section 14) — safest trigger point for "Meet IVE":
// mounted once alongside IveOverlay in app.dart's global Stack (not inside
// any specific screen, so DashboardScreen and every other screen stay
// untouched), and gated on `currentProfileProvider` resolving to a non-null
// profile — the same "authenticated and app initialization is stable"
// signal `_AppState.didChangeAppLifecycleState` already uses elsewhere in
// this file. Never shown on Splash/Login (no profile exists yet there).
class IveIntroGate extends ConsumerStatefulWidget {
  const IveIntroGate({super.key, required this.navigatorKey});

  // STABILITY-09-FIX — app.dart's MaterialApp.router `builder` mounts this
  // widget as a Stack SIBLING of `child` (the real GoRouter-managed
  // Router/Navigator), never a DESCENDANT of it. From that structural
  // position, ancestor-based `Navigator.of`/`Navigator.maybeOf` can NEVER
  // resolve the real Navigator — proven both by the symbolicated
  // STABILITY-09O-SHA production crash and by an empirical topology probe
  // reproducing this exact structure (immediate=false, settled=false, even
  // long after full route settlement). This GlobalKey is the SAME key
  // app.dart passes as GoRouter's own `navigatorKey`, so it reaches the
  // real root NavigatorState directly, independent of BuildContext
  // position — confirmed by the same probe (keyBased=true). It is the
  // existing root navigator GoRouter already manages, not a second,
  // competing Navigator architecture (mission section 08).
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<IveIntroGate> createState() => _IveIntroGateState();
}

class _IveIntroGateState extends ConsumerState<IveIntroGate> {
  bool _presented = false;

  // STABILITY-09-FIX — root cause (source/runtime evidence, not
  // speculation): app.dart's MaterialApp.router `builder` places
  // IveIntroGate as a Stack SIBLING of `child` (the actual GoRouter-managed
  // Router/Navigator), never a DESCENDANT of it. This is a PERMANENT
  // structural property of this widget's mount point, not a transient
  // timing race — ancestor-based Navigator lookup from here never
  // resolves, at any point in the widget's lifetime (topology probe:
  // immediate=false, settled=false). The symbolicated STABILITY-09O-SHA
  // production crash's exact path —
  //   _IveIntroGateState.build.<anonymous function>
  //   -> showIveIntroSheet -> showModalBottomSheet -> Navigator.of
  //   -> failure ("Null check operator used on a null value")
  // — is this same defect surfacing as a crash instead of a silent no-op,
  // because the pre-fix code called `Navigator.of` unconditionally.
  //
  // Fix: reach the real root Navigator via `widget.navigatorKey` (the same
  // GlobalKey app.dart supplies to GoRouter's own `navigatorKey`) instead
  // of ancestor-based lookup. Critically, `showModalBottomSheet` still
  // needs a BuildContext that has the Navigator as an ANCESTOR -- the
  // Navigator's own `currentContext` does NOT qualify (Navigator.of's
  // ancestor search starts at the given context's PARENT, so calling it
  // from the Navigator's own context searches ABOVE the Navigator, not the
  // Navigator itself, and would fail exactly like the original bug for a
  // root Navigator with nothing above it). `navigatorKey.currentState!
  // .overlay!.context` is used instead -- the Overlay is a genuine
  // DESCENDANT the Navigator builds internally, from which ancestor lookup
  // correctly finds this same Navigator. Verified empirically (not just
  // reasoned about) via a controlled reproduction test using the exact
  // app.dart topology before this was relied on for production.
  //
  // The key's Navigator/Overlay is only attached once GoRouter has
  // actually built its Navigator for the current frame, which can still
  // lag by one or a few frames right after app boot -- so a small,
  // hard-bounded, frame-driven retry (never a Timer, never unbounded --
  // mission section 06: "No polling loop. No timer storm.") covers that
  // narrow window. If it is still unattached after the bounded window
  // (pathological, not the reproduced case), `_presented` is reset so a
  // LATER rebuild gets a fresh attempt instead of permanently losing the
  // intro for this session (mission section 07: "do NOT mark the intro as
  // shown before it has actually been safely presented" / "no permanent
  // loss of intro due to one transient unavailable frame").
  static const _maxNavigatorRetryAttempts = 10;
  int _navigatorRetryAttempt = 0;

  // STABILITY-09-FIX (Codex Gate round 2, P1) — profile resolution
  // (currentProfileProvider, a network fetch) and GoRouter's own
  // Splash->Dashboard/Login redirect (SplashScreen's fixed 800ms timer) are
  // driven by two INDEPENDENT clocks. On a fast connection/warm session the
  // profile can resolve WHILE the app is still showing Splash -- and since
  // IveIntroGate is mounted globally in app.dart's builder (not per-route),
  // its build() runs regardless of the current route. Without a route
  // check, this let the intro sheet schedule and open on top of the Splash
  // screen instead of Dashboard/login-adjacent authenticated content.
  //
  // IveForensicSnapshot.currentRoute (already updated synchronously on
  // every GoRouter `redirect` evaluation, see app.dart) is reused as the
  // "has routing left Splash" signal -- no new Navigator/route-guard
  // architecture, just reading state that already exists for exactly this
  // kind of purpose (mission section 08).
  bool _routeReady() {
    final route = IveForensicSnapshot.currentRoute;
    return route.isNotEmpty && route != AppConstants.routeSplash;
  }

  @override
  void initState() {
    super.initState();
    // Profile/intro state alone (watched in build()) cannot detect a LATER
    // route transition away from Splash, since a route change by itself
    // does not rebuild this widget (it is not a descendant of the Router).
    // Listening to the same redirect-driven signal lets a presentation that
    // was blocked purely on route-readiness retry the instant the app
    // actually leaves Splash, instead of being silently lost forever
    // (mission section 07: "no permanent loss of intro").
    IveForensicSnapshot.currentRouteNotifier.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    IveForensicSnapshot.currentRouteNotifier.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    // ignore: avoid_print
    print('DEBUG_ROUTE_CHANGED mounted=$mounted route=${IveForensicSnapshot.currentRoute}');
    if (!mounted) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final introState = ref.read(iveIntroProvider);
    // ignore: avoid_print
    print('DEBUG_ROUTE_CHANGED profile=${profile != null} shouldShow=${introState.shouldShow} presented=$_presented routeReady=${_routeReady()}');
    _maybeSchedule(profile, introState);
  }

  void _maybeSchedule(Profile? profile, IveIntroState introState) {
    if (_presented || profile == null || !introState.shouldShow || !_routeReady()) return;
    // ignore: avoid_print
    print('DEBUG_SCHEDULING');
    _presented = true;
    _navigatorRetryAttempt = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryPresent());
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final introState   = ref.watch(iveIntroProvider);

    _maybeSchedule(profileAsync.valueOrNull, introState);

    // Renders nothing — this widget only observes state and, at most once,
    // schedules the intro sheet. It must never affect layout (mounted in
    // the same Stack as IveOverlay, above the routed page).
    return const SizedBox.shrink();
  }

  void _tryPresent() {
    if (!mounted) return;
    final overlayContext = widget.navigatorKey.currentState?.overlay?.context;
    // ignore: avoid_print
    print('DEBUG_TRY_PRESENT overlayContext=${overlayContext != null} attempt=$_navigatorRetryAttempt');
    if (overlayContext == null) {
      if (_navigatorRetryAttempt < _maxNavigatorRetryAttempts) {
        _navigatorRetryAttempt++;
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryPresent());
        return;
      }
      // Bounded window exhausted without the root Navigator's Overlay ever
      // becoming attached -- re-arm rather than leaving the intro
      // permanently skipped for the rest of this session. iveIntroProvider's
      // own SharedPreferences state is untouched either way (it's only ever
      // written by the user's own CONTINUE/SKIP action inside the sheet,
      // see ive_intro_sheet.dart), so no persisted state needs correcting.
      _presented = false;
      return;
    }
    // Uses the Overlay's context (a genuine DESCENDANT of the real
    // Router/Navigator subtree), not this widget's own context --
    // ProviderScope is still reachable upward from it since it wraps the
    // whole app above MaterialApp.router.
    showIveIntroSheet(overlayContext, trigger: 'first_use');
  }
}
