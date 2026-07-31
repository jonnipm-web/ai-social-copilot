import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/feature_flag_provider.dart';

// ── Avatar version enum ───────────────────────────────────────────────────────

enum IveAvatarVersion {
  legacy, // render IveOverlay (legado — padrão)
  v2, // render IveAvatarV2 overlay
  hidden, // render nothing
}

// ── Local override enum ───────────────────────────────────────────────────────

enum IveAvatarLocalOverride {
  automatic, // follow remote feature flag
  legacy, // force legacy regardless of flag
  v2, // force V2 regardless of flag
  hidden; // force hidden on this device

  static const _prefKey = 'ive_avatar_local_override';

  static IveAvatarLocalOverride fromString(String? v) {
    switch (v) {
      case 'legacy':
        return legacy;
      case 'v2':
        return v2;
      case 'hidden':
        return hidden;
      default:
        return automatic;
    }
  }

  static Future<IveAvatarLocalOverride> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromString(prefs.getString(_prefKey));
  }

  static Future<void> save(IveAvatarLocalOverride value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value.name);
  }
}

// ── Local override notifier ───────────────────────────────────────────────────

class IveAvatarLocalOverrideNotifier
    extends StateNotifier<IveAvatarLocalOverride> {
  IveAvatarLocalOverrideNotifier() : super(IveAvatarLocalOverride.automatic) {
    _load();
  }

  Future<void> _load() async {
    if (!_canOverride) return;
    state = await IveAvatarLocalOverride.load();
  }

  Future<void> set(IveAvatarLocalOverride override) async {
    if (!_canOverride) return;
    state = override;
    await IveAvatarLocalOverride.save(override);
  }

  // Available only in debug builds or when admin role is implemented.
  bool get _canOverride => kDebugMode;
}

final iveAvatarLocalOverrideProvider = StateNotifierProvider<
    IveAvatarLocalOverrideNotifier,
    IveAvatarLocalOverride>((_) => IveAvatarLocalOverrideNotifier());

// ── Remote flag provider ──────────────────────────────────────────────────────
//
// Wraps the async featureFlagsProvider into a sync bool that defaults to false.
// Never blocks UI — loading/error both produce false safely.

final iveAvatarV2FlagProvider = Provider<bool>((ref) {
  final flags = ref.watch(featureFlagsProvider);
  return flags.maybeWhen(
    data: (map) => map[FeatureFlag.iveAvatarV2Enabled] ?? false,
    orElse: () => false,
  );
});

// ── Effective version provider ────────────────────────────────────────────────
//
// Returns the version to render (legacy or v2). Route/auth hiding is handled
// in the IveAvatarResolver widget, which also reads IveAvatarVisibilityService.
//
// Priority:
//   1. local override hidden  → hidden
//   2. local override legacy  → legacy
//   3. local override v2      → v2
//   4. automatic              → follow remote flag (default false → legacy)

final effectiveIveAvatarVersionProvider = Provider<IveAvatarVersion>((ref) {
  final localOverride = ref.watch(iveAvatarLocalOverrideProvider);

  if (localOverride == IveAvatarLocalOverride.hidden) {
    return IveAvatarVersion.hidden;
  }
  if (localOverride == IveAvatarLocalOverride.legacy) {
    return IveAvatarVersion.legacy;
  }
  if (localOverride == IveAvatarLocalOverride.v2) {
    return IveAvatarVersion.v2;
  }

  // automatic: follow remote feature flag
  final v2Enabled = ref.watch(iveAvatarV2FlagProvider);
  return v2Enabled ? IveAvatarVersion.v2 : IveAvatarVersion.legacy;
});

// ── Auth helper ───────────────────────────────────────────────────────────────

bool iveIsAuthenticated() =>
    Supabase.instance.client.auth.currentSession != null;

// ── Hidden routes ─────────────────────────────────────────────────────────────

const kIveHiddenRoutes = <String>{
  '/',
  '/login',
  '/signup',
  '/forgot-password',
  '/reset-password',
  '/advisor-onboarding',
  '/debug/ive-avatar-v2',
};

bool iveIsHiddenRoute(String route) {
  if (route.isEmpty || route == '/') return true;
  for (final r in kIveHiddenRoutes) {
    if (r == '/') continue;
    if (route == r || route.startsWith('$r/')) return true;
  }
  return false;
}
