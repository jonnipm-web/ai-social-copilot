-- ═══════════════════════════════════════════════════════════════
-- FASE 9 — Market Intelligence Engine
-- ═══════════════════════════════════════════════════════════════

-- ── market_analyses ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS market_analyses (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  input               TEXT        NOT NULL,
  input_type          TEXT        NOT NULL DEFAULT 'url',
  niche               TEXT,
  sub_niche           TEXT,
  target_audience     TEXT,
  business_type       TEXT,
  value_proposition   TEXT,
  positioning         TEXT,
  monetization_model  TEXT,
  opportunity_score   INT         NOT NULL DEFAULT 0,
  status              TEXT        NOT NULL DEFAULT 'pending',
  analysis_json       JSONB       NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE market_analyses ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'market_analyses' AND policyname = 'Users manage own market_analyses'
  ) THEN
    CREATE POLICY "Users manage own market_analyses" ON market_analyses FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── competitors ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS competitors (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  market_analysis_id  UUID        REFERENCES market_analyses(id) ON DELETE SET NULL,
  name                TEXT        NOT NULL,
  url                 TEXT        NOT NULL,
  type                TEXT        NOT NULL DEFAULT 'direct',
  similarity_score    INT         NOT NULL DEFAULT 0,
  authority_score     INT         NOT NULL DEFAULT 0,
  relevance_score     INT         NOT NULL DEFAULT 0,
  details_json        JSONB       NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE competitors ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'competitors' AND policyname = 'Users manage own competitors'
  ) THEN
    CREATE POLICY "Users manage own competitors" ON competitors FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── gap_analyses ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gap_analyses (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  market_analysis_id  UUID        REFERENCES market_analyses(id) ON DELETE SET NULL,
  content_gaps        JSONB       NOT NULL DEFAULT '[]',
  seo_gaps            JSONB       NOT NULL DEFAULT '[]',
  authority_gaps      JSONB       NOT NULL DEFAULT '[]',
  monetization_gaps   JSONB       NOT NULL DEFAULT '[]',
  product_gaps        JSONB       NOT NULL DEFAULT '[]',
  analysis_json       JSONB       NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE gap_analyses ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'gap_analyses' AND policyname = 'Users manage own gap_analyses'
  ) THEN
    CREATE POLICY "Users manage own gap_analyses" ON gap_analyses FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── opportunities ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS opportunities (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  market_analysis_id  UUID        REFERENCES market_analyses(id) ON DELETE SET NULL,
  title               TEXT        NOT NULL,
  type                TEXT        NOT NULL DEFAULT 'content',
  description         TEXT        NOT NULL DEFAULT '',
  opportunity_score   INT         NOT NULL DEFAULT 0,
  market_score        INT         NOT NULL DEFAULT 0,
  growth_score        INT         NOT NULL DEFAULT 0,
  competition_score   INT         NOT NULL DEFAULT 0,
  monetization_score  INT         NOT NULL DEFAULT 0,
  difficulty_score    INT         NOT NULL DEFAULT 0,
  details_json        JSONB       NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE opportunities ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'opportunities' AND policyname = 'Users manage own opportunities'
  ) THEN
    CREATE POLICY "Users manage own opportunities" ON opportunities FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── niche_rankings ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS niche_rankings (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  market_analysis_id  UUID        REFERENCES market_analyses(id) ON DELETE SET NULL,
  name                TEXT        NOT NULL,
  level               TEXT        NOT NULL DEFAULT 'niche',
  description         TEXT        NOT NULL DEFAULT '',
  competition_score   INT         NOT NULL DEFAULT 0,
  potential_score     INT         NOT NULL DEFAULT 0,
  growth_score        INT         NOT NULL DEFAULT 0,
  monetization_score  INT         NOT NULL DEFAULT 0,
  difficulty_score    INT         NOT NULL DEFAULT 0,
  trend_score         INT         NOT NULL DEFAULT 0,
  overall_score       INT         NOT NULL DEFAULT 0,
  details_json        JSONB       NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE niche_rankings ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'niche_rankings' AND policyname = 'Users manage own niche_rankings'
  ) THEN
    CREATE POLICY "Users manage own niche_rankings" ON niche_rankings FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── content_clusters ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS content_clusters (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  market_analysis_id  UUID        REFERENCES market_analyses(id) ON DELETE SET NULL,
  main_keyword        TEXT        NOT NULL,
  clusters            JSONB       NOT NULL DEFAULT '[]',
  silos               JSONB       NOT NULL DEFAULT '[]',
  articles            JSONB       NOT NULL DEFAULT '[]',
  editorial_roadmap   JSONB       NOT NULL DEFAULT '[]',
  seo_structure       JSONB       NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE content_clusters ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'content_clusters' AND policyname = 'Users manage own content_clusters'
  ) THEN
    CREATE POLICY "Users manage own content_clusters" ON content_clusters FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── revenue_plans ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS revenue_plans (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  market_analysis_id    UUID          REFERENCES market_analyses(id) ON DELETE SET NULL,
  project_name          TEXT          NOT NULL,
  monthly_conservative  NUMERIC(12,2) NOT NULL DEFAULT 0,
  monthly_moderate      NUMERIC(12,2) NOT NULL DEFAULT 0,
  monthly_aggressive    NUMERIC(12,2) NOT NULL DEFAULT 0,
  annual_conservative   NUMERIC(12,2) NOT NULL DEFAULT 0,
  annual_moderate       NUMERIC(12,2) NOT NULL DEFAULT 0,
  annual_aggressive     NUMERIC(12,2) NOT NULL DEFAULT 0,
  plan_json             JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
ALTER TABLE revenue_plans ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'revenue_plans' AND policyname = 'Users manage own revenue_plans'
  ) THEN
    CREATE POLICY "Users manage own revenue_plans" ON revenue_plans FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── projects ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS projects (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name                  TEXT          NOT NULL,
  description           TEXT          NOT NULL DEFAULT '',
  type                  TEXT          NOT NULL DEFAULT 'website',
  url                   TEXT,
  opportunity_score     INT           NOT NULL DEFAULT 0,
  revenue_potential     NUMERIC(12,2) NOT NULL DEFAULT 0,
  complexity_score      INT           NOT NULL DEFAULT 0,
  priority_score        INT           NOT NULL DEFAULT 0,
  time_to_revenue_days  INT           NOT NULL DEFAULT 0,
  status                TEXT          NOT NULL DEFAULT 'idea',
  market_analysis_id    UUID          REFERENCES market_analyses(id) ON DELETE SET NULL,
  details_json          JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'projects' AND policyname = 'Users manage own projects'
  ) THEN
    CREATE POLICY "Users manage own projects" ON projects FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── roi_metrics ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS roi_metrics (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id   UUID          REFERENCES projects(id) ON DELETE SET NULL,
  metric_type  TEXT          NOT NULL,
  metric_value NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes        TEXT,
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
ALTER TABLE roi_metrics ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'roi_metrics' AND policyname = 'Users manage own roi_metrics'
  ) THEN
    CREATE POLICY "Users manage own roi_metrics" ON roi_metrics FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;
