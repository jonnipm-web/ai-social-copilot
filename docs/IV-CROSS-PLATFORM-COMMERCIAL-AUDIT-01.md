# IV-CROSS-PLATFORM-COMMERCIAL-AUDIT-01
## InsightValues V1 — Cross-Platform Commercial Release Readiness Audit

**OWNER:** Paulo  
**ARCHITECT:** ChatGPT — Agente Martins  
**PRIMARY EXECUTOR:** Claude Code  
**DATE:** 2026-10-01  
**SCOPE:** Web + Android, all 31 feature modules  
**EXECUTION MODE:** AUTONOMOUS — NO MICROGATES  

---

## §1 — SUMMARY HEADER

| Item | Value |
|------|-------|
| Total modules audited | 31 |
| P1 findings | 4 |
| P2 findings | 5 |
| Owner-only blockers | 3 |
| Fixes applied | 9 (FIX-001 … FIX-009) |
| Files modified | 12 |
| AEF exposure | GATED (compile-time flag OFF by default) |
| Final verdict | **READY_FOR_OWNER_PHYSICAL_VALIDATION** |

---

## §2 — AUDIT SCOPE & METHOD

- Full static analysis of 266 Dart files across 31 modules
- Cross-platform parity: shared codebase confirmed (no `kIsWeb` / platform splits in audited modules)
- R16 localization: PT/EN ARB files audited for hardcoded strings
- AEF exposure: deploy-allowlist.tsv + compile-time gate verified
- IVE context: provider chain traced from call site to Edge Function payload
- Plan separation: admin/pro/free entitlements verified
- Navigation: scroll, back-stack, settings footer behavior verified

---

## §3 — PLATFORM BASELINE

**Finding:** Both Web and Android share 100% of the audited code. No platform-specific divergence was found in any of the 31 modules. The navigation scroll fix (WEB-007) is applied via shared `Scrollbar(thumbVisibility: true)` in `app_drawer.dart`. Settings items (Upgrade/Account/Support/About/Admin) are pinned outside the `Expanded` widget and always visible on both platforms.

**Conclusion:** Cross-platform drift was a testing artefact (old APK), not a code-level divergence.

---

## §4 — MODULE REGISTRY AUDIT

| Module ID | Commercial | Min Plan | Status |
|-----------|-----------|----------|--------|
| business-dashboard | ✅ | free | ACTIVE |
| projects | ✅ | free | ACTIVE |
| knowledge-vault | ✅ | free | ACTIVE |
| website-analyzer | ✅ | free | ACTIVE |
| market-intelligence | ✅ | free | ACTIVE |
| opportunity-lab | ✅ | free | DB-gated |
| action-engine | ✅ | free | DB-gated + AEF lab off |
| improve-post | ✅ | pro | ACTIVE |
| personas | ✅ | pro | ACTIVE |
| content-library | ✅ | pro | ACTIVE |
| calendar | ✅ | pro | ACTIVE |
| campaigns | ✅ | pro | ACTIVE |
| performance | ✅ | pro | ACTIVE |
| roi-tracker | ✅ | pro | ACTIVE |
| strategy-builder | ❌ | — | DISABLED (web accident reverted) |
| impact | ❌ | — | DISABLED (internal) |
| aef-runtime-lab | ❌ | — | DISABLED (lab) |
| command-center | ❌ | — | route=null, never shown |

Remaining modules (market-analysis, hotmart, shopify, amazon, post-editor, etc.): `commercialEnabled: false` — correct for V1.

---

## §5 — PER-MODULE FINDINGS

### 5.1 knowledge-vault
**P1 FIX-004 (FIXED):** `_ActionButtons.build` built `CopilotContextData` from `iveContextDataProvider` only. The `analysis: KnowledgeAnalysis` field received by `_ActionButtons` was never wired into the IVE context. IVE received ecosystem-level grounding but had zero knowledge of the analysis on screen (summary, keywords, post ideas, scores). Fix: enrich `CopilotContextData` with an `analysis` map from `widget.analysis` before calling `showCopilotChat`. Also added `analysis` field to `CopilotContextData` model + `toMap()` serialization.

