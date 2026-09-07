-- IVE-X4R-MB2 reference initialization data.
--
-- This is REFERENCE/SEED DATA, not schema and not runtime configuration:
--   SCHEMA               -> supabase/migrations/*.sql (structure only)
--   REFERENCE/SEED DATA   -> this file (deterministic starting content
--                            for a fresh install, e.g. feature_flags)
--   RUNTIME CONFIGURATION -> whatever an admin tool/dashboard changes
--                            afterward; this file must never fight that
--
-- Run automatically by `supabase start` / `supabase db reset` after all
-- migrations apply. Every statement below is ON CONFLICT DO NOTHING --
-- deliberately, so this file only ever affects a genuinely fresh/reset
-- database and never overwrites already-existing runtime state. This is
-- the opposite of the legacy migrations 007/009/020 (archived at
-- docs/legacy-migrations-archive/), which force-overwrote feature_flags
-- unconditionally on every replay -- that behavior is not reproduced
-- here on purpose.
--
-- Values captured read-only from live production during IVE-X4R-MB2
-- (all 6 rows, current as of the baseline capture date). If production's
-- actual flag values change later, this file is NOT the place that
-- change belongs -- it stays a fresh-install starting point, not a
-- synced mirror of runtime state.

INSERT INTO public.feature_flags (feature_name, enabled, plan_required) VALUES
  ('action_engine_enabled',     true, 'free'),
  ('advisor_enabled',           true, 'free'),
  ('business_memory_enabled',   true, 'free'),
  ('copilot_enabled',           true, 'free'),
  ('ecosystem_view_enabled',    true, 'free'),
  ('opportunity_lab_enabled',   true, 'free')
ON CONFLICT (feature_name) DO NOTHING;
