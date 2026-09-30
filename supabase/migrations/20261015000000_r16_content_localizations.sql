-- R16 — GLOBAL END-TO-END LANGUAGE CONSISTENCY — presentation localization cache.
--
-- Stores, per (user, source row, target language), a TRANSLATED
-- PRESENTATION of persisted content (historical AI output + a few original
-- user fields such as projects.description). Written ONLY by the
-- `localize-content` Edge Function (service_role) after it has verified the
-- caller owns the source row. Originals are never modified (R16 §8): the
-- source tables are untouched by this migration and by the function.
--
-- Additive only: one new table, no change to existing tables, no data
-- migration. Rollback: supabase/rollbacks/20261015000000_r16_content_localizations.down.sql
--
-- Access model: RLS enabled with NO policy for anon/authenticated -> clients
-- cannot read or write this table directly; the function returns the rows it
-- is allowed to return. service_role bypasses RLS (Supabase default).

CREATE TABLE IF NOT EXISTS public.content_localizations (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_table     text NOT NULL CHECK (source_table IN (
                     'projects', 'knowledge_analysis', 'knowledge_strategies', 'campaigns',
                     'market_analyses', 'competitors', 'gap_analyses', 'opportunities',
                     'niche_rankings', 'content_clusters', 'revenue_plans', 'website_analyses',
                     'opportunity_lab', 'action_queue')),
  source_id        uuid NOT NULL,
  target_language  text NOT NULL CHECK (target_language IN ('pt-BR', 'en-US')),
  source_hash      text NOT NULL CHECK (char_length(source_hash) = 64),
  source_language  text CHECK (source_language IS NULL OR char_length(source_language) <= 16),
  payload          jsonb NOT NULL,
  model            text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, source_table, source_id, target_language)
);

CREATE INDEX IF NOT EXISTS idx_content_localizations_user_updated
  ON public.content_localizations (user_id, updated_at);

ALTER TABLE public.content_localizations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.content_localizations FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.content_localizations TO service_role;

COMMENT ON TABLE public.content_localizations IS
  'R16: cached presentation translations of persisted content. Written only by the localize-content Edge Function (service_role) after ownership check; originals are never modified.';
