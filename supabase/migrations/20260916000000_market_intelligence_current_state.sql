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
--     REPLACE the current result, not append to a history. Same pattern in
--     content_cluster_screen.dart / revenue_planner_screen.dart (their
--     "Gerar" forms only appear before a result exists, and there is no
--     separate history view anywhere in these three screens).
--   - Data: production has exactly ONE existing duplicate — gap_analyses,
--     market_analysis_id 26d5ce9b-1f38-47a6-97b9-e74e6f1f44c0, two rows for
--     the SAME user, created 1m28s apart (2026-08-01 14:19:20 and
--     14:20:48), with IDENTICAL gap counts in every category — consistent
--     with a user re-running the same analysis, not two distinct analyses.
--     content_clusters and revenue_plans have ZERO existing duplicates.
-- This is a CURRENT-STATE relationship (option A per mission spec), not a
-- versioned/historical one — so reconciliation-by-keep-latest is correct,
-- and a UNIQUE constraint is the right invariant going forward.
--
-- market_analysis_id is nullable on all three tables (a row may exist
-- without being linked to any analysis — e.g. revenue_plans' existing
-- idx_revenue_plans_project_name covers a separate project-only flow with
-- market_analysis_id IS NULL). A plain UNIQUE index/constraint on a
-- nullable column already treats NULLs as pairwise distinct in Postgres
-- (never conflicts with each other), so the project-only revenue-plan flow
-- is completely unaffected by this migration.
--
-- SAFE FOR EXISTING DUPLICATES: reconciliation (step 1, per table) runs
-- BEFORE the unique index is created (step 2), keeping only the most
-- recent row (by created_at) per market_analysis_id. This is NOT a blind
-- "ADD UNIQUE and hope it passes" — the delete is scoped to exactly the
-- duplicate condition and verified via a read-only dry run (see mission
-- report) to affect only the one known production duplicate before this
-- migration is ever applied.

-- ── Step 1: reconciliation — keep the most recent row per
--    market_analysis_id, delete older duplicates. A no-op wherever no
--    duplicate exists (the overwhelming majority of rows).
DELETE FROM public.gap_analyses ga
USING (
  SELECT id, row_number() OVER (
    PARTITION BY market_analysis_id ORDER BY created_at DESC, id DESC
  ) AS rn
  FROM public.gap_analyses
  WHERE market_analysis_id IS NOT NULL
) dup
WHERE ga.id = dup.id AND dup.rn > 1;

DELETE FROM public.content_clusters cc
USING (
  SELECT id, row_number() OVER (
    PARTITION BY market_analysis_id ORDER BY created_at DESC, id DESC
  ) AS rn
  FROM public.content_clusters
  WHERE market_analysis_id IS NOT NULL
) dup
WHERE cc.id = dup.id AND dup.rn > 1;

DELETE FROM public.revenue_plans rp
USING (
  SELECT id, row_number() OVER (
    PARTITION BY market_analysis_id ORDER BY created_at DESC, id DESC
  ) AS rn
  FROM public.revenue_plans
  WHERE market_analysis_id IS NOT NULL
) dup
WHERE rp.id = dup.id AND dup.rn > 1;

-- ── Step 2: enforce the invariant going forward.
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
