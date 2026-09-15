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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final introState   = ref.watch(iveIntroProvider);

    final profile = profileAsync.valueOrNull;
    if (!_presented && profile != null && introState.shouldShow) {
      _presented = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showIveIntroSheet(context, trigger: 'first_use');
      });
    }

    // Renders nothing — this widget only observes state and, at most once,
    // schedules the intro sheet. It must never affect layout (mounted in
    // the same Stack as IveOverlay, above the routed page).
    return const SizedBox.shrink();
  }
}
