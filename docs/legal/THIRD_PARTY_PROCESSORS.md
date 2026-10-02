# InsightValues — Third-Party Data Processors

**Mission:** IV-RELEASE-LEGAL-POLICIES-01  
**Status as of:** 2026-10-03  
**Auditor:** Claude Sonnet 4.6

> Only processors confirmed to receive user data are listed. No processor is listed if its integration was not verified in the codebase.

---

## 1. Supabase

| Field | Value |
|-------|-------|
| **Purpose** | Backend-as-a-service: database, authentication, file storage, server-side functions |
| **Data category** | Account data (email, profile), user-created content, AI analysis results, subscription records, IVE memory, copilot sessions/messages |
| **Current status** | PRODUCTION — active |
| **Privacy URL** | https://supabase.com/privacy |
| **Notes** | Supabase Auth handles email/password credentials and OAuth token management. Data stored in PostgreSQL with Row Level Security. Supabase infrastructure runs on AWS. |

---

## 2. Stripe

| Field | Value |
|-------|-------|
| **Purpose** | Subscription billing and payment processing |
| **Data category** | Email address (to create Stripe Customer), Stripe customer ID, subscription ID/status. Payment card data is collected directly by Stripe — InsightValues never sees raw card numbers. |
| **Current status** | PRODUCTION — active (subscription billing for PRO plan) |
| **Privacy URL** | https://stripe.com/privacy |
| **Notes** | Stripe webhooks are verified server-side (HMAC-SHA256). InsightValues stores only the Stripe customer ID and subscription status, not payment card data. |

---

## 3. Groq

| Field | Value |
|-------|-------|
| **Purpose** | AI language model inference for all IVE-powered features |
| **Data category** | User-provided content passed to AI functions (project descriptions, website URLs, knowledge item text, post content, business context). All processing is server-side via Supabase Edge Functions — content is never sent directly from the client device to Groq. |
| **Current status** | PRODUCTION — active |
| **Privacy URL** | https://groq.com/privacy-policy |
| **Notes** | Model: openai/gpt-oss-120b, endpoint: api.groq.com. Groq's data processing terms govern how inference inputs are handled. InsightValues does not store raw prompts sent to Groq beyond what is recorded in copilot_messages and analysis tables in Supabase. |

---

## 4. Google (OAuth)

| Field | Value |
|-------|-------|
| **Purpose** | Optional Google Sign-In authentication |
| **Data category** | Google account email address and Google user ID (used to create/authenticate a Supabase user). No Google Drive or Gmail access is used in authentication flow. |
| **Current status** | IMPLEMENTED — active (Google Sign-In available on login screen, deferred for production testing) |
| **Privacy URL** | https://policies.google.com/privacy |
| **Notes** | Google Drive integration exists in the codebase (google_sign_in package) for optional file import via Smart Import Engine. This is a separate scope from the OAuth authentication flow. |

---

## 5. Google Fonts (Web only)

| Field | Value |
|-------|-------|
| **Purpose** | Font delivery for Flutter web rendering |
| **Data category** | Browser IP address logged by Google Fonts CDN (standard HTTP request) |
| **Current status** | PRODUCTION — active (web version only; Android bundles fonts locally) |
| **Privacy URL** | https://fonts.google.com/about |
| **Notes** | Standard CDN font loading. No user-identifying data beyond browser request metadata. |

---

## NOT USED

The following providers are **confirmed absent** from the codebase:

| Provider | Reason |
|----------|--------|
| Firebase / Google Analytics | No dependency or configuration found |
| Mixpanel, Amplitude, Segment | No dependency or configuration found |
| Sentry, Crashlytics, Datadog | No dependency or configuration found |
| Any ad network | Not present |
| Any email marketing platform | Not present |

---

*Accuracy note: This list reflects what was verified in the codebase as of the audit date. The owner must update this document if new processors are added.*
