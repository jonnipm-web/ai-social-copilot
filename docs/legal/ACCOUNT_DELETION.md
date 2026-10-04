# InsightValues — Account Deletion

**Mission:** IV-RELEASE-LEGAL-POLICIES-01  
**Status as of:** 2026-10-03  
**Auditor:** Claude Sonnet 4.6

---

## Current State: GAP IDENTIFIED

```
ACCOUNT_DELETION_FLOW_REQUIRED

Current status:
  - The app provides a "Sign Out" function (Conta → Sair da conta).
  - Sign Out ends the session but does NOT delete the account or associated data.
  - No in-app "Delete my account" flow exists.
  - No web form for account deletion exists.
  - Database has ON DELETE CASCADE from auth.users → profiles, so if a user
    record is deleted from Supabase Auth by an admin, all profile data cascades.
  - However, cascaded deletion does NOT cover: copilot_messages, analysis
    results in analysis tables, assets in Supabase Storage, Stripe subscription
    records. These must be cleaned up separately.

Google Play requirement:
  Apps that require account creation MUST provide an in-app option to
  delete the account, or a link to a web page where the user can request
  deletion. See: https://support.google.com/googleplay/android-developer/answer/13327111
  
  InsightValues requires account creation (login is mandatory). This
  requirement applies.
```

---

## Gap Analysis

| Requirement | Status | Gap |
|-------------|--------|-----|
| User can request account deletion | ❌ NOT IMPLEMENTED | No in-app or web flow |
| Google Play in-app deletion or external link | ❌ NOT IMPLEMENTED | Required by policy |
| Data associated with account is deleted | ⚠️ PARTIAL | DB cascade covers profiles; other tables must be audited |
| Stripe subscription cancellation on deletion | ❌ NOT IMPLEMENTED | Stripe subscription remains active if user account is deleted |
| Retention exceptions documented | ⚠️ PARTIAL | Legal/billing records should be noted in policy |

---

## Minimum Safe Implementation (Scope-Bounded)

The following is a minimal, reversible approach to satisfy Google Play requirements without complex backend changes:

### Option A — Email Request Flow (Minimum viable, no code change)
1. Owner creates a dedicated email/form at insightvalues.com for account deletion requests.
2. app_constants.dart gains an `accountDeletionUrl` constant pointing to this page.
3. About screen or Account screen adds a "Delete my account" link.
4. Owner manually processes requests by deleting users in Supabase Auth Console (cascade handles profile data) and cancelling Stripe subscription.

**Pros**: Implementable today, no backend code.  
**Cons**: Manual process, response time not guaranteed.

### Option B — In-App Deletion Flow (Full implementation, future mission)
- Requires a new Supabase Edge Function that:
  1. Verifies JWT
  2. Cancels Stripe subscription (if active)
  3. Deletes all user data from all tables
  4. Calls Supabase Auth admin API to delete user account
- Requires Codex adversarial review (Class D — auth/data destruction)

---

## Recommended Immediate Action (Option A)

**BLOCKED_OWNER**: Owner must:
1. Create a page at `insightvalues.com/delete-account/` (or similar) with a form or email link.
2. Authorize Claude Code to add `accountDeletionUrl` constant and link in the Account screen.

Until Owner authorizes Option A implementation, this gap remains OPEN.

---

## Data Deletion Scope (When Implemented)

When a deletion request is processed, the following data should be removed:

| Table | Deletion Method | Notes |
|-------|----------------|-------|
| auth.users | Supabase Auth admin delete | Triggers cascade |
| profiles | CASCADE from auth.users | Automatic |
| subscriptions | CASCADE from auth.users | Automatic |
| personas | CASCADE via user_id FK | Automatic |
| projects | CASCADE via user_id FK | Automatic |
| knowledge_items, knowledge_analysis | CASCADE | Automatic |
| post_generations, content_items | CASCADE | Automatic |
| website_analyses, market_analyses | CASCADE | Automatic |
| business_memory (IVE memory) | CASCADE | Automatic |
| copilot_sessions, copilot_messages | CASCADE | Automatic |
| action_queue, opportunity_lab | CASCADE | Automatic |
| Stripe subscription | Manual API call | Must cancel before user deletion |
| Supabase Storage assets | Manual or Edge Function | Not covered by DB cascade |

**Retention exceptions** (may need to be retained per legal obligation):
- Billing records (Stripe invoices retained by Stripe per their policy)
- Processed webhook events (internal audit log for billing events)

---

*This document must be reviewed and acted on before Google Play submission.*
