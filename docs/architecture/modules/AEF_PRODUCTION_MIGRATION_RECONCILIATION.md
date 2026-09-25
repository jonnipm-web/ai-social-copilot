# AEF Production Migration Reconciliation (P05 / P10)

Mission `IV-AEF-PRE-RUNTIME-CLOSURE-01`. **Status: P05 RECONCILED, P10 RECONCILED**
(for the AEF chain). Nothing was applied, recorded or renamed in production.

## Evidence

The evidence comes from read-only metadata queries on production
(`ai-social-copilot`, `nzngvbajrnruknpzzjbf`, PostgreSQL 17). All queries ran
inside `BEGIN TRANSACTION READ ONLY … ROLLBACK`: catalog and
`supabase_migrations.schema_migrations` (version, name) only. No user data was
read.

**Why history ids ≠ file names (P10):** production records every migration under
the **apply timestamp** (`version`) together with the repo file's **suffix**
(`name`). File `20260910190000_commercial_ai_quota.sql` is recorded as
`20260910220256 / commercial_ai_quota`. The reconciliation key is therefore the
**name**, and it is confirmed by a **schema check** of the objects each migration
creates. The version is not used. All 16 history rows map 1:1 by name to repo
files, in the same order.

Status legend:
- MATCHED: name in history **and** its objects present.
- FUNCTIONALLY_PRESENT: objects present without a history row.
- NOT_PRESENT: neither.
- DRIFTED: history and schema disagree.
- UNKNOWN: not verifiable.

## Matrix

| REPO_MIGRATION | PURPOSE | EXPECTED_DEPENDENCIES | PRODUCTION_HISTORY_MATCH | PRODUCTION_SCHEMA_PRESENT | DRIFT | RISK | ACTION_BEFORE_DEPLOY |
|---|---|---|---|---|---|---|---|
| 20260907120000_baseline_production_pre_x4r | baseline schema (projects, profiles, assets, action_queue, market_analyses, opportunity_lab, business_memory…) | Supabase auth | 20260907120000 | yes (tables, `projects.id/user_id uuid NOT NULL`, PK) | none | — | none |
| 20260907120001_x4b_search_path_and_role_protection | search_path / role protection | baseline | 20260907120001 | yes | none | — | none |
| 20260910190000_commercial_ai_quota | AI quota (`ai_usage`, `try_reserve_ai_quota`) | baseline | 20260910220256 | yes | none | — | none |
| 20260911010000_stripe_billing | billing (`subscriptions`, `processed_webhook_events`) | baseline | 20260911002606 | yes | none | — | none |
| 20260911020000_stripe_billing_atomic_apply | `apply_stripe_subscription_state` (9 args) | stripe_billing | 20260911004603 | yes (signature matches) | none | — | none |
| 20260911030000_stripe_billing_event_ordering | event ordering | stripe_billing_atomic_apply | 20260911005340 | yes | none | — | none |
| 20260913200000_diagnostic_logger | `diagnostic_*` tables and archives | baseline | 20260913232856 | yes | none | — | none |
| 20260914000000_diagnostic_logger_anon_revoke_hardening | anon revokes | diagnostic_logger | 20260913234333 | yes (anon has no EXECUTE on cleanup) | none | — | none |
| 20260915000000_diagnostic_one_active_session | one active session, `cleanup_old_diagnostic_sessions(integer)` | diagnostic_logger | 20260914010735 | yes | none | — | none |
| 20260916000000_market_intelligence_current_state | market intelligence | baseline | 20260914152844 | yes | none | — | none |
| 20260917000000_project_resource_allocations | `project_resource_allocations` | baseline | 20260914224953 | yes | none | — | none |
| 20260917000001_project_resource_allocations_search_path_hardening | search_path | project_resource_allocations | 20260914225121 | yes | none | — | none |
| 20260918000000_ai_quota_idempotency | `ai_quota_reservations`, `try_reserve_ai_quota(uuid, text)`, `refund_ai_quota(uuid)` | commercial_ai_quota | 20260915134525 | yes (signatures match) | none | — | none |
| 20260919000000_project_ownership_boundary_closure | ownership policies on projects | baseline | 20260915194037 | yes (policies check projects) | none | — | none |
| 20260920000000_diagnostic_events_build_sha | `build_sha` plus 2 constraints | diagnostic_logger | 20260916175904 | yes | none | — | none |
| 20260920000001_opportunity_knowledge_links | opportunity knowledge links | baseline | 20260917205611 | yes | none | — | none |
| **20260923000000_entitlement_subject_roles** | `subject_roles` (entitlement) | `profiles(id, role)`, `auth.uid()` | — | **NOT_PRESENT** | none (consistent absence) | AEF operator reconciliation needs it | apply **before** aef_hardening, in the owner-approved change window |
| **20260924000000_ive_memory_governance** | business_memory scope/status/origin/dedup_key/expires_at | `business_memory` | — | **NOT_PRESENT** | none | independent of AEF | may be applied in the same window; not required by AEF |
| **20260925000000_aef_persistence** | AEF tables, 13 RPCs, audit chain | `projects(id uuid, user_id uuid NOT NULL)`, anon/authenticated/service_role, `sha256`, `gen_random_uuid`, `auth.uid()` | — | **NOT_PRESENT** (0 `aef_*` objects) | none | exposes the audit sequence (P03) until `20260927` follows | apply only as part of the chain, **immediately followed by 20260927** |
| **20260926000000_aef_hardening** | retention, erasure, coalescing, reconciliation, receipt 1.1 | aef_persistence, `subject_roles`, `auth.users(id uuid)`, `hashtextextended` | — | **NOT_PRESENT** | none | fails fast without `subject_roles` (P05) | apply after 20260923 and 20260925 |
| **20260927000000_aef_sequence_privileges** | REVOKE on AEF sequences (P03) | aef_persistence | — | **NOT_PRESENT** | none | — | apply immediately after 20260925/20260926 |