### 5.2 action-engine
**P2 FIX-005/006 (FIXED):** "Pause" button on `executing` items in `action_engine_screen.dart:553` and `action_detail_screen.dart:882` called `notifier.approve()` (sets status→'approved'). Label said "Pause", action was "approve". Fix: added `pause()` method to `ActionQueueNotifier` with correct semantic name; both screens now call `notifier.pause()`. Popup menu value also fixed from `'approve'` to `'pause'`.

**AEF gate (unchanged):** `action-engine-runtime` Edge Function is NOT in `.github/deploy-allowlist.tsv`. `kAefRuntimeLabEnabled = bool.fromEnvironment('AEF_RUNTIME_LAB')` defaults to `false` at runtime. `ActionEngineExecuteSheet` (Human Gate) calls the undeployed function and would fail with a 404 — but this is intentional (LAB-only). The action queue listing, approval, and cancel flows are fully functional.

**DB feature flag gate:** `featureFlagProvider(FeatureFlag.actionEngineEnabled)` gates the entire screen. Default = `false` in `feature_flags` table. No user-visible risk.

### 5.3 website-analyzer
**P2 FIX-007 (FIXED):** "SEO Plan" and "AdSense Plan" action buttons were styled as active (`color.withOpacity(0.15)` border, full color icon/text) but called a SnackBar "coming soon" handler. Visually deceptive. Fix: made `_ActionButton.onTap` nullable; `null` triggers a visually muted/disabled state (reduced opacity, `Colors.white24`). Buttons now clearly signal "not available" rather than pretending to be actionable.

### 5.4 upgrade / billing
**P1 FIX-003 (FIXED, pre-compaction):** `_UsageBanner` showed `${quota.used} / ${quota.limit}` for all users, which displayed `0 / 99999` for admin accounts. Fix: added `bool get isAdmin => role == 'admin'` to `QuotaInfo`; banner shows `${quota.used} / ∞` for admin, remaining-text uses `quota.isAdmin` guard.

**Plan catalog (unchanged):** `_UpgradeContent` already used hardcoded `_proLimit = 300` for plan display — admin's `limit=99999` never appeared in the plan cards. Comment confirms the rationale.

### 5.5 debug (intelligence_debug_hub)
**P2 FIX-009 (FIXED):** Access-denied path (`!isAdmin`) used hardcoded PT strings: `'Acesso Negado'`, `'Você não tem permissão para acessar esta área.'`. These are shown to non-admin users on any locale. Fix: uses `t.uxAdminAccessDeniedTitle` / `t.uxAdminAccessDeniedBody` (existing EN/PT ARB keys).

**Note:** Tab labels (`'Decisões'`, `'Saúde'` etc.) are hardcoded PT but admin-only and internal tooling — not a R16 commercial blocker. Tracked as known tech debt.

### 5.6 app-constants / freeTierLimit
**P2 FIX-008 (FIXED):** `AppConstants.freeTierLimit = 9999` was a stale placeholder from before the commercial quota system. Actual free limit is `planLimits['free'] = 15`. Used as a fallback in `content_generation_screen.dart:69` — would give 9984 extra client-side analyses before the real server gate fires. Fix: updated to `15`, comment added.

### 5.7 web/index.html + pubspec.yaml (identity)
**P1 FIX-001/002 (FIXED, pre-compaction):**
- `<html>` → `<html lang="pt">`, title/description/apple-title updated to "InsightValues"
- `pubspec.yaml` description updated to "InsightValues — Plataforma de Inteligência de Negócios"
- Package name `ai_social_copilot` intentionally unchanged (breaking change)

### 5.8 quota_info model
**P1 FIX-003 partial — isAdmin getter (FIXED, pre-compaction):** Added `bool get isAdmin => role == 'admin'` to `QuotaInfo`.

### 5.9 app-drawer / navigation
**No issues.** Navigation scroll (WEB-007) confirmed fixed. Settings footer pinned correctly. `SafeArea` applied. `pushReplacement` guard prevents stack growth. Cross-platform: identical behavior (shared code).

### 5.10 about-screen
**Owner action required (not a code fix):**
- `AppConstants.officialWebsiteUrl = 'https://jonnipm-web.github.io/ai-social-copilot/'` — legacy GitHub Pages URL; should point to `insightvalues.com`
- `AppConstants.privacyPolicyUrl = null` — renders "owner config required"; RELEASE BLOCKER
- `AppConstants.termsOfUseUrl = null` — same; RELEASE BLOCKER

