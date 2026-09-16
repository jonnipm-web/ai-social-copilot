import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final introState   = ref.watch(iveIntroProvider);

    final profile = profileAsync.valueOrNull;
    if (!_presented && profile != null && introState.shouldShow) {
      _presented = true;
      _navigatorRetryAttempt = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryPresent());
    }

    // Renders nothing — this widget only observes state and, at most once,
    // schedules the intro sheet. It must never affect layout (mounted in
    // the same Stack as IveOverlay, above the routed page).
    return const SizedBox.shrink();
  }

  void _tryPresent() {
    if (!mounted) return;
    final overlayContext = widget.navigatorKey.currentState?.overlay?.context;
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
