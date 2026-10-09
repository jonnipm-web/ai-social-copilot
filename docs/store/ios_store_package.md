# iOS Store Package — InsightValues
## IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — D8

> **STATUS:** SUBMISSION_BLOCKED — iOS builds require macOS/Xcode environment.
> All fields below are pre-configured or owner-gated. See EXTERNAL_RELEASE_GATES.

---

## Bundle Identifiers

| Product | Bundle ID |
|---------|-----------|
| Core    | com.insightvalues.core |
| Impact  | com.insightvalues.impact |
| Quant   | com.insightvalues.quant |

Each bundle ID maps to a **separate App Store Connect listing**.

---

## Display Names

| Product | App Name |
|---------|----------|
| Core    | InsightValues |
| Impact  | InsightValues Impact |
| Quant   | InsightValues Quant |

---

## Version

| Field | Value |
|-------|-------|
| CFBundleShortVersionString | 1.0.0 |
| CFBundleVersion | 1 |

Both fields managed via `pubspec.yaml` version and Flutter's iOS build bridge.
Match `version_catalog.properties` versionName and versionCode respectively.

---

## iOS Targets

| Product | Info.plist | Status |
|---------|-----------|--------|
| Core    | ios/targets/core/Info.plist   | Configured (GIDClientID = PLACEHOLDER) |
| Impact  | ios/targets/impact/Info.plist | Requires creation |
| Quant   | ios/targets/quant/Info.plist  | Requires creation |

**GATE-EXT-5:** Full iOS target configuration requires macOS/Xcode. Dart
abstraction layer (billing adapters, route policy) is complete and tested.

---

## URL Schemes (Deep Links)

| Product | Scheme | Notes |
|---------|--------|-------|
| Core    | insightvalues-core   | CFBundleURLSchemes in Info.plist |
| Impact  | insightvalues-impact | CFBundleURLSchemes in Info.plist |
| Quant   | insightvalues-quant  | CFBundleURLSchemes in Info.plist |

Cross-product deep link isolation is enforced at the Dart route layer
(`lib/core/modules/route_policy.dart`) and tested in D4 tests.

---

## Firebase (Google Services)

| Product | Config File | Status |
|---------|-------------|--------|
| Core    | ios/targets/core/GoogleService-Info.plist   | PLACEHOLDER_CLIENT_ID |
| Impact  | ios/targets/impact/GoogleService-Info.plist | BLOCKED_OWNER |
| Quant   | ios/targets/quant/GoogleService-Info.plist  | BLOCKED_OWNER |

**GATE-EXT-2:** Create one Firebase project per bundle ID, download
GoogleService-Info.plist, place in per-target directory.

---

## In-App Purchases (Apple IAP)

| Description | productId | Status |
|-------------|-----------|--------|
| Core — Pro Monthly  | OWNER_INPUT_REQUIRED | BLOCKED_OWNER |
| Impact — Monthly    | OWNER_INPUT_REQUIRED | BLOCKED_OWNER |
| Quant — Monthly     | OWNER_INPUT_REQUIRED | BLOCKED_OWNER |
| Suite — All Monthly | OWNER_INPUT_REQUIRED | BLOCKED_OWNER |

**GATE-EXT-7:** Create apps in App Store Connect, create in-app purchases,
then update `lib/mobile/billing/mobile_product_catalog.dart` with real product IDs.

**ACTIVATION GATE:** Set `APPLE_SHARED_SECRET` in Supabase Vault and
`MOBILE_BILLING_ACTIVE=true` in Edge Function secrets (requires AM+Paulo).

---

## App Review Notes

For each product listing in App Store Connect, include reviewer notes:
- Demo account credentials (if applicable)
- Steps to access key features
- Note that some features require sign-up (Supabase auth)
- Note that in-app purchases are subscriptions, not consumables

---

## Privacy Policy and Terms of Service URLs

**REQUIRED** before App Store submission (Apple enforces this):

| URL | Status |
|-----|--------|
| Privacy Policy | BLOCKED_OWNER — must be live at insightvalues.com |
| Terms of Service | BLOCKED_OWNER — must be live at insightvalues.com |

Related: IV-WEB-LEGAL-01 (PR #116, open).

---

## App Store Categories

| Product | Primary Category | Secondary Category |
|---------|-----------------|-------------------|
| Core    | Business | Productivity |
| Impact  | Finance  | Business |
| Quant   | Finance  | Business |

---

## Store Descriptions

### Subtitle (30 chars max)

| Product | Subtitle |
|---------|----------|
| Core    | AI Business Intelligence |
| Impact  | ESG Investment Analysis |
| Quant   | Quantitative Investor Tools |

### Short Description / Promotional Text (170 chars)

| Product | Promo Text |
|---------|-----------|
| Core    | Transform your business strategy with AI-powered market intelligence, competitor analysis, and personalized growth recommendations. |
| Impact  | Evaluate ESG impact with institutional-grade metrics. Research, verify, and monitor impact investments with confidence. |
| Quant   | Run quantitative analysis on your investment data. Upload CSVs, build watchlists, and get AI-powered research on demand. |

### Full Descriptions (same as Android — see android_store_package.md)

---

## App Icon

- Size: 1024×1024 px PNG (no alpha, no rounded corners — App Store adds them)
- Source: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

---

## Screenshots

| Device | Size |
|--------|------|
| iPhone 6.7" (required) | 1290×2796 |
| iPhone 6.5" (required) | 1242×2688 |
| iPad Pro 12.9" (optional) | 2048×2732 |

**NOTE:** Screenshots require physical device or Simulator with iOS + macOS/Xcode
(GATE-EXT-5).

---

## Age Rating

Content Rating: **4+** (no objectionable content for a business/finance app).

---

## Data Collection (App Privacy)

Required in App Store Connect. Pre-filled:

| Data Type | Collected? | Used for Tracking? | Notes |
|-----------|-----------|-------------------|-------|
| Contact Info (email) | Yes | No | Auth/account |
| Identifiers (User ID) | Yes | No | Internal only |
| Usage Data | Yes | No | Analytics |
| Crash Data | Yes | No | Debugging |
| Financial Info | No | — | No card/payment data on device |

---

## iOS Build Requirements (GATE-EXT-5)

Full iOS build requires:
1. macOS with Xcode 15+
2. Apple Developer Program membership (paid)
3. Distribution certificate + provisioning profile per bundle ID
4. `flutter build ipa --flavor core -t lib/main_core.dart`
5. Upload via Transporter or Xcode Organizer

**The Dart abstraction layer (billing providers, route policy, entitlement
resolver) is complete, tested, and platform-agnostic. Only the Xcode build
step and signing are blocked.**

---

## EXTERNAL_RELEASE_GATES (blocking iOS submission)

| Gate | Description | Owner Action |
|------|-------------|--------------|
| GATE-EXT-2 | Firebase 3 projects | Create one per bundle ID, download GoogleService-Info.plist |
| GATE-EXT-5 | iOS build on macOS/Xcode | Requires Mac with Xcode 15+, Apple Developer account |
| GATE-EXT-7 | App Store Connect 3 apps | Create 3 apps, configure in-app purchases |
| GATE-B-1..3 | Backend migrations + EF deploy | 12-step bundle, AM+Paulo gate |
| Legal URLs | Privacy Policy + ToS live | PR #116 must be merged and deployed |
