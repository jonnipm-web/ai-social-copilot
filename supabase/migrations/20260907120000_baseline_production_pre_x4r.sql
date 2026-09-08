-- ============================================================================
-- IVE-X4R-MB2 — CANONICAL PRODUCTION BASELINE (PRE-X4R)
-- ============================================================================
--
-- This is the canonical starting point for this project's migration
-- history, replacing the 22 files archived at
-- docs/legacy-migrations-archive/ (see that directory's README.md for
-- why). It represents LIVE PRODUCTION STATE captured read-only via
-- pg_catalog/information_schema queries during IVE-X4R-MB1/MB1.5/MB2 --
-- not the legacy migration files' stated intent, which in several
-- documented places (recursive profiles_admin_* policies, a duplicate
-- version-001 pair, tables/functions the legacy files never declared)
-- diverges from what is actually live. See docs/legacy-migrations-archive/
-- README.md and POST_BASELINE_HARDENING_BACKLOG.md for the full audit
-- trail (IVE-X4R Gates 1B-1F, MB1, MB1.5).
--
-- Deliberately excluded from this baseline (LIVE FACT, not DESIRED
-- FUTURE STATE):
--   - profiles_admin_select / profiles_admin_update (legacy, recursive,
--     not live -- see docs/legacy-migrations-archive/README.md)
--   - migration 022's search_path hardening on is_admin_user()/
--     handle_new_user() -- migration 022 is not yet applied to
--     production as of this baseline's capture date, and is the FIRST
--     migration after this baseline
--   - action_queue.asset_id / opportunity_lab.asset_id foreign keys are
--     INCLUDED as-is (they already exist live -- MB1.5's report that
--     they were missing was a genuine finding error, corrected during
--     MB2's capture pass and documented in
--     docs/legacy-migrations-archive/POST_BASELINE_HARDENING_BACKLOG.md)
--   - the broader-than-strictly-needed TRUNCATE/REFERENCES/TRIGGER
--     grants to anon/authenticated are NOT re-declared here: no legacy
--     migration ever contained a GRANT statement either -- these come
--     from Supabase's own platform-level default-privilege bootstrap
--     (confirmed live via pg_default_acl during MB1.5), which
--     `supabase start`'s local stack replicates independently of any
--     migration. See POST_BASELINE_HARDENING_BACKLOG.md item H1 for the
--     proposed future tightening -- not applied here.
--
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Extensions
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- FUNCTIONS, PART 1 -- plpgsql only, safe before any table exists (PL/pgSQL
-- function bodies are opaque strings at CREATE time, not validated against
-- the catalog until first execution -- unlike LANGUAGE sql functions,
-- see PART 2 below, found dynamically via this branch's own CI run: a
-- second attempt put ALL functions here and failed with "ERROR: relation
-- public.profiles does not exist" on is_admin_user(), a LANGUAGE sql
-- function, because SQL-language function bodies ARE parsed/validated
-- against the catalog immediately at creation time).
-- Also fixes a first, separate ordering bug: several tables below declare
-- triggers inline that bind to these functions at creation time, so they
-- must all exist before any CREATE TABLE regardless of language.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_executive_contexts_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_project_events_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_asset_id_ownership()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public, pg_catalog'
AS $function$
BEGIN
  IF NEW.asset_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.assets
      WHERE id = NEW.asset_id AND user_id = NEW.user_id
    ) THEN
      RAISE EXCEPTION 'asset_id does not belong to the acting user';
    END IF;
    IF NEW.project_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.assets
      WHERE id = NEW.asset_id AND project_id = NEW.project_id
    ) THEN
      RAISE EXCEPTION 'asset_id does not belong to the specified project';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_asset_parent_ownership()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public, pg_catalog'
AS $function$
BEGIN
  IF NEW.parent_asset_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.assets
      WHERE id = NEW.parent_asset_id
        AND user_id = NEW.user_id
        AND project_id = NEW.project_id
    ) THEN
      RAISE EXCEPTION 'parent_asset_id does not belong to the acting user/project';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_asset_resource_ownership()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public, pg_catalog'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.assets
    WHERE id = NEW.asset_id AND user_id = NEW.user_id
  ) THEN
    RAISE EXCEPTION 'asset_id does not belong to the acting user';
  END IF;
  RETURN NEW;
END;
$function$;

-- ----------------------------------------------------------------------------
-- profiles -- created here (ahead of the main TABLES section) because
-- is_admin_user() and get_current_user_role() below are LANGUAGE sql and
-- must be able to resolve public.profiles at CREATE FUNCTION time.
-- ----------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id            uuid NOT NULL,
  email         text,
  full_name     text,
  role          text NOT NULL DEFAULT 'free',
  monthly_limit integer NOT NULL DEFAULT 5,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT profiles_role_check CHECK (role = ANY (ARRAY['free','pro','premium','beta_tester','admin']))
);

