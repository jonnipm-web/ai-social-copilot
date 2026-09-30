-- IV-IMPACT-I5-PRODUCT-UX-01 — dossier rate limit counters (migration
-- 20260928010000). DISPOSABLE database only. Ends with 'IMPACT_RATE_LIMIT: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

CREATE TEMP TABLE i5_log (n serial, label text);
GRANT ALL ON i5_log TO PUBLIC;
GRANT ALL ON SEQUENCE i5_log_n_seq TO PUBLIC;

CREATE FUNCTION pg_temp.expect_fail(p_label text, p_sql text, p_pattern text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN others THEN
    IF SQLERRM ~* p_pattern OR SQLSTATE ~* p_pattern THEN
      INSERT INTO i5_log (label) VALUES (p_label);
      RETURN;
    END IF;
    RAISE EXCEPTION '% failed for the WRONG reason: [%] %', p_label, SQLSTATE, SQLERRM;
  END;
  RAISE EXCEPTION '% was expected to FAIL but succeeded', p_label;
END $$;

CREATE FUNCTION pg_temp.expect_eq(p_label text, p_actual text, p_expected text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_actual IS DISTINCT FROM p_expected THEN
    RAISE EXCEPTION '% expected [%] got [%]', p_label, p_expected, p_actual;
  END IF;
  INSERT INTO i5_log (label) VALUES (p_label);
END $$;

CREATE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(uid, ''), false);
  PERFORM set_config('request.jwt.claim.role', CASE WHEN uid IS NULL THEN 'anon' ELSE 'authenticated' END, false);
END $$;

INSERT INTO auth.users (id, email) VALUES
  ('77777777-0000-0000-0000-000000000007', 'user-r1@test.invalid'),
  ('66666666-0000-0000-0000-000000000006', 'user-r2@test.invalid')
ON CONFLICT (id) DO NOTHING;

SET ROLE authenticated;
SELECT pg_temp.act_as('77777777-0000-0000-0000-000000000007');
SELECT pg_temp.expect_eq('R5-01 first hit in a window counts 1', (SELECT hit_count::text FROM public.impact_rate_limit_hit('dossier_build')), '1');
SELECT pg_temp.expect_eq('R5-02 hits accumulate atomically in the same window', (SELECT hit_count::text FROM public.impact_rate_limit_hit('dossier_build')), '2');
SELECT pg_temp.expect_eq('R5-03 buckets are independent', (SELECT hit_count::text FROM public.impact_rate_limit_hit('dossier_export')), '1');
SELECT pg_temp.expect_eq('R5-04 window start is aligned to the window size',
  (SELECT (extract(epoch FROM window_start)::bigint % 60)::text FROM public.impact_rate_limit_hit('dossier_verify')), '0');
SELECT pg_temp.expect_fail('R5-05 unknown bucket refused', $$SELECT public.impact_rate_limit_hit('publish')$$, 'IMPACT_RATE_LIMIT_INVALID');
SELECT pg_temp.expect_fail('R5-06 the window is not a caller argument (I5G2-01): the 2-arg form does not exist', $$SELECT public.impact_rate_limit_hit('dossier_build', 10)$$, '42883');
SELECT pg_temp.expect_fail('R5-07 a client cannot write the counters directly (insert)',
  $$INSERT INTO public.impact_rate_limits (user_id, bucket, window_start, hit_count) VALUES ('77777777-0000-0000-0000-000000000007', 'dossier_build', now(), 0)$$, '42501');
SELECT pg_temp.expect_fail('R5-08 a client cannot reset its counters (update)',
  $$UPDATE public.impact_rate_limits SET hit_count = 0$$, '42501');
SELECT pg_temp.expect_fail('R5-09 a client cannot delete its counters',
  $$DELETE FROM public.impact_rate_limits$$, '42501');
SELECT pg_temp.expect_eq('R5-10 owner reads only its own counters', (SELECT count(*)::text FROM public.impact_rate_limits), '3');
SELECT pg_temp.act_as('66666666-0000-0000-0000-000000000006');
SELECT pg_temp.expect_eq('R5-11 cross-user: another user sees none of them', (SELECT count(*)::text FROM public.impact_rate_limits), '0');
SELECT pg_temp.expect_eq('R5-12 another user has an isolated budget', (SELECT hit_count::text FROM public.impact_rate_limit_hit('dossier_build')), '1');
RESET ROLE;

SET ROLE anon;
SELECT pg_temp.act_as(NULL);
SELECT pg_temp.expect_fail('R5-13 anon cannot call the limiter', $$SELECT public.impact_rate_limit_hit('dossier_build')$$, '42501');
SELECT pg_temp.expect_fail('R5-14 anon cannot read counters', $$SELECT count(*) FROM public.impact_rate_limits$$, '42501');
RESET ROLE;

SET ROLE service_role;
SELECT pg_temp.expect_fail('R5-15 service_role gets no execute on the limiter (no silent bypass, no expansion)',
  $$SELECT public.impact_rate_limit_hit('dossier_build')$$, '42501');
SELECT pg_temp.expect_fail('R5-16 service_role cannot write counters', $$UPDATE public.impact_rate_limits SET hit_count = 0$$, '42501');
RESET ROLE;

SELECT pg_temp.expect_eq('R5-17 the limiter is SECURITY DEFINER with an empty search_path (identity = auth.uid())',
  (SELECT prosecdef::text || '/' || array_to_string(proconfig, ',') FROM pg_proc WHERE proname = 'impact_rate_limit_hit' AND pronamespace = 'public'::regnamespace AND pronargs = 1),
  'true/search_path=""');
SELECT pg_temp.expect_eq('R5-18 RLS on the counter table', (SELECT relrowsecurity::text FROM pg_class WHERE relname = 'impact_rate_limits'), 'true');
SELECT pg_temp.expect_eq('R5-19 the counter table stores no content / verdict column',
  (SELECT count(*)::text FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'impact_rate_limits'
     AND column_name !~ '^(user_id|bucket|window_start|hit_count|updated_at)$'), '0');

-- I5G2-01 — bounded growth: past windows of the caller are removed on the next hit.
INSERT INTO public.impact_rate_limits (user_id, bucket, window_start, hit_count)
SELECT '77777777-0000-0000-0000-000000000007', b, date_trunc('minute', now()) - (g || ' minutes')::interval, 1
  FROM unnest(ARRAY['dossier_build', 'dossier_export', 'dossier_verify']) b, generate_series(1, 50) g;
SET ROLE authenticated;
SELECT pg_temp.act_as('77777777-0000-0000-0000-000000000007');
SELECT public.impact_rate_limit_hit('dossier_build');
SELECT pg_temp.expect_eq('R5-20 after a hit the caller holds at most one row per bucket (no unbounded growth)',
  (SELECT (count(*) <= 3 AND count(*) = count(DISTINCT bucket))::text FROM public.impact_rate_limits), 'true');
SELECT pg_temp.expect_eq('R5-21 only the current 60 s window survives',
  (SELECT bool_and(extract(epoch FROM window_start)::bigint % 60 = 0 AND window_start >= date_trunc('minute', now()) - interval '1 minute')::text FROM public.impact_rate_limits), 'true');
RESET ROLE;
SELECT pg_temp.expect_eq('R5-22 housekeeping never touches another caller''s rows',
  (SELECT count(*)::text FROM public.impact_rate_limits WHERE user_id = '66666666-0000-0000-0000-000000000006'), '1');
SELECT pg_temp.expect_eq('R5-23 exactly one limiter signature, no execute for PUBLIC',
  (SELECT count(*)::text || '/' || bool_or(has_function_privilege('public', p.oid, 'EXECUTE'))::text FROM pg_proc p
     WHERE p.proname = 'impact_rate_limit_hit' AND p.pronamespace = 'public'::regnamespace), '1/false');

SELECT 'IMPACT_RATE_LIMIT: PASS ' || count(*) || ' checks' FROM i5_log;
