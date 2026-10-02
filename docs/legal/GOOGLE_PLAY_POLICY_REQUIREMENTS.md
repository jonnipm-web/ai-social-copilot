# InsightValues — Google Play Policy Requirements

**Mission:** IV-RELEASE-LEGAL-POLICIES-01  
**Status as of:** 2026-10-03  
**Auditor:** Claude Sonnet 4.6

---

## Requirements Matrix

| # | Requirement | Source | Current Compliance | Gap | Action |
|---|-------------|--------|--------------------|-----|--------|
| GP-01 | Privacy Policy required for apps that collect personal data | Google Play Developer Policy Center — Privacy, Security, and Deception | ❌ NOT MET — no URL configured | OB-01: `privacyPolicyUrl = null` | Create and publish Privacy Policy; add URL to app_constants.dart |
| GP-02 | Privacy Policy must be on a live, non-gated URL accessible to anyone | Play Policy Center | ❌ NOT MET | No page exists yet | Publish to insightvalues.com without login gate |
| GP-03 | Data Safety form must be completed in Google Play Console | Data Safety section | ❌ NOT SUBMITTED | No submission yet | Complete using DATA_SAFETY_MATRIX.md after OB-01/OB-02 resolved |
| GP-04 | Apps requiring account creation must offer in-app or linked account deletion | Account Deletion policy (https://support.google.com/googleplay/android-developer/answer/13327111) | ❌ NOT MET | No deletion flow or link | Implement Option A or B per ACCOUNT_DELETION.md — BLOCKED_OWNER |
| GP-05 | Terms of Service / Terms of Use recommended for paid features | Play Policy — Payments | ❌ NOT MET | OB-02: `termsOfUseUrl = null` | Create and publish Terms of Use; add URL to app_constants.dart |
| GP-06 | Prominent disclosure of any data collection that is not obvious to user | Prominent Disclosure guidelines | ⚠️ PARTIAL | No prominent disclosure UI for AI data processing | Add disclosure to onboarding or in IVE intro (low priority, current disclosure in policies is sufficient for initial release) |
| GP-07 | No deceptive behavior or misleading claims | Play Policy — Deception | ✅ MET | No deceptive claims found | Maintain |
| GP-08 | App must not collect, use, or share user data in ways the user hasn't consented to | User Data policy | ✅ MET (server-side AI processing disclosed in policies) | — | Maintain via accurate policies |
| GP-09 | AI-generated content disclosure for AI features | Play Policy — Generative AI (emerging) | ✅ PARTIAL — IVE branding communicates AI nature | Policies should state AI output limitations | Include in Privacy Policy + Terms of Use (addressed in IV-RELEASE-LEGAL-POLICIES-01) |
| GP-10 | Financial products/services: additional disclosures | Financial Services policy | ⚠️ WATCH | Quant Lab and Strategy Lab contain financial analysis features (admin-only currently) | Quant and Strategy disclaimers must be included in Terms — see TERMS_OF_USE_EN.md Section 12 |
| GP-11 | Subscription terms must be clearly disclosed before purchase | Play Billing policy | ✅ MET | Upgrade screen shows plan/price before Stripe checkout | Maintain |
| GP-12 | No sharing of data with third parties for advertising | — | ✅ MET | No advertising SDK or data sharing for ads | Maintain |
| GP-13 | COPPA / children's content | Families policy | ✅ NOT APPLICABLE | App is for business users (adults), not designed for children | Maintain — state minimum age (18) in Terms |
| GP-14 | Health/sensitive data: not collected | — | ✅ MET | No health data collected | Maintain |

---

## Priority Actions Before Google Play Submission

```
CRITICAL (blocks submission):
  GP-01: Publish Privacy Policy → update app_constants.dart privacyPolicyUrl
  GP-05: Publish Terms of Use → update app_constants.dart termsOfUseUrl
  GP-03: Complete Data Safety form in Google Play Console (owner action)
  GP-04: Account deletion flow — BLOCKED_OWNER (minimum: Option A email form)

IMPORTANT:
  GP-10: Quant/Strategy disclaimers in Terms of Use (addressed in this mission)

LOWER PRIORITY:
  GP-06: Prominent disclosure — acceptable for initial release if policies are accurate
```

---

## Sources Consulted

- Google Play Developer Policy Center: https://play.google.com/about/developer-content-policy/
- Data Safety requirements: https://support.google.com/googleplay/android-developer/answer/10787469
- Account Deletion requirement: https://support.google.com/googleplay/android-developer/answer/13327111
- Families Policy: https://play.google.com/about/families/
- Financial Services Policy: https://play.google.com/about/monetization-ads/

*Policy requirements change. Owner must verify against current Google Play Policy before submission.*
