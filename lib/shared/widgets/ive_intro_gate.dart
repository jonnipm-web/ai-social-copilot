import 'package:flutter/foundation.dart' show debugPrint;
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
  const IveIntroGate({super.key});

  @override
  ConsumerState<IveIntroGate> createState() => _IveIntroGateState();
}

class _IveIntroGateState extends ConsumerState<IveIntroGate> {
  bool _presented = false;

  // STABILITY-09-FIX — symbolicated production evidence (mission
  // STABILITY-09O-SHA) proved the exact failure path:
  //   _IveIntroGateState.build.<anonymous function> (this callback)
  //   -> showIveIntroSheet -> showModalBottomSheet -> Navigator.of
  //   -> failure ("Null check operator used on a null value").
  //
  // Root cause (source/runtime evidence, not speculation): app.dart's
  // MaterialApp.router `builder` places IveIntroGate as a Stack SIBLING of
  // `child` (the actual GoRouter-managed Router/Navigator), never a
  // DESCENDANT of it — `Navigator.of(context)` from here has always
  // depended on an ambient Navigator reachable through that same builder
  // scope, exactly like IveOverlay's own showModalBottomSheet call
  // (context_copilot_widget.dart's showCopilotChat, same Stack position),
  // which works reliably because it only ever fires from a deliberate user
  // tap, long after the app's initial route has settled. IveIntroGate is
  // different: it fires from the FIRST resolution of currentProfileProvider,
  // which is the EXACT SAME signal that drives GoRouter's own initial
  // redirect (splash -> dashboard/login, in _computeRedirect) — the one
  // moment the Router/Navigator subtree is itself being freshly built,
  // making it transiently unavailable for one or a few frames. Every
  // natural production occurrence captured across STABILITY-09O-R and
  // STABILITY-09O-SHA happened on a fresh page load/reload with an
  // already-authenticated session — never during steady-state in-app
  // navigation — consistent with this explanation.
  //
  // Fix: verify the Navigator is actually reachable BEFORE calling
  // showModalBottomSheet, with a small, hard-bounded, frame-driven retry
  // (never a Timer, never unbounded — mission section 06: "No polling
  // loop. No timer storm.") for the rare case for the Navigator not being
  // mounted yet on the very first frame. If it's still not reachable after
  // the bounded window (a pathological case, not the one reproduced),
  // `_presented` is reset so a LATER rebuild gets a fresh attempt instead
  // of permanently losing the intro for this session (mission section 07:
  // "do NOT mark the intro as shown before it has actually been safely
  // presented" / "no permanent loss of intro due to one transient
  // unavailable frame").
  static const _maxNavigatorRetryAttempts = 10;
  int _navigatorRetryAttempt = 0;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final introState   = ref.watch(iveIntroProvider);

    final profile = profileAsync.valueOrNull;
    debugPrint('[09FIX-DEBUG] build: presented=$_presented profile=${profile != null} loading=${introState.loading} shouldShow=${introState.shouldShow}');
    if (!_presented && profile != null && introState.shouldShow) {
      _presented = true;
      _navigatorRetryAttempt = 0;
      debugPrint('[09FIX-DEBUG] scheduling _tryPresent');
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryPresent());
    }

    // Renders nothing — this widget only observes state and, at most once,
    // schedules the intro sheet. It must never affect layout (mounted in
    // the same Stack as IveOverlay, above the routed page).
    return const SizedBox.shrink();
  }

  void _tryPresent() {
    debugPrint('[09FIX-DEBUG] _tryPresent called, mounted=$mounted attempt=$_navigatorRetryAttempt');
    if (!mounted) return;
    final nav = Navigator.maybeOf(context);
    debugPrint('[09FIX-DEBUG] Navigator.maybeOf = ${nav != null}');
    if (nav == null) {
      if (_navigatorRetryAttempt < _maxNavigatorRetryAttempts) {
        _navigatorRetryAttempt++;
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryPresent());
        return;
      }
      // Bounded window exhausted without a Navigator ever becoming
      // reachable — re-arm rather than leaving the intro permanently
      // skipped for the rest of this session. iveIntroProvider's own
      // SharedPreferences state is untouched either way (it's only ever
      // written by the user's own CONTINUE/SKIP action inside the sheet,
      // see ive_intro_sheet.dart), so no persisted state needs correcting.
      debugPrint('[09FIX-DEBUG] retry window exhausted, re-arming');
      _presented = false;
      return;
    }
    debugPrint('[09FIX-DEBUG] calling showIveIntroSheet');
    showIveIntroSheet(context, trigger: 'first_use').then((_) {
      debugPrint('[09FIX-DEBUG] showIveIntroSheet future completed normally');
    }, onError: (Object e, StackTrace st) {
      debugPrint('[09FIX-DEBUG] showIveIntroSheet future ERRORED: $e\n$st');
    });
  }
}
