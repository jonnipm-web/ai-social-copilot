# InsightValues — Data Safety Matrix

**Mission:** IV-RELEASE-LEGAL-POLICIES-01  
**Status as of:** 2026-10-03  
**Auditor:** Claude Sonnet 4.6  
**Purpose:** Base document for Google Play Console Data Safety form

> All entries reflect verified product behavior as of the audit date. Only confirmed data types are listed.

---

## Data Collection Matrix

| Data Type | Collected? | Shared? | Purpose | Optional? | Ephemeral? | Encrypted in Transit? | User Can Delete? | Retention | Processor(s) |
|-----------|-----------|---------|---------|-----------|-----------|----------------------|-----------------|-----------|-------------|
| Email address | YES | YES (Stripe — to create customer) | Authentication, account identity, billing | No (required for account) | No | YES (HTTPS/TLS) | Via account deletion request | Until account deleted | Supabase, Stripe |
| Name (full_name) | NO* | No | — | — | — | — | — | — | — |
| Google account ID | YES (if Google Sign-In used) | No | Authentication only | Yes (optional login method) | No | YES | Via account deletion | Until account deleted | Supabase, Google |
| Profile/plan data | YES | No | App functionality, quota enforcement | No | No | YES | Via account deletion | Until account deleted | Supabase |
| Subscription status | YES | No | Access control, billing | No | No | YES | Via account deletion | Until account deleted | Supabase, Stripe |
| Payment card data | NO (never seen by app) | — | Stripe handles directly | Required for PRO | — | YES (Stripe) | Via Stripe billing portal | Per Stripe policy | Stripe only |
| User-created content (projects, personas, campaigns, etc.) | YES | No | Core product functionality | User's choice | No | YES | Yes — user can delete items individually; full deletion via account deletion | Until deleted by user or account deletion | Supabase |
| Uploaded files (knowledge items) | YES | No | AI analysis (server-side) | User's choice | No | YES | Yes — user can delete items | Until deleted by user or account deletion | Supabase (storage), Groq (processing) |
| AI analysis results | YES | No | Display analysis to user | No | No | YES | Yes — user can delete analysis | Until deleted by user or account deletion | Supabase |
| IVE conversation messages | YES | No | Context Copilot functionality | User's choice | No | YES | Via account deletion | Until account deletion | Supabase |
| IVE memory (business_memory) | YES | No | Personalization, context | No | No | YES | Via account deletion | Until account deletion | Supabase |
| Language preference | YES (local + profile) | No | UI localization | Yes | No | YES (sync) | Yes (reset in settings) | Until changed | Supabase, device storage |
| App diagnostic events | YES (admin-initiated sessions only) | No | Internal debugging, owner-run sessions only | Admin only | No | YES | Via account deletion | Until session stopped/deleted | Supabase |
| IP address / request logs | YES (server infrastructure) | No | Security, abuse prevention | No | Relatively short | YES | No (infrastructure log) | Per Supabase/hosting policy | Supabase |

*`full_name` column exists in database schema but no UI for editing or setting it was found — not actively collected from users.

---

## Google Play Data Safety — Summary Categories

These map to Google Play Console Data Safety form selections:

| Google Play Category | Sub-type | Collected | Shared | Purpose |
|----------------------|----------|-----------|--------|---------|
| Personal info | Email address | YES | NO (to Stripe for billing only; not sold/shared for advertising) | Account management |
| Personal info | Name | NO | NO | — |
| Financial info | Purchase history | YES (subscription status) | NO | App functionality |
| Financial info | Payment info | NOT COLLECTED by app | — | Stripe handles directly |
| App activity | App interactions | NO (no analytics SDK) | NO | — |
| App activity | In-app search history | NO | NO | — |
| App content | User-generated content | YES | NO | Core functionality |
| App content | Files and docs | YES (uploaded for analysis) | NO | Core functionality |
| Web browsing | Web history | NO | NO | — |
| Device or other IDs | Device ID | NO | NO | — |

---

## Sensitive Permissions

| Permission | Used | Purpose |
|-----------|------|---------|
| INTERNET | YES | Required for all network operations |
| Any Camera | NO | — |
| Microphone | NO | — |
| Location | NO | — |
| Contacts | NO | — |
| Storage (READ/WRITE) | LIMITED (file picker) | User-initiated file import only |

---

## Notes for Google Play Console

1. **Account deletion**: Currently NO in-app deletion flow. See ACCOUNT_DELETION.md — gap must be resolved before submission.
2. **Data shared for advertising**: NONE. No advertising SDK. No data sold or shared for ad targeting.
3. **Data encrypted in transit**: YES — all communication over HTTPS/TLS.
4. **Data encrypted at rest**: Supabase provides encryption at rest (AES-256) on their infrastructure. InsightValues does not independently encrypt at the application layer beyond what Supabase provides.
5. **No independent security certification** is claimed for InsightValues itself.

---

*This matrix must be reviewed and updated before each Google Play release that changes data handling.*
