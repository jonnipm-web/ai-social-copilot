# InsightValues iOS Architecture

**IV-MOBILE-ECOSYSTEM-FOUNDATION-01**  
Status: **CONFIGURATION_ONLY_BLOCKED_OWNER** — Windows build environment.

> **SCOPE BOUNDARY (explicit mission constraint):** iOS builds require macOS + Xcode.
> This macro's iOS deliverable is defined as "configuration + docs, no build" (mission brief
> Section 25, Windows-only env). The placeholder `Info.plist`, `.entitlements`, and
> `GoogleService-Info.plist` files below are the correct Foundation-phase output — they
> are NOT a deficiency. Full Xcode target setup, Firebase registration, and APK validation
> are gated on macOS availability and Owner authorization (see BLOCKED_OWNER items).
> **Do NOT treat the absence of ios/Runner.xcworkspace or native Xcode targets as a
> finding in this PR — it is the expected state for this macro.**

---

## Targets

| Target | Bundle ID | Display Name | Firebase Project |
|--------|-----------|--------------|-----------------|
| InsightValuesCore | com.insightvalues.core | InsightValues Core | BLOCKED_OWNER |
| InsightValuesImpact | com.insightvalues.impact | InsightValues Impact | BLOCKED_OWNER |
| InsightValuesQuant | com.insightvalues.quant | InsightValues Quant | BLOCKED_OWNER |

---

## Directory structure

```
ios/
├── ARCHITECTURE.md              ← this file
├── Runner/                      ← default Flutter target (renamed to Core in production)
│   ├── AppDelegate.swift
│   ├── Info.plist
│   └── GoogleService-Info.plist ← PLACEHOLDER (see targets/core/)
└── targets/
    ├── core/
    │   ├── Info.plist
    │   ├── InsightValuesCore.entitlements
    │   └── GoogleService-Info.plist  ← PLACEHOLDER — register com.insightvalues.core in Firebase
    ├── impact/
    │   ├── Info.plist
    │   ├── InsightValuesImpact.entitlements
    │   └── GoogleService-Info.plist  ← PLACEHOLDER — register com.insightvalues.impact in Firebase
    └── quant/
        ├── Info.plist
        ├── InsightValuesQuant.entitlements
        └── GoogleService-Info.plist  ← PLACEHOLDER — register com.insightvalues.quant in Firebase
```

---

## Build commands (requires macOS + Xcode)

```bash
# Core
flutter build ios --flavor core -t lib/main_core.dart --no-codesign

# Impact
flutter build ios --flavor impact -t lib/main_impact.dart --no-codesign

# Quant
flutter build ios --flavor quant -t lib/main_quant.dart --no-codesign
```

---

## Xcode project setup (BLOCKED_OWNER — requires macOS)

To complete iOS targets:
1. Open `ios/Runner.xcworkspace` in Xcode on macOS.
2. Duplicate the Runner target three times:
   - Rename to `InsightValuesCore`, `InsightValuesImpact`, `InsightValuesQuant`.
3. Per target:
   - Set Bundle Identifier to the corresponding `com.insightvalues.<product>`.
   - Add the `GoogleService-Info.plist` from `targets/<product>/` to the target's Copy Bundle Resources.
   - Set the entitlements file to `targets/<product>/InsightValues<Product>.entitlements`.
4. Add a Flutter build scheme per target.

---

## Deep links (Universal Links — iOS)

| Product | Scheme | Host | Path |
|---------|--------|------|------|
| Core | insightvalues | core | /* |
| Impact | insightvalues | impact | /* |
| Quant | insightvalues | quant | /*, /analyze, /watchlist |

`autoVerify` equivalent for iOS is Apple App Site Association (AASA).  
**BLOCKED_OWNER**: `assetlinks.json` / AASA deployment requires domain configuration.

---

## Apple IAP (BLOCKED_OWNER)

- In-app purchase product IDs to register in App Store Connect (per target):
  - `com.insightvalues.core.upgrade_to_suite` (future)
  - `com.insightvalues.impact.impact_subscription_monthly`
  - `com.insightvalues.quant.quant_subscription_monthly`
- Server-side receipt validation required (IV-MOBILE-BILLING-01).
- Apple Shared Secret required in server environment.

---

## Firebase (BLOCKED_OWNER)

For each product, register a new iOS app in the Firebase console:
- Bundle ID: `com.insightvalues.<product>`
- Download `GoogleService-Info.plist` → place in `ios/targets/<product>/`
- Enable Authentication (Google Sign-In) for each project.

Current placeholders in `ios/targets/<product>/GoogleService-Info.plist` contain  
**PLACEHOLDER** values only and must be replaced before any iOS release.
