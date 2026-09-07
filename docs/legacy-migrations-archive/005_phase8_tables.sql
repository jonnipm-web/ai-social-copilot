-- ═══════════════════════════════════════════════════════════════
-- FASE 8 — Knowledge + Strategy + Marketing + Monetization OS
-- ═══════════════════════════════════════════════════════════════

-- Adicionar colunas às tabelas existentes (IF NOT EXISTS para segurança)

ALTER TABLE knowledge_items
  ADD COLUMN IF NOT EXISTS opportunity_score INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS auto_title TEXT,
  ADD COLUMN IF NOT EXISTS auto_type TEXT,
  ADD COLUMN IF NOT EXISTS auto_niche TEXT,
  ADD COLUMN IF NOT EXISTS auto_audience TEXT;

ALTER TABLE content_items
  ADD COLUMN IF NOT EXISTS knowledge_item_id UUID REFERENCES knowledge_items(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS auto_generated BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS keywords JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS opportunity_score INT NOT NULL DEFAULT 0;

ALTER TABLE calendar_items
  ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS publication_url TEXT,
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS external_platform TEXT;

-- ── persona_training ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS persona_training (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  persona_id        UUID        NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
  knowledge_item_id UUID        REFERENCES knowledge_items(id) ON DELETE SET NULL,
  training_summary  TEXT,
  tone_profile_json JSONB       NOT NULL DEFAULT '{}',
  vocabulary_json   JSONB       NOT NULL DEFAULT '[]',
  brand_values_json JSONB       NOT NULL DEFAULT '[]',
  positioning_json  JSONB       NOT NULL DEFAULT '{}',
  audience_json     JSONB       NOT NULL DEFAULT '{}',
  examples_json     JSONB       NOT NULL DEFAULT '[]',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE persona_training ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'persona_training' AND policyname = 'Users manage own persona_training'
  ) THEN
    CREATE POLICY "Users manage own persona_training" ON persona_training
      FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── performance_metrics ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS performance_metrics (
  id                UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID           NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  campaign_id       UUID           REFERENCES campaigns(id) ON DELETE SET NULL,
  content_id        UUID           REFERENCES content_items(id) ON DELETE SET NULL,
  knowledge_item_id UUID           REFERENCES knowledge_items(id) ON DELETE SET NULL,
  platform          TEXT           NOT NULL,
  impressions       INT            NOT NULL DEFAULT 0,
  clicks            INT            NOT NULL DEFAULT 0,
  likes             INT            NOT NULL DEFAULT 0,
  comments          INT            NOT NULL DEFAULT 0,
  shares            INT            NOT NULL DEFAULT 0,
  saves             INT            NOT NULL DEFAULT 0,
  leads             INT            NOT NULL DEFAULT 0,
  sales             INT            NOT NULL DEFAULT 0,
  revenue           NUMERIC(12,2)  NOT NULL DEFAULT 0,
  ctr               NUMERIC(6,2)   NOT NULL DEFAULT 0,
  engagement_rate   NUMERIC(6,2)   NOT NULL DEFAULT 0,
  conversion_rate   NUMERIC(6,2)   NOT NULL DEFAULT 0,
  notes             TEXT,
  created_at        TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

ALTER TABLE performance_metrics ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'performance_metrics' AND policyname = 'Users manage own performance_metrics'
  ) THEN
    CREATE POLICY "Users manage own performance_metrics" ON performance_metrics
      FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;

-- ── website_analyses ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS website_analyses (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  knowledge_item_id   UUID        REFERENCES knowledge_items(id) ON DELETE SET NULL,
  url                 TEXT        NOT NULL,
  title               TEXT,
  description         TEXT,
  score_website       INT         NOT NULL DEFAULT 0,
  score_adsense       INT         NOT NULL DEFAULT 0,
  score_seo           INT         NOT NULL DEFAULT 0,
  score_monetization  INT         NOT NULL DEFAULT 0,
  analysis_json       JSONB       NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE website_analyses ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'website_analyses' AND policyname = 'Users manage own website_analyses'
  ) THEN
    CREATE POLICY "Users manage own website_analyses" ON website_analyses
      FOR ALL USING (auth.uid() = user_id);
  END IF;
END $$;
