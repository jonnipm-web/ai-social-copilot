import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// IVE-EXPERIENCE-V1-06 (Section 15) — first-use "Meet IVE" persistence.
// Mirrors the existing SharedPreferences pattern already proven by
// language_provider.dart (LanguageNotifier): fails silently on any
// SharedPreferences error (e.g. a test environment without a plugin host),
// keeping the deterministic in-memory default rather than crashing or
// blocking the app. Device-local by design for V1 — not synced to the
// `profiles` table (accepted tradeoff, see mission report Section 12/33).
const _kIntroCompletedKey = 'ive_intro_completed';
const _kIntroSkippedKey = 'ive_intro_skipped';
const _kIntroVersionKey = 'ive_intro_version';

// Bump this to re-show a materially changed introduction to users who
// already completed/skipped an older version — without resetting any other
// onboarding state (mission Section 06/15). Never decremented.
const kIveIntroCurrentVersion = 1;

class IveIntroState {
  /// True while SharedPreferences hasn't restored yet — the caller must not
  /// decide to show/hide the intro during this window (avoids a flash).
  final bool loading;
  final bool completed;
  final bool skipped;
  final int? seenVersion;

  const IveIntroState({
    this.loading = true,
    this.completed = false,
    this.skipped = false,
    this.seenVersion,
  });

  // IVE-EXPERIENCE-V1-06 (Section 15) — "ive_intro_seen" from the mission's
  // minimum-state list is intentionally a DERIVED value, not a fifth
  // persisted flag: persisting it separately would let it silently drift
  // from `completed`/`skipped` (e.g. a bug that sets one but not the
  // other). Two ground-truth flags plus a derived getter cannot disagree
  // with themselves.
  bool get seen => completed || skipped;

  /// Show the intro when the user has never dealt with it, or when a newer
  /// version exists than the one they last completed/skipped — the
  /// versioning hook mission Section 06/15 asks for.
  bool get shouldShow =>
      !loading && (seenVersion == null || seenVersion! < kIveIntroCurrentVersion);

  IveIntroState copyWith({bool? loading, bool? completed, bool? skipped, int? seenVersion}) =>
      IveIntroState(
        loading:     loading     ?? this.loading,
        completed:   completed   ?? this.completed,
        skipped:     skipped     ?? this.skipped,
        seenVersion: seenVersion ?? this.seenVersion,
      );
}

class IveIntroNotifier extends StateNotifier<IveIntroState> {
  IveIntroNotifier() : super(const IveIntroState(loading: true)) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = IveIntroState(
        loading:     false,
        completed:   prefs.getBool(_kIntroCompletedKey) ?? false,
        skipped:     prefs.getBool(_kIntroSkippedKey) ?? false,
        seenVersion: prefs.getInt(_kIntroVersionKey),
      );
    } catch (_) {
      // SharedPreferences pode falhar em ambiente de teste — mantém o
      // estado padrão (não visto), mas encerra o loading para não bloquear
      // indefinidamente uma decisão de exibição.
      state = state.copyWith(loading: false);
    }
  }

  Future<void> complete() async {
    state = state.copyWith(completed: true, skipped: false, seenVersion: kIveIntroCurrentVersion);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIntroCompletedKey, true);
      await prefs.setBool(_kIntroSkippedKey, false);
      await prefs.setInt(_kIntroVersionKey, kIveIntroCurrentVersion);
    } catch (_) {
      // Não persistido, mas a sessão atual já não mostra a introdução de novo.
    }
  }

  Future<void> skip() async {
    state = state.copyWith(completed: false, skipped: true, seenVersion: kIveIntroCurrentVersion);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIntroSkippedKey, true);
      await prefs.setInt(_kIntroVersionKey, kIveIntroCurrentVersion);
    } catch (_) {
      // Não persistido, mas a sessão atual já não mostra a introdução de novo.
    }
  }
}

final iveIntroProvider = StateNotifierProvider<IveIntroNotifier, IveIntroState>(
  (ref) => IveIntroNotifier(),
);