Summary: **16 MATCHED, 5 NOT_PRESENT, 0 FUNCTIONALLY_PRESENT, 0 DRIFTED,
0 UNKNOWN.**

## Real dependency graph (from the code, not from file numbering)

```
profiles(id, role) + auth.uid ─► 20260923 entitlement_subject_roles ──┐
business_memory ───────────────► 20260924 ive_memory_governance       │ (independent of AEF)
projects + roles + sha256 +                                           │
gen_random_uuid + auth.uid ────► 20260925 aef_persistence ─┬──────────┤
                                                           │          ▼
                                auth.users + hashtextextended ─► 20260926 aef_hardening
                                                           └────► 20260927 aef_sequence_privileges
```

- `20260926` depends on `20260923`: `aef_reconcile` checks `subject_roles` for the
  operator admin. This is P05. Operator reconciliation is OFF (D4), but the function
  body still references the table, so the dependency is real.
- The chain can **never** be applied as "AEF alone". Every AEF migration now opens
  with an `AEF_PRECONDITION` guard (`AE010`) that fails **before creating anything**
  if a real dependency is missing. This is tested in the runner as
  `AEF_FAIL_FAST: PASS`, including "no partial state after a failed precondition".
- Guards were added to `20260925` and `20260926` (option B). These migrations are
  Lab-only and have been applied nowhere, so editing them changes no recorded
  history. `20260927` carries its own guard.

## Guardrail

`supabase/preflight/aef_deploy_preflight.sql` runs READ-ONLY and fails closed. It
encodes this matrix:
- the 16 predecessors must be present by name;
- the functional schema checks;
- history and schema must agree for each chain migration;
- dependency order;
- no stray `aef_*` objects;
- P03 sequence exposure.

It is tested against simulated production states in the runner
(`AEF_DEPLOY_PREFLIGHT_TESTS: PASS`):
- production-like baseline → PASS with the full chain remaining;
- missing predecessor → FAIL;
- history row without objects → FAIL;
- stray `aef_` object → FAIL;
- `projects.user_id` nullable → FAIL;
- chain stopped before `20260927` → FAIL (exposed sequence);
- history claiming `20260927` while the sequence is exposed → FAIL;
- full chain → PASS "(none)";
- hardening in the history without entitlement → FAIL (order).

## What was deliberately NOT done

- Nothing was inserted into, deleted from or renamed in
  `supabase_migrations.schema_migrations`.
- Repo migrations were not renamed to match the production versions.
- Nothing was applied.
- The history uses apply-time versions by design (Supabase CLI / MCP
  `apply_migration`). A future deploy through the same channel will record new
  apply-time versions with the same names, and the preflight keys on names.
