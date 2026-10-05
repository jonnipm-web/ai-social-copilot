-- INSIGHTVALUES-COMMERCIAL-V1-FINAL-CLOSURE-01 — quota drift + ACL fix.
--
-- Corrects two defects in the function applied by 20261004000001:
--   1. v_free_limit was set to 5 instead of the approved commercial value 15.
--   2. anon role retained EXECUTE (PUBLIC revoke did not strip it explicitly).
--
-- Approved quota (canonical decision from InsightValues Commercial V1):
--   free users     → max 15 insights per calendar month, per project
--   pro/premium    → unlimited
--   admin          → unlimited
--
-- All security hardening from 20261004000001 is preserved:
--   auth.uid() null-guard, project ownership check (RLS bypass coverage),
--   COALESCE on v_is_pro (NULL = free, Codex P1), to_jsonb() casts,
--   SECURITY DEFINER, pinned search_path.

CREATE OR REPLACE FUNCTION public.save_insight_quota_checked(
  p_project_id       uuid,
  p_title            text,
  p_description      text,
  p_confidence       int,
  p_sources          text[],
  p_action_steps     text[],
  p_opportunity_type text DEFAULT 'expansão'
)
RETURNS SETOF public.opportunity_lab
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid             uuid   := auth.uid();
  v_count           int;
  v_is_pro          boolean := false;
  v_first_of_month  timestamptz;
  v_free_limit      constant int := 15;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Project ownership check: SECURITY DEFINER bypasses RLS, so we must
  -- explicitly verify ownership here (mirrors opportunity_lab's WITH CHECK).
  IF NOT EXISTS (
    SELECT 1 FROM public.projects
     WHERE id = p_project_id AND user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'project_not_found';
  END IF;

  -- Resolve entitlement (missing profile → treat as free).
  -- COALESCE required: SELECT INTO sets target to NULL when no row is
  -- found (PL/pgSQL documented behaviour). Without COALESCE, a missing
  -- profile row makes v_is_pro NULL; IF NOT NULL evaluates as false in
  -- PL/pgSQL → quota block skipped → unlimited inserts. (Codex P1)
  SELECT COALESCE((role IN ('pro', 'premium', 'admin')), false)
    INTO v_is_pro
    FROM public.profiles
   WHERE id = v_uid;

  IF NOT v_is_pro THEN
    v_first_of_month := date_trunc('month', now() AT TIME ZONE 'UTC');

    SELECT COUNT(*)
      INTO v_count
      FROM public.opportunity_lab
     WHERE user_id   = v_uid
       AND project_id = p_project_id
       AND origin     = 'ive_analysis'
       AND created_at >= v_first_of_month;

    IF v_count >= v_free_limit THEN
      RAISE EXCEPTION 'quota_exceeded';
    END IF;
  END IF;

  RETURN QUERY
    INSERT INTO public.opportunity_lab (
      user_id, project_id, title, description,
      confidence, sources, action_steps, origin,
      opportunity_type
    )
    VALUES (
      v_uid, p_project_id, p_title, p_description,
      p_confidence, to_jsonb(p_sources), to_jsonb(p_action_steps), 'ive_analysis',
      p_opportunity_type
    )
    RETURNING *;
END;
$$;

-- ACL: authenticated only.
-- Explicit anon revoke in addition to PUBLIC, because anon may have
-- inherited or been directly granted EXECUTE before this correction.
REVOKE ALL ON FUNCTION public.save_insight_quota_checked(
  uuid, text, text, int, text[], text[], text
) FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.save_insight_quota_checked(
  uuid, text, text, int, text[], text[], text
) FROM anon;

GRANT EXECUTE ON FUNCTION public.save_insight_quota_checked(
  uuid, text, text, int, text[], text[], text
) TO authenticated;
