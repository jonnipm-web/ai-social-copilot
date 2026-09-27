# InsightValues Quant — Watchlist Model (IV-QUANT-DATA-PLANE-AND-API-02)

Migration `supabase/migrations/20260924000000_quant_watchlists.sql` —
**Quant Lab only, NOT applied to production.** Module `quant-watchlists`
(INTERNAL, REVERSIBLE).

## 1. Tables

| `quant_watchlists` | |
|---|---|
| `id` uuid PK | |
| `user_id` uuid → auth.users, default `auth.uid()` | owner; immutable |
| `project_id` uuid → projects, ON DELETE SET NULL | optional; immutable after create |
| `name` text 1–80, trimmed | the only updatable column |
| `created_at`, `updated_at` | trigger-maintained |

| `quant_watchlist_items` | |
|---|---|
| `watchlist_id` → quant_watchlists ON DELETE CASCADE | |
| `user_id` (= parent owner) | |
| `asset_class` ∈ EQUITY, ETF, INDEX | Foundation-supported classes |
| `symbol`, `exchange_mic?`, `currency`, `isin?`, `figi?` | canonical identity, format-checked |
| `instrument_key` GENERATED | `class:MIC|UNSPECIFIED:symbol:currency`, cannot be forged |
| UNIQUE (watchlist_id, instrument_key) | same ticker on another venue/currency is a different item |

Relational, not a JSON blob: per-item uniqueness, constraints and RLS are
enforceable in the database.

## 2. Security

* **RLS** on both tables; every policy = `user_id = auth.uid()` **AND**
  `quant_watchlists_access_allowed()`; item inserts also require an owned,
  visible parent.
* **Module entitlement in the database** (Codex CXA-01):
  `quant_watchlists_access_allowed()` (SECURITY INVOKER, reads only the
  caller's own `profiles.role` / `subject_roles`) is true only for admins
  while the module is INTERNAL. Direct PostgREST access by a non-entitled
  user returns nothing and cannot write. Drift test QB-16 fails CI if the
  server lifecycle changes without a new predicate migration.
* **Privileges:** anon none; authenticated SELECT/INSERT/DELETE + UPDATE(name);
  items have no UPDATE. `user_id`/`project_id` can never be rewritten.
* **Cross-project:** INSERT with `project_id` requires a project owned by
  the caller (policy) — and the Edge Function checks ownership first.
* **Limits:** 200 items per watchlist (parent row lock), 50 watchlists per
  user (advisory lock) — enforced in the database and the API.
* The Edge Function writes as the **caller** (JWT), never with the service
  role, so RLS is the isolation authority.

## 3. Tests

`supabase/tests/quant_watchlists_rls_test.sql` (runs in CI via
`scripts/ci/run_disposable_db_tests.sh`): Q01 anonymous deny · Q02 owner
insert, cross-project deny, forged owner deny · Q03 identity constraints,
generated key, duplicate · Q04 owner select/update(name), immutable
user/project/items · Q05 other user select/update/delete/insert deny ·
Q06 limits · Q07 owner delete + cascade · Q08 project deletion detaches ·
Q09 authenticated-but-not-entitled user denied even on own rows · Q10
demotion revokes access; `subject_roles` admin recognised.

Mutation check (local): 5 mutants (open SELECT policy, dropped project
check, anon grant, broad UPDATE grant, predicate returning true) — all
caught. A 6th mutant (entitlement predicate removed from the item INSERT
policy only) is **equivalent**: the policy's parent-visibility check already
depends on the predicate, and Q09 proves a non-entitled user cannot insert.

## 4. Rollback

Additive migration; rollback = `DROP TABLE quant_watchlist_items,
quant_watchlists; DROP FUNCTION quant_watchlists_access_allowed(),
quant_watchlists_before_write(), quant_watchlist_items_before_insert();`.
No existing table or policy is altered. Production preflight: none needed
(new tables, no constraints added to existing data).
