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
-- Codex I5G2-01: the window is FIXED here (60 s) — never a caller argument —
-- and each call deletes the caller's past windows, so a caller holds at most
-- one row per bucket (3 rows) however it calls the RPC directly.
-- Codex I5G2-03: a pre-existing table with a different shape stops the
-- migration (schema-drift guard) instead of being silently accepted.
--
-- Rollback (Lab only; counters are disposable, nothing else references them):
--   DROP FUNCTION IF EXISTS public.impact_rate_limit_hit(text);
--   DROP TABLE IF EXISTS public.impact_rate_limits;
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
-- Schema-drift guard (I5G2-03): exact column set + the expected primary key.
DO $$
BEGIN
  IF (SELECT string_agg(column_name || ':' || data_type, ',' ORDER BY column_name)
        FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'impact_rate_limits')
     IS DISTINCT FROM 'bucket:text,hit_count:integer,updated_at:timestamp with time zone,user_id:uuid,window_start:timestamp with time zone'
  OR NOT EXISTS (
       SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.impact_rate_limits'::regclass AND contype = 'p'
          AND conname = 'impact_rate_limits_pkey'
          AND pg_get_constraintdef(oid) = 'PRIMARY KEY (user_id, bucket, window_start)')
  THEN
    RAISE EXCEPTION 'IMPACT_RATE_LIMIT_SCHEMA_DRIFT: public.impact_rate_limits exists with an unexpected shape';
  END IF;
END $$;

COMMENT ON TABLE public.impact_rate_limits IS
  'Per-caller fixed-window counters for Impact dossier actions. Written only by impact_rate_limit_hit(); no verdict, no content.';

-- The earlier Lab-only draft took a caller-chosen window; it must not survive.
DROP FUNCTION IF EXISTS public.impact_rate_limit_hit(text, integer);

CREATE OR REPLACE FUNCTION public.impact_rate_limit_hit(p_bucket text)
RETURNS TABLE (hit_count integer, window_start timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
  v_user uuid := auth.uid();
  v_window constant integer := 60; -- server-fixed; mirrored by RATE_WINDOW_SECONDS in rate_limit.ts
  v_start timestamptz;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'IMPACT_RATE_LIMIT_UNAUTHENTICATED' USING ERRCODE = '42501';
  END IF;
  IF p_bucket IS NULL OR p_bucket NOT IN ('dossier_build', 'dossier_export', 'dossier_verify') THEN
    RAISE EXCEPTION 'IMPACT_RATE_LIMIT_INVALID' USING ERRCODE = '22023';
  END IF;
  v_start := to_timestamp(floor(extract(epoch FROM now()) / v_window) * v_window);
  -- Bounded housekeeping (I5G2-01): drop ALL of this caller's past windows,
  -- so the table holds at most one current row per (caller, bucket).
  DELETE FROM public.impact_rate_limits r
  WHERE r.user_id = v_user AND r.window_start < v_start;
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

REVOKE ALL ON FUNCTION public.impact_rate_limit_hit(text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.impact_rate_limit_hit(text) TO authenticated;
