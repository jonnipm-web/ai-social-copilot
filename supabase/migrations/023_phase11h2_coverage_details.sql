-- 023_phase11h2_coverage_details.sql
-- Phase 11H.2: coverage explicável, metodologia versionada, rastreabilidade context_usage

ALTER TABLE market_analyses
  ADD COLUMN IF NOT EXISTS coverage_details    JSONB,
  ADD COLUMN IF NOT EXISTS methodology_version TEXT,
  ADD COLUMN IF NOT EXISTS context_usage       JSONB;

-- post-check
-- SELECT id, methodology_version, coverage, coverage_details IS NOT NULL AS has_details
-- FROM market_analyses
-- WHERE created_at > NOW() - INTERVAL '1 hour'
-- ORDER BY created_at DESC
-- LIMIT 10;
