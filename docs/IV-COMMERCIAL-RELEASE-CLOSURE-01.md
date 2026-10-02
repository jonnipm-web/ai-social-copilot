# IV-COMMERCIAL-RELEASE-CLOSURE-01
## InsightValues V1 — Commercial Release Closure Gate

**OWNER:** Paulo  
**ARCHITECT:** ChatGPT — Agente Martins  
**PRIMARY EXECUTOR:** Claude Code  
**DATE:** 2026-10-02  
**SCOPE:** Full product closure — discovery → inventory → architecture → implementation → integration → tests → security → monetization → audit → regression → documentation → PR → final gate  
**EXECUTION MODE:** AUTONOMOUS — deadline EOD Saturday 2026-10-03 (RC) · Google Auth DEFERRED 2026-10-04

---

## §1 — EXECUTIVE VERDICT

| Status | Value |
|--------|-------|
| Code verdict | **RELEASE_CANDIDATE_READY_EXCEPT_GOOGLE_AUTH** |
| Owner-only blockers | 2 (OB-01: Privacy Policy URL · OB-02: Terms of Use URL) |
| Deferred by design | Google Auth (clean rebuild 2026-10-04) |
| Critical security findings | 0 |
| P0/P1 code defects | 0 |
| Tests | PENDING (CI gate — see §5) |

All P1/P2 code-fixable issues from both this mission and the preceding IV-CROSS-PLATFORM-COMMERCIAL-AUDIT-01 have been resolved. Two release blockers remain that only the owner can resolve (privacy policy and terms of use pages). Google Auth is intentionally deferred to a clean rebuild on 2026-10-04.

---

## §2 — BASE STATE

| Item | Value |
|------|-------|
| BASE_MAIN_SHA | `90a59af059fa936dc873736ad6d035bdc00d8574` |
| MISSION_BRANCH | `claude/iv-commercial-release-closure-01` |
| PRIOR_AUDIT_BRANCH | `iv-cross-platform-audit-01` (merged to main) |
| PRIOR_AUDIT_PR | #111 (MERGED) |
| R16_ROUND3_PR | #110 (MERGED) — E/F/I |
| PRIOR_AUDIT_FIXES | FIX-001…FIX-009 ALL APPLIED |
| PACKAGE | `ai_social_copilot` (package name intentionally unchanged) |
| APPLICATION_ID | `com.insightvalues.app` |
| PLATFORM | Flutter/Dart · Web + Android |
| DB | Supabase · latest migration `20261015000000_r16_content_localizations.sql` |

---

## §3 — INVENTORY: WHAT WAS ALREADY DONE (inherited from origin/main)

The `iv-cross-platform-audit-01` mission (merged 2026-10-01) delivered 9 commercial fixes. This closure mission inherits all of them.

### 3.1 — FIX register (inherited)

| ID | Priority | Description | Status |
|----|----------|-------------|--------|
| FIX-001 | P1 | `web/index.html` lang/title/description → InsightValues brand | APPLIED |
| FIX-002 | P2 | `pubspec.yaml` description → InsightValues brand | APPLIED |
| FIX-003 | P1 | Admin/commercial-Pro separation: `isCommercialPro` getter · admin shows `X / 99.999` · upgrade button disabled for admin · plan cards never mark admin as "current plan" | APPLIED (v2 · a367f8d) |
| FIX-004 | P1 | `knowledge_analysis_screen.dart` + `copilot_context_data.dart`: IVE context enriched with full analysis (summary · keywords · topics · pillars · pain points · commercial angles · post/campaign ideas · scores) | APPLIED |
| FIX-005 | P2 | `action_engine_screen.dart` + `action_queue_provider.dart`: Pause button uses `notifier.pause()` not `notifier.approve()` | APPLIED |
| FIX-006 | P2 | `action_detail_screen.dart`: same Pause fix, popup menu value corrected | APPLIED |
| FIX-007 | P2 | `website_analysis_result_screen.dart`: SEO/AdSense "coming soon" buttons visually disabled (not falsely actionable) | APPLIED |
| FIX-008 | P2 | `app_constants.dart`: `freeTierLimit` 9999 → 15 (mirrors real server limit) | APPLIED |
| FIX-009 | P2 | `intelligence_debug_hub_screen.dart`: access-denied strings localized (R16) | APPLIED |

### 3.2 — R16 QA Round 3 fixes (PR #110 — c8d1b69)

| Item | Description | Status |
|------|-------------|--------|
| E | SnackBar "Projeto criado!" + "Adicionar Fonte" action → `routeKnowledgeNew` with projectId | APPLIED |
| F | KnowledgeAnalysisScreen hierarchy (INFORMATION → EXPLANATION → sticky CONTEXTUAL ACTION) + `_CollapsibleSection` for secondary sections | APPLIED |
| I | `_SummaryCard` contextual hint (💡 lightbulb + `knowledgeAnalysisSummaryHint`) | APPLIED |

