# Android Store Package — InsightValues
## IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D1

> **STATUS:** SUBMISSION_BLOCKED — see EXTERNAL_RELEASE_GATES below.
> All fields below are pre-configured or owner-gated. No field may be altered
> without explicit authorization from Paulo + Agente Martins.

---

## Application IDs (Package Names)

| Product | applicationId |
|---------|---------------|
| Core    | com.insightvalues.core |
| Impact  | com.insightvalues.impact |
| Quant   | com.insightvalues.quant |

Each applicationId maps to a **separate Play Store listing**.

---

## Display Names

| Product | App Name |
|---------|----------|
| Core    | InsightValues |
| Impact  | InsightValues Impact |
| Quant   | InsightValues Quant |

---

## Version Catalog

Source of truth: `android/app/version_catalog.properties`

| Product | versionCode | versionName |
|---------|-------------|-------------|
| Core    | 1           | 1.0.0       |
| Impact  | 1           | 1.0.0       |
| Quant   | 1           | 1.0.0       |

**Rules:**
- versionCode must be monotonically increasing per product (independent sequences)
- versionName follows MAJOR.MINOR.PATCH (semver)
- Update ONLY via `version_catalog.properties` — Gradle reads it at build time
- Never reuse a versionCode once submitted to Play Console

---

## Target SDK / Min SDK

| Field | Value |
|-------|-------|
| compileSdk | `flutter.compileSdkVersion` (resolved at build) |
| minSdk | `flutter.minSdkVersion` |
| targetSdk | `flutter.targetSdkVersion` |

---

## Permissions

Declared in `android/app/src/main/AndroidManifest.xml`.
Review before submission — no new permissions without AM+Paulo gate.

| Permission | Reason |
|------------|--------|
| INTERNET | Core network connectivity |
| WAKE_LOCK | Background sync (if any) |

*Additional permissions added by plugins are inherited automatically. Run
`flutter build apk --debug --flavor core` and inspect the merged manifest.*

---

## Deep Links (Android App Links)

| Product | Scheme | Host | autoVerify |
|---------|--------|------|------------|
| Core    | insightvalues | core   | false until GATE-EXT-3 |
| Impact  | insightvalues | impact | false until GATE-EXT-3 |
| Quant   | insightvalues | quant  | false until GATE-EXT-3 |

Template: `android/.well-known/assetlinks.template.json`
Verification script: `scripts/verify_assetlinks.ps1`

**GATE-EXT-3:** Deploy assetlinks.json to insightvalues.com/.well-known/ before
enabling autoVerify. Use real keystore SHA256 fingerprints (not placeholders).

---

## In-App Products (Mobile Billing)

| Description | productId | Platform | Status |
|-------------|-----------|----------|--------|
| Core — Pro Monthly     | OWNER_INPUT_REQUIRED | both | BLOCKED_OWNER |
| Impact — Monthly       | OWNER_INPUT_REQUIRED | both | BLOCKED_OWNER |
| Quant — Monthly        | OWNER_INPUT_REQUIRED | both | BLOCKED_OWNER |
| Suite — All Monthly    | OWNER_INPUT_REQUIRED | both | BLOCKED_OWNER |

**GATE-EXT-6:** Create apps in Play Console, create in-app products, then update
`lib/mobile/billing/mobile_product_catalog.dart` with real product IDs.

---

## Firebase (Google Services)

| Product | Config File | Status |
|---------|-------------|--------|
| Core    | android/app/src/core/google-services.json   | BLOCKED_OWNER |
| Impact  | android/app/src/impact/google-services.json | BLOCKED_OWNER |
| Quant   | android/app/src/quant/google-services.json  | BLOCKED_OWNER |

**GATE-EXT-2:** Create one Firebase project per applicationId, download
google-services.json, place in the per-flavor source directory.

---

## Release Signing (PLAY-READINESS-18)

