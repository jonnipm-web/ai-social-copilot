-- IVE-COMMERCIAL-STABILITY-08 — market_analysis "current state" child
-- tables (gap_analyses, content_clusters, revenue_plans) enforced as
-- at-most-one-row-per-market_analysis_id.
--
-- CONTEXT: COMMERCIAL-E2E-001 (a ~6h real usage session) reproduced a
-- live PostgrestException 406 ("Results contain 2 rows") while browsing
-- Market Intelligence. Root-caused to: fetchGapAnalysis/fetchContentCluster/
-- fetchRevenuePlan in lib/data/services/market_analysis_service.dart read
-- with `.eq('market_analysis_id', id).maybeSingle()`, assuming at most one
-- row, while runGapAnalysis/buildContentCluster/buildRevenuePlan always did
-- a plain INSERT (no upsert) with no DB-level uniqueness to back that
-- assumption — re-running the same "Analisar"/"Gerar" action for the same
-- market_analysis_id creates a second row.
--
-- SEMANTICS CONFIRMED (not assumed) before writing this migration:
--   - Product/UI: gap_analysis_screen.dart's "Analisar" action stays
--     enabled after a result already exists — running it again is meant to
--     REPLACE what the app treats as the CURRENT result. Same pattern in
--     content_cluster_screen.dart / revenue_planner_screen.dart (no
--     separate history view anywhere in these three screens) — this
--     justifies the UNIQUE(market_analysis_id) invariant added below.
--   - Data: production has exactly ONE existing duplicate — gap_analyses,
--     market_analysis_id 26d5ce9b-1f38-47a6-97b9-e74e6f1f44c0, two rows for
--     the SAME user, created 1m28s apart (2026-08-01 14:19:20 and
--     14:20:48). content_clusters and revenue_plans have ZERO existing
--     duplicates.
--
-- CODEX-FOUND CORRECTION (mission report Phase 8, finding #4): an earlier
-- version of this migration compared only per-category ITEM COUNTS between
-- the two known duplicate rows (8/8/6/6/6 both) and concluded the content
-- was "identical", reconciling by DELETing the older row outright. Reading
-- the actual jsonb text disproved that: each AI generation produces
-- genuinely different gap descriptions even for the same input (expected
-- LLM behavior, not a bug) — the older row contains real, distinct
-- insights (e.g. "recursos sobre bolsas de estudo e financiamento",
-- "relação entre dinheiro e bem-estar mental") that do NOT appear in the
-- newer row. A plain DELETE would have destroyed that data. This version
-- ARCHIVES the older duplicate(s) instead of deleting them — the
-- uniqueness invariant only needs to hold on the LIVE table; nothing
-- requires the superseded content to be destroyed rather than kept
-- alongside it.
--
-- market_analysis_id is nullable on all three tables (a row may exist
-- without being linked to any analysis — e.g. revenue_plans' existing
-- idx_revenue_plans_project_name covers a separate project-only flow with
-- market_analysis_id IS NULL). A plain UNIQUE index/constraint on a
-- nullable column already treats NULLs as pairwise distinct in Postgres
-- (never conflicts with each other), so the project-only revenue-plan flow
-- is completely unaffected by this migration.

-- ── Step 1: archive tables — same shape as the source table plus
--    archived_at, so a superseded row's full content is preserved and
--    could still be inspected/restored/shown as history later if the
--    product ever wants that, without living on the live table today.
CREATE TABLE IF NOT EXISTS public.gap_analyses_archive (
  LIKE public.gap_analyses INCLUDING ALL
);
ALTER TABLE public.gap_analyses_archive
  ADD COLUMN IF NOT EXISTS archived_at timestamptz NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS public.content_clusters_archive (
  LIKE public.content_clusters INCLUDING ALL
);
ALTER TABLE public.content_clusters_archive
  ADD COLUMN IF NOT EXISTS archived_at timestamptz NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS public.revenue_plans_archive (
  LIKE public.revenue_plans INCLUDING ALL
);
ALTER TABLE public.revenue_plans_archive
  ADD COLUMN IF NOT EXISTS archived_at timestamptz NOT NULL DEFAULT now();

-- ── Step 2: reconciliation — move every OLDER duplicate row (per
--    market_analysis_id) to its archive table, keep only the newest on
--    the live table. A no-op wherever no duplicate exists (the
--    overwhelming majority of rows). NOT a delete: full content survives
--    in the *_archive table.
--
-- IVE-COMMERCIAL-STABILITY-08 (Codex adversarial review, round 2) — an
-- earlier version of this step ran the archive INSERT and the live
-- DELETE as two SEPARATE statements, each independently recomputing
-- row_number(). A row inserted by a concurrent request between those two
-- statements could shift the ranking, so the DELETE could remove a row
-- the INSERT never actually archived. A single `WITH ... DELETE ...
-- RETURNING` CTE feeding the INSERT is one atomic statement — Postgres
-- guarantees it sees one consistent snapshot and there is no window
-- between "decide what to delete" and "delete it" for a concurrent write
-- to land in.
WITH deleted AS (
  DELETE FROM public.gap_analyses ga
  USING (
    SELECT id, row_number() OVER (
      PARTITION BY market_analysis_id ORDER BY created_at DESC, id DESC
    ) AS rn
    FROM public.gap_analyses
    WHERE market_analysis_id IS NOT NULL
  ) dup
  WHERE ga.id = dup.id AND dup.rn > 1
  RETURNING ga.*
)
INSERT INTO public.gap_analyses_archive
SELECT deleted.*, now() FROM deleted;

WITH deleted AS (
  DELETE FROM public.content_clusters cc
  USING (
    SELECT id, row_number() OVER (
      PARTITION BY market_analysis_id ORDER BY created_at DESC, id DESC
    ) AS rn
    FROM public.content_clusters
    WHERE market_analysis_id IS NOT NULL
  ) dup
  WHERE cc.id = dup.id AND dup.rn > 1
  RETURNING cc.*
)
INSERT INTO public.content_clusters_archive
SELECT deleted.*, now() FROM deleted;

WITH deleted AS (
  DELETE FROM public.revenue_plans rp
  USING (
    SELECT id, row_number() OVER (
      PARTITION BY market_analysis_id ORDER BY created_at DESC, id DESC
    ) AS rn
    FROM public.revenue_plans
    WHERE market_analysis_id IS NOT NULL
  ) dup
  WHERE rp.id = dup.id AND dup.rn > 1
  RETURNING rp.*
)
INSERT INTO public.revenue_plans_archive
SELECT deleted.*, now() FROM deleted;

-- ── Step 3: RLS on the archive tables — same ownership rule as the live
--    tables (owner can read their own archived rows; nothing else needs
--    write access to an archive).
ALTER TABLE public.gap_analyses_archive      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_clusters_archive  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_plans_archive     ENABLE ROW LEVEL SECURITY;

-- IVE-COMMERCIAL-STABILITY-08 (Codex adversarial review, round 3) —
-- DROP IF EXISTS first so this migration is safely re-runnable
-- (CREATE POLICY has no IF NOT EXISTS form in Postgres).
DROP POLICY IF EXISTS "Users read own gap_analyses_archive" ON public.gap_analyses_archive;
DROP POLICY IF EXISTS "Users read own content_clusters_archive" ON public.content_clusters_archive;
DROP POLICY IF EXISTS "Users read own revenue_plans_archive" ON public.revenue_plans_archive;

CREATE POLICY "Users read own gap_analyses_archive"
  ON public.gap_analyses_archive FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users read own content_clusters_archive"
  ON public.content_clusters_archive FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users read own revenue_plans_archive"
  ON public.revenue_plans_archive FOR SELECT
  USING (auth.uid() = user_id);

-- ── Step 4: enforce the invariant going forward on the LIVE tables.
--
-- Deliberately NOT a partial index (`WHERE market_analysis_id IS NOT
-- NULL`) despite that being the more explicit statement of intent: a
-- partial unique index cannot be used as an `ON CONFLICT (column)` target
-- unless the exact same WHERE clause is repeated in the conflict clause
-- itself (verified live: PostgREST's upsert — and this app's own
-- supabase-dart client — has no way to express that partial predicate),
-- so `.upsert(..., onConflict: 'market_analysis_id')` would fail with
-- "there is no unique or exclusion constraint matching the ON CONFLICT
-- specification" against a partial index. A plain (non-partial) unique
-- index already gives the exact same real-world guarantee here: Postgres
-- treats NULLs as pairwise distinct in a unique index/constraint
-- regardless of partiality, so rows with market_analysis_id IS NULL
-- (the separate project-only revenue-plan flow) are still completely
-- unaffected either way.
CREATE UNIQUE INDEX IF NOT EXISTS gap_analyses_one_per_market_analysis
  ON public.gap_analyses (market_analysis_id);

CREATE UNIQUE INDEX IF NOT EXISTS content_clusters_one_per_market_analysis
  ON public.content_clusters (market_analysis_id);

CREATE UNIQUE INDEX IF NOT EXISTS revenue_plans_one_per_market_analysis
  ON public.revenue_plans (market_analysis_id);

-- DEPLOY ORDERING (critical): this migration MUST be applied to
-- production BEFORE the application code that upserts on
-- onConflict:'market_analysis_id' (lib/data/services/
-- market_analysis_service.dart's runGapAnalysis/buildContentCluster/
-- buildRevenuePlan) is deployed — upsert has nothing to match against
-- without the unique index above and will fail with
-- "there is no unique or exclusion constraint matching the ON CONFLICT
-- specification". The read-side fix (order by created_at desc, limit 1)
-- in the same file is safe to deploy in any order relative to this
-- migration.
