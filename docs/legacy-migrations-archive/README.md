# Legacy migrations archive

## What this is

These 22 files (`001_create_post_generations.sql` through
`021_action_queue_plan_column.sql`, plus the original
`022_x4b_search_path_and_role_protection.sql` before it was renamed —
see below) are **historical development artifacts**, moved here from
`supabase/migrations/` during IVE-X4R-MB2. Their content is unchanged
from the versions previously committed at `supabase/migrations/` — this
is a pure relocation, not a rewrite. Full history remains available via
`git log --follow` on each file.

## Why they moved

A multi-session security audit (IVE-X4R, Gates 1B through 1F, then MB1
and MB1.5) found that this migration history does **not** represent a
trustworthy record of how production's schema actually came to be:

- `supabase_migrations.schema_migrations` on production contains **zero
  rows** — none of these 22 files, migration 022 included, was ever
  applied through the Supabase CLI's tracked migration mechanism.
- **`001` is duplicated**: `001_create_post_generations.sql` and
  `001_platform_schema.sql` both carry the same version prefix, which
  collides in the CLI's own migration-version bookkeeping the moment a
  fresh `supabase start` tries to apply both (discovered in Gate 1C/1E).
- **`profiles_admin_select` / `profiles_admin_update`** (created in
  `001_platform_schema.sql`) are structurally recursive — their `USING`
  clause is a direct `EXISTS` subquery against `profiles`, written
  inside a policy defined *on* `profiles`, which Postgres correctly
  rejects with "infinite recursion detected in policy" the moment any
  `UPDATE` touches the table (discovered dynamically in Gate 1E). They
  are not live in production — production replaced them, undocumented,
  with `users_own_profile` / `admin_all_profiles`, which route the admin
  check through a `SECURITY DEFINER` function (`get_current_user_role()`)
  specifically to avoid this exact recursion. Notably, `is_admin_user()`
  — created two migrations later, in `003_knowledge_vault.sql` — carries
  its own comment stating it exists *"para evitar recursão"* (to avoid
  recursion), meaning the problem was already known at the time and
  simply never retrofitted onto `profiles` itself.
- **Migrations `011`, and parts of `017`, were never applied to
  production** — `011_phase10c_knowledge_layer.sql`'s three tables don't
  exist live; `020_p0_stabilization_fixes.sql` and
  `021_action_queue_plan_column.sql` each contain their own first-party
  comments acknowledging `017`'s column was never applied and had to be
  defensively re-added.
- Several production-only objects (`assets`, `asset_resources`,
  `executive_contexts`, `project_events`, and their ownership-validation
  triggers/functions) exist live with **no corresponding migration file
  at all** anywhere in this history.

None of this reflects an active exploit — see
`docs/ive/X4R_FINDINGS.md`, `docs/ive/X4B_FINDINGS.md`, and the IVE-X4R
Gate 1D/1E/1F and MB1/MB1.5 reports for the full, evidence-based audit
trail — but it does mean this file set must never be replayed against
production, and must not be treated as the canonical schema history
going forward.

## What replaces them

`supabase/migrations/` now begins with a single canonical baseline
migration (`20260907120000_baseline_production_pre_x4r.sql`),
authored directly from live production's actual current schema via
read-only catalog inspection (IVE-X4R-MB2) — not reconstructed from
these files' stated intent, which in several places (above) diverges
from what is actually live. Migration `022_x4b_search_path_and_role_
protection.sql` — already independently, dynamically validated across
IVE-X4R Gate 1F's full A–P authorization test matrix — is preserved
byte-for-byte (SHA256-verified identical) and renamed to
`20260907120001_x4b_search_path_and_role_protection.sql`, taking its
place as the first migration *after* the new baseline.

## Rules going forward

- **Never replay these files against production or any fresh
  environment.** They are historical record only.
- The duplicate `001` version, the recursive `profiles_admin_*`
  policies, and every other item above are documented here precisely so
  a future reader doesn't have to rediscover them — not fixed in place,
  since these files are frozen history now, not live migrations.
- Canonical migration history begins at
  `supabase/migrations/20260907120000_baseline_production_pre_x4r.sql`.
