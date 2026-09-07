-- ============================================================
-- 004_strategies_campaigns.sql
-- Smart Import Engine + Strategies + Campaigns + Opportunity Score
-- ============================================================

-- ── Extend knowledge_items ───────────────────────────────────
ALTER TABLE public.knowledge_items
  ADD COLUMN IF NOT EXISTS opportunity_score INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS file_type         TEXT,
  ADD COLUMN IF NOT EXISTS file_storage_path TEXT;

-- ── Extend knowledge_analysis ────────────────────────────────
ALTER TABLE public.knowledge_analysis
  ADD COLUMN IF NOT EXISTS score_opportunity INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_hotmart     INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS score_shopify     INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hotmart_data      JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS shopify_data      JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS persona_training  JSONB DEFAULT '{}';

-- ── knowledge_strategies ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.knowledge_strategies (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  knowledge_item_id UUID NOT NULL REFERENCES public.knowledge_items(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  strategy_json     JSONB NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── campaigns ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.campaigns (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  knowledge_item_id UUID REFERENCES public.knowledge_items(id) ON DELETE SET NULL,
  title             TEXT NOT NULL DEFAULT '',
  objective         TEXT NOT NULL DEFAULT 'venda',
  duration_days     INT NOT NULL DEFAULT 30,
  channels          TEXT[] DEFAULT '{}',
  campaign_json     JSONB NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── campaign_calendar ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.campaign_calendar (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id  UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day_number   INT NOT NULL DEFAULT 1,
  channel      TEXT NOT NULL DEFAULT '',
  content_type TEXT NOT NULL DEFAULT '',
  topic        TEXT,
  cta          TEXT,
  content_json JSONB DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Triggers ──────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_knowledge_strategies_updated_at ON public.knowledge_strategies;
CREATE TRIGGER trg_knowledge_strategies_updated_at
  BEFORE UPDATE ON public.knowledge_strategies
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_campaigns_updated_at ON public.campaigns;
CREATE TRIGGER trg_campaigns_updated_at
  BEFORE UPDATE ON public.campaigns
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE public.knowledge_strategies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_calendar    ENABLE ROW LEVEL SECURITY;

-- knowledge_strategies
CREATE POLICY "ks_select_own" ON public.knowledge_strategies
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "ks_insert_own" ON public.knowledge_strategies
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "ks_update_own" ON public.knowledge_strategies
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "ks_delete_own" ON public.knowledge_strategies
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());

-- campaigns
CREATE POLICY "cp_select_own" ON public.campaigns
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "cp_insert_own" ON public.campaigns
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "cp_update_own" ON public.campaigns
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "cp_delete_own" ON public.campaigns
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());

-- campaign_calendar
CREATE POLICY "cc_select_own" ON public.campaign_calendar
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "cc_insert_own" ON public.campaign_calendar
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "cc_delete_own" ON public.campaign_calendar
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());