-- ============================================================================
-- FUNCTIONS, PART 2 -- depend on public.profiles existing (two are
-- LANGUAGE sql, validated against the catalog at creation time; the third,
-- handle_new_user, is plpgsql and doesn't strictly require this ordering,
-- but is grouped here for readability since it's profiles-related too).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  insert into public.profiles (id, email)
    values (new.id, new.email)
    on conflict (id) do nothing;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.is_admin_user()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$function$;

CREATE OR REPLACE FUNCTION public.get_current_user_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT role FROM public.profiles WHERE id = auth.uid();
  $function$;

-- ============================================================================
-- TABLES (dependency order; forward/circular references added via ALTER
-- TABLE further below, exactly the way pg_dump itself handles them.
-- profiles was already created above, ahead of this section.)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- personas
-- ----------------------------------------------------------------------------
CREATE TABLE public.personas (
  id                      uuid NOT NULL DEFAULT uuid_generate_v4(),
  owner_id                uuid,
  is_global               boolean NOT NULL DEFAULT false,
  name                    text NOT NULL,
  description             text,
  voice_tone              text,
  target_audience         text,
  niche                   text,
  objectives              text,
  main_language           text NOT NULL DEFAULT 'pt-BR',
  brand_colors            text,
  words_to_use            text[] NOT NULL DEFAULT '{}',
  words_to_avoid          text[] NOT NULL DEFAULT '{}',
  preferred_content_types text[] NOT NULL DEFAULT '{}',
  cta_style               text,
  communication_examples  text,
  specific_rules          text,
  is_active               boolean NOT NULL DEFAULT true,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT personas_pkey PRIMARY KEY (id),
  CONSTRAINT personas_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- projects
-- ----------------------------------------------------------------------------
CREATE TABLE public.projects (
  id                   uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL,
  name                 text NOT NULL,
  description          text NOT NULL DEFAULT '',
  type                 text NOT NULL DEFAULT 'website',
  url                  text,
  opportunity_score    integer NOT NULL DEFAULT 0,
  revenue_potential    numeric NOT NULL DEFAULT 0,
  complexity_score     integer NOT NULL DEFAULT 0,
  priority_score       integer NOT NULL DEFAULT 0,
  time_to_revenue_days integer NOT NULL DEFAULT 0,
  status               text NOT NULL DEFAULT 'idea',
  market_analysis_id   uuid, -- FK to market_analyses added below (circular dependency)
  details_json         jsonb NOT NULL DEFAULT '{}',
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT projects_pkey PRIMARY KEY (id),
  CONSTRAINT projects_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- knowledge_items
-- ----------------------------------------------------------------------------
CREATE TABLE public.knowledge_items (
  id                 uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL,
  title              text NOT NULL,
  source_type        text NOT NULL DEFAULT 'manual',
  source_url         text,
  file_name          text,
  content            text NOT NULL DEFAULT '',
  niche              text,
  target_audience    text,
  language           text NOT NULL DEFAULT 'pt-BR',
  persona_id         uuid,
  status             text NOT NULL DEFAULT 'pending',
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  opportunity_score  integer DEFAULT 0,
  file_type          text,
  file_storage_path  text,
  auto_title         text,
  auto_type          text,
  auto_niche         text,
  auto_audience      text,
  project_id         uuid,
  CONSTRAINT knowledge_items_pkey PRIMARY KEY (id),
  CONSTRAINT knowledge_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT knowledge_items_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.personas(id) ON DELETE SET NULL,
  CONSTRAINT knowledge_items_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL
);
CREATE INDEX knowledge_items_project_id_idx ON public.knowledge_items USING btree (project_id);
CREATE TRIGGER trg_knowledge_items_updated_at BEFORE UPDATE ON public.knowledge_items FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- content_items
-- ----------------------------------------------------------------------------
CREATE TABLE public.content_items (
  id                   uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id              uuid NOT NULL,
  persona_id           uuid,
  title                text NOT NULL,
  type                 text NOT NULL DEFAULT 'texto',
  description          text,
  base_text            text,
  niche                text,
  target_audience      text,
  commercial_objective text,
  language             text NOT NULL DEFAULT 'pt-BR',
  status               text NOT NULL DEFAULT 'active',
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  knowledge_item_id    uuid,
  auto_generated       boolean NOT NULL DEFAULT false,
  keywords             jsonb NOT NULL DEFAULT '[]',
  opportunity_score    integer NOT NULL DEFAULT 0,
  project_id           uuid,
  CONSTRAINT content_items_pkey PRIMARY KEY (id),
  CONSTRAINT content_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT content_items_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.personas(id) ON DELETE SET NULL,
  CONSTRAINT content_items_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL,
  CONSTRAINT content_items_knowledge_item_id_fkey FOREIGN KEY (knowledge_item_id) REFERENCES public.knowledge_items(id) ON DELETE SET NULL
);
CREATE INDEX content_items_project_id_idx ON public.content_items USING btree (project_id);
-- NOTE: no updated_at trigger -- confirmed absent live (MB1.5: the app
-- itself already sets updated_at client-side on every write to this
-- table; see docs/legacy-migrations-archive/POST_BASELINE_HARDENING_
-- BACKLOG.md and MB1.5's report -- not reintroduced here on purpose).

-- ----------------------------------------------------------------------------
-- calendar_items
-- ----------------------------------------------------------------------------
CREATE TABLE public.calendar_items (
  id                 uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id            uuid NOT NULL,
  persona_id         uuid,
  content_item_id    uuid,
  suggested_date     date,
  platform           text,
  theme              text,
  format             text,
  objective          text,
  cta                text,
  status             text NOT NULL DEFAULT 'ideia'
                       CHECK (status = ANY (ARRAY['ideia','planejado','gerado','aprovado','publicado','arquivado'])),
  generated_content  text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  campaign_id        uuid, -- FK to campaigns added below (created later)
  publication_url    text,
  scheduled_at       timestamptz,
  published_at       timestamptz,
  external_platform  text,
  CONSTRAINT calendar_items_pkey PRIMARY KEY (id),
  CONSTRAINT calendar_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT calendar_items_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.personas(id) ON DELETE SET NULL,
  CONSTRAINT calendar_items_content_item_id_fkey FOREIGN KEY (content_item_id) REFERENCES public.content_items(id) ON DELETE SET NULL
);
-- NOTE: no updated_at trigger -- same as content_items, app-managed, absent live.

-- ----------------------------------------------------------------------------
-- post_generations
-- ----------------------------------------------------------------------------
CREATE TABLE public.post_generations (
  id                   uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL,
  original_text        text NOT NULL,
  improved_text        text NOT NULL,
  professional_version text NOT NULL,
  casual_version       text NOT NULL,
  persuasive_version   text NOT NULL,
  comment_reply        text NOT NULL,
  clarity_score        numeric NOT NULL CHECK (clarity_score BETWEEN 0 AND 10),
  impact_score         numeric NOT NULL CHECK (impact_score BETWEEN 0 AND 10),
  engagement_score     numeric NOT NULL CHECK (engagement_score BETWEEN 0 AND 10),
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT post_generations_pkey PRIMARY KEY (id),
  CONSTRAINT post_generations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
CREATE INDEX post_generations_user_created ON public.post_generations USING btree (user_id, created_at DESC);

-- ----------------------------------------------------------------------------
-- market_analyses
-- ----------------------------------------------------------------------------
CREATE TABLE public.market_analyses (
  id                   uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL,
  input                text NOT NULL,
  input_type           text NOT NULL DEFAULT 'url',
  niche                text,
  sub_niche            text,
  target_audience      text,
  business_type        text,
  value_proposition    text,
  positioning          text,
  monetization_model   text,
  opportunity_score    integer NOT NULL DEFAULT 0,
  status               text NOT NULL DEFAULT 'pending',
  analysis_json        jsonb NOT NULL DEFAULT '{}',
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  coverage_details     jsonb,
  methodology_version  text DEFAULT '2.0',
  context_usage        jsonb,
  project_id           uuid,
  context_snapshot     jsonb,
  source_ids           text[] DEFAULT ARRAY[]::text[],
  coverage             real,
  missing_data         text[] DEFAULT ARRAY[]::text[],
  version              integer DEFAULT 1,
  supersedes_id        uuid,
  confidence           real,
  generated_at         timestamptz,
  deleted_at           timestamptz,
  CONSTRAINT market_analyses_pkey PRIMARY KEY (id),
  CONSTRAINT market_analyses_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT market_analyses_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL,
  CONSTRAINT market_analyses_supersedes_id_fkey FOREIGN KEY (supersedes_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL
);
CREATE INDEX market_analyses_project_id_idx ON public.market_analyses USING btree (project_id);
CREATE INDEX market_analyses_supersedes_id_idx ON public.market_analyses USING btree (supersedes_id);
CREATE INDEX market_analyses_deleted_at_idx ON public.market_analyses USING btree (deleted_at);
CREATE INDEX idx_market_analyses_coverage_details ON public.market_analyses USING gin (coverage_details);

-- ----------------------------------------------------------------------------
-- assets
-- ----------------------------------------------------------------------------
CREATE TABLE public.assets (
  id                  uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL,
  project_id          uuid NOT NULL,
  parent_asset_id     uuid,
  name                text NOT NULL,
  type                text NOT NULL,
  subtype             text,
  description         text,
  status              text NOT NULL DEFAULT 'idea',
  category            text,
  niche               text,
  target_market       text,
  target_audience     text,
  business_model      text,
  revenue_model       text,
  lifecycle_stage     text,
  strategic_priority  integer DEFAULT 0,
  metadata            jsonb NOT NULL DEFAULT '{}',
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assets_pkey PRIMARY KEY (id),
  CONSTRAINT assets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT assets_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE,
  CONSTRAINT assets_parent_asset_id_fkey FOREIGN KEY (parent_asset_id) REFERENCES public.assets(id) ON DELETE SET NULL,
  CONSTRAINT assets_no_self_reference CHECK (id <> parent_asset_id),
  CONSTRAINT assets_name_not_empty CHECK (char_length(TRIM(BOTH FROM name)) > 0),
  CONSTRAINT assets_type_not_empty CHECK (char_length(TRIM(BOTH FROM type)) > 0),
  CONSTRAINT assets_type_valid CHECK (type = ANY (ARRAY['product','service','book','series','website','app','course','content_property','brand','module','market','niche','technology','intellectual_property','other'])),
  CONSTRAINT assets_status_valid CHECK (status = ANY (ARRAY['idea','research','validation','planned','active','paused','completed','archived']))
);
CREATE INDEX idx_assets_user_id ON public.assets USING btree (user_id);
CREATE INDEX idx_assets_project_id ON public.assets USING btree (project_id);
CREATE INDEX idx_assets_parent_asset_id ON public.assets USING btree (parent_asset_id) WHERE (parent_asset_id IS NOT NULL);
CREATE INDEX idx_assets_status ON public.assets USING btree (status);
CREATE INDEX idx_assets_type ON public.assets USING btree (type);
CREATE INDEX idx_assets_niche ON public.assets USING btree (niche) WHERE (niche IS NOT NULL);
CREATE INDEX idx_assets_user_project ON public.assets USING btree (user_id, project_id);
CREATE TRIGGER trg_assets_updated_at BEFORE UPDATE ON public.assets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- asset_resources
-- ----------------------------------------------------------------------------
CREATE TABLE public.asset_resources (
  id               uuid NOT NULL DEFAULT gen_random_uuid(),
  asset_id         uuid NOT NULL,
  user_id          uuid NOT NULL,
  resource_type    text NOT NULL DEFAULT 'resource',
  title            text NOT NULL,
  description      text,
  source_type      text,
  source_id        text,
  source_name      text,
  source_url       text,
  parser_version   text,
  confidence       double precision NOT NULL DEFAULT 1.0,
  raw_text         text,
  structured_data  jsonb,
  storage_path     text,
  mime_type        text,
  size_bytes       bigint,
  fingerprint      text,
  metadata         jsonb NOT NULL DEFAULT '{}',
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT asset_resources_pkey PRIMARY KEY (id),
  CONSTRAINT asset_resources_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id) ON DELETE CASCADE,
  CONSTRAINT asset_resources_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT asset_resources_title_not_empty CHECK (char_length(TRIM(BOTH FROM title)) > 0),
  CONSTRAINT asset_resources_type_valid CHECK (resource_type = ANY (ARRAY['resource','evidence','reference','document','image','url','text','data'])),
  CONSTRAINT asset_resources_confidence_range CHECK (confidence >= 0::double precision AND confidence <= 1::double precision)
);
CREATE INDEX idx_asset_resources_asset_id ON public.asset_resources USING btree (asset_id);
CREATE INDEX idx_asset_resources_user_id ON public.asset_resources USING btree (user_id);
CREATE INDEX idx_asset_resources_user_asset ON public.asset_resources USING btree (user_id, asset_id);
CREATE INDEX idx_asset_resources_resource_type ON public.asset_resources USING btree (resource_type);
CREATE INDEX idx_asset_resources_source_url ON public.asset_resources USING btree (source_url) WHERE (source_url IS NOT NULL);
CREATE INDEX idx_asset_resources_fingerprint ON public.asset_resources USING btree (fingerprint) WHERE (fingerprint IS NOT NULL);
CREATE TRIGGER trg_asset_resources_updated_at BEFORE UPDATE ON public.asset_resources FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- campaigns
-- ----------------------------------------------------------------------------
CREATE TABLE public.campaigns (
  id                 uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL,
  knowledge_item_id  uuid,
  title              text NOT NULL DEFAULT '',
  objective          text NOT NULL DEFAULT 'venda',
  duration_days      integer NOT NULL DEFAULT 30,
  channels           text[] DEFAULT '{}',
  campaign_json      jsonb NOT NULL DEFAULT '{}',
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT campaigns_pkey PRIMARY KEY (id),
  CONSTRAINT campaigns_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT campaigns_knowledge_item_id_fkey FOREIGN KEY (knowledge_item_id) REFERENCES public.knowledge_items(id) ON DELETE SET NULL
);
CREATE TRIGGER trg_campaigns_updated_at BEFORE UPDATE ON public.campaigns FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- campaign_calendar
-- ----------------------------------------------------------------------------
CREATE TABLE public.campaign_calendar (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  campaign_id   uuid NOT NULL,
  user_id       uuid NOT NULL,
  day_number    integer NOT NULL DEFAULT 1,
  channel       text NOT NULL DEFAULT '',
  content_type  text NOT NULL DEFAULT '',
  topic         text,
  cta           text,
  content_json  jsonb DEFAULT '{}',
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT campaign_calendar_pkey PRIMARY KEY (id),
  CONSTRAINT campaign_calendar_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE,
  CONSTRAINT campaign_calendar_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
-- NOTE: no UPDATE policy exists live for this table (see policies section
-- below) -- confirmed unused by the application entirely (MB1.5); not
-- added here, matching live state exactly.

-- ----------------------------------------------------------------------------
-- knowledge_analysis
-- ----------------------------------------------------------------------------
CREATE TABLE public.knowledge_analysis (
  id                        uuid NOT NULL DEFAULT gen_random_uuid(),
  knowledge_item_id         uuid NOT NULL,
  user_id                   uuid NOT NULL,
  summary                   text,
  keywords_primary          text[] DEFAULT '{}',
  keywords_secondary        text[] DEFAULT '{}',
  keywords_longtail         text[] DEFAULT '{}',
  entities                  text[] DEFAULT '{}',
  topics                    text[] DEFAULT '{}',
  content_pillars           text[] DEFAULT '{}',
  audience_pain_points      text[] DEFAULT '{}',
  audience_desires          text[] DEFAULT '{}',
  commercial_angles         text[] DEFAULT '{}',
  ctas                      text[] DEFAULT '{}',
  campaign_ideas            text[] DEFAULT '{}',
  post_ideas                text[] DEFAULT '{}',
  article_ideas             text[] DEFAULT '{}',
  seo_opportunities         text[] DEFAULT '{}',
  adsense_opportunities     text[] DEFAULT '{}',
  amazon_kdp_opportunities  text[] DEFAULT '{}',
  score_seo                 integer DEFAULT 0,
  score_adsense             integer DEFAULT 0,
  score_amazon_kdp          integer DEFAULT 0,
  score_linkedin            integer DEFAULT 0,
  score_social              integer DEFAULT 0,
  score_details             jsonb DEFAULT '{}',
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  score_opportunity         integer DEFAULT 0,
  score_hotmart             integer DEFAULT 0,
  score_shopify             integer DEFAULT 0,
  hotmart_data              jsonb DEFAULT '{}',
  shopify_data              jsonb DEFAULT '{}',
  persona_training          jsonb DEFAULT '{}',
  project_id                uuid,
  CONSTRAINT knowledge_analysis_pkey PRIMARY KEY (id),
  CONSTRAINT knowledge_analysis_item_id_unique UNIQUE (knowledge_item_id),
  CONSTRAINT knowledge_analysis_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT knowledge_analysis_knowledge_item_id_fkey FOREIGN KEY (knowledge_item_id) REFERENCES public.knowledge_items(id) ON DELETE CASCADE,
  CONSTRAINT knowledge_analysis_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL
);
CREATE INDEX knowledge_analysis_project_id_idx ON public.knowledge_analysis USING btree (project_id);
CREATE TRIGGER trg_knowledge_analysis_updated_at BEFORE UPDATE ON public.knowledge_analysis FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- knowledge_strategies
-- ----------------------------------------------------------------------------
CREATE TABLE public.knowledge_strategies (
  id                 uuid NOT NULL DEFAULT gen_random_uuid(),
  knowledge_item_id  uuid NOT NULL,
  user_id            uuid NOT NULL,
  strategy_json      jsonb NOT NULL DEFAULT '{}',
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT knowledge_strategies_pkey PRIMARY KEY (id),
  CONSTRAINT knowledge_strategies_knowledge_item_id_key UNIQUE (knowledge_item_id),
  CONSTRAINT knowledge_strategies_knowledge_item_id_fkey FOREIGN KEY (knowledge_item_id) REFERENCES public.knowledge_items(id) ON DELETE CASCADE,
  CONSTRAINT knowledge_strategies_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
CREATE TRIGGER trg_knowledge_strategies_updated_at BEFORE UPDATE ON public.knowledge_strategies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----------------------------------------------------------------------------
-- business_memory
-- ----------------------------------------------------------------------------
CREATE TABLE public.business_memory (
  id                uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL,
  project_id        uuid,
  memory_type       text NOT NULL,
  title             text NOT NULL DEFAULT '',
  content           text DEFAULT '',
  confidence_score  integer DEFAULT 50,
  source            text DEFAULT '',
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_memory_pkey PRIMARY KEY (id),
  CONSTRAINT business_memory_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT business_memory_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL
);
CREATE INDEX idx_business_memory_user ON public.business_memory USING btree (user_id);
CREATE INDEX idx_business_memory_project ON public.business_memory USING btree (project_id);
CREATE INDEX idx_business_memory_type ON public.business_memory USING btree (memory_type);

-- ----------------------------------------------------------------------------
-- opportunity_lab
-- ----------------------------------------------------------------------------
CREATE TABLE public.opportunity_lab (
  id                  uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL,
  project_id          uuid,
  opportunity_type    text NOT NULL DEFAULT 'expansão',
  title               text NOT NULL DEFAULT '',
  description         text DEFAULT '',
  market_score        integer DEFAULT 0,
  revenue_score       integer DEFAULT 0,
  competition_score   integer DEFAULT 0,
  synergy_score       integer DEFAULT 0,
  strategic_fit       integer DEFAULT 0,
  final_score         integer DEFAULT 0,
  status              text DEFAULT 'pending',
  created_at          timestamptz DEFAULT now(),
  market_analysis_id  uuid,
  asset_id            uuid,
  origin              text DEFAULT 'manual',
  sources             jsonb DEFAULT '[]',
  rationale           text,
  confidence          integer DEFAULT 0,
  risks               jsonb DEFAULT '[]',
  action_steps        jsonb DEFAULT '[]',
  CONSTRAINT opportunity_lab_pkey PRIMARY KEY (id),
  CONSTRAINT opportunity_lab_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT opportunity_lab_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL,
  CONSTRAINT opportunity_lab_market_analysis_id_fkey FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL,
  CONSTRAINT opportunity_lab_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id) ON DELETE SET NULL,
  CONSTRAINT opportunity_lab_confidence_check CHECK (confidence >= 0 AND confidence <= 100)
);
CREATE INDEX idx_opportunity_lab_user ON public.opportunity_lab USING btree (user_id);
CREATE INDEX idx_opportunity_lab_project ON public.opportunity_lab USING btree (project_id);
CREATE INDEX idx_opportunity_lab_project_id ON public.opportunity_lab USING btree (project_id);
CREATE INDEX idx_opportunity_lab_analysis ON public.opportunity_lab USING btree (market_analysis_id);
CREATE INDEX idx_opportunity_lab_asset_id ON public.opportunity_lab USING btree (asset_id) WHERE (asset_id IS NOT NULL);
CREATE INDEX idx_opportunity_lab_user_asset ON public.opportunity_lab USING btree (user_id, asset_id) WHERE (asset_id IS NOT NULL);
CREATE INDEX idx_opportunity_lab_status ON public.opportunity_lab USING btree (status);
CREATE TRIGGER trg_opportunity_lab_asset_ownership BEFORE INSERT OR UPDATE ON public.opportunity_lab FOR EACH ROW EXECUTE FUNCTION public.validate_asset_id_ownership();

-- ----------------------------------------------------------------------------
-- action_queue
-- ----------------------------------------------------------------------------
CREATE TABLE public.action_queue (
  id                   uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL,
  project_id           uuid,
  action_type          text NOT NULL DEFAULT 'task',
  title                text NOT NULL DEFAULT '',
  priority             integer DEFAULT 0,
  impact_score         integer DEFAULT 0,
  effort_score         integer DEFAULT 0,
  roi_score            integer DEFAULT 0,
  status               text DEFAULT 'pending',
  created_at           timestamptz DEFAULT now(),
  opportunity_lab_id   uuid,
  asset_id             uuid,
  origin               text DEFAULT 'manual',
  sources              jsonb DEFAULT '[]',
  rationale            text,
  confidence           integer DEFAULT 0,
  risks                jsonb DEFAULT '[]',
  action_steps         jsonb DEFAULT '[]',
  description          text DEFAULT '',
  market_score         integer DEFAULT 0,
  market_analysis_id   uuid,
  plan                 jsonb DEFAULT '[]',
  CONSTRAINT action_queue_pkey PRIMARY KEY (id),
  CONSTRAINT action_queue_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT action_queue_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL,
  CONSTRAINT action_queue_market_analysis_id_fkey FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL,
  CONSTRAINT action_queue_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id) ON DELETE SET NULL,
  CONSTRAINT action_queue_opportunity_lab_id_fkey FOREIGN KEY (opportunity_lab_id) REFERENCES public.opportunity_lab(id) ON DELETE SET NULL
);
CREATE INDEX idx_action_queue_user ON public.action_queue USING btree (user_id);
CREATE INDEX idx_action_queue_project ON public.action_queue USING btree (project_id);
CREATE INDEX idx_action_queue_project_id ON public.action_queue USING btree (project_id);
CREATE INDEX action_queue_market_analysis_id_idx ON public.action_queue USING btree (market_analysis_id);
CREATE INDEX idx_action_queue_asset_id ON public.action_queue USING btree (asset_id) WHERE (asset_id IS NOT NULL);
CREATE INDEX idx_action_queue_user_asset ON public.action_queue USING btree (user_id, asset_id) WHERE (asset_id IS NOT NULL);
CREATE INDEX idx_action_queue_opportunity ON public.action_queue USING btree (opportunity_lab_id);
CREATE INDEX idx_action_queue_status ON public.action_queue USING btree (status);
CREATE TRIGGER trg_action_queue_asset_ownership BEFORE INSERT OR UPDATE ON public.action_queue FOR EACH ROW EXECUTE FUNCTION public.validate_asset_id_ownership();

-- ----------------------------------------------------------------------------
-- advisor_profiles
-- ----------------------------------------------------------------------------
CREATE TABLE public.advisor_profiles (
  id                        uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id                   uuid NOT NULL,
  advisor_name              text NOT NULL DEFAULT 'Atlas',
  advisor_role              text NOT NULL DEFAULT 'Geral',
  advisor_style             text NOT NULL DEFAULT 'Executivo',
  advisor_avatar            text DEFAULT '',
  advisor_personality_json  jsonb DEFAULT '{}',
  created_at                timestamptz DEFAULT now(),
  CONSTRAINT advisor_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT advisor_profiles_user_id_key UNIQUE (user_id),
  CONSTRAINT advisor_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
CREATE INDEX idx_advisor_profiles_user ON public.advisor_profiles USING btree (user_id);

-- ----------------------------------------------------------------------------
-- competitors
-- ----------------------------------------------------------------------------
CREATE TABLE public.competitors (
  id                  uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL,
  market_analysis_id  uuid,
  name                text NOT NULL,
  url                 text NOT NULL,
  type                text NOT NULL DEFAULT 'direct',
  similarity_score    integer NOT NULL DEFAULT 0,
  authority_score     integer NOT NULL DEFAULT 0,
  relevance_score     integer NOT NULL DEFAULT 0,
  details_json        jsonb NOT NULL DEFAULT '{}',
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT competitors_pkey PRIMARY KEY (id),
  CONSTRAINT competitors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT competitors_market_analysis_id_fkey FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- content_clusters
-- ----------------------------------------------------------------------------
CREATE TABLE public.content_clusters (
  id                  uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL,
  market_analysis_id  uuid,
  main_keyword        text NOT NULL,
  clusters            jsonb NOT NULL DEFAULT '[]',
  silos               jsonb NOT NULL DEFAULT '[]',
  articles            jsonb NOT NULL DEFAULT '[]',
  editorial_roadmap   jsonb NOT NULL DEFAULT '[]',
  seo_structure       jsonb NOT NULL DEFAULT '{}',
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT content_clusters_pkey PRIMARY KEY (id),
  CONSTRAINT content_clusters_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT content_clusters_market_analysis_id_fkey FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- copilot_sessions / copilot_messages / copilot_context
-- ----------------------------------------------------------------------------
CREATE TABLE public.copilot_sessions (
  id             uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL,
  title          text DEFAULT '',
  context_json   jsonb DEFAULT '{}',
  status         text DEFAULT 'active',
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now(),
  CONSTRAINT copilot_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT copilot_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
CREATE INDEX idx_copilot_sessions_user ON public.copilot_sessions USING btree (user_id);

CREATE TABLE public.copilot_messages (
  id          uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id  uuid NOT NULL,
  user_id     uuid NOT NULL,
  role        text NOT NULL DEFAULT 'user',
  content     text NOT NULL DEFAULT '',
  created_at  timestamptz DEFAULT now(),
  CONSTRAINT copilot_messages_pkey PRIMARY KEY (id),
  CONSTRAINT copilot_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT copilot_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.copilot_sessions(id) ON DELETE CASCADE
);
CREATE INDEX idx_copilot_messages_session ON public.copilot_messages USING btree (session_id);
CREATE INDEX idx_copilot_messages_user ON public.copilot_messages USING btree (user_id);

CREATE TABLE public.copilot_context (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL,
  context_type  text NOT NULL DEFAULT 'general',
  context_data  jsonb DEFAULT '{}',
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now(),
  CONSTRAINT copilot_context_pkey PRIMARY KEY (id),
  CONSTRAINT copilot_context_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
CREATE INDEX idx_copilot_context_user ON public.copilot_context USING btree (user_id);

-- ----------------------------------------------------------------------------
-- gap_analyses / niche_rankings / opportunities
-- ----------------------------------------------------------------------------
CREATE TABLE public.gap_analyses (
  id                   uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL,
  market_analysis_id   uuid,
  content_gaps         jsonb NOT NULL DEFAULT '[]',
  seo_gaps             jsonb NOT NULL DEFAULT '[]',
  authority_gaps       jsonb NOT NULL DEFAULT '[]',
  monetization_gaps    jsonb NOT NULL DEFAULT '[]',
  product_gaps         jsonb NOT NULL DEFAULT '[]',
  analysis_json        jsonb NOT NULL DEFAULT '{}',
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT gap_analyses_pkey PRIMARY KEY (id),
  CONSTRAINT gap_analyses_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT gap_analyses_market_analysis_id_fkey FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL
);

CREATE TABLE public.niche_rankings (
  id                    uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL,
  market_analysis_id    uuid,
  name                  text NOT NULL,
  level                 text NOT NULL DEFAULT 'niche',
  description           text NOT NULL DEFAULT '',
  competition_score     integer NOT NULL DEFAULT 0,
  potential_score       integer NOT NULL DEFAULT 0,
  growth_score          integer NOT NULL DEFAULT 0,
  monetization_score    integer NOT NULL DEFAULT 0,
  difficulty_score      integer NOT NULL DEFAULT 0,
  trend_score           integer NOT NULL DEFAULT 0,
  overall_score         integer NOT NULL DEFAULT 0,
  details_json          jsonb NOT NULL DEFAULT '{}',
  created_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT niche_rankings_pkey PRIMARY KEY (id),
  CONSTRAINT niche_rankings_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT niche_rankings_market_analysis_id_fkey FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL
);

CREATE TABLE public.opportunities (
  id                    uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL,
  market_analysis_id    uuid,
  title                 text NOT NULL,
  type                  text NOT NULL DEFAULT 'content',
  description           text NOT NULL DEFAULT '',
  opportunity_score     integer NOT NULL DEFAULT 0,
  market_score          integer NOT NULL DEFAULT 0,
  growth_score          integer NOT NULL DEFAULT 0,
  competition_score     integer NOT NULL DEFAULT 0,
  monetization_score    integer NOT NULL DEFAULT 0,
  difficulty_score      integer NOT NULL DEFAULT 0,
  details_json          jsonb NOT NULL DEFAULT '{}',
  created_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT opportunities_pkey PRIMARY KEY (id),
  CONSTRAINT opportunities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT opportunities_market_analysis_id_fkey FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- performance_metrics
-- ----------------------------------------------------------------------------
CREATE TABLE public.performance_metrics (
  id                  uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL,
  campaign_id         uuid,
  content_id          uuid,
  knowledge_item_id   uuid,
  platform            text NOT NULL,
  impressions         integer NOT NULL DEFAULT 0,
  clicks              integer NOT NULL DEFAULT 0,
  likes               integer NOT NULL DEFAULT 0,
  comments             integer NOT NULL DEFAULT 0,
  shares              integer NOT NULL DEFAULT 0,
  saves               integer NOT NULL DEFAULT 0,
  leads               integer NOT NULL DEFAULT 0,
  sales               integer NOT NULL DEFAULT 0,
  revenue             numeric NOT NULL DEFAULT 0,
  ctr                 numeric NOT NULL DEFAULT 0,
  engagement_rate     numeric NOT NULL DEFAULT 0,
  conversion_rate     numeric NOT NULL DEFAULT 0,
  notes               text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT performance_metrics_pkey PRIMARY KEY (id),
  CONSTRAINT performance_metrics_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT performance_metrics_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE SET NULL,
  CONSTRAINT performance_metrics_content_id_fkey FOREIGN KEY (content_id) REFERENCES public.content_items(id) ON DELETE SET NULL,
  CONSTRAINT performance_metrics_knowledge_item_id_fkey FOREIGN KEY (knowledge_item_id) REFERENCES public.knowledge_items(id) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- persona_training
-- ----------------------------------------------------------------------------
CREATE TABLE public.persona_training (
  id                  uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL,
  persona_id          uuid NOT NULL,
  knowledge_item_id   uuid,
  training_summary    text,
  tone_profile_json   jsonb NOT NULL DEFAULT '{}',
  vocabulary_json     jsonb NOT NULL DEFAULT '[]',
  brand_values_json   jsonb NOT NULL DEFAULT '[]',
  positioning_json    jsonb NOT NULL DEFAULT '{}',
  audience_json       jsonb NOT NULL DEFAULT '{}',
  examples_json       jsonb NOT NULL DEFAULT '[]',
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT persona_training_pkey PRIMARY KEY (id),
  CONSTRAINT persona_training_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT persona_training_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.personas(id) ON DELETE CASCADE,
  CONSTRAINT persona_training_knowledge_item_id_fkey FOREIGN KEY (knowledge_item_id) REFERENCES public.knowledge_items(id) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- revenue_plans
-- ----------------------------------------------------------------------------
CREATE TABLE public.revenue_plans (
  id                    uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL,
  market_analysis_id    uuid,
  project_name          text NOT NULL,
  monthly_conservative  numeric NOT NULL DEFAULT 0,
  monthly_moderate      numeric NOT NULL DEFAULT 0,
  monthly_aggressive    numeric NOT NULL DEFAULT 0,
  annual_conservative   numeric NOT NULL DEFAULT 0,
  annual_moderate       numeric NOT NULL DEFAULT 0,
  annual_aggressive     numeric NOT NULL DEFAULT 0,
  plan_json             jsonb NOT NULL DEFAULT '{}',
  created_at            timestamptz NOT NULL DEFAULT now(),
  project_id            uuid,
  CONSTRAINT revenue_plans_pkey PRIMARY KEY (id),
  CONSTRAINT revenue_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT revenue_plans_market_analysis_id_fkey FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL,
  CONSTRAINT revenue_plans_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL
);
CREATE INDEX revenue_plans_project_id_idx ON public.revenue_plans USING btree (project_id);
CREATE INDEX idx_revenue_plans_project_name ON public.revenue_plans USING btree (user_id, project_name) WHERE (market_analysis_id IS NULL);

-- ----------------------------------------------------------------------------
-- roi_metrics
-- ----------------------------------------------------------------------------
CREATE TABLE public.roi_metrics (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL,
  project_id    uuid,
  metric_type   text NOT NULL,
  metric_value  numeric NOT NULL DEFAULT 0,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT roi_metrics_pkey PRIMARY KEY (id),
  CONSTRAINT roi_metrics_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT roi_metrics_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- trend_signals
-- ----------------------------------------------------------------------------
CREATE TABLE public.trend_signals (
  id            uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL,
  source        text NOT NULL DEFAULT '',
  keyword       text NOT NULL DEFAULT '',
  trend_score   integer DEFAULT 0,
  growth_rate   double precision DEFAULT 0.0,
  detected_at   timestamptz DEFAULT now(),
  CONSTRAINT trend_signals_pkey PRIMARY KEY (id),
  CONSTRAINT trend_signals_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
CREATE INDEX idx_trend_signals_user ON public.trend_signals USING btree (user_id);
CREATE INDEX idx_trend_signals_keyword ON public.trend_signals USING btree (keyword);

-- ----------------------------------------------------------------------------
-- website_analyses
-- ----------------------------------------------------------------------------
CREATE TABLE public.website_analyses (
  id                    uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL,
  knowledge_item_id     uuid,
  url                   text NOT NULL,
  title                 text,
  description           text,
  score_website         integer NOT NULL DEFAULT 0,
  score_adsense         integer NOT NULL DEFAULT 0,
  score_seo             integer NOT NULL DEFAULT 0,
  score_monetization    integer NOT NULL DEFAULT 0,
  analysis_json         jsonb NOT NULL DEFAULT '{}',
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT website_analyses_pkey PRIMARY KEY (id),
  CONSTRAINT website_analyses_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT website_analyses_knowledge_item_id_fkey FOREIGN KEY (knowledge_item_id) REFERENCES public.knowledge_items(id) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- executive_contexts
-- ----------------------------------------------------------------------------
CREATE TABLE public.executive_contexts (
  id                   uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL,
  project_id           uuid NOT NULL,
  executive_summary    text NOT NULL DEFAULT '',
  health               jsonb NOT NULL DEFAULT '{}',
  decisions            jsonb NOT NULL DEFAULT '[]',
  risks                jsonb NOT NULL DEFAULT '[]',
  relationships        jsonb NOT NULL DEFAULT '[]',
  priority_score       integer NOT NULL DEFAULT 0,
  check_in_due         boolean NOT NULL DEFAULT false,
  last_activity_at     timestamptz,
  last_analysis_at     timestamptz,
  context_version      integer NOT NULL DEFAULT 1,
  generated_at         timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT executive_contexts_pkey PRIMARY KEY (id),
  CONSTRAINT executive_contexts_project_id_key UNIQUE (project_id),
  CONSTRAINT executive_contexts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT executive_contexts_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE,
  CONSTRAINT executive_contexts_priority_score_check CHECK (priority_score >= 0 AND priority_score <= 100)
);
CREATE INDEX executive_contexts_user_id_idx ON public.executive_contexts USING btree (user_id);
CREATE INDEX executive_contexts_project_id_idx ON public.executive_contexts USING btree (project_id);
CREATE INDEX executive_contexts_priority_idx ON public.executive_contexts USING btree (user_id, priority_score DESC);
CREATE INDEX executive_contexts_check_in_idx ON public.executive_contexts USING btree (user_id, check_in_due) WHERE (check_in_due = true);
CREATE TRIGGER executive_contexts_updated_at BEFORE UPDATE ON public.executive_contexts FOR EACH ROW EXECUTE FUNCTION public.update_executive_contexts_updated_at();

-- ----------------------------------------------------------------------------
-- project_events
-- ----------------------------------------------------------------------------
CREATE TABLE public.project_events (
  id                 uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL,
  project_id         uuid NOT NULL,
  event_type         text NOT NULL
                       CHECK (event_type = ANY (ARRAY['project_created','stage_changed','analysis_completed','decision_taken','opportunity_created','document_added','action_completed','check_in','interview_completed','relationship_detected','health_changed','priority_changed'])),
  title              text NOT NULL DEFAULT '',
  description        text NOT NULL DEFAULT '',
  metadata           jsonb NOT NULL DEFAULT '{}',
  source_module      text,
  source_entity_id   uuid,
  idempotency_key    text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT project_events_pkey PRIMARY KEY (id),
  CONSTRAINT project_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT project_events_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE
);
CREATE INDEX project_events_user_id_idx ON public.project_events USING btree (user_id) ;
CREATE INDEX project_events_project_id_idx ON public.project_events USING btree (project_id);
CREATE INDEX project_events_project_created_idx ON public.project_events USING btree (project_id, created_at DESC);
CREATE INDEX project_events_user_created_idx ON public.project_events USING btree (user_id, created_at DESC);
CREATE INDEX project_events_event_type_idx ON public.project_events USING btree (event_type);
CREATE UNIQUE INDEX project_events_idempotency_key_idx ON public.project_events USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);
CREATE TRIGGER project_events_updated_at BEFORE UPDATE ON public.project_events FOR EACH ROW EXECUTE FUNCTION public.update_project_events_updated_at();

-- ----------------------------------------------------------------------------
-- feature_flags (schema only -- reference row content lives in
-- supabase/seed.sql, not here, per SCHEMA vs REFERENCE DATA separation)
-- ----------------------------------------------------------------------------
CREATE TABLE public.feature_flags (
  feature_name  text NOT NULL,
  enabled       boolean DEFAULT false,
  plan_required text DEFAULT 'free',
  created_at    timestamptz DEFAULT now(),
  CONSTRAINT feature_flags_pkey PRIMARY KEY (feature_name)
);

-- ============================================================================
-- Deferred / circular foreign keys (added after both sides exist, exactly
-- the way pg_dump itself sequences genuinely circular references)
-- ============================================================================
ALTER TABLE public.projects
  ADD CONSTRAINT projects_market_analysis_id_fkey
  FOREIGN KEY (market_analysis_id) REFERENCES public.market_analyses(id) ON DELETE SET NULL;

ALTER TABLE public.calendar_items
  ADD CONSTRAINT calendar_items_campaign_id_fkey
  FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE SET NULL;

-- ============================================================================
-- Remaining triggers not already declared alongside their table above
-- ============================================================================
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- NOTE (found during MB2R's dynamic fidelity re-verification): production
-- has ZERO triggers on public.profiles today -- confirmed via a direct,
-- targeted query (`SELECT ... FROM pg_trigger WHERE tgrelid =
-- 'public.profiles'::regclass`, empty result). Migration 001_platform_
-- schema.sql declares `set_profiles_updated_at`, but it is not live,
-- exactly the same "declared but not live" pattern MB1.5 already found
-- for personas/content_items/calendar_items -- profiles itself was never
-- checked for this specifically until now. Not created here, matching
-- live fact over declared intent, per this file's own stated principle.

CREATE TRIGGER trg_assets_parent_ownership BEFORE INSERT OR UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.validate_asset_parent_ownership();

CREATE TRIGGER trg_asset_resource_ownership BEFORE INSERT OR UPDATE ON public.asset_resources
  FOR EACH ROW EXECUTE FUNCTION public.validate_asset_resource_ownership();

-- ============================================================================
-- ROW LEVEL SECURITY (enable on every table; matches live: relrowsecurity
-- =true, relforcerowsecurity=false everywhere, confirmed via pg_class)
-- ============================================================================
ALTER TABLE public.profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_items       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_items         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_items        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_generations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_analyses       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_resources       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_calendar     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_analysis    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_strategies  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_memory       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opportunity_lab       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.action_queue          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.advisor_profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competitors           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_clusters      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.copilot_sessions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.copilot_messages      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.copilot_context       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gap_analyses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.niche_rankings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opportunities         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performance_metrics   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.persona_training      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_plans         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roi_metrics           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trend_signals         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.website_analyses      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.executive_contexts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_events        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags         ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICIES (exactly as captured live via pg_policies -- names, commands,
-- USING/WITH CHECK expressions all verbatim, not paraphrased)
-- ============================================================================

-- profiles -- LIVE shape only. The legacy profiles_admin_select/
-- profiles_admin_update (recursive, dead) are deliberately NOT created.
CREATE POLICY "users_own_profile" ON public.profiles
  FOR ALL USING (auth.uid() = id);
CREATE POLICY "admin_all_profiles" ON public.profiles
  FOR ALL USING (public.get_current_user_role() = 'admin'::text);

-- personas
CREATE POLICY "personas_read" ON public.personas
  FOR SELECT USING (is_global = true OR owner_id = auth.uid());
CREATE POLICY "personas_write" ON public.personas
  FOR ALL USING (owner_id = auth.uid());
CREATE POLICY "admin_personas" ON public.personas
  FOR ALL USING (public.is_admin_user());

-- projects
CREATE POLICY "Users manage own projects" ON public.projects
  FOR ALL USING (auth.uid() = user_id);

-- knowledge_items
CREATE POLICY "ki_select_own" ON public.knowledge_items
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "ki_insert_own" ON public.knowledge_items
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "ki_update_own" ON public.knowledge_items
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "ki_delete_own" ON public.knowledge_items
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());

-- content_items
CREATE POLICY "content_own" ON public.content_items
  FOR ALL USING (user_id = auth.uid());
CREATE POLICY "admin_content" ON public.content_items
  FOR ALL USING (public.is_admin_user());

-- calendar_items
CREATE POLICY "calendar_own" ON public.calendar_items
  FOR ALL USING (user_id = auth.uid());
CREATE POLICY "admin_calendar" ON public.calendar_items
  FOR ALL USING (public.is_admin_user());

-- post_generations
CREATE POLICY "select_own" ON public.post_generations
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "insert_own" ON public.post_generations
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "delete_own" ON public.post_generations
  FOR DELETE USING (auth.uid() = user_id);

-- market_analyses
CREATE POLICY "Users manage own market_analyses" ON public.market_analyses
  FOR ALL USING (auth.uid() = user_id);

-- assets
CREATE POLICY "assets_select_own" ON public.assets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "assets_insert_own" ON public.assets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "assets_update_own" ON public.assets FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "assets_delete_own" ON public.assets FOR DELETE USING (auth.uid() = user_id);

-- asset_resources
CREATE POLICY "asset_resources_select_own" ON public.asset_resources FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "asset_resources_insert_own" ON public.asset_resources FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "asset_resources_update_own" ON public.asset_resources FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "asset_resources_delete_own" ON public.asset_resources FOR DELETE USING (auth.uid() = user_id);

-- campaigns
CREATE POLICY "cp_select_own" ON public.campaigns FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "cp_insert_own" ON public.campaigns FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "cp_update_own" ON public.campaigns FOR UPDATE USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "cp_delete_own" ON public.campaigns FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());

-- campaign_calendar -- LIVE shape: no UPDATE policy exists (confirmed
-- unused by the app entirely, MB1.5). Not added here.
CREATE POLICY "cc_select_own" ON public.campaign_calendar
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "cc_insert_own" ON public.campaign_calendar
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "cc_delete_own" ON public.campaign_calendar
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());

-- knowledge_analysis
CREATE POLICY "ka_select_own" ON public.knowledge_analysis
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "ka_insert_own" ON public.knowledge_analysis
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "ka_update_own" ON public.knowledge_analysis
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "ka_delete_own" ON public.knowledge_analysis
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());

-- knowledge_strategies
CREATE POLICY "ks_select_own" ON public.knowledge_strategies
  FOR SELECT USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "ks_insert_own" ON public.knowledge_strategies
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "ks_update_own" ON public.knowledge_strategies
  FOR UPDATE USING (user_id = auth.uid() OR public.is_admin_user());
CREATE POLICY "ks_delete_own" ON public.knowledge_strategies
  FOR DELETE USING (user_id = auth.uid() OR public.is_admin_user());

-- business_memory
CREATE POLICY "business_memory_user" ON public.business_memory
  FOR ALL USING (auth.uid() = user_id);

-- opportunity_lab
CREATE POLICY "opportunity_lab_user" ON public.opportunity_lab
  FOR ALL USING (auth.uid() = user_id);

-- action_queue
CREATE POLICY "action_queue_user" ON public.action_queue
  FOR ALL USING (auth.uid() = user_id);

-- advisor_profiles
CREATE POLICY "advisor_profiles_user" ON public.advisor_profiles
  FOR ALL USING (auth.uid() = user_id);

-- competitors, content_clusters, market_analyses siblings, etc. -- simple
-- own-user FOR ALL pattern
CREATE POLICY "Users manage own competitors" ON public.competitors
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own content_clusters" ON public.content_clusters
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own gap_analyses" ON public.gap_analyses
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own niche_rankings" ON public.niche_rankings
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own opportunities" ON public.opportunities
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own performance_metrics" ON public.performance_metrics
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own persona_training" ON public.persona_training
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own revenue_plans" ON public.revenue_plans
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own roi_metrics" ON public.roi_metrics
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own website_analyses" ON public.website_analyses
  FOR ALL USING (auth.uid() = user_id);

-- copilot_*
CREATE POLICY "copilot_sessions_user" ON public.copilot_sessions
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "copilot_messages_user" ON public.copilot_messages
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "copilot_context_user" ON public.copilot_context
  FOR ALL USING (auth.uid() = user_id);

-- trend_signals
CREATE POLICY "trend_signals_user" ON public.trend_signals
  FOR ALL USING (auth.uid() = user_id);

-- executive_contexts -- CORRECTED during baseline authoring: MB1.5's
-- report claimed neither executive_contexts nor project_events has an
-- UPDATE policy. Re-verified via a direct pg_policies query while
-- authoring this baseline and found that claim was only correct for
-- project_events -- executive_contexts genuinely DOES have
-- executive_contexts_update_own (USING/WITH CHECK both auth.uid()=
-- user_id). Documented here as a correction, not silently fixed, per
-- this engagement's practice.
CREATE POLICY "executive_contexts_select_own" ON public.executive_contexts
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "executive_contexts_insert_own" ON public.executive_contexts
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM public.projects WHERE projects.id = executive_contexts.project_id AND projects.user_id = auth.uid())
  );
CREATE POLICY "executive_contexts_update_own" ON public.executive_contexts
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "executive_contexts_delete_own" ON public.executive_contexts
  FOR DELETE USING (auth.uid() = user_id);

-- project_events -- LIVE shape: no UPDATE policy, same reasoning.
CREATE POLICY "project_events_select_own" ON public.project_events
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "project_events_insert_own" ON public.project_events
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM public.projects WHERE projects.id = project_events.project_id AND projects.user_id = auth.uid())
  );
CREATE POLICY "project_events_delete_own" ON public.project_events
  FOR DELETE USING (auth.uid() = user_id);

-- feature_flags -- LIVE shape: globally readable, no write policy at all
-- (only postgres/service_role can write).
CREATE POLICY "feature_flags_read" ON public.feature_flags
  FOR SELECT USING (true);
