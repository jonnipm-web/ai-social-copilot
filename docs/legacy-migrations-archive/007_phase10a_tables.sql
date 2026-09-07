-- ============================================================
-- Fase 10A — Business Operating System Foundation
-- ============================================================

-- ── M7: Feature Flags (deve vir primeiro — outras tabelas podem referenciar) ──
CREATE TABLE IF NOT EXISTS feature_flags (
  feature_name  TEXT PRIMARY KEY,
  enabled       BOOLEAN   DEFAULT FALSE,
  plan_required TEXT      DEFAULT 'free',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "feature_flags_read" ON feature_flags;
CREATE POLICY "feature_flags_read" ON feature_flags
  FOR SELECT USING (true);

INSERT INTO feature_flags (feature_name, enabled, plan_required) VALUES
  ('business_memory_enabled', true,  'free'),
  ('ecosystem_view_enabled',  true,  'free'),
  ('advisor_enabled',         false, 'premium'),
  ('opportunity_lab_enabled', false, 'pro'),
  ('action_engine_enabled',   false, 'pro'),
  ('copilot_enabled',         false, 'premium')
ON CONFLICT (feature_name) DO NOTHING;

-- ── M1: Business Memory Engine ────────────────────────────────
CREATE TABLE IF NOT EXISTS business_memory (
  id               UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id          UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  project_id       UUID        REFERENCES projects(id)   ON DELETE SET NULL,
  memory_type      TEXT        NOT NULL,
  title            TEXT        NOT NULL DEFAULT '',
  content          TEXT        DEFAULT '',
  confidence_score INT         DEFAULT 50,
  source           TEXT        DEFAULT '',
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE business_memory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "business_memory_user" ON business_memory;
CREATE POLICY "business_memory_user" ON business_memory
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_business_memory_user   ON business_memory(user_id);
CREATE INDEX IF NOT EXISTS idx_business_memory_type   ON business_memory(memory_type);
CREATE INDEX IF NOT EXISTS idx_business_memory_project ON business_memory(project_id);

-- ── M2: Advisor Profiles ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS advisor_profiles (
  id                      UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id                 UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  advisor_name            TEXT        NOT NULL DEFAULT 'Atlas',
  advisor_role            TEXT        NOT NULL DEFAULT 'Geral',
  advisor_style           TEXT        NOT NULL DEFAULT 'Executivo',
  advisor_avatar          TEXT        DEFAULT '',
  advisor_personality_json JSONB      DEFAULT '{}',
  created_at              TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE advisor_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "advisor_profiles_user" ON advisor_profiles;
CREATE POLICY "advisor_profiles_user" ON advisor_profiles
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_advisor_profiles_user ON advisor_profiles(user_id);

-- ── M4: Opportunity Lab ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS opportunity_lab (
  id               UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id          UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  project_id       UUID        REFERENCES projects(id)   ON DELETE SET NULL,
  opportunity_type TEXT        NOT NULL DEFAULT 'expansão',
  title            TEXT        NOT NULL DEFAULT '',
  description      TEXT        DEFAULT '',
  market_score     INT         DEFAULT 0,
  revenue_score    INT         DEFAULT 0,
  competition_score INT        DEFAULT 0,
  synergy_score    INT         DEFAULT 0,
  strategic_fit    INT         DEFAULT 0,
  final_score      INT         DEFAULT 0,
  status           TEXT        DEFAULT 'pending',
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE opportunity_lab ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "opportunity_lab_user" ON opportunity_lab;
CREATE POLICY "opportunity_lab_user" ON opportunity_lab
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_opportunity_lab_user    ON opportunity_lab(user_id);
CREATE INDEX IF NOT EXISTS idx_opportunity_lab_project ON opportunity_lab(project_id);
CREATE INDEX IF NOT EXISTS idx_opportunity_lab_status  ON opportunity_lab(status);

-- ── M5: Action Queue ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS action_queue (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  project_id   UUID        REFERENCES projects(id)   ON DELETE SET NULL,
  action_type  TEXT        NOT NULL DEFAULT 'task',
  title        TEXT        NOT NULL DEFAULT '',
  priority     INT         DEFAULT 0,
  impact_score INT         DEFAULT 0,
  effort_score INT         DEFAULT 0,
  roi_score    INT         DEFAULT 0,
  status       TEXT        DEFAULT 'pending',
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE action_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "action_queue_user" ON action_queue;
CREATE POLICY "action_queue_user" ON action_queue
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_action_queue_user    ON action_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_action_queue_status  ON action_queue(status);
CREATE INDEX IF NOT EXISTS idx_action_queue_project ON action_queue(project_id);

-- ── M8: Business Copilot Foundation ──────────────────────────
CREATE TABLE IF NOT EXISTS copilot_sessions (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title        TEXT        DEFAULT '',
  context_json JSONB       DEFAULT '{}',
  status       TEXT        DEFAULT 'active',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE copilot_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "copilot_sessions_user" ON copilot_sessions;
CREATE POLICY "copilot_sessions_user" ON copilot_sessions
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_copilot_sessions_user ON copilot_sessions(user_id);

CREATE TABLE IF NOT EXISTS copilot_messages (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID        REFERENCES copilot_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id    UUID        REFERENCES auth.users(id)        ON DELETE CASCADE NOT NULL,
  role       TEXT        NOT NULL DEFAULT 'user',
  content    TEXT        NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE copilot_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "copilot_messages_user" ON copilot_messages;
CREATE POLICY "copilot_messages_user" ON copilot_messages
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_copilot_messages_session ON copilot_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_copilot_messages_user    ON copilot_messages(user_id);

CREATE TABLE IF NOT EXISTS copilot_context (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  context_type TEXT        NOT NULL DEFAULT 'general',
  context_data JSONB       DEFAULT '{}',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE copilot_context ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "copilot_context_user" ON copilot_context;
CREATE POLICY "copilot_context_user" ON copilot_context
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_copilot_context_user ON copilot_context(user_id);

-- ── M10: Trend Signals (Fase 11 Preparation) ──────────────────
CREATE TABLE IF NOT EXISTS trend_signals (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  source      TEXT        NOT NULL DEFAULT '',
  keyword     TEXT        NOT NULL DEFAULT '',
  trend_score INT         DEFAULT 0,
  growth_rate FLOAT       DEFAULT 0.0,
  detected_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE trend_signals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "trend_signals_user" ON trend_signals;
CREATE POLICY "trend_signals_user" ON trend_signals
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_trend_signals_user    ON trend_signals(user_id);
CREATE INDEX IF NOT EXISTS idx_trend_signals_keyword ON trend_signals(keyword);