- Keystore managed by Owner only (never committed to git)
- `android/key.properties` must exist at release build time with:
  - `keyAlias`, `keyPassword`, `storeFile`, `storePassword`
- Fail-closed: `assembleRelease`/`bundleRelease` throws `GradleException` if
  key.properties is absent or incomplete

**GATE-EXT-1:** Owner must generate keystore, configure `android/key.properties`,
and rotate KEYSTORE_* secrets before Play Store submission.

---

## Content Rating

Must be completed in Play Console for each app before submission:
- Fill out the Rating Questionnaire (IARC)
- Select the appropriate maturity level for a business analytics/investment app
- Declare no objectionable content, violence, or age-restricted features

---

## Data Safety Declaration

Required for each Play Store listing. Pre-filled answers (verify before
submission):

| Data type | Collected? | Shared? | Required? | Notes |
|-----------|-----------|---------|-----------|-------|
| Account info (email) | Yes | No | Yes | Authentication |
| Financial info | No | No | — | No payment data stored on device |
| App activity | Yes | No | No | Feature usage analytics |
| App info and performance | Yes | No | No | Crash reporting |

---

## Store Descriptions

### Short Description (80 chars max)

| Product | Short Description |
|---------|-------------------|
| Core    | AI-powered business intelligence for entrepreneurs |
| Impact  | ESG impact investment analysis and insights |
| Quant   | Quantitative analysis tools for investors |

### Full Descriptions

#### InsightValues Core

InsightValues is an AI-powered business intelligence platform designed for entrepreneurs and business owners. Get instant market analysis, competitor insights, strategic recommendations, and content generation to grow your business faster.

**Key Features:**
- Market intelligence and competitor analysis
- AI strategy generation and gap analysis
- Content calendar and campaign planner
- Business dashboard and KPI tracking
- Opportunity discovery and niche research

#### InsightValues Impact

InsightValues Impact brings ESG (Environmental, Social, Governance) investment analysis to professional investors. Evaluate companies through multiple sustainability lenses and build impact-focused portfolios with confidence.

**Key Features:**
- ESG scoring and impact metrics
- Company investigation and verification
- Portfolio monitoring and alerts
- Impact dossier generation
- Cross-sector comparison tools

#### InsightValues Quant

InsightValues Quant provides quantitative analysis capabilities for data-driven investors. Upload datasets, run analysis, manage watchlists, and get AI-powered insights on your investment universe.

**Key Features:**
- Quantitative data analysis (CSV/Excel)
- Watchlist management with real-time data
- AI research assistant for investment ideas
- Risk-adjusted performance metrics
- Export-ready analytical reports

---

## App Icon

- Size: 512×512 px PNG (no alpha)
- Source: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- Per-flavor branding: `android/app/src/<flavor>/res/` (if any)

---

## Screenshots (Required per listing)

Minimum 2, maximum 8 per device type.
Required device types: phone. Tablet optional.

| Device | Size |
|--------|------|
| Phone | 1080×1920 or 1440×2560 (portrait) |

**NOTE:** Screenshots must be captured with OWNER_INPUT_REQUIRED product IDs
replaced (GATE-EXT-6) and Firebase configured (GATE-EXT-2) to show real UI.

---

## EXTERNAL_RELEASE_GATES (blocking submission)

| Gate | Description | Owner Action |
|------|-------------|--------------|
| GATE-EXT-1 | Keystore / signing configuration | Generate keystore, configure key.properties |
| GATE-EXT-2 | Firebase 3 projects | Create one per applicationId in Firebase Console |
| GATE-EXT-3 | assetlinks.json deploy | Deploy to insightvalues.com/.well-known/ |
| GATE-EXT-4 | autoVerify flip | After GATE-EXT-3: set autoVerify="true" in manifests |
| GATE-EXT-6 | Play Console 3 apps | Create 3 apps, configure in-app products |
| GATE-B-1..3 | Backend migrations + EF deploy | 12-step bundle, AM+Paulo gate |