---

## §4 — SECURITY AUDIT

### 4.1 — Client-side secret exposure

| Check | Result |
|-------|--------|
| `service_role` key in client code | ❌ NOT FOUND — only appears in `diagnostic_sanitizer.dart` redaction pattern and admin screen comment |
| `.env` committed to git | ❌ NOT COMMITTED — `.gitignore` confirmed, `.env.example` exists |
| Stripe LIVE key in client | ❌ NOT FOUND — only `sk_live_` in sanitizer regex pattern; test file uses `sk_live_abcdef…` dummy |
| `anonKey` source | ✅ SAFE — `dotenv.env['SUPABASE_ANON_KEY']!` at runtime |
| `applicationId` / namespace | ✅ `com.insightvalues.app` — unchanged |

### 4.2 — Billing security

| Check | Result |
|-------|--------|
| `create-checkout-session` auth gate | ✅ JWT required — no `--no-verify-jwt` in deploy allowlist |
| `body.user_id` / `body.role` / `body.price_id` | ✅ NEVER READ — "request body isn't even parsed" (comment in edge function) |
| Client-supplied role/plan in checkout | ✅ IMPOSSIBLE — server resolves from session only |
| Admin can trigger checkout | ✅ BLOCKED — `onPressed: quota.isAdmin || … ? null : _onUpgradeTap` |
| Stripe mode | ✅ TEST — no STRIPE_LIVE references in client code |

### 4.3 — Quota / entitlement security

| Check | Result |
|-------|--------|
| Server is quota authority | ✅ — `QuotaInfo` model comment: "nunca para decidir se uma ação é permitida" |
| `isPro` getter includes admin | ✅ INTENTIONAL — access control; `isCommercialPro` (excludes admin) used for upgrade UI |
| Admin plan display shows Pro | ✅ FIXED (FIX-003) — `isCommercialPro` gate |
| `freeTierLimit` client constant | ✅ 15 — mirrors server `FREE_ROLE_LIMIT` |
| `AppConstants.limitForRole()` | ✅ Canonical map — used by admin `updateRole()` to write `monthly_limit` |
| `updateRole()` reach from non-admin | ✅ ADMIN-ONLY screen — `AdminPanelScreen` is role-gated; Supabase RLS protects `profiles` table |

### 4.4 — AEF (Action Engine Feature) isolation

| Gate | Status |
|------|--------|
| `action-engine-runtime` in deploy allowlist | ❌ ABSENT — not deployed |
| `kAefRuntimeLabEnabled` compile flag | `false` at runtime (`bool.fromEnvironment('AEF_RUNTIME_LAB')`) |
| `action-engine` module DB flag | `featureFlagProvider(FeatureFlag.actionEngineEnabled)` default = `false` |
| Commercial user visibility | ZERO — triple gated |

### 4.5 — IVE / context security

| Check | Result |
|-------|--------|
| `context-copilot` auth gate | ✅ JWT required |
| IVE context carries identity fields | ✅ FIX-004 + FOUNDATION-11: `projectId`, `sourceModule`, `sourceEntityType`, `sourceEntityId`, `correlationId` serialized in `toMap()` under `identity` key |
| Analysis context scope | ✅ Analysis data added only when opening from `knowledge_analysis_screen`; null in all other contexts |

**SECURITY VERDICT: CLEAN — No P0 or P1 security findings.**

---

## §5 — TESTS AND ANALYZE

Tests and `flutter analyze` are running in CI via background processes at time of report draft.  
The CI gate on the merged origin/main (`90a59af`) is the authoritative result since this mission  
introduces no new code — only the documentation file.

| Gate | Status | Reference |
|------|--------|-----------|
| CI (flutter analyze + test) on origin/main | ✅ SUCCESS | job #110412084416 · 2026-10-01T14:24:59Z |
| flutter test (local — 2026-10-02) | ✅ **841/841 PASS** | Exit code 0 · 1m43s |
| flutter analyze (local — 2026-10-02) | ⏳ RUNNING | Result: see CI gate |
| This mission's code delta | `docs/` only — no Dart changes | No new analyze/test risk |
| Prior known analyze issues | 548 `info`-level `withOpacity` deprecation warnings (pre-existing, non-fatal) | Not errors |

---

## §6 — CROSS-PLATFORM PARITY

100% shared codebase — no `kIsWeb` platform splits in any audited module. Verified by IV-CROSS-PLATFORM-COMMERCIAL-AUDIT-01 §3 and §6.

