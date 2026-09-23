-- IV-QUANT-DATA-PLANE-AND-API-02 — RLS / privilege tests for
-- public.quant_watchlists + public.quant_watchlist_items (migration
-- 20260924000000). Runs against a DISPOSABLE database with every migration
-- applied (never production). Every check RAISEs on failure; a clean run
-- ends with 'QUANT_WATCHLISTS_RLS: PASS'.
\set ON_ERROR_STOP 1
SET search_path = public, extensions;

-- ── fixtures (as the migration owner) ─────────────────────────────────
INSERT INTO auth.users (id, email) VALUES
  ('1a000000-0000-4000-8000-00000000000a', 'qa@test.invalid'),
  ('1b000000-0000-4000-8000-00000000000b', 'qb@test.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.projects (id, user_id, name) VALUES
  ('2a000000-0000-4000-8000-00000000000a', '1a000000-0000-4000-8000-00000000000a', 'Project A'),
  ('2b000000-0000-4000-8000-00000000000b', '1b000000-0000-4000-8000-00000000000b', 'Project B')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION pg_temp.act_as(uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', uid, false);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', false);
END $$;

-- ── Q01 anonymous has no access at all ────────────────────────────────
SELECT set_config('request.jwt.claim.sub', '', false);
SET ROLE anon;
DO $$ BEGIN
  BEGIN PERFORM 1 FROM public.quant_watchlists; RAISE EXCEPTION 'Q01 anon SELECT watchlists allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM 1 FROM public.quant_watchlist_items; RAISE EXCEPTION 'Q01 anon SELECT items allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO public.quant_watchlists (user_id, name) VALUES ('1a000000-0000-4000-8000-00000000000a', 'x');
    RAISE EXCEPTION 'Q01 anon INSERT allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- ── Q02 owner INSERT (no project, own project); cross-project + forged owner denied ──
SELECT pg_temp.act_as('1a000000-0000-4000-8000-00000000000a');
SET ROLE authenticated;
INSERT INTO public.quant_watchlists (id, name) VALUES ('3a000000-0000-4000-8000-00000000000a', 'A core');
INSERT INTO public.quant_watchlists (id, name, project_id) VALUES ('3a000000-0000-4000-8000-0000000000a2', 'A proj', '2a000000-0000-4000-8000-00000000000a');
DO $$ BEGIN
  BEGIN INSERT INTO public.quant_watchlists (name, project_id) VALUES ('steal', '2b000000-0000-4000-8000-00000000000b');
    RAISE EXCEPTION 'Q02 cross-project INSERT allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO public.quant_watchlists (name, user_id) VALUES ('forged', '1b000000-0000-4000-8000-00000000000b');
    RAISE EXCEPTION 'Q02 forged user_id INSERT allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO public.quant_watchlists (name) VALUES ('   ');
    RAISE EXCEPTION 'Q02 blank name allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- ── Q03 owner items: INSERT, duplicate, identity constraints, generated key ──
INSERT INTO public.quant_watchlist_items (id, watchlist_id, asset_class, symbol, exchange_mic, currency, isin)
VALUES ('4a000000-0000-4000-8000-00000000000a', '3a000000-0000-4000-8000-00000000000a', 'EQUITY', 'AAPL', 'XNAS', 'USD', 'US0378331005');
DO $$ BEGIN
  IF (SELECT instrument_key FROM public.quant_watchlist_items WHERE id = '4a000000-0000-4000-8000-00000000000a') <> 'EQUITY:XNAS:AAPL:USD' THEN
    RAISE EXCEPTION 'Q03 instrument_key not generated canonically';
  END IF;
  BEGIN INSERT INTO public.quant_watchlist_items (watchlist_id, asset_class, symbol, exchange_mic, currency)
    VALUES ('3a000000-0000-4000-8000-00000000000a', 'EQUITY', 'AAPL', 'XNAS', 'USD');
    RAISE EXCEPTION 'Q03 duplicate instrument allowed';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.quant_watchlist_items (watchlist_id, asset_class, symbol, currency)
    VALUES ('3a000000-0000-4000-8000-00000000000a', 'EQUITY', 'aapl', 'USD');
    RAISE EXCEPTION 'Q03 non-canonical symbol allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.quant_watchlist_items (watchlist_id, asset_class, symbol, currency)
    VALUES ('3a000000-0000-4000-8000-00000000000a', 'CRYPTO', 'BTC', 'USD');
    RAISE EXCEPTION 'Q03 unsupported asset class allowed';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.quant_watchlist_items (watchlist_id, asset_class, symbol, currency, instrument_key)
    VALUES ('3a000000-0000-4000-8000-00000000000a', 'EQUITY', 'MSFT', 'USD', 'EQUITY:XNAS:AAPL:USD');
    RAISE EXCEPTION 'Q03 forged instrument_key accepted';
  EXCEPTION WHEN generated_always OR syntax_error OR feature_not_supported OR insufficient_privilege THEN NULL; END;
  -- Same ticker, different venue/currency is a DIFFERENT instrument.
  INSERT INTO public.quant_watchlist_items (watchlist_id, asset_class, symbol, exchange_mic, currency)
  VALUES ('3a000000-0000-4000-8000-00000000000a', 'EQUITY', 'AAPL', 'XLON', 'GBP');
END $$;

-- ── Q04 owner SELECT / UPDATE (name only) ──────────────────────────────
DO $$ BEGIN
  IF (SELECT count(*) FROM public.quant_watchlists) <> 2 THEN RAISE EXCEPTION 'Q04 owner SELECT count wrong'; END IF;
  IF (SELECT count(*) FROM public.quant_watchlist_items) <> 2 THEN RAISE EXCEPTION 'Q04 owner items count wrong'; END IF;
  UPDATE public.quant_watchlists SET name = 'A renamed' WHERE id = '3a000000-0000-4000-8000-00000000000a';
  IF (SELECT name FROM public.quant_watchlists WHERE id = '3a000000-0000-4000-8000-00000000000a') <> 'A renamed' THEN
    RAISE EXCEPTION 'Q04 owner UPDATE name failed';
  END IF;
  BEGIN UPDATE public.quant_watchlists SET project_id = '2b000000-0000-4000-8000-00000000000b' WHERE id = '3a000000-0000-4000-8000-00000000000a';
    RAISE EXCEPTION 'Q04 project_id is mutable';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE public.quant_watchlists SET user_id = '1b000000-0000-4000-8000-00000000000b' WHERE id = '3a000000-0000-4000-8000-00000000000a';
    RAISE EXCEPTION 'Q04 user_id is mutable';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE public.quant_watchlist_items SET symbol = 'MSFT';
    RAISE EXCEPTION 'Q04 items are mutable';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- ── Q05 other user: SELECT / UPDATE / DELETE / item INSERT all denied ──
SELECT pg_temp.act_as('1b000000-0000-4000-8000-00000000000b');
SET ROLE authenticated;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.quant_watchlists) <> 0 THEN RAISE EXCEPTION 'Q05 other user SELECT sees foreign watchlists'; END IF;
  IF (SELECT count(*) FROM public.quant_watchlist_items) <> 0 THEN RAISE EXCEPTION 'Q05 other user SELECT sees foreign items'; END IF;
  UPDATE public.quant_watchlists SET name = 'hijacked' WHERE id = '3a000000-0000-4000-8000-00000000000a';
  DELETE FROM public.quant_watchlists WHERE id = '3a000000-0000-4000-8000-00000000000a';
  DELETE FROM public.quant_watchlist_items WHERE id = '4a000000-0000-4000-8000-00000000000a';
  BEGIN INSERT INTO public.quant_watchlist_items (watchlist_id, asset_class, symbol, currency)
    VALUES ('3a000000-0000-4000-8000-00000000000a', 'EQUITY', 'EVIL', 'USD');
    RAISE EXCEPTION 'Q05 other user inserted into a foreign watchlist';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- B's own watchlist cannot adopt A's project either.
  BEGIN INSERT INTO public.quant_watchlists (name, project_id) VALUES ('b steal', '2a000000-0000-4000-8000-00000000000a');
    RAISE EXCEPTION 'Q05 cross-project INSERT allowed for B';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT name FROM public.quant_watchlists WHERE id = '3a000000-0000-4000-8000-00000000000a') <> 'A renamed' THEN
    RAISE EXCEPTION 'Q05 other user UPDATE took effect';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.quant_watchlist_items WHERE id = '4a000000-0000-4000-8000-00000000000a') THEN
    RAISE EXCEPTION 'Q05 other user DELETE took effect';
  END IF;
