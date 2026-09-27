-- IV-QUANT-REAL-DATA-READINESS-03 — tests for public.quant_rate_limit_hit and
-- public.quant_rate_limits (migration 20260924000100). DISPOSABLE database
-- only. A clean run ends with 'QUANT_RATE_LIMITS: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

INSERT INTO auth.users (id, email) VALUES
  ('5a000000-0000-4000-8000-00000000000a', 'rla@test.invalid'),
  ('5b000000-0000-4000-8000-00000000000b', 'rlb@test.invalid')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', uid, false);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', false);
END $$;

-- ── R01 anonymous cannot call the function or touch the table ─────────
SELECT set_config('request.jwt.claim.sub', '', false);
SET ROLE anon;
DO $$ BEGIN
  BEGIN PERFORM public.quant_rate_limit_hit('quant-analyze'); RAISE EXCEPTION 'R01 anon executed the limiter';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM 1 FROM public.quant_rate_limits; RAISE EXCEPTION 'R01 anon read counters';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- ── R02 within / at / over limit; unknown bucket denied; counters private ──
SELECT pg_temp.act_as('5a000000-0000-4000-8000-00000000000a');
SET ROLE authenticated;
DO $$
DECLARE r jsonb; i int;
BEGIN
  FOR i IN 1..30 LOOP
    r := public.quant_rate_limit_hit('quant-analyze');
    IF NOT (r->>'allowed')::boolean THEN RAISE EXCEPTION 'R02 hit % denied within limit: %', i, r; END IF;
  END LOOP;
  IF (r->>'remaining')::int <> 0 OR (r->>'limit')::int <> 30 THEN RAISE EXCEPTION 'R02 at-limit metadata wrong: %', r; END IF;
  r := public.quant_rate_limit_hit('quant-analyze');
  IF (r->>'allowed')::boolean THEN RAISE EXCEPTION 'R02 31st hit allowed'; END IF;
  IF (r->>'retry_after_seconds')::int NOT BETWEEN 1 AND 60 THEN RAISE EXCEPTION 'R02 retry_after out of range: %', r; END IF;
  r := public.quant_rate_limit_hit('admin-bypass');
  IF (r->>'allowed')::boolean OR r->>'reason' <> 'unknown_bucket' THEN RAISE EXCEPTION 'R02 unknown bucket not denied: %', r; END IF;
  -- other buckets are independent
  r := public.quant_rate_limit_hit('quant-watchlists-read');
  IF NOT (r->>'allowed')::boolean OR (r->>'limit')::int <> 120 THEN RAISE EXCEPTION 'R02 read bucket wrong: %', r; END IF;
  r := public.quant_rate_limit_hit('quant-watchlists-write');
  IF (r->>'limit')::int <> 60 THEN RAISE EXCEPTION 'R02 write bucket wrong: %', r; END IF;
  -- Codex Final: ingress bucket consumed before the watchlist body is read.
  r := public.quant_rate_limit_hit('quant-watchlists-ingress');
  IF NOT (r->>'allowed')::boolean OR (r->>'limit')::int <> 180 THEN RAISE EXCEPTION 'R02 ingress bucket wrong: %', r; END IF;
  BEGIN PERFORM 1 FROM public.quant_rate_limits; RAISE EXCEPTION 'R02 authenticated can read counters';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE public.quant_rate_limits SET hits = 0; RAISE EXCEPTION 'R02 authenticated can reset counters';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- ── R03 another user has an independent counter ───────────────────────
SELECT pg_temp.act_as('5b000000-0000-4000-8000-00000000000b');
SET ROLE authenticated;
DO $$ DECLARE r jsonb; BEGIN
  r := public.quant_rate_limit_hit('quant-analyze');
  IF NOT (r->>'allowed')::boolean OR (r->>'remaining')::int <> 29 THEN RAISE EXCEPTION 'R03 user B affected by user A: %', r; END IF;
END $$;
RESET ROLE;

-- ── R04 identity comes only from auth.uid(): no JWT sub → denied ───────
SELECT set_config('request.jwt.claim.sub', '', false);
SET ROLE authenticated;
DO $$ DECLARE r jsonb; BEGIN
  r := public.quant_rate_limit_hit('quant-analyze');
  IF (r->>'allowed')::boolean OR r->>'reason' <> 'unauthenticated' THEN RAISE EXCEPTION 'R04 missing identity allowed: %', r; END IF;
END $$;
RESET ROLE;

-- ── R05 counters recorded per (user, bucket, window) ──────────────────
DO $$ BEGIN
  IF (SELECT hits FROM public.quant_rate_limits WHERE user_id = '5a000000-0000-4000-8000-00000000000a' AND bucket = 'quant-analyze') <> 31 THEN
    RAISE EXCEPTION 'R05 counter not atomic/accurate';
  END IF;
END $$;

SELECT 'QUANT_RATE_LIMITS: PASS';
