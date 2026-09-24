-- IV-QUANT-REAL-DATA-READINESS-03 — technical rate limiting for Quant APIs
-- (Quant Lab only; NOT applied to production). Policy: docs/quant/QUANT_RATE_LIMIT_POLICY.md.
--
-- quant_rate_limit_hit(bucket) is the ONLY way to touch the counters:
--   * identity = auth.uid() (never a parameter) — a forged user_id, plan or
--     role in a request body cannot change whose counter is incremented;
--   * limits live INSIDE the function per bucket (never a parameter), so a
--     direct PostgREST call cannot raise its own limit; unknown buckets are denied;
--   * fixed 60-second window, one atomic INSERT … ON CONFLICT DO UPDATE per hit
--     (row lock serializes concurrent hits of the same user+bucket+window);
--   * the table has RLS enabled and NO policies and no client privileges:
--     counters are neither readable nor writable directly.
-- The TypeScript mirror (supabase/functions/_shared/quant/rate_limit_policy.ts)
-- must match these numbers — enforced by test QB-17.
-- Idempotent.

CREATE TABLE IF NOT EXISTS public.quant_rate_limits (
  user_id      uuid        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  bucket       text        NOT NULL,
  window_start timestamptz NOT NULL,
  hits         integer     NOT NULL DEFAULT 0 CHECK (hits >= 0),
  PRIMARY KEY (user_id, bucket, window_start)
);

ALTER TABLE public.quant_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.quant_rate_limits FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.quant_rate_limits TO service_role;

CREATE OR REPLACE FUNCTION public.quant_rate_limit_hit(p_bucket text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_limit   integer;
  v_window  timestamptz := to_timestamp(floor(extract(epoch FROM clock_timestamp()) / 60) * 60);
  v_hits    integer;
  v_reset   timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthenticated');
  END IF;

  -- Per-minute technical limits (QUANT_RATE_LIMIT_POLICY.md). Not commercial quotas.
  v_limit := CASE p_bucket
    WHEN 'quant-analyze' THEN 30
    WHEN 'quant-watchlists-read' THEN 120
    WHEN 'quant-watchlists-write' THEN 60
    ELSE NULL
  END;
  IF v_limit IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unknown_bucket');
  END IF;

  INSERT INTO public.quant_rate_limits AS r (user_id, bucket, window_start, hits)
  VALUES (v_user_id, p_bucket, v_window, 1)
  ON CONFLICT (user_id, bucket, window_start) DO UPDATE SET hits = r.hits + 1
  RETURNING hits INTO v_hits;

  -- Opportunistic cleanup of this user's old windows (bounded table growth).
  DELETE FROM public.quant_rate_limits
  WHERE user_id = v_user_id AND window_start < v_window - interval '10 minutes';

  v_reset := v_window + interval '60 seconds';
  RETURN jsonb_build_object(
    'allowed', v_hits <= v_limit,
    'limit', v_limit,
    'remaining', greatest(v_limit - v_hits, 0),
    'reset_at', to_char(v_reset AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'retry_after_seconds', greatest(ceil(extract(epoch FROM (v_reset - clock_timestamp())))::int, 1)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.quant_rate_limit_hit(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quant_rate_limit_hit(text) TO authenticated;