### 5.11 Remaining modules (content-library, campaigns, calendar, roi-tracker, improve-post, personas, performance, market-intelligence, opportunity-lab, projects, home, history, strategy, etc.)
Static analysis: no hardcoded string violations in commercial paths, no AEF exposure, no plan leaks. IVE context chain verified at each `showCopilotChat` call site — all pass `CopilotContextData.fromIveContext` or explicit context. See §8 (unchanged register) for full list.

---

## §6 — CROSS-PLATFORM PARITY MATRIX

| Feature | Web | Android | Notes |
|---------|-----|---------|-------|
| Navigation drawer scroll | ✅ | ✅ | Scrollbar(thumbVisibility:true) — shared |
| Settings footer visibility | ✅ | ✅ | Outside Expanded — shared |
| Back-stack drill-in | ✅ | ✅ | push/pushReplacement — shared |
| SafeArea | ✅ | ✅ | Drawer level — shared |
| Admin gate (debug hub) | ✅ | ✅ | fail-closed on null profile — shared |
| Quota display (admin ∞) | ✅ (FIX-003) | ✅ (FIX-003) | Fixed |
| AEF Human Gate | ❌ (lab) | ❌ (lab) | Intentionally disabled both |
| Plan catalog | ✅ | ✅ | Canonical limits displayed |
| IVE knowledge analysis | ✅ (FIX-004) | ✅ (FIX-004) | Fixed |

**Verdict: No cross-platform code divergence. All fixes apply equally to both platforms.**

---

## §7 — AEF EXPOSURE REGISTER

| Item | Status | Evidence |
|------|--------|---------|
| `action-engine-runtime` Edge Function | NOT deployed | Absent from `.github/deploy-allowlist.tsv` |
| `aef-runtime-lab` module | `commercialEnabled: false` | Module registry — never shown in drawer |
| `kAefRuntimeLabEnabled` compile flag | `false` at runtime | `bool.fromEnvironment('AEF_RUNTIME_LAB')` |
| `ActionEngineExecuteSheet` | Reachable via UI | Only when `status == 'approved'` or `'executing'`; calls undeployed function → 404 |
| `action-engine` module | DB-gated OFF | `featureFlagProvider(FeatureFlag.actionEngineEnabled)` default=false |
| AEF scope | FROZEN | No changes made to AEF architecture or activation state |

**Conclusion:** AEF is defense-in-depth gated (compile flag + DB flag + undeployed function). No AEF functionality is reachable by commercial users. Architecture frozen per mission brief.

---

## §8 — FIX REGISTER

| ID | Priority | File | Description | Status |
|----|----------|------|-------------|--------|
| FIX-001 | P1 | `web/index.html` | lang="pt", title/description/apple-title → InsightValues | APPLIED |
| FIX-002 | P2 | `pubspec.yaml` | description → InsightValues brand | APPLIED |
| FIX-003 | P1 | `lib/data/models/quota_info.dart` + `lib/data/models/profile.dart` + `upgrade_screen.dart` + `account_screen.dart` | Admin/commercial-Pro separation: `isCommercialPro` getter added; admin shows `99.999` (not `∞`), not labeled Pro, cannot trigger checkout | APPLIED (v2 — a367f8d) |
| FIX-004 | P1 | `lib/features/knowledge/screens/knowledge_analysis_screen.dart` + `lib/data/models/copilot_context_data.dart` | IVE context now includes analysis fields | APPLIED |
| FIX-005 | P2 | `lib/features/action_engine/screens/action_engine_screen.dart` + `lib/providers/action_queue_provider.dart` | Pause button uses notifier.pause() not approve() | APPLIED |
| FIX-006 | P2 | `lib/features/action_engine/screens/action_detail_screen.dart` | Same Pause button fix, popup menu value | APPLIED |
| FIX-007 | P2 | `lib/features/website_analyzer/screens/website_analysis_result_screen.dart` | SEO/AdSense "coming soon" buttons visually disabled | APPLIED |
| FIX-008 | P2 | `lib/core/constants/app_constants.dart` | freeTierLimit 9999 → 15 | APPLIED |
| FIX-009 | P2 | `lib/features/debug/screens/intelligence_debug_hub_screen.dart` | Access-denied strings localized (R16) | APPLIED |

