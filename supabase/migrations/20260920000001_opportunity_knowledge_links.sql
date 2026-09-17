-- COMMERCIAL-EXPERIENCE-CLOSURE-16 — Section 17/18 (Opportunity <-> Knowledge
-- Vault integration). Owner-mandated: "New Opportunity" must let the user
-- reference relevant Knowledge Vault items belonging to the CURRENT project
-- (mission Section 01.6), storing REFERENCES rather than duplicating
-- Knowledge content (Section 18).
--
-- `opportunity_lab` already has a generic `sources jsonb` column, but it is
-- populated today by the market-analysis/auto-bootstrap pipeline as
-- free-text display labels (e.g. competitor names, data sources) rendered
-- directly as chips in the UI -- overloading it with structured knowledge_item
-- UUIDs would make that existing rendering path ambiguous. A dedicated,
-- narrowly-purposed column is the smaller, safer change.
--
-- Security: this column stores ids only. The actual read-time boundary is
-- knowledge_items' own RLS (`user_id = auth.uid()`, verified via
-- pg_policies before writing this migration) -- a ref to another user's
-- knowledge item simply fails to resolve for the viewer, exactly like any
-- other cross-user id reference in this schema. No new RLS is needed on
-- opportunity_lab itself (already scoped by its own `opportunity_lab_user`
-- policy, unchanged by this migration).
--
-- ADDITIVE ONLY.
--
-- ROLLBACK:
--   ALTER TABLE public.opportunity_lab DROP COLUMN IF EXISTS knowledge_item_ids;

ALTER TABLE public.opportunity_lab
  ADD COLUMN IF NOT EXISTS knowledge_item_ids jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.opportunity_lab.knowledge_item_ids IS
  'Array of knowledge_items.id (uuid, stored as jsonb strings) the user explicitly linked when creating/editing this opportunity. References only -- actual content stays in knowledge_items, protected by its own RLS.';
