-- Macro-10 §8 — full independent Codex audit of 15d4177..a3f7fc2 (job
-- task-mule52ro-y4v3vh), P1 finding on strategies_create_with_version
-- (20261008000000):
--
--   "Reuse an idempotency key with a different payload but the same
--   forged hash, defeating the claimed payload-conflict protection."
--
-- The RPC compared the CALLER-SUPPLIED p_spec_hash against the stored
-- version's spec_hash to decide whether an idempotency-key replay was a
-- genuine retry (same spec) or a conflicting reuse (different spec) --
-- but p_spec_hash is client-computed (sha256(JSON.stringify(spec)) in
-- _shared/strategy_server.ts) and never verified server-side, so a
-- caller could send any spec paired with a hash that happens to match
-- the original row's stored hash, silently defeating the conflict
-- check. Recomputing the exact same hash inside Postgres is NOT a safe
-- fix -- jsonb's text serialization (key order, spacing) does not
-- reliably match JavaScript's JSON.stringify, so a server-side digest()
-- over the jsonb column would diverge from legitimate client hashes and
-- cause false conflicts. Fixed by comparing the actual jsonb CONTENT
-- (`v.spec = p_spec`, Postgres jsonb structural equality) instead of
-- the caller-suppliable hash proxy -- this is strictly stronger (no
-- forgeable intermediate value) and requires no new hashing logic.
--
-- Second, unrelated fix bundled here (Codex P2, same audit): two
-- concurrent requests using the same idempotency key both pass the
-- pre-check (neither sees the other's row yet), then race on the
-- INSERT -- the loser hit the unique index and surfaced as an uncaught
-- 500 instead of returning the winner's row. Both effects only ever
-- self-scope to the calling user's own (user_id, idempotency_key) pair
-- (the index and idempotency check are user-scoped) -- no cross-user
-- impact was found or is possible via this path.
--
-- Idempotent: safe to re-apply. LAB until rehearsed.

CREATE OR REPLACE FUNCTION public.strategies_create_with_version(
  p_name text,
  p_spec jsonb,
  p_spec_hash text,
  p_idempotency_key text DEFAULT NULL
) RETURNS TABLE (
  strategy_id uuid, strategy_name text, strategy_status text, strategy_current_version integer,
  strategy_created_at timestamptz, strategy_updated_at timestamptz, strategy_holdout_first_viewed_at timestamptz,
  version_id uuid, version_strategy_id uuid, version_number integer, version_spec jsonb, version_spec_hash text, version_created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_strategy_id uuid;
  v_version_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = '28000';
  END IF;
  IF NOT public.strategy_builder_access_allowed() THEN
    RAISE EXCEPTION 'MODULE_NOT_AVAILABLE' USING ERRCODE = '42501';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT s.id INTO v_strategy_id FROM public.strategies s
      WHERE s.user_id = v_uid AND s.idempotency_key = p_idempotency_key;
    IF FOUND THEN
      -- Compare the actual stored spec content, not the caller-supplied
      -- hash -- the hash is an unverified client value and must never be
      -- the thing that decides whether this is a genuine retry.
      PERFORM 1 FROM public.strategy_versions v
        WHERE v.strategy_id = v_strategy_id AND v.version_number = 1 AND v.spec = p_spec;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT' USING ERRCODE = '23505';
      END IF;
      RETURN QUERY
        SELECT s.id, s.name, s.status, s.current_version, s.created_at, s.updated_at, s.holdout_first_viewed_at,
               v.id, v.strategy_id, v.version_number, v.spec, v.spec_hash, v.created_at
        FROM public.strategies s
        JOIN public.strategy_versions v ON v.strategy_id = s.id AND v.version_number = 1
        WHERE s.id = v_strategy_id;
      RETURN;
    END IF;
  END IF;

  BEGIN
    INSERT INTO public.strategies (user_id, name, status, current_version, idempotency_key)
      VALUES (v_uid, p_name, 'DRAFT', 1, p_idempotency_key)
      RETURNING id INTO v_strategy_id;

    INSERT INTO public.strategy_versions (strategy_id, user_id, version_number, spec, spec_hash)
      VALUES (v_strategy_id, v_uid, 1, p_spec, p_spec_hash)
      RETURNING id INTO v_version_id;
  EXCEPTION WHEN unique_violation THEN
    -- A concurrent request for the SAME (user_id, idempotency_key) won
    -- the race between our pre-check and this INSERT. Re-read and
    -- return its result instead of surfacing a generic 500 -- this is
    -- the same genuine-retry semantics as the pre-check above, just
    -- reached via the race path instead of a second HTTP call.
    IF p_idempotency_key IS NULL THEN
      RAISE;
    END IF;
    SELECT s.id INTO v_strategy_id FROM public.strategies s
      WHERE s.user_id = v_uid AND s.idempotency_key = p_idempotency_key;
    IF NOT FOUND THEN
      RAISE;
    END IF;
    PERFORM 1 FROM public.strategy_versions v
      WHERE v.strategy_id = v_strategy_id AND v.version_number = 1 AND v.spec = p_spec;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'IDEMPOTENCY_KEY_CONFLICT' USING ERRCODE = '23505';
    END IF;
    RETURN QUERY
      SELECT s.id, s.name, s.status, s.current_version, s.created_at, s.updated_at, s.holdout_first_viewed_at,
             v.id, v.strategy_id, v.version_number, v.spec, v.spec_hash, v.created_at
      FROM public.strategies s
      JOIN public.strategy_versions v ON v.strategy_id = s.id AND v.version_number = 1
      WHERE s.id = v_strategy_id;
    RETURN;
  END;

  RETURN QUERY
    SELECT s.id, s.name, s.status, s.current_version, s.created_at, s.updated_at, s.holdout_first_viewed_at,
           v.id, v.strategy_id, v.version_number, v.spec, v.spec_hash, v.created_at
    FROM public.strategies s JOIN public.strategy_versions v ON v.id = v_version_id
    WHERE s.id = v_strategy_id;
END $$;

REVOKE ALL ON FUNCTION public.strategies_create_with_version(text, jsonb, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.strategies_create_with_version(text, jsonb, text, text) TO authenticated;
