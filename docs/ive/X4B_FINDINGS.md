# IVE-X4B Findings — Database Authorization Closure

All findings below come from live, read-only SQL against the production
Supabase project (`nzngvbajrnruknpzzjbf`) via the Supabase MCP
`get_advisors` and `execute_sql` tools — `SELECT` against `pg_policies`,
`pg_proc`, `pg_constraint`, `pg_class`, `pg_trigger`,
`information_schema.columns`/`column_privileges`/`table_privileges` only.
**No row of application data was read, and no write of any kind was
executed against production** by this session. The one exploit path found
below was proven by inspecting the live policy/constraint/trigger/grant
definitions, not by attempting it.

## RLS coverage — the good news first

Every one of the 34 tables in `public` has `rowsecurity = true` and at
least one policy (checked via `pg_class.relrowsecurity` joined to
`pg_policies`). No table is silently wide open.

## `is_admin_user()` — three parallel implementations, inconsistent coverage

Not simply "pre-006 vs. post-006" as earlier audits approximated — the
live policy set shows **three different, functionally-overlapping admin
checks**, applied to a minority of tables:

| Mechanism | Used by |
|---|---|
| `is_admin_user()` function call, OR'd into the owner check | `campaign_calendar`, `campaigns`, `knowledge_analysis`, `knowledge_items`, `knowledge_strategies` |
| Inline `EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')`, as a *separate* policy | `calendar_items`, `content_items`, `personas` |
| `get_current_user_role() = 'admin'`, as a *separate* policy | `profiles` |
| **No admin path at all** | The other 26 tables, including `action_queue`, `business_memory`, `projects`, `assets` |

**Classification: INCONSISTENT / LEGACY technical debt, not itself
EXPLOITABLE.** `is_admin_user()`'s own logic is sound (checks the calling
session's own `profiles.role` via `auth.uid()`, cannot be spoofed by
payload). The three-mechanism duplication is real maintainability risk
(one could be patched without the others being noticed), and the fact
that the majority of tables have *no* admin override means even a
legitimate admin cannot manage other users' actions/memory/projects
through the API today — they would need direct/service-role access for
any support case. Not fixed in this migration (would require an
owner-directed decision on where admin access *should* exist); the two
things that **are** fixed are described below.

## `function_search_path_mutable` — real class, low exploitability here

Supabase's own security advisor flagged 5 functions. Read the actual
`pg_get_functiondef` output for each (not inferred):

- `is_admin_user()`, `handle_new_user()` — **`SECURITY DEFINER`**, no
  `SET search_path`. Every reference inside both bodies is already
  schema-qualified (`public.profiles`, `auth.uid()`), so there is no
  unqualified identifier for a search_path hijack to intercept *today* —
  this is a defense-in-depth fix against a *future* edit reintroducing an
  unqualified reference, not evidence of a currently exploitable path.
- `set_updated_at()`, `update_project_events_updated_at()`,
  `update_executive_contexts_updated_at()` — plain `SECURITY INVOKER`
  trigger functions (no elevated privilege involved at all). Fixed for
  consistency/hygiene; materially lower priority than the two above.

Migration 022 adds `SET search_path` to all five, reproducing each
function's existing body verbatim (verified against the live
`pg_get_functiondef` output) — behavior-preserving, not a rewrite.

## `WITH CHECK` — X3's correction re-confirmed, one exception found

57 `CREATE POLICY` statements exist; 6 declare an explicit `WITH CHECK`.
Postgres reuses `USING` as the implicit `WITH CHECK` when a `FOR ALL` or
per-command policy omits it — **confirmed still correct**, not a
vulnerability by itself. No blanket "add `WITH CHECK` everywhere" change
is proposed; the missing-but-safe pattern is left as-is except where noted
below, per the mission's own instruction not to declare textual absence a
vulnerability.

## THE CRITICAL FINDING — profiles self-promotion (CONFIRMED, now fixed)

**Any authenticated user could set their own `profiles.role` to `'admin'`
via a normal `UPDATE`, with nothing server-side to stop it.** Proven by
reading, together:

1. `users_own_profile` policy: `FOR ALL USING (auth.uid() = id)`, no
   `WITH CHECK`. This constrains *which row* (only your own), never
   *which columns or values* within it.
2. `profiles.role` is a plain `text` column, `NOT NULL DEFAULT 'free'`,
   with **zero `CHECK` constraints** (`pg_constraint` for
   `public.profiles` returned no rows).
3. **No trigger existed on `public.profiles`** before this migration
   (`pg_trigger` returned no user-defined triggers).
4. `authenticated` has an unrestricted, table-level `UPDATE` grant on
   `profiles` (`information_schema.column_privileges` showed no
   column-level restriction narrowing it).

Put together: `supabase.from('profiles').update({role:'admin'}).eq('id', myOwnId)`
succeeds today, for any signed-in user, against production. That grants:
the `is_admin_user()`/inline-EXISTS bypass on `campaign_calendar`,
`campaigns`, `knowledge_analysis`, `knowledge_items`, `knowledge_strategies`,
`calendar_items`, `content_items`, `personas` for **every user's** rows,
and — via `admin_all_profiles` (`get_current_user_role() = 'admin'`, also
`FOR ALL`, also no explicit `WITH CHECK`) — full read/write on **every
row of the `profiles` table**, including other users' `role`, `email`,
`monthly_limit`, and `is_active`.

**This was not executed against production by this session** — no test
account exists for this session to safely exercise the exploit with, and
doing so against a real account would itself be exactly the kind of
production write this mission prohibits. The proof above is a static
derivation from the live catalog definitions, which is sufficient and
does not require a live demonstration.

### Fix (migration 022, PREPARED not applied)

A `BEFORE UPDATE` trigger on `profiles` blocks changes to `role`,
`monthly_limit`, or `is_active` unless the acting session is already an
admin (`is_admin_user()`, now search_path-hardened) or is `service_role`
(so dashboard/CLI-driven admin promotion — presumably how the very first
admin gets created today — keeps working). `full_name`/`email` remain
freely editable by the row's own owner, unchanged. See
`x4b_authorization_tests.sql` tests 4–6 for the exact before/after
behavior this proves.

## Migration ordering

`022_x4b_search_path_and_role_protection.sql` is additive-only: it
`CREATE OR REPLACE`s five existing functions (same signatures, same
behavior plus `search_path`) and adds one new function + one new trigger.
No column is dropped, no existing row is touched, no existing policy is
altered or removed. Safe to apply independently of any other pending
migration; no ordering dependency.

## Rollback

```sql
DROP TRIGGER IF EXISTS trg_prevent_self_privilege_escalation ON public.profiles;
DROP FUNCTION IF EXISTS public.prevent_self_privilege_escalation();
-- the five CREATE OR REPLACE FUNCTION statements have no rollback path
-- other than re-deploying the pre-migration body; since they are
-- behavior-identical plus search_path, rollback is not expected to be
-- needed for those five.
```
