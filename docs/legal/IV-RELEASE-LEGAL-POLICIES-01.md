# IV-RELEASE-LEGAL-POLICIES-01 — Mission Tracker

**Branch:** `claude/iv-release-legal-policies-01`  
**Date started:** 2026-10-03  
**Executor:** Claude Sonnet 4.6  
**Auditor:** Codex (READ-ONLY, pending invocation)  
**Owner:** Paulo Martins

---

## Discovery Summary

**Product audited:** InsightValues App (Flutter) + insightvalues.com (WordPress)  
**Backend:** Supabase (PostgreSQL + RLS + Auth + Storage)  
**AI Provider:** Groq exclusively (model: openai/gpt-oss-120b, server-side via Edge Functions)  
**Payments:** Stripe (subscription billing)  
**Auth:** Supabase Auth — email/password + Google OAuth  
**Analytics/Telemetry:** NONE (no Firebase, Amplitude, Mixpanel, Sentry, etc.)  
**Crash reporting:** NONE  
**Admin-only features:** Quant Lab, Impact Lab (not publicly released)  
**Account deletion:** NOT IMPLEMENTED (gap identified)

---

## Documents Created

| Document | Path | Status |
|----------|------|--------|
| Privacy Policy (EN) | docs/legal/PRIVACY_POLICY_EN.md | ✅ COMPLETE |
| Privacy Policy (PT-BR) | docs/legal/PRIVACY_POLICY_PT_BR.md | ✅ COMPLETE |
| Terms of Use (EN) | docs/legal/TERMS_OF_USE_EN.md | ✅ COMPLETE |
| Terms of Use (PT-BR) | docs/legal/TERMS_OF_USE_PT_BR.md | ✅ COMPLETE |
| Data Safety Matrix | docs/legal/DATA_SAFETY_MATRIX.md | ✅ COMPLETE |
| Google Play Requirements | docs/legal/GOOGLE_PLAY_POLICY_REQUIREMENTS.md | ✅ COMPLETE |
| Third-Party Processors | docs/legal/THIRD_PARTY_PROCESSORS.md | ✅ COMPLETE |
| Account Deletion | docs/legal/ACCOUNT_DELETION.md | ✅ COMPLETE (gap documented) |

---

## Owner Legal Decision Required

These items are marked OWNER_LEGAL_DECISION_REQUIRED in the policy documents and must be resolved before public release:

| # | Item | Impact |
|---|------|--------|
| OLEG-01 | Formal legal entity name, registration, and jurisdiction | Affects governing law, LGPD compliance, Terms of Use Section 20 |
| OLEG-02 | Governing law and dispute resolution forum | Terms of Use Section 20 |
| OLEG-03 | LGPD legal basis for data processing (if Brazilian users are targeted) | Privacy Policy Sections 10, 13 |
| OLEG-04 | LGPD Data Protection Officer (Encarregado) designation | Privacy Policy Section 13 |
| OLEG-05 | Refund policy | Terms of Use Section 11.4 |

These items do not block publishing the policies or resolving OB-01/OB-02, but must be addressed before the product is commercially promoted to users.

---

## Gap: Account Deletion (GP-04)

```
ACCOUNT_DELETION_FLOW_REQUIRED

Google Play requires: apps that need account creation must offer
in-app deletion OR link to an external deletion page.

Current state: Only "Sign Out" exists. No deletion flow.

Minimum fix (Option A — no code change required initially):
  1. Owner creates insightvalues.com/delete-account/ page with email form
  2. Claude adds accountDeletionUrl constant + link in Account screen
  3. Owner manually processes requests via Supabase Auth Console

BLOCKED_OWNER: Option A requires owner to create the page first.
```

---

## Site Publication Status

| Page | URL | Status |
|------|-----|--------|
| Privacy Policy (EN) | https://insightvalues.com/en/privacy-policy/ | ⏳ PENDING — not yet published |
| Privacy Policy (PT) | https://insightvalues.com/politica-de-privacidade/ | ⏳ PENDING — not yet published |
| Terms of Use (EN) | https://insightvalues.com/en/terms-of-use/ | ⏳ PENDING — not yet published |
| Terms of Use (PT) | https://insightvalues.com/termos-de-uso/ | ⏳ PENDING — not yet published |

---

## app_constants.dart Status

| Constant | Current value | Target value | Status |
|----------|--------------|--------------|--------|
| privacyPolicyUrl | null | https://insightvalues.com/en/privacy-policy/ | ⏳ PENDING — awaiting site publication |
| termsOfUseUrl | null | https://insightvalues.com/en/terms-of-use/ | ⏳ PENDING — awaiting site publication |

---

## Codex Review Status

⏳ PENDING — to be invoked after site publication and app_constants update

---

## Final Gate Checklist

| Item | Status |
|------|--------|
| PRIVACY_POLICY_EN | ✅ WRITTEN |
| PRIVACY_POLICY_PT | ✅ WRITTEN |
| TERMS_EN | ✅ WRITTEN |
| TERMS_PT | ✅ WRITTEN |
| GOOGLE_PLAY_REQUIREMENTS | ✅ COMPLETE |
| DATA_SAFETY | ✅ COMPLETE |
| ACCOUNT_DELETION | ⚠️ GAP DOCUMENTED — BLOCKED_OWNER |
| PROCESSORS | ✅ COMPLETE |
| QUANT_DISCLOSURE | ✅ IN TERMS_EN + TERMS_PT (Section 9) |
| IMPACT_DISCLOSURE | ✅ IN TERMS_EN + TERMS_PT (Section 10) |
| SITE_PUBLISHED | ⏳ PENDING |
| APP_CONSTANTS | ⏳ PENDING (awaiting site URLs) |
| WEB_PHYSICAL | ⏳ PENDING |
| ANDROID_PHYSICAL | ⏳ PENDING |
| PT | ✅ WRITTEN |
| EN | ✅ WRITTEN |
| CODEX | ⏳ PENDING |
| OB-01 | ⏳ PENDING — awaiting site publication + app_constants |
| OB-02 | ⏳ PENDING — awaiting site publication + app_constants |

---

## Current Verdict

```
CONDITIONAL_PASS — awaiting site publication + app_constants update

Documents: COMPLETE
Site publication: PENDING (requires WordPress access)
App constants: PENDING (after URLs confirmed)
Owner legal decisions: 5 items outstanding (do not block OB-01/OB-02)
Account deletion: BLOCKED_OWNER
```
