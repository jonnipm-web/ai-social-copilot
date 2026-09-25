-- IV-IMPACT-I5-PRODUCT-UX-01 — server-authoritative dossier rate limit
-- (closes Codex I4G3-04).
--
-- STATUS: Impact Lab only. NOT applied to production by this mission.
--
-- Same pattern as the existing AI quota (20260910190000): a counter table no
-- client can write, and ONE SECURITY DEFINER function that derives identity
-- from auth.uid() only — never from a parameter — and increments atomically
-- (a single INSERT … ON CONFLICT DO UPDATE statement: concurrent requests
-- serialize on the row lock and can never undercount).
--
-- The impact-lab Edge Function calls it with the CALLER'S session client
-- before any ownership check, compares the returned count with its own
-- server-side limit, and answers 429 RATE_LIMITED. No service_role privilege
-- is added (SERVICE_ROLE_TRUST_GATE = LAB_ONLY unchanged).
--
-- Rollback (Lab): DROP FUNCTION public.impact_rate_limit_hit(text, integer);
--   DROP TABLE public.impact_rate_limits;
-- Idempotent: safe to re-run.

CREATE TABLE IF NOT EXISTS public.impact_rate_limits (
  user_id      uuid        NOT NULL,
  bucket       text        NOT NULL,
  window_start timestamptz NOT NULL,
  hit_count    integer     NOT NULL DEFAULT 0,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT impact_rate_limits_pkey PRIMARY KEY (user_id, bucket, window_start),
  CONSTRAINT impact_rate_limits_user_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT impact_rate_limits_bucket_check CHECK (bucket IN ('dossier_build', 'dossier_export', 'dossier_verify')),
  CONSTRAINT impact_rate_limits_count_check CHECK (hit_count >= 0)
);
COMMENT ON TABLE public.impact_rate_limits IS
  'Per-caller fixed-window counters for Impact dossier actions. Written only by impact_rate_limit_hit(); no verdict, no content.';

CREATE OR REPLACE FUNCTION public.impact_rate_limit_hit(p_bucket text, p_window_seconds integer)
RETURNS TABLE (hit_count integer, window_start timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
  v_user uuid := auth.uid();
  v_start timestamptz;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'IMPACT_RATE_LIMIT_UNAUTHENTICATED' USING ERRCODE = '42501';
  END IF;
  IF p_bucket IS NULL OR p_bucket NOT IN ('dossier_build', 'dossier_export', 'dossier_verify')
     OR p_window_seconds IS NULL OR p_window_seconds < 10 OR p_window_seconds > 3600 THEN
    RAISE EXCEPTION 'IMPACT_RATE_LIMIT_INVALID' USING ERRCODE = '22023';
  END IF;
  v_start := to_timestamp(floor(extract(epoch FROM now()) / p_window_seconds) * p_window_seconds);
  -- Bounded housekeeping: only this caller's windows older than a day.
  DELETE FROM public.impact_rate_limits r
  WHERE r.user_id = v_user AND r.window_start < now() - interval '1 day';
  RETURN QUERY
  INSERT INTO public.impact_rate_limits AS r (user_id, bucket, window_start, hit_count)
  VALUES (v_user, p_bucket, v_start, 1)
  ON CONFLICT (user_id, bucket, window_start)
  DO UPDATE SET hit_count = r.hit_count + 1, updated_at = now()
  RETURNING r.hit_count, r.window_start;
END $$;

ALTER TABLE public.impact_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.impact_rate_limits FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.impact_rate_limits TO authenticated;
DROP POLICY IF EXISTS impact_rate_limits_select_own ON public.impact_rate_limits;
CREATE POLICY impact_rate_limits_select_own ON public.impact_rate_limits FOR SELECT TO authenticated
  USING (user_id = auth.uid());

REVOKE ALL ON FUNCTION public.impact_rate_limit_hit(text, integer) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.impact_rate_limit_hit(text, integer) TO authenticated;
