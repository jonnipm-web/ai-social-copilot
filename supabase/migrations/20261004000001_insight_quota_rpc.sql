-- MACRO-08 P1-Q1/Q2: server-side quota enforcement for IVE Analysis insights.
--
-- Moves the insightFreeMonthlyLimit check from the Flutter client into a
-- SECURITY DEFINER function so the limit cannot be bypassed by calling the
-- table directly.  The client-side gate in IveAnalysisScreen._isQuotaBlocked()
-- stays as a UX fast-path; this function is the authoritative gate.
--
-- Quota rule (mirrors AppConstants.insightFreeMonthlyLimit = 5):
--   free users   → max 5 insights per calendar month, per project
--   pro/premium/admin → unlimited

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
  v_free_limit      constant int := 5;
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

  -- Resolve entitlement (missing profile → treat as free)
  SELECT (role IN ('pro', 'premium', 'admin'))
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
      p_confidence, p_sources, p_action_steps, 'ive_analysis',
      p_opportunity_type
    )
    RETURNING *;
END;
$$;

-- Only authenticated users may call this function
REVOKE ALL ON FUNCTION public.save_insight_quota_checked(
  uuid, text, text, int, text[], text[], text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.save_insight_quota_checked(
  uuid, text, text, int, text[], text[], text
) TO authenticated;
