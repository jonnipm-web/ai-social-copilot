-- ════════════════════════════════════════════════════════════════════════════
-- Migration 011 — Phase 10C: Knowledge Intelligence Layer
-- ════════════════════════════════════════════════════════════════════════════
BEGIN;

-- ── persona_learning_history ─────────────────────────────────────────────
-- Tracks each learning event when a persona processes a knowledge item
CREATE TABLE IF NOT EXISTS public.persona_learning_history (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  persona_id        UUID NOT NULL REFERENCES public.personas(id) ON DELETE CASCADE,
  knowledge_item_id UUID REFERENCES public.knowledge_items(id) ON DELETE SET NULL,
  project_id        UUID REFERENCES public.projects(id) ON DELETE SET NULL,
  learned_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  learning_type     TEXT NOT NULL DEFAULT 'knowledge_item',
  summary           TEXT NOT NULL DEFAULT '',
  confidence_score  INT NOT NULL DEFAULT 50 CHECK (confidence_score BETWEEN 0 AND 100),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_persona_lh_persona ON public.persona_learning_history(persona_id);
CREATE INDEX IF NOT EXISTS idx_persona_lh_user    ON public.persona_learning_history(user_id);

ALTER TABLE public.persona_learning_history ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'persona_learning_history'
      AND policyname = 'user_own_learning_history'
  ) THEN
    CREATE POLICY user_own_learning_history ON public.persona_learning_history
      FOR ALL USING (user_id = auth.uid());
  END IF;
END $$;

-- ── project_intelligence_profiles ────────────────────────────────────────
-- Persisted intelligence profiles per project (computed + cached)
CREATE TABLE IF NOT EXISTS public.project_intelligence_profiles (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id     UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  profile_json   JSONB NOT NULL DEFAULT '{}',
  coverage_score INT NOT NULL DEFAULT 0 CHECK (coverage_score BETWEEN 0 AND 100),
  maturity_stage TEXT NOT NULL DEFAULT 'ideia',
  last_updated   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, project_id)
);

CREATE INDEX IF NOT EXISTS idx_pip_project ON public.project_intelligence_profiles(project_id);
CREATE INDEX IF NOT EXISTS idx_pip_user    ON public.project_intelligence_profiles(user_id);

ALTER TABLE public.project_intelligence_profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'project_intelligence_profiles'
      AND policyname = 'user_own_profiles'
  ) THEN
    CREATE POLICY user_own_profiles ON public.project_intelligence_profiles
      FOR ALL USING (user_id = auth.uid());
  END IF;
END $$;

-- ── knowledge_graph_edges ─────────────────────────────────────────────────
-- Persisted Knowledge Graph relationships between entities
CREATE TABLE IF NOT EXISTS public.knowledge_graph_edges (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_type       TEXT NOT NULL,
  source_id         TEXT NOT NULL,
  source_name       TEXT NOT NULL DEFAULT '',
  target_type       TEXT NOT NULL,
  target_id         TEXT NOT NULL,
  target_name       TEXT NOT NULL DEFAULT '',
  relationship_type TEXT NOT NULL DEFAULT 'related_to',
  weight            FLOAT NOT NULL DEFAULT 1.0 CHECK (weight BETWEEN 0 AND 1),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, source_id, target_id, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_kge_source ON public.knowledge_graph_edges(user_id, source_id);
CREATE INDEX IF NOT EXISTS idx_kge_target ON public.knowledge_graph_edges(user_id, target_id);

ALTER TABLE public.knowledge_graph_edges ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'knowledge_graph_edges'
      AND policyname = 'user_own_graph_edges'
  ) THEN
    CREATE POLICY user_own_graph_edges ON public.knowledge_graph_edges
      FOR ALL USING (user_id = auth.uid());
  END IF;
END $$;

COMMIT;
