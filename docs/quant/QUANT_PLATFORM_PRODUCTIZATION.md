# Quant Platform Productization

**Mission:** IV-QUANT-MACRO-05 FASE 22–26  
**Status date:** 2026-10-04  
**Status:** DESIGN — not yet implemented  
**Decision authority:** Agente Martins + Paulo

---

## 1. Current Platform State

The `/quant` route (`QuantScreen`) is a Flutter widget that compiles for all
targets (Android, iOS, Web) without platform-specific code. No deep links,
push notifications, or platform channels are used.

---

## 2. Android (FASE 22)

### Deep links
- Intent filter for `https://app.insightvalues.com/quant` and
  `https://app.insightvalues.com/quant/*`
- `AndroidManifest.xml` `<intent-filter>` with `autoVerify="true"`
- Requires Digital Asset Links file at `/.well-known/assetlinks.json`
- **Status:** NOT YET IMPLEMENTED — requires domain configuration by Paulo

### App links for watchlist sharing
- Pattern: `insightvalues://quant/watchlist/{id}`
- Custom URI scheme fallback for older Android
- **Status:** DESIGN ONLY — authorisation required

### Gradle / build
- No new Gradle dependencies required for the pilot shell
- When real-time data is added: consider `WorkManager` for background refresh

---

## 3. iOS (FASE 23)

### Universal links
- Associated Domains entitlement: `applinks:app.insightvalues.com`
- `apple-app-site-association` file at `/.well-known/apple-app-site-association`
- **Status:** NOT YET IMPLEMENTED — requires Paulo to configure Apple Developer account

### App Clip (future)
- Quant summary view as an App Clip for sharing watchlist snapshots
- **Status:** NOT YET DESIGNED — requires commercial authorisation

---

## 4. Web (FASE 24)

### URL structure
- `/quant` → `QuantScreen` (already wired in GoRouter)
- `/quant/watchlist/{id}` → watchlist detail (future)
- PWA: no special changes needed; Flutter web already supports it

### CSP / security headers
- No new external resources introduced by the pilot shell
- When Databento real data is added: server-to-server only (Edge Function);
  no client-side calls to Databento ever

### SEO / crawlability
- Quant routes should remain `noindex` until commercial launch
- Existing `NOINDEX` meta tag strategy applies

---

## 5. Cross-Platform Disclaimer

The `QuantDisclaimerBanner` widget renders identically across Android, iOS,
and Web. No platform-specific disclaimer variant is needed for the pilot.

---

## 6. Pre-requisites Before Platform Activation

| # | Pre-requisite | Owner |
|---|---|---|
| PL-01 | Domain verification for deep links (Android/iOS) | Paulo |
| PL-02 | Apple Developer account Associated Domains | Paulo |
| PL-03 | Commercial launch gate (INTERNAL → EXPOSED) | Agente Martins + Paulo |
| PL-04 | Legal disclaimer review for each market | Paulo + legal |
| PL-05 | App Store / Play Store listing update | Paulo |