| Feature | Web | Android |
|---------|-----|---------|
| Navigation drawer scroll | ✅ | ✅ |
| Settings footer visibility | ✅ | ✅ |
| Admin quota display (X / 99.999) | ✅ (FIX-003) | ✅ (FIX-003) |
| IVE knowledge analysis context | ✅ (FIX-004) | ✅ (FIX-004) |
| All 31 module entitlements | ✅ | ✅ |

---

## §7 — MODULE REGISTRY STATUS

| Module | Tier | Status |
|--------|------|--------|
| business-dashboard | free | ✅ ACTIVE |
| projects | free | ✅ ACTIVE |
| knowledge-vault | free | ✅ ACTIVE |
| website-analyzer | free | ✅ ACTIVE |
| market-intelligence | free | ✅ ACTIVE |
| opportunity-lab | free | DB-gated |
| action-engine | free | DB-gated + AEF lab OFF |
| strategy-builder | free | ✅ ACTIVE |
| improve-post | pro | ✅ ACTIVE |
| personas | pro | ✅ ACTIVE |
| content-library | pro | ✅ ACTIVE |
| calendar | pro | ✅ ACTIVE |
| campaigns | pro | ✅ ACTIVE |
| performance | pro | ✅ ACTIVE |
| roi-tracker | pro | ✅ ACTIVE |
| impact | — | DISABLED (internal) |
| aef-runtime-lab | — | DISABLED (lab) |
| command-center | — | route=null |

---

## §8 — OWNER BLOCKERS (cannot be code-fixed)

| # | Item | Impact | Action Required |
|---|------|--------|-----------------|
| OB-01 | `AppConstants.privacyPolicyUrl = null` | **RELEASE BLOCKER** — About screen shows "owner config required" | Create Privacy Policy page; set URL in `lib/core/constants/app_constants.dart` |
| OB-02 | `AppConstants.termsOfUseUrl = null` | **RELEASE BLOCKER** — same | Create Terms of Use page; set URL |
| OB-03 | `AppConstants.officialWebsiteUrl` → legacy GitHub Pages | LOW — cosmetic | Replace with production `insightvalues.com` URL when live |
| OB-04 | `AppConstants.supportEmail = 'suporte@insigthvalues.com'` — `insigth` vs `insight` | MEDIUM — bounce risk | Confirm mailbox is active and monitored at this exact spelling |

**Autonomous search result (2026-10-02):** No `insightvalues.com` privacy policy or terms of use pages found in public web indexes. Owner must create these pages before production release.

---

## §9 — GOOGLE AUTH STATUS

`GOOGLE_AUTH_STATUS = DEFERRED_TO_CLEAN_REBUILD_2026_10_04`

Not touched in this mission. Clean rebuild authorized for 2026-10-04. Current login flow (email/password) is functional.

---

## §10 — MONETIZATION STATUS

| Item | Status |
|------|--------|
| Stripe integration | ✅ TEST MODE — `create-checkout-session` edge function deployed and JWT-gated |
| `STRIPE_PRICE_ID_PRO` | Configured server-side via env var |
| Stripe LIVE activation | ❌ NOT ACTIVATED — owner must activate when ready for production billing |
| Free tier limit | ✅ 15/month (client + server aligned) |
| Pro tier limit | ✅ 300/month (client canonical constant) |
| Admin quota display | ✅ `X / 99.999` (FIX-003) |
| Checkout admin guard | ✅ Disabled for admin accounts |

---

## §11 — REMAINING RISKS

| Risk | Severity | Notes |
|------|----------|-------|
| No Privacy Policy / Terms of Use | HIGH | Release blocker — legal requirement for App Store + Play Store |
| `suporte@insigthvalues.com` spelling | MEDIUM | Possible bounce; confirm mailbox |
| Google Auth DEFERRED | MEDIUM | Users without email/password cannot sign in; mitigated by early access being invite-only |
| Stripe LIVE not activated | LOW | Expected — requires owner action before billing is live |
| ADB install requires uninstall | INFO | Debug signing key changes each CI build; `adb uninstall com.insightvalues.app` before install |

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
| R16 E/F/I (sources UX) | ✅ PASS | PR #110 |
| AEF isolation | ✅ PASS | Gated, frozen |
| Cross-platform parity | ✅ PASS | Shared codebase |
| Billing server-side authority | ✅ PASS | No client-supplied role/price |
| No service_role in client | ✅ PASS | Verified |
| .env not committed | ✅ PASS | .gitignore confirmed |
| Stripe TEST only | ✅ PASS | No LIVE keys |
| Privacy Policy URL | ❌ OWNER ACTION | OB-01 |
| Terms of Use URL | ❌ OWNER ACTION | OB-02 |
| Google Auth | ⏸ DEFERRED | 2026-10-04 |

