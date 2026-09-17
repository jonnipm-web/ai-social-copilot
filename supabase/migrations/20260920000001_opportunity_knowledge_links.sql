-- COMMERCIAL-EXPERIENCE-CLOSURE-16 — Section 17/18 (Opportunity <-> Knowledge
-- Vault integration). Owner-mandated: "New Opportunity" must let the user
-- reference relevant Knowledge Vault items belonging to the CURRENT project
-- (mission Section 01.6), storing REFERENCES rather than duplicating
-- Knowledge content (Section 18).
--
-- `opportunity_lab` already has a generic `sources jsonb` column, but it is
-- populated today by the market-analysis/auto-bootstrap pipeline as
-- free-text display labels (e.g. competitor names, data sources) rendered
-- directly as chips in the UI -- overloading it with structured knowledge_item
-- UUIDs would make that existing rendering path ambiguous. A dedicated,
-- narrowly-purposed column is the smaller, safer change.
--
-- Security: cross-USER leakage is closed by knowledge_items' own RLS
-- (`user_id = auth.uid()`, verified via pg_policies before writing this
-- migration) -- a ref to another user's knowledge item simply fails to
-- resolve for the viewer. No new RLS is needed on opportunity_lab itself
-- (already scoped by its own `opportunity_lab_user` policy, unchanged by
-- this migration).
--
-- Codex Gate (COMMERCIAL-EXPERIENCE-CLOSURE-16, P1 ACCEPTED) found the
-- narrower but real gap this first version of the migration missed:
-- cross-PROJECT leakage within the SAME user's account. The client picker
-- (_AddOpportunityDialog._knowledgeSection) only ever offers the active
-- project's own knowledge, but nothing server-side stopped a write from
-- containing a knowledge_items id that belongs to a DIFFERENT project of
-- the same user (or to no project) -- and the detail screen
-- (_LinkedKnowledgeSection) resolves and displays whatever ids are stored,
-- by id alone, with no project check. Under normal client usage this
-- never happens, but "the UI currently prevents it" is a client-only
-- guarantee, not a server-enforced one -- exactly the class of gap
-- mission Section 19 ("Project isolation — non-negotiable... No
-- cross-project mixing") and this repo's own CLASS D review criteria
-- ("Is validation client-only?") exist to catch. The trigger below closes
-- it structurally: any id that does not belong to a knowledge_items row
-- owned by the SAME user AND matching the opportunity's own project_id
-- (NULL-safe: a project-less opportunity may only reference project-less
-- knowledge, never "any project") is silently dropped from the array
-- before the row is ever written -- chosen over rejecting the write
-- outright because a stale/already-invalid id (e.g. the opportunity's
-- project was changed after linking) should not block an otherwise-valid
-- save, per the same "fail safely, don't break legitimate use" principle
-- already used elsewhere in this schema (see route_policy.dart's
-- unclassified-route handling for the same philosophy in a different
-- layer). SECURITY INVOKER (not DEFINER): must run with the CALLING
-- user's own RLS in effect on the knowledge_items lookup, so it can only
-- ever validate against knowledge that user can already see -- there is
-- no privilege escalation surface here to guard against.
--
-- ADDITIVE ONLY.
--
-- ROLLBACK:
--   DROP TRIGGER IF EXISTS opportunity_lab_filter_knowledge_links ON public.opportunity_lab;
--   DROP FUNCTION IF EXISTS public.filter_opportunity_knowledge_links();
--   ALTER TABLE public.opportunity_lab DROP COLUMN IF EXISTS knowledge_item_ids;

ALTER TABLE public.opportunity_lab
  ADD COLUMN IF NOT EXISTS knowledge_item_ids jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.opportunity_lab.knowledge_item_ids IS
  'Array of knowledge_items.id (uuid, stored as jsonb strings) the user explicitly linked when creating/editing this opportunity. References only -- actual content stays in knowledge_items, protected by its own RLS. Every write is filtered by filter_opportunity_knowledge_links() to ids owned by the same user AND matching this opportunity''s own project_id (NULL-safe) -- see that function for the full rationale.';

CREATE OR REPLACE FUNCTION public.filter_opportunity_knowledge_links()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = 'public'
AS $function$
DECLARE
  filtered jsonb;
BEGIN
  IF NEW.knowledge_item_ids IS NULL OR jsonb_array_length(NEW.knowledge_item_ids) = 0 THEN
    NEW.knowledge_item_ids := '[]'::jsonb;
    RETURN NEW;
  END IF;

  SELECT coalesce(jsonb_agg(ki.id::text), '[]'::jsonb)
  INTO filtered
  FROM knowledge_items ki
  WHERE ki.id::text IN (
          SELECT jsonb_array_elements_text(NEW.knowledge_item_ids)
        )
    AND ki.user_id = NEW.user_id
    -- NULL-safe equality: a project-less opportunity (NEW.project_id IS
    -- NULL) may only reference project-less knowledge, never knowledge
    -- from an arbitrary project -- "no active project -> no knowledge"
    -- (mission Section 19) applies here too, not just in the client UI.
    AND ki.project_id IS NOT DISTINCT FROM NEW.project_id;

  NEW.knowledge_item_ids := filtered;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS opportunity_lab_filter_knowledge_links ON public.opportunity_lab;
CREATE TRIGGER opportunity_lab_filter_knowledge_links
  BEFORE INSERT OR UPDATE OF knowledge_item_ids, project_id ON public.opportunity_lab
  FOR EACH ROW
  EXECUTE FUNCTION public.filter_opportunity_knowledge_links();