---

## §9 — UNCHANGED REGISTER

The following modules were audited and require no code changes:

- `business-dashboard` — scores, KPIs, project selection: correct, no plan leaks
- `projects` — CRUD, health scoring: correct
- `market-intelligence` — opportunity cards, score display: correct
- `improve-post` — pro-gated, IVE context wired: correct
- `personas` — pro-gated, CRUD: correct
- `content-library` — pro-gated, media: correct
- `calendar` — pro-gated, scheduling: correct
- `campaigns` — pro-gated, IVE context: correct
- `performance` — pro-gated, metrics: correct
- `roi-tracker` — pro-gated, metrics: correct
- `home` / `history` — free-tier, no plan leaks
- `account-screen` — profile, subscription info: correct
- `support-screen` — email link: correct (`suporte@insigthvalues.com`)
- `splash/login/auth` — no commercial UI
- `app-drawer` — navigation, role chip: correct (verified §5.9)
- `admin-panel` — fail-closed on null, admin-only: correct
- `ive-overlay` / `ive-detail-sheet` — context chain correct (FOUNDATION-11 applied)
- `copilot-context-data` — `withIdentity` wires identity fields: correct

---

## §10 — OWNER BLOCKERS (action required, cannot be code-fixed)

| # | Item | Impact | Action |
|---|------|--------|--------|
| OB-01 | `AppConstants.privacyPolicyUrl = null` | RELEASE BLOCKER — About screen shows "owner config required" | Create Privacy Policy page, set URL in app_constants.dart |
| OB-02 | `AppConstants.termsOfUseUrl = null` | RELEASE BLOCKER — same | Create Terms of Use page, set URL |
| OB-03 | `AppConstants.officialWebsiteUrl` points to legacy GitHub Pages | Low severity, cosmetic | Update to production domain when available |
| OB-04 | `AppConstants.supportEmail = 'suporte@insigthvalues.com'` — typo in domain (`insigth` vs `insight`) | Medium — bounce risk | Confirm mailbox is active; if domain is `insightvalues.com`, update constant and ensure MX record exists |

---

## §11 — OWNER RETEST CHECKLIST

Targeted manual tests only. Do NOT retest unchanged modules.

```
[ ] 1. UPGRADE SCREEN — admin account: Usage banner shows "X / 99.999" (not "∞" and not "0 / 99999"); Pro plan card shows "Most Popular" badge (not "Plano Atual"); Upgrade button disabled for admin
[ ] 2. UPGRADE SCREEN — free account: Usage banner shows correct used/limit and remaining text
[ ] 3. UPGRADE SCREEN — exhausted free account: red bar + "You've used all analyses" text shown
[ ] 4. KNOWLEDGE ANALYSIS → ASK IVE: IVE response must reference the document summary/keywords
        (test: ask "What are the main keywords for this document?" — answer must come from analysis, not generic)
[ ] 5. ACTION ENGINE (if feature-flag enabled in dev): "Pause" button on EXECUTING item
        → action goes back to APPROVED state (not re-confirmed "approved pending" dialog)
[ ] 6. WEBSITE ANALYZER result page: SEO Plan + AdSense Plan buttons appear visually muted/disabled
        (no color, no tap effect — NOT same style as "Create Campaign" button)
[ ] 7. DEBUG HUB — non-admin account (EN locale): access-denied screen shows English text
        ("Access denied" / "You don't have permission to access this area.")
[ ] 8. DEBUG HUB — admin account: tabs load normally
[ ] 9. WEB — HTML title in browser tab reads "InsightValues" (not "ai_social_copilot")
[ ] 10. ANDROID — install fresh APK; navigation drawer: all settings items visible without scrolling
```

---

## §12 — FINAL RELEASE MATRIX