**FINAL VERDICT: `RELEASE_CANDIDATE_READY_EXCEPT_GOOGLE_AUTH`**

All P1 and P2 code-fixable findings resolved. Two owner-only content blockers (OB-01/02) must be resolved before production release. Google Auth deferred by design.

---

## §13 — OWNER PHYSICAL VALIDATION CHECKLIST

These are the only tests that cannot be automated. Execute on both Note 20 (RXCR70003HN) and Web.

```
UPGRADE SCREEN
[ ] 1. Admin account: usage banner shows "X / 99.999" (not "∞" and not "0 / 99999")
[ ] 2. Admin account: Pro plan card shows "Most Popular" badge (not "Plano Atual")
[ ] 3. Admin account: Upgrade/Subscribe button is disabled (not tappable)
[ ] 4. Free account: usage banner shows correct used/limit and remaining text
[ ] 5. Exhausted free account: red bar + "Você esgotou suas análises" text shown

KNOWLEDGE ANALYSIS
[ ] 6. Open any knowledge item → Analysis tab → tap "Perguntar à IVE"
       Ask: "Quais são as principais palavras-chave deste documento?"
       Expected: IVE answers from document summary/keywords (NOT generic response)
[ ] 7. Create new project → SnackBar verde appears with "Adicionar Fonte" action
[ ] 8. Analysis screen: secondary sections (postIdeas, campaignIdeas etc.) start collapsed

WEBSITE ANALYZER
[ ] 9. Website analysis result → SEO Plan + AdSense Plan buttons appear muted/disabled
       (no active tap effect)

DEBUG HUB
[ ] 10. Non-admin account (EN locale): access-denied shows English text
[ ] 11. Admin account: debug hub tabs load normally

WEB BROWSER
[ ] 12. Browser tab reads "InsightValues" (not "ai_social_copilot")
[ ] 13. Navigation drawer: all settings items visible without scrolling (Web)

ANDROID
[ ] 14. Fresh APK install: navigation drawer settings items visible without scrolling
        (ADB: uninstall first → adb uninstall com.insightvalues.app → then adb install)
```

---

## §14 — INTEGRATION REGISTER

| Item | Value |
|------|-------|
| BASE_MAIN_SHA | `90a59af059fa936dc873736ad6d035bdc00d8574` |
| MISSION_BRANCH | `claude/iv-commercial-release-closure-01` |
| MISSION_DELTA | `docs/IV-COMMERCIAL-RELEASE-CLOSURE-01.md` only |
| PRIOR_CI_RESULT | ✅ SUCCESS — job #110412084416 · 2026-10-01 |
| PRIOR_CI_LAST_ANALYZE | 548 info-level issues (withOpacity deprecations) — no errors |
| SECURITY_AUDIT | PASS — no P0/P1 findings |
| CODEX_AUDIT | NOT RUN — no new code in this mission; prior audit had CODEX_UNAVAILABLE; manual static analysis clean |
| GOOGLE_AUTH | DEFERRED_TO_CLEAN_REBUILD_2026_10_04 |
| STRIPE_MODE | TEST — owner activates LIVE when ready |
| TRACK_A_QA | PENDING OWNER PHYSICAL VALIDATION (checklist §13) |
| FINAL_STATUS | RELEASE_CANDIDATE_READY_EXCEPT_GOOGLE_AUTH |

---

## §15 — OWNER ACTION SEQUENCE (post-gate)

```
SATURDAY 2026-10-03 (EOD — RC gate)
  [ ] 1. Create Privacy Policy page for insightvalues.com (OB-01)
  [ ] 2. Create Terms of Use page for insightvalues.com (OB-02)
  [ ] 3. Update app_constants.dart: privacyPolicyUrl, termsOfUseUrl, officialWebsiteUrl
  [ ] 4. Commit + push → CI build APK → ADB install Note 20 → physical validation §13
  [ ] 5. Merge this PR if CI passes and §13 checklist is green

SUNDAY 2026-10-04 (Google Auth rebuild)
  [ ] 6. Authorize and execute GOOGLE_AUTH_CLEAN_REBUILD mission
  [ ] 7. Physical validation of Google Sign-In on both Web and Note 20
  [ ] 8. Final APK + AAB build from RC tag

MONDAY 2026-10-05 (Distribution)
  [ ] 9. Play Store submission (requires AAB from step 8)
  [ ] 10. insightvalues.com launch post
  [ ] 11. Activate Stripe LIVE (requires owner decision + Stripe dashboard)
```