END $$;

-- ── Q06 limits: 200 items per watchlist, 50 watchlists per user ─────────
SELECT pg_temp.act_as('1a000000-0000-4000-8000-00000000000a');
SET ROLE authenticated;
INSERT INTO public.quant_watchlist_items (watchlist_id, asset_class, symbol, currency)
SELECT '3a000000-0000-4000-8000-0000000000a2', 'EQUITY', 'T' || g, 'USD' FROM generate_series(1, 200) g;
DO $$ BEGIN
  BEGIN INSERT INTO public.quant_watchlist_items (watchlist_id, asset_class, symbol, currency)
    VALUES ('3a000000-0000-4000-8000-0000000000a2', 'EQUITY', 'T201', 'USD');
    RAISE EXCEPTION 'Q06 201st item accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
INSERT INTO public.quant_watchlists (name) SELECT 'L' || g FROM generate_series(1, 48) g;
DO $$ BEGIN
  BEGIN INSERT INTO public.quant_watchlists (name) VALUES ('L51');
    RAISE EXCEPTION 'Q06 51st watchlist accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- ── Q07 owner DELETE cascades items ─────────────────────────────────────
DELETE FROM public.quant_watchlists WHERE id = '3a000000-0000-4000-8000-0000000000a2';
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.quant_watchlist_items WHERE watchlist_id = '3a000000-0000-4000-8000-0000000000a2') THEN
    RAISE EXCEPTION 'Q07 items survived their watchlist';
  END IF;
  DELETE FROM public.quant_watchlist_items WHERE id = '4a000000-0000-4000-8000-00000000000a';
  IF EXISTS (SELECT 1 FROM public.quant_watchlist_items WHERE id = '4a000000-0000-4000-8000-00000000000a') THEN
    RAISE EXCEPTION 'Q07 owner item DELETE failed';
  END IF;
END $$;
RESET ROLE;

-- ── Q08 project deletion detaches (does not delete) the watchlist ───────
SELECT pg_temp.act_as('1a000000-0000-4000-8000-00000000000a');
SET ROLE authenticated;
INSERT INTO public.quant_watchlists (id, name, project_id) VALUES ('3a000000-0000-4000-8000-0000000000a3', 'A proj 2', '2a000000-0000-4000-8000-00000000000a');
RESET ROLE;
DELETE FROM public.projects WHERE id = '2a000000-0000-4000-8000-00000000000a';
DO $$ BEGIN
  IF (SELECT project_id FROM public.quant_watchlists WHERE id = '3a000000-0000-4000-8000-0000000000a3') IS NOT NULL THEN
    RAISE EXCEPTION 'Q08 project deletion did not detach the watchlist';
  END IF;
END $$;

SELECT 'QUANT_WATCHLISTS_RLS: PASS';
