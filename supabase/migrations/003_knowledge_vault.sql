-- ============================================================
-- 003_knowledge_vault.sql
-- Tabelas para o Cofre de Conhecimento (Knowledge Vault)
-- ============================================================

-- ── knowledge_items ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.knowledge_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title          TEXT NOT NULL,
  source_type    TEXT NOT NULL DEFAULT 'manual',  -- manual | url | file
  source_url     TEXT,
  file_name      TEXT,
  content        TEXT NOT NULL DEFAULT '',
  niche          TEXT,
  target_audience TEXT,
  language       TEXT NOT NULL DEFAULT 'pt-BR',
  persona_id     UUID REFERENCES public.personas(id) ON DELETE SET NULL,
  status         TEXT NOT NULL DEFAULT 'pending', -- pending | processing | analyzed | error
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── knowledge_analysis ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.knowledge_analysis (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  knowledge_item_id         UUID NOT NULL REFERENCES public.knowledge_items(id) ON DELETE CASCADE,
  user_id                   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  summary                   TEXT,
  keywords_primary          TEXT[] DEFAULT '{}',
  keywords_secondary        TEXT[] DEFAULT '{}',
  keywords_longtail         TEXT[] DEFAULT '{}',
  entities                  TEXT[] DEFAULT '{}',
  topics                    TEXT[] DEFAULT '{}',
  content_pillars           TEXT[] DEFAULT '{}',
  audience_pain_points      TEXT[] DEFAULT '{}',
  audience_desires          TEXT[] DEFAULT '{}',
  commercial_angles         TEXT[] DEFAULT '{}',
  ctas                      TEXT[] DEFAULT '{}',
  campaign_ideas            TEXT[] DEFAULT '{}',
  post_ideas                TEXT[] DEFAULT '{}',
  article_ideas             TEXT[] DEFAULT '{}',
  seo_opportunities         TEXT[] DEFAULT '{}',
  adsense_opportunities     TEXT[] DEFAULT '{}',
  amazon_kdp_opportunities  TEXT[] DEFAULT '{}',
  score_seo                 INT DEFAULT 0,
  score_adsense             INT DEFAULT 0,
  score_amazon_kdp          INT DEFAULT 0,
  score_linkedin            INT DEFAULT 0,
  score_social              INT DEFAULT 0,
  score_details             JSONB DEFAULT '{}',
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── updated_at trigger ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_knowledge_items_updated_at ON public.knowledge_items;
CREATE TRIGGER trg_knowledge_items_updated_at
  BEFORE UPDATE ON public.knowledge_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_knowledge_analysis_updated_at ON public.knowledge_analysis;
CREATE TRIGGER trg_knowledge_analysis_updated_at
  BEFORE UPDATE ON public.knowledge_analysis
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── RLS ─────────────────────────────────────────────────────
ALTER TABLE public.knowledge_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_analysis ENABLE ROW LEVEL SECURITY;

-- Função auxiliar (SECURITY DEFINER) para evitar recursão
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- knowledge_items: usuário vê somente os seus; admin vê todos
CREATE POLICY "ki_select_own" ON public.knowledge_items
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());

CREATE POLICY "ki_insert_own" ON public.knowledge_items
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "ki_update_own" ON public.knowledge_items
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin_user());

CREATE POLICY "ki_delete_own" ON public.knowledge_items
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());

-- knowledge_analysis: mesmo padrão
CREATE POLICY "ka_select_own" ON public.knowledge_analysis
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());

CREATE POLICY "ka_insert_own" ON public.knowledge_analysis
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "ka_update_own" ON public.knowledge_analysis
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin_user());

CREATE POLICY "ka_delete_own" ON public.knowledge_analysis
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());