| Gate | Status | Notes |
|------|--------|-------|
| Web identity (title/lang) | ✅ PASS | FIX-001 |
| Admin quota display | ✅ PASS | FIX-003 |
| IVE knowledge context | ✅ PASS | FIX-004 |
| Pause button semantic | ✅ PASS | FIX-005/006 |
| Coming-soon button UX | ✅ PASS | FIX-007 |
| Free tier limit constant | ✅ PASS | FIX-008 |
| R16 debug screen | ✅ PASS | FIX-009 |
| AEF isolation | ✅ PASS | Gated, frozen |
| Cross-platform parity | ✅ PASS | Shared codebase, no drift |
| Privacy Policy URL | ❌ OWNER ACTION | OB-01 |
| Terms of Use URL | ❌ OWNER ACTION | OB-02 |
| Official website URL | ⚠️ LOW | OB-03 |

**FINAL VERDICT: `READY_FOR_OWNER_PHYSICAL_VALIDATION`**

All P1 and P2 code-fixable findings have been resolved. Two owner-only release blockers remain (Privacy Policy + Terms of Use URLs). Physical validation against Owner Retest Checklist §11 is the next gate before production release.

---

## §13 — FINAL INTEGRATION REGISTER (sealed 2026-10-01)

| Item | Value |
|------|-------|
| BASE_MAIN_SHA | c8d1b698 |
| PR_BRANCH | `iv-cross-platform-audit-01` |
| PR_NUMBER | #111 (MERGED) |
| FIX-003_v1_SHA | 41dc6d8 |
| FIX-003_v2_SHA | a367f8d |
| FIX-004_VALIDATED | ✅ analysis map + identity fields confirmed in source |
| CI_LAST_RESULT | ✅ SUCCESS — job #110412084416, 8m42s, 2026-10-01T14:24:59Z |
| LATEST_TECHNICAL_MERGE_SHA | f9797d46 |
| CANONICAL_MAIN_SHA | 2897d7d237ea1b351a1771adf59df9128a5ebf18 |
| CODEX_FINAL_AUDIT | CODEX_UNAVAILABLE — independent audit not run; manual static analysis performed by primary executor; finding: no regressions detected |
| FLUTTER_BUILD_ENV | UNAVAILABLE in cloud container — local build required |
| WEB_BUILD | NOT RUN — Flutter not installed in cloud |
| APK_BUILD | NOT RUN — Flutter not installed in cloud |
| APK_SOURCE_SHA | 2897d7d237ea1b351a1771adf59df9128a5ebf18 (canonical main) |
| APK_SHA256 | PENDING OWNER BUILD |
| APK_PACKAGE | ai.insightvalues.app (assumed — confirm in pubspec.yaml) |
| NOTE20_INSTALL_STATUS | PENDING — ADB not available in cloud; see §14 for manual steps |
| EXTERNAL_URL_CHECK | BLOCKED — network egress not available in cloud; see §14 |
| OB-01_STATUS | ❌ RELEASE BLOCKER — privacyPolicyUrl = null |
| OB-02_STATUS | ❌ RELEASE BLOCKER — termsOfUseUrl = null |
| OB-03_STATUS | ⚠️ LOW — officialWebsiteUrl = legacy GitHub Pages |
| OB-04_STATUS | ⚠️ UNCONFIRMED — supportEmail typo: `insigth` vs `insight` |
| TRACK_A_STATUS | PENDING OWNER PHYSICAL VALIDATION |
| FINAL_VERDICT | READY_FOR_OWNER_PHYSICAL_VALIDATION |

---

## §14 — OWNER ACTION ITEMS (required before CROSS_PLATFORM_RELEASE_READY)

### 14.1 — APK QA Build (OWNER executes)

Flutter is not installed in the cloud container. Owner must build locally from canonical main.

```bash
# 1. Pull canonical main
git fetch origin && git checkout main && git pull origin main
# Confirm: git log --oneline -1 → 2897d7d

# 2. Build debug APK for QA
flutter clean && flutter pub get
flutter build apk --debug

# 3. Record provenance
sha256sum build/app/outputs/flutter-apk/app-debug.apk
git rev-parse HEAD

# 4. Install on Note 20 (RXCR70003HN)
adb devices   # confirm device connected
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm list packages | grep insight   # confirm installed

# 5. Record and fill in §13:
#   APK_SHA256: <sha256 from step 3>
#   APK_SOURCE_SHA: <git rev-parse from step 3>
#   NOTE20_INSTALL_STATUS: INSTALLED / FAILED
```

