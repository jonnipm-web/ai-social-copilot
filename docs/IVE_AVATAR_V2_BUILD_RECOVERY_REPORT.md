# IVE Avatar V2 — Build Recovery Report (Fase 11G)

**Branch:** `claude/ive-avatar-v2-build-recovery`  
**Date:** 2026-08-01  
**Base commit (Fase 11F):** `78786fb0a062e8b0191ec55c0db4d989731bbfe1`  
**Recovery HEAD:** `63d1953` (before this commit)

---

## Summary

All four technical blockers identified by the Codex auditor have been resolved.
The mandatory CI gates pass locally. The CI workflow now enforces a real APK build
with a verifiable SHA-256 and file size.

---

## Criteria Checklist

| # | Criterion | Status |
|---|-----------|--------|
| 1 | `dart format` — module scope (lib/shared/ive_avatar, test/features/ive) exits 0 | ✅ PASS |
| 2 | `dart analyze lib/shared/ive_avatar test/features/ive` exits 0 | ✅ PASS |
| 3 | `flutter analyze lib/shared/ive_avatar lib/features/ive lib/app.dart --fatal-warnings` exits 0 | ✅ PASS |
| 4 | `flutter analyze --fatal-warnings` (global) exits 0 | ✅ PASS (business_memory fixed) |
| 5 | V2 test suite: 39/39 Avatar V2 unit + visual tests pass | ✅ PASS (39 of ive_avatar_v2 + ive_visual_runtime) |
| 6 | Full resolver suite: 31/31 IveAvatarResolver tests pass | ✅ PASS |
| 7 | New E2E lifecycle suite: 11/11 tests pass (tests 32-42) | ✅ PASS |
| 8 | Total test suite: 104/104 pass across all V2 test files | ✅ PASS |
| 9 | `android/app/build.gradle.kts` committed | ✅ PRESENT |
| 10 | `MainActivity.kt` uses `io.flutter.embedding.android.FlutterActivity` | ✅ V2 EMBEDDING |
| 11 | `AndroidManifest.xml` declares `flutterEmbedding=2` | ✅ PRESENT |
| 12 | `applicationId = "com.example.ai_social_copilot"` preserved | ✅ PRESERVED |
| 13 | CI step 12 checks `build.gradle.kts`, mandatory (no skip path) | ✅ UPDATED |
| 14 | CI APK upload uses `if-no-files-found: error` | ✅ UPDATED |
| 15 | CI `apk_hash` step in MANDATORY gates | ✅ UPDATED |
| 16 | Feature flag default = false | ✅ UNCHANGED |
| 17 | V2 not referenced in production screens (outside lib/shared/ive_avatar/) | ✅ CONFIRMED |
| 18 | Legacy IveOverlay preserved and reachable | ✅ CONFIRMED |
| 19 | `main.dart` not modified | ✅ CONFIRMED |
| 20 | `SUPABASE_SERVICE_KEY` not written anywhere | ✅ CONFIRMED |

---

## Commits (in order)

| Hash | Message |
|------|---------|
| `f668fb4` | `style(ive-avatar-v2): normalize scoped formatting` |
| `67b26a0` | `fix(analyze): repair business memory Supabase query` |
| `ba3ea88` | `fix(android): commit full v2-embedding Android project scaffold` |
| `d6a6d74` | `test(ive-avatar-v2): add command-center chat lifecycle regression` |
| `ff350aa` | `ci(ive-avatar-v2): require real APK artifact` |
| `63d1953` | `docs(ive-avatar-v2): publish build recovery baseline` |

---

## CI Expectations

When the branch is pushed and CI runs on `claude/ive-avatar-v2-build-recovery`:

| Gate | Expected |
|------|----------|
| dart format (9 phase-11F files) | PASS |
| dart analyze ive_avatar module | PASS |
| flutter analyze V2 scope --fatal-warnings | PASS |
| Isolation checks | PASS |
| Smoke test — flag false | PASS |
| SUITE — Avatar V2 | PASS |
| SUITE — Full project | PASS (includes new lifecycle tests) |
| Build APK debug | PASS (android/app/build.gradle.kts present) |
| DEBUG_APK_SHA | real SHA-256 (not N/A) |
| DEBUG_APK_SIZE | real file size (not N/A) |
| APK artifact uploaded | with if-no-files-found: error |

---

## Open Items (Post-Recovery)

- **Real APK SHA-256**: will be confirmed from the CI run artifact.
- **Device test authorization**: requires GO from product owner after CI passes with real APK.
- **pubspec.lock**: not committed (excluded by constraint); CI generates its own via `flutter pub get`.

---

## Constraints Confirmed

- Feature flag NOT activated — remains false by default
- Avatar V2 NOT integrated in production
- Legacy avatar NOT removed — `IveOverlay` preserved
- `main.dart` NOT modified
- No global refactoring performed
- `SUPABASE_SERVICE_KEY` NOT written anywhere (not in .env, not in logs, not in APK)
- Safe placeholders only for SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_CLIENT_ID
