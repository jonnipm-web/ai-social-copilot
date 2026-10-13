# 13 — Client Architecture (Flutter)

Baseline E-MAIN. 221 Dart files under `lib/` (~51 k lines), app version `1.0.0+1`
(`pubspec.yaml`), package name `ai_social_copilot`.

## 1. Stack

| Concern | Package / mechanism | Evidence |
|---|---|---|
| State | `flutter_riverpod ^2.5.1` — `StateNotifierProvider`, `FutureProvider(.autoDispose)`, families | `lib/providers/` (37 provider files) |
| Routing | `go_router ^14.2.7`, hash URL strategy (no `usePathUrlStrategy`), async `redirect`, `errorBuilder`, root `navigatorKey` shared with IVE overlay | `lib/app.dart` |
| Backend SDK | `supabase_flutter >=2.5.6 <2.15.0` | `pubspec.yaml` |
| Config | `flutter_dotenv` loads bundled `.env` asset (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_CLIENT_ID`) | `lib/main.dart:91-95` |
| Google | `google_sign_in ^6.2.1` (login and Drive, separate instances/scopes), `http` | `auth_service.dart`, `drive_service.dart` |
| Local persistence | `shared_preferences` (IVE memory, language) | `ive_memory_provider.dart` |
| Avatar | `rive ^0.13.12` (frozen; fallback used) | `lib/features/ive/visual/` |
| Files | `file_picker >=12.0.0-beta.1` (beta pin for win32 compatibility) | `pubspec.yaml` comment |
| Billing UX | `url_launcher` opens Stripe Checkout URL | `billing_service.dart` |
| i18n | `flutter_localizations` + gen-l10n; `pt` (template) and `en`; 145 keys each | `l10n.yaml`, `lib/l10n/app_pt.arb`, `app_en.arb` |
| Error capture | `runZonedGuarded` + `FlutterError.onError` → diagnostic logger; `BUILD_SHA` via `--dart-define` | `lib/main.dart`, `lib/core/diagnostics/build_info.dart` |

## 2. Layering

```
lib/
  core/        constants, theme, modules (registry + route policy), diagnostics, app_lifecycle, utils, services (IVE event bus)
  data/        models (54 files), services (33 files, roughly one per table/EF family)
  providers/   Riverpod state per domain
  features/    screens per module (projects, knowledge, market_intelligence, opportunity_lab, action_engine, ecosystem, ive, admin, …)
  shared/      widgets (IVE overlay, Context Copilot widget, AI execution confirmation, drawer, …)
  l10n/        ARB + generated localizations
```

Services call Supabase directly (`.from(table)` under RLS) or `functions.invoke(name)`; there is
no repository/API abstraction layer between providers and Supabase.

## 3. Module registry and route policy

- `lib/core/modules/module_registry.dart` — `kModuleRegistry`: **37 modules** with `status`
  (`active | beta | inDevelopment | disabled | planned | internal`), `commercialEnabled`,
  `minimumPlan` (`free | pro | admin`), `route`, backend/EF/DB dependencies, readiness notes,
  `releaseClassification` (`commercialV1 | postV1 | betaProgram | internalTooling | externalPlanned`).
- `lib/core/modules/route_policy.dart` — explicit route→module map; `decideForModule`:
  admin → allow; always-allowed routes (upgrade/account/about/support) → allow; unclassified →
  allow; `commercialEnabled=false` → deny; `pro` → allow if `isPro` else upgrade; profile fetch
  failure → fail closed (never grants Pro/admin).
- Wired in `lib/app.dart` `_resolveEntitlementRedirect`; `test/core/modules/route_policy_test.dart`
  asserts every GoRoute path is classified (29 static tests).
- **The registry is presentation + client routing only.** Its own header states it "never
  replaces RLS/server authorization".

## 4. Entitlements on the client

`Profile.isPro = role ∈ {pro, premium, admin}`, `isPremium = role ∈ {premium, admin}`,
`isBetaTester = role ∈ {beta_tester, admin}` (`lib/data/models/profile.dart`). `QuotaInfo` mirrors
server usage (`ai_usage`, `profiles.monthly_limit`). `AppConstants.planLimits`
(`admin 99999, premium 1000, pro 100, beta_tester 50, free 5`) is used by the admin panel when
assigning a role (`profile_service.dart updateRole`).

Legacy residue: `profile_service.dart` still contains an email-based auto-promotion to admin and
an upsert that sets `role`; both are neutralized server-side by `trg_prevent_self_privilege_escalation`
(the update is caught and ignored). → `LEGACY` code path, see [26](26-legacy-deprecation-register.md).

## 5. AI execution UX

`lib/shared/widgets/ai_execution_confirmation.dart` — `AiExecutionController` (confirmation dialog,
double-submit guard, states `idle → awaitingConfirmation → reservingQuota → thinking → success/error`),
used by 16 screens/widgets on E-MAIN. Auto-bootstrap (`auto_bootstrap_provider.dart`) runs only after
a confirmation that shows estimated quota units (`project_command_center_screen.dart:142-145`).

## 6. Feature/runtime state

| Mechanism | Scope | Notes |
|---|---|---|
| `kModuleRegistry.commercialEnabled` | client, compile-time | authoritative for navigation on E-MAIN |
| `feature_flags` table (`feature_flag_provider.dart`) | DB, 6 rows | duplicates registry for Opportunity Lab / Action Engine (E-INT02 D1) |
| `IveRiveFeatureGate.enabled = false` | compile-time constant | not a `--dart-define` by design |
| Diagnostic sessions | admin-only, server-scoped | see [20](20-observability.md) |

## 7. Domain boundaries in the client

Feature folders map 1:1 to registry modules; cross-module aggregation happens in providers
(`ecosystem_intelligence_provider.dart`, `ive_context_provider.dart`, dashboard screens). The
Executive layer (Executive Dashboard, Decision Center, Resource Allocation, Weekly Briefing) is
pure client-side aggregation with no table or function of its own.