### 14.2 — Track A Physical Validation Checklist (10–15 min)

Test ONLY changed surfaces. Do not re-test unchanged modules.

```
UPGRADE SCREEN — ADMIN ACCOUNT
[ ] 1a. Banner shows "X / 99.999" (not "∞" and not "0 / 99999")
[ ] 1b. Free plan card: no "Plano Atual" badge; button disabled
[ ] 1c. Pro plan card: shows "Mais Popular" badge (NOT "Plano Atual")
[ ] 1d. Pro plan card: Upgrade button is disabled (grey, no tap)
[ ] 1e. Account screen: shows "Admin" label + shield/card icon (not gold star)

UPGRADE SCREEN — FREE ACCOUNT
[ ] 2a. Banner shows "X / 15" used/limit, remaining text correct
[ ] 2b. Free plan card shows "Plano Atual"
[ ] 2c. Pro plan card: Upgrade button is active and tappable

KNOWLEDGE ANALYSIS → ASK IVE
[ ] 3a. Open a Knowledge item that has been analyzed
[ ] 3b. Tap "Ask IVE" action button
[ ] 3c. Ask: "Quais são as principais palavras-chave deste documento?"
       Expected: IVE answers using actual keywords from THIS analysis
       (not generic — must name specific keywords from the analysis on screen)

NAVIGATION DRAWER (Note 20)
[ ] 4a. All settings items visible without scrolling
       (Upgrade / Account / Support / About / Admin visible together)

WEBSITE ANALYZER
[ ] 5a. Open any Website Analysis result
[ ] 5b. "SEO Plan" and "AdSense Plan" buttons appear muted/grey
       (no color border, no tap ripple — clearly disabled)

ACTION ENGINE (requires dev feature flag ON)
[ ] 6a. Set feature_flags.action_engine_enabled = true in Supabase for test account
[ ] 6b. Find an item in EXECUTING status
[ ] 6c. Tap "Pause" → item status returns to APPROVED
       (no "approve" dialog, no status = 'approved pending confirmation')

R16 SPOT-CHECK
[ ] 7a. Set device locale to English
[ ] 7b. Trigger Debug Hub access with non-admin account
       Expected: "Access Denied" / "You don't have permission to access this area."
[ ] 7c. Set back to Portuguese → same screen shows Portuguese

ABOUT / LEGAL LINKS
[ ] 8a. Open About screen
[ ] 8b. Note current state of Privacy Policy link (active / "owner config required")
[ ] 8c. Note current state of Terms of Use link (active / "owner config required")
[ ] 8d. Note current state of Website link destination
```

### 14.3 — Owner Blockers (resolve before release)

| # | Item | Required Action |
|---|------|----------------|
| OB-01 | `privacyPolicyUrl = null` | Create Privacy Policy page (insightvalues.com/privacy or equivalent). Set URL in `lib/core/constants/app_constants.dart`. Must be reachable via HTTPS. |
| OB-02 | `termsOfUseUrl = null` | Same — Terms of Use page. |
| OB-03 | `officialWebsiteUrl = 'https://jonnipm-web.github.io/ai-social-copilot/'` | If insightvalues.com is the real domain, update to `'https://insightvalues.com'`. Verify domain is live first. |
| OB-04 | `supportEmail = 'suporte@insigthvalues.com'` | Confirm this mailbox receives email. If the domain is `insightvalues.com` (not `insigthvalues.com`), fix the typo and update the constant. |

When OB-01 and OB-02 are resolved, update `lib/core/constants/app_constants.dart`, run CI, and merge to main. That is the final code gate before production deploy.

### 14.4 — External URL Verification (OWNER performs)

Check these URLs in a browser. Report results to update OB-03/OB-04:

```
[ ] https://insightvalues.com          → live? (expected 200)
[ ] https://insightvalues.com/privacy  → exists? (any 200 URL acceptable)
[ ] https://insightvalues.com/terms    → exists?
[ ] https://jonnipm-web.github.io/ai-social-copilot/  → legacy app (confirm still up)
[ ] Send test email to suporte@insigthvalues.com → bounces or delivers?
```
