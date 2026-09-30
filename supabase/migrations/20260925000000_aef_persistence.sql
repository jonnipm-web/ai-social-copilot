-- IV-AEF-PERSISTENCE-01 — durable AEF governance state.
--
-- MODULE LAB ONLY. Not applied to production or to any shared database.
-- Tested on a disposable PostgreSQL 17 (scripts/ci/run_disposable_db_tests.sh).
--
-- PostgreSQL is the single authority for the AEF state machine:
--   * every state change goes through a service_role-only function that
--     locks the operation row, checks the transition and writes the audit
--     trail in the same transaction;
--   * guard triggers re-check every transition and every immutable column,
--     so even a direct UPDATE by service_role cannot skip a state, revert a
--     terminal state or re-run an execution (attempt_count is 0 or 1);
--   * receipts and audit events are append-only (UPDATE/DELETE/TRUNCATE
--     rejected) and hash-anchored (per-subject hash chain).
-- End users (authenticated) may only SELECT their own rows. anon: nothing.
-- service_role (privileged infrastructure) may only SELECT and call the ten
-- aef_* RPCs; it has no direct INSERT/UPDATE/DELETE and cannot call the
-- internal aef__* helpers. The RPCs are SECURITY DEFINER with a pinned
-- search_path (pg_catalog, pg_temp; every object schema-qualified); the guard triggers apply to the owner too (a superuser can
-- disable triggers — tampering is then detectable, AEF_SECURITY_MODEL.md).
--
-- No payload, prompt, JWT, credential or free text is stored: only ids,
-- hashes, codes and timestamps. Idempotency keys are stored hashed.
--
-- Idempotent: safe to re-apply (the CI runner re-applies it).

-- ── preconditions (IV-AEF-PRE-RUNTIME-CLOSURE-01, P05) ─────────────────
-- Fail fast, before creating anything, when an object this migration
-- depends on is missing or has an incompatible shape. Dependencies are the
-- objects actually referenced (not the file numbering): public.projects
-- (resource ownership), the API roles, pg_catalog.sha256 / gen_random_uuid.
DO $$
DECLARE v_missing text[] := ARRAY[]::text[];
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'projects'
                  AND column_name = 'id' AND data_type = 'uuid') THEN
    v_missing := v_missing || 'public.projects.id uuid'::text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'projects'
                  AND column_name = 'user_id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN
    v_missing := v_missing || 'public.projects.user_id uuid NOT NULL'::text;
  END IF;
  IF (SELECT count(*) FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')) <> 3 THEN
    v_missing := v_missing || 'roles anon/authenticated/service_role'::text;
  END IF;
  IF to_regprocedure('pg_catalog.sha256(bytea)') IS NULL
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('pg_catalog.sha256(bytea)')) IS DISTINCT FROM 'bytea'::regtype
     OR to_regprocedure('pg_catalog.gen_random_uuid()') IS NULL
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('pg_catalog.gen_random_uuid()')) IS DISTINCT FROM 'uuid'::regtype THEN
    v_missing := v_missing || 'pg_catalog.sha256(bytea) -> bytea / pg_catalog.gen_random_uuid() -> uuid'::text;
  END IF;
  IF to_regprocedure('auth.uid()') IS NULL
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('auth.uid()')) IS DISTINCT FROM 'uuid'::regtype THEN
    v_missing := v_missing || 'auth.uid() returning uuid'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'AEF_PRECONDITION (20260925000000_aef_persistence): missing or incompatible: %', array_to_string(v_missing, ', ')
      USING ERRCODE = 'AE010';
  END IF;
END $$;

-- ── helpers ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef__sha256(p text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT SET search_path = pg_catalog, pg_temp AS $$
  SELECT encode(sha256(convert_to(p, 'UTF8')), 'hex')
$$;

CREATE OR REPLACE FUNCTION public.aef__ts(p timestamptz) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT CASE WHEN p IS NULL THEN NULL
              ELSE to_char(p AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END
$$;

CREATE OR REPLACE FUNCTION public.aef__is_terminal(p_state text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT p_state IN ('SUCCEEDED', 'FAILED', 'UNKNOWN_OUTCOME', 'REJECTED', 'EXPIRED', 'CANCELLED', 'INVALIDATED')
$$;

CREATE OR REPLACE FUNCTION public.aef__outcome_for(p_state text, p_side_effect boolean) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT CASE p_state
    WHEN 'SUCCEEDED' THEN 'SUCCESS'
    WHEN 'FAILED' THEN CASE WHEN p_side_effect IS TRUE THEN 'PARTIAL' ELSE 'FAILURE' END
    WHEN 'UNKNOWN_OUTCOME' THEN 'UNKNOWN_OUTCOME'
    WHEN 'REJECTED' THEN 'NOT_EXECUTED'
    WHEN 'EXPIRED' THEN 'NOT_EXECUTED'
    WHEN 'CANCELLED' THEN 'NOT_EXECUTED'
    WHEN 'INVALIDATED' THEN 'NOT_EXECUTED'
    ELSE NULL END
$$;

CREATE OR REPLACE FUNCTION public.aef__err(p_code text, p_state text DEFAULT NULL) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT CASE WHEN p_state IS NULL THEN jsonb_build_object('ok', false, 'code', p_code)
              ELSE jsonb_build_object('ok', false, 'code', p_code, 'state', p_state) END
$$;

-- Argument parsing. Every RPC takes ONE jsonb object; unknown keys are a
-- mass-assignment attempt and are rejected (SQLSTATE AE001 → ARGUMENT_REJECTED).
CREATE OR REPLACE FUNCTION public.aef__check_keys(p jsonb, p_allowed text[]) RETURNS void
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF p IS NULL OR jsonb_typeof(p) <> 'object' THEN
    RAISE EXCEPTION 'AEF_ARGUMENT: object required' USING ERRCODE = 'AE001';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p) k WHERE NOT (k = ANY (p_allowed))) THEN
    RAISE EXCEPTION 'AEF_ARGUMENT: unknown key' USING ERRCODE = 'AE001';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.aef__text(p jsonb, p_key text, p_required boolean, p_max int, p_re text DEFAULT NULL) RETURNS text
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
DECLARE v text;
BEGIN
  IF NOT (p ? p_key) OR jsonb_typeof(p -> p_key) = 'null' THEN
    IF p_required THEN RAISE EXCEPTION 'AEF_ARGUMENT: % required', p_key USING ERRCODE = 'AE001'; END IF;
    RETURN NULL;
  END IF;
  IF jsonb_typeof(p -> p_key) <> 'string' THEN
    RAISE EXCEPTION 'AEF_ARGUMENT: % must be a string', p_key USING ERRCODE = 'AE001';
  END IF;
  v := p ->> p_key;
  IF length(v) < 1 OR length(v) > p_max OR (p_re IS NOT NULL AND v !~ p_re) THEN
    RAISE EXCEPTION 'AEF_ARGUMENT: % invalid', p_key USING ERRCODE = 'AE001';
  END IF;
  RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.aef__uuid(p jsonb, p_key text, p_required boolean) RETURNS uuid
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
DECLARE v text;
BEGIN
  v := public.aef__text(p, p_key, p_required, 36, '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  RETURN v::uuid;
END $$;

CREATE OR REPLACE FUNCTION public.aef__int(p jsonb, p_key text, p_required boolean, p_min int, p_max int) RETURNS int
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
DECLARE n numeric;
BEGIN
  IF NOT (p ? p_key) OR jsonb_typeof(p -> p_key) = 'null' THEN
    IF p_required THEN RAISE EXCEPTION 'AEF_ARGUMENT: % required', p_key USING ERRCODE = 'AE001'; END IF;
    RETURN NULL;
  END IF;
  IF jsonb_typeof(p -> p_key) <> 'number' THEN
    RAISE EXCEPTION 'AEF_ARGUMENT: % must be a number', p_key USING ERRCODE = 'AE001';
  END IF;
  n := (p ->> p_key)::numeric;
  IF n <> trunc(n) OR n < p_min OR n > p_max THEN
    RAISE EXCEPTION 'AEF_ARGUMENT: % out of range', p_key USING ERRCODE = 'AE001';
  END IF;
  RETURN n::int;
END $$;

CREATE OR REPLACE FUNCTION public.aef__bool(p jsonb, p_key text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF jsonb_typeof(p -> p_key) IS DISTINCT FROM 'boolean' THEN
    RAISE EXCEPTION 'AEF_ARGUMENT: % must be a boolean', p_key USING ERRCODE = 'AE001';
  END IF;
  RETURN (p ->> p_key)::boolean;
END $$;

-- ── tables ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.aef_operations (
  id                    uuid PRIMARY KEY,
  subject_id            uuid NOT NULL,
  request_id            uuid NOT NULL,
  idempotency_key_hash  text NOT NULL CHECK (idempotency_key_hash ~ '^[0-9a-f]{64}$'),
  domain                text NOT NULL CHECK (domain IN ('core', 'quant', 'impact', 'internal')),
  action                text NOT NULL CHECK (length(action) <= 200 AND action ~ '^[a-z][a-z0-9_]*([.][a-z][a-z0-9_]*)+$'),
  tool_id               text NOT NULL CHECK (length(tool_id) BETWEEN 1 AND 200),
  action_class          text NOT NULL CHECK (action_class IN ('READ_ONLY', 'REVERSIBLE', 'CONSEQUENTIAL')),
  resource_type         text CHECK (resource_type IS NULL OR resource_type = 'project'),
  resource_id           text,
  project_id            uuid,
  payload_hash          text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  payload_bytes         integer NOT NULL CHECK (payload_bytes BETWEEN 2 AND 16384),
  binding_hash          text NOT NULL CHECK (binding_hash ~ '^[0-9a-f]{64}$'),
  policy_version        text NOT NULL CHECK (policy_version ~ '^[a-z0-9._/-]{1,64}$'),
  risk_version          text NOT NULL CHECK (risk_version ~ '^[a-z0-9._/-]{1,64}$'),
  requires_human_gate   boolean NOT NULL,
  state                 text NOT NULL CHECK (state IN ('AWAITING_APPROVAL', 'AUTHORIZED', 'EXECUTING', 'SUCCEEDED', 'FAILED',
                                                       'UNKNOWN_OUTCOME', 'REJECTED', 'EXPIRED', 'CANCELLED', 'INVALIDATED')),
  state_reason          text CHECK (state_reason IS NULL OR state_reason ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  attempt_count         smallint NOT NULL DEFAULT 0 CHECK (attempt_count IN (0, 1)),
  execution_token       uuid,
  lease_expires_at      timestamptz,
  side_effect_observed  boolean,
  created_at            timestamptz NOT NULL DEFAULT now(),
  authorized_at         timestamptz,
  completed_at          timestamptz,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  expires_at            timestamptz NOT NULL,
  CONSTRAINT aef_operations_resource CHECK (
    (resource_type IS NULL AND resource_id IS NULL AND project_id IS NULL)
    OR (resource_type = 'project' AND project_id IS NOT NULL AND resource_id = project_id::text)),
  CONSTRAINT aef_operations_consequential_gated CHECK (action_class <> 'CONSEQUENTIAL' OR requires_human_gate),
  CONSTRAINT aef_operations_idempotency UNIQUE (subject_id, idempotency_key_hash),
  CONSTRAINT aef_operations_request UNIQUE (request_id)
);
CREATE INDEX IF NOT EXISTS aef_operations_subject_idx ON public.aef_operations (subject_id, created_at DESC);
CREATE INDEX IF NOT EXISTS aef_operations_open_idx ON public.aef_operations (state, lease_expires_at, expires_at)
  WHERE state IN ('AWAITING_APPROVAL', 'AUTHORIZED', 'EXECUTING');
CREATE INDEX IF NOT EXISTS aef_operations_open_subject_idx ON public.aef_operations (subject_id)
  WHERE state IN ('AWAITING_APPROVAL', 'AUTHORIZED', 'EXECUTING');

CREATE TABLE IF NOT EXISTS public.aef_human_gates (
  id              uuid PRIMARY KEY,
  operation_id    uuid NOT NULL UNIQUE REFERENCES public.aef_operations (id),
  subject_id      uuid NOT NULL,
  binding_hash    text NOT NULL CHECK (binding_hash ~ '^[0-9a-f]{64}$'),
  policy_version  text NOT NULL CHECK (policy_version ~ '^[a-z0-9._/-]{1,64}$'),
  state           text NOT NULL CHECK (state IN ('REVIEW_REQUIRED', 'AUTHORIZED', 'REJECTED', 'EXPIRED', 'EXECUTED', 'CANCELLED', 'INVALIDATED')),
  state_reason    text CHECK (state_reason IS NULL OR state_reason ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  approver_id     uuid,
  decided_at      timestamptz,
  consumed_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS aef_human_gates_subject_idx ON public.aef_human_gates (subject_id);

CREATE TABLE IF NOT EXISTS public.aef_receipts (
  id            uuid PRIMARY KEY,
  operation_id  uuid NOT NULL UNIQUE REFERENCES public.aef_operations (id),
  subject_id    uuid NOT NULL,
  receipt       jsonb NOT NULL,
  receipt_hash  text NOT NULL CHECK (receipt_hash ~ '^[0-9a-f]{64}$'),
  issued_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS aef_receipts_subject_idx ON public.aef_receipts (subject_id);

CREATE TABLE IF NOT EXISTS public.aef_audit_heads (
  subject_id  uuid PRIMARY KEY,
  last_seq    bigint NOT NULL CHECK (last_seq >= 0),
  last_hash   text NOT NULL CHECK (last_hash ~ '^[0-9a-f]{64}$')
);

CREATE TABLE IF NOT EXISTS public.aef_audit_events (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  subject_id    uuid NOT NULL,
  seq           bigint NOT NULL CHECK (seq >= 1),
  operation_id  uuid,
  event_type    text NOT NULL CHECK (event_type ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  from_state    text CHECK (from_state IS NULL OR from_state ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  to_state      text CHECK (to_state IS NULL OR to_state ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  reason_code   text CHECK (reason_code IS NULL OR reason_code ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  ref_hash      text CHECK (ref_hash IS NULL OR ref_hash ~ '^[0-9a-f]{64}$'),
  occurred_at   timestamptz NOT NULL,
  prev_hash     text NOT NULL CHECK (prev_hash ~ '^[0-9a-f]{64}$'),
  event_hash    text NOT NULL CHECK (event_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT aef_audit_events_chain UNIQUE (subject_id, seq)
);
CREATE INDEX IF NOT EXISTS aef_audit_events_operation_idx ON public.aef_audit_events (operation_id);

-- ── audit chain ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef__event_hash(
  p_subject uuid, p_seq bigint, p_op uuid, p_event text, p_from text, p_to text,
  p_reason text, p_ref text, p_at timestamptz, p_prev text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT public.aef__sha256(jsonb_build_array('aef-audit/1', p_subject, p_seq, p_op, p_event, p_from, p_to,
                                              p_reason, p_ref, public.aef__ts(p_at), p_prev)::text)
$$;

CREATE OR REPLACE FUNCTION public.aef__audit_append(
  p_subject uuid, p_op uuid, p_event text, p_from text, p_to text, p_reason text, p_ref text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_seq bigint; v_prev text; v_at timestamptz := clock_timestamp(); v_hash text;
BEGIN
  INSERT INTO public.aef_audit_heads (subject_id, last_seq, last_hash)
  VALUES (p_subject, 0, repeat('0', 64)) ON CONFLICT (subject_id) DO NOTHING;
  SELECT last_seq, last_hash INTO v_seq, v_prev FROM public.aef_audit_heads WHERE subject_id = p_subject FOR UPDATE;
  v_seq := v_seq + 1;
  v_hash := public.aef__event_hash(p_subject, v_seq, p_op, p_event, p_from, p_to, p_reason, p_ref, v_at, v_prev);
  INSERT INTO public.aef_audit_events (subject_id, seq, operation_id, event_type, from_state, to_state, reason_code,
                                       ref_hash, occurred_at, prev_hash, event_hash)
  VALUES (p_subject, v_seq, p_op, p_event, p_from, p_to, p_reason, p_ref, v_at, v_prev, v_hash);
  UPDATE public.aef_audit_heads SET last_seq = v_seq, last_hash = v_hash WHERE subject_id = p_subject;
END $$;

-- ── guard triggers (defense in depth; apply to service_role too) ────────
CREATE OR REPLACE FUNCTION public.aef__guard_operations() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE g public.aef_human_gates;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'AEF_GUARD: aef_operations rows are never deleted';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.state <> (CASE WHEN NEW.requires_human_gate THEN 'AWAITING_APPROVAL' ELSE 'AUTHORIZED' END)
       OR NEW.attempt_count <> 0 OR NEW.execution_token IS NOT NULL OR NEW.lease_expires_at IS NOT NULL
       OR NEW.side_effect_observed IS NOT NULL OR NEW.completed_at IS NOT NULL OR NEW.state_reason IS NOT NULL THEN
      RAISE EXCEPTION 'AEF_GUARD: invalid initial operation state';
    END IF;
    NEW.created_at := now();
    NEW.updated_at := now();
    NEW.authorized_at := CASE WHEN NEW.state = 'AUTHORIZED' THEN now() END;
    IF NEW.expires_at <= now() THEN
      RAISE EXCEPTION 'AEF_GUARD: operation already expired at insert';
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE
  IF (NEW.id, NEW.subject_id, NEW.request_id, NEW.idempotency_key_hash, NEW.domain, NEW.action, NEW.tool_id,
      NEW.action_class, NEW.resource_type, NEW.resource_id, NEW.project_id, NEW.payload_hash, NEW.payload_bytes,
      NEW.binding_hash, NEW.policy_version, NEW.risk_version, NEW.requires_human_gate, NEW.created_at, NEW.expires_at)
     IS DISTINCT FROM
     (OLD.id, OLD.subject_id, OLD.request_id, OLD.idempotency_key_hash, OLD.domain, OLD.action, OLD.tool_id,
      OLD.action_class, OLD.resource_type, OLD.resource_id, OLD.project_id, OLD.payload_hash, OLD.payload_bytes,
      OLD.binding_hash, OLD.policy_version, OLD.risk_version, OLD.requires_human_gate, OLD.created_at, OLD.expires_at) THEN
    RAISE EXCEPTION 'AEF_GUARD: immutable operation column changed';
  END IF;
  IF public.aef__is_terminal(OLD.state) THEN
    RAISE EXCEPTION 'AEF_GUARD: operation % is terminal (%)', OLD.id, OLD.state;
  END IF;
  IF NOT ((OLD.state = 'AWAITING_APPROVAL' AND NEW.state IN ('AUTHORIZED', 'REJECTED', 'EXPIRED', 'CANCELLED', 'INVALIDATED'))
       OR (OLD.state = 'AUTHORIZED' AND NEW.state IN ('EXECUTING', 'EXPIRED', 'CANCELLED', 'INVALIDATED'))
       OR (OLD.state = 'EXECUTING' AND NEW.state IN ('SUCCEEDED', 'FAILED', 'UNKNOWN_OUTCOME'))) THEN
    RAISE EXCEPTION 'AEF_GUARD: transition % -> % not allowed', OLD.state, NEW.state;
  END IF;

  IF NEW.state = 'AUTHORIZED' THEN
    SELECT * INTO g FROM public.aef_human_gates WHERE operation_id = NEW.id;
    IF NOT FOUND OR g.state <> 'AUTHORIZED' OR g.approver_id IS DISTINCT FROM NEW.subject_id
       OR g.binding_hash <> NEW.binding_hash THEN
      RAISE EXCEPTION 'AEF_GUARD: operation cannot be AUTHORIZED without a bound, approved gate';
    END IF;
    NEW.authorized_at := now();
  ELSE
    NEW.authorized_at := OLD.authorized_at;
  END IF;

  IF NEW.state = 'EXECUTING' THEN
    IF OLD.attempt_count <> 0 OR NEW.attempt_count <> 1 OR NEW.execution_token IS NULL OR NEW.lease_expires_at IS NULL THEN
      RAISE EXCEPTION 'AEF_GUARD: execution claim must set attempt 0 -> 1, a token and a lease';
    END IF;
    IF NEW.requires_human_gate THEN
      SELECT * INTO g FROM public.aef_human_gates WHERE operation_id = NEW.id;
      IF NOT FOUND OR g.state <> 'EXECUTED' OR g.approver_id IS DISTINCT FROM NEW.subject_id THEN
        RAISE EXCEPTION 'AEF_GUARD: gated operation cannot execute without consuming its approved gate';
      END IF;
    END IF;
  ELSIF (NEW.attempt_count, NEW.execution_token, NEW.lease_expires_at)
        IS DISTINCT FROM (OLD.attempt_count, OLD.execution_token, OLD.lease_expires_at) THEN
    RAISE EXCEPTION 'AEF_GUARD: execution columns change only on the execution claim';
  END IF;

  IF NEW.state NOT IN ('SUCCEEDED', 'FAILED', 'UNKNOWN_OUTCOME') AND NEW.side_effect_observed IS DISTINCT FROM OLD.side_effect_observed THEN
    RAISE EXCEPTION 'AEF_GUARD: side_effect_observed is set only on completion';
  END IF;

  NEW.completed_at := CASE WHEN public.aef__is_terminal(NEW.state) THEN now() END;
  NEW.updated_at := now();
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.aef__guard_gates() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE o public.aef_operations;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'AEF_GUARD: aef_human_gates rows are never deleted';
  END IF;

  IF TG_OP = 'INSERT' THEN
    SELECT * INTO o FROM public.aef_operations WHERE id = NEW.operation_id;
    IF NOT FOUND OR o.state <> 'AWAITING_APPROVAL' OR NOT o.requires_human_gate
       OR o.subject_id <> NEW.subject_id OR o.binding_hash <> NEW.binding_hash OR o.policy_version <> NEW.policy_version
       OR NEW.state <> 'REVIEW_REQUIRED' OR NEW.approver_id IS NOT NULL OR NEW.decided_at IS NOT NULL
       OR NEW.consumed_at IS NOT NULL OR NEW.state_reason IS NOT NULL
       OR NEW.expires_at > o.expires_at OR NEW.expires_at <= now() THEN
      RAISE EXCEPTION 'AEF_GUARD: invalid human gate at insert';
    END IF;
    NEW.created_at := now();
    NEW.updated_at := now();
    RETURN NEW;
  END IF;

  IF (NEW.id, NEW.operation_id, NEW.subject_id, NEW.binding_hash, NEW.policy_version, NEW.created_at, NEW.expires_at)
     IS DISTINCT FROM (OLD.id, OLD.operation_id, OLD.subject_id, OLD.binding_hash, OLD.policy_version, OLD.created_at, OLD.expires_at) THEN
    RAISE EXCEPTION 'AEF_GUARD: immutable gate column changed';
  END IF;
  IF OLD.state NOT IN ('REVIEW_REQUIRED', 'AUTHORIZED') THEN
    RAISE EXCEPTION 'AEF_GUARD: gate % is terminal (%)', OLD.id, OLD.state;
  END IF;
  IF NOT ((OLD.state = 'REVIEW_REQUIRED' AND NEW.state IN ('AUTHORIZED', 'REJECTED', 'EXPIRED', 'CANCELLED', 'INVALIDATED'))
       OR (OLD.state = 'AUTHORIZED' AND NEW.state IN ('EXECUTED', 'EXPIRED', 'CANCELLED', 'INVALIDATED'))) THEN
    RAISE EXCEPTION 'AEF_GUARD: gate transition % -> % not allowed', OLD.state, NEW.state;
  END IF;

  IF NEW.state IN ('AUTHORIZED', 'REJECTED') THEN
    IF NEW.approver_id IS NULL OR NEW.approver_id <> NEW.subject_id THEN
      RAISE EXCEPTION 'AEF_GUARD: only the operation subject may decide its gate';
    END IF;
    IF now() >= NEW.expires_at THEN
      RAISE EXCEPTION 'AEF_GUARD: gate expired';
    END IF;
    NEW.decided_at := now();
  ELSIF NEW.approver_id IS DISTINCT FROM OLD.approver_id OR NEW.decided_at IS DISTINCT FROM OLD.decided_at THEN
    RAISE EXCEPTION 'AEF_GUARD: approver is written only by the decision';
  END IF;

  IF NEW.state = 'EXECUTED' THEN
    SELECT * INTO o FROM public.aef_operations WHERE id = NEW.operation_id;
    IF o.state <> 'AUTHORIZED' OR now() >= NEW.expires_at THEN
      RAISE EXCEPTION 'AEF_GUARD: gate can be consumed only by an authorized, unexpired operation';
    END IF;
    NEW.consumed_at := now();
  ELSIF NEW.consumed_at IS DISTINCT FROM OLD.consumed_at THEN
    RAISE EXCEPTION 'AEF_GUARD: consumed_at is written only on consumption';
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.aef__guard_receipts() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE o public.aef_operations;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'AEF_GUARD: receipts are immutable';
  END IF;
  SELECT * INTO o FROM public.aef_operations WHERE id = NEW.operation_id;
  IF NOT FOUND OR NOT public.aef__is_terminal(o.state)
     OR NEW.subject_id <> o.subject_id
     OR NEW.receipt ->> 'receipt_id' IS DISTINCT FROM NEW.id::text
     OR NEW.receipt ->> 'operation_id' IS DISTINCT FROM o.id::text
     OR NEW.receipt ->> 'subject_id' IS DISTINCT FROM o.subject_id::text
     OR NEW.receipt ->> 'binding_hash' IS DISTINCT FROM o.binding_hash
     OR NEW.receipt ->> 'final_state' IS DISTINCT FROM o.state
     OR NEW.receipt ->> 'outcome' IS DISTINCT FROM public.aef__outcome_for(o.state, o.side_effect_observed)
     OR NEW.receipt_hash <> public.aef__sha256(NEW.receipt::text) THEN
    RAISE EXCEPTION 'AEF_GUARD: receipt does not match its terminal operation';
  END IF;
  NEW.issued_at := now();
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.aef__guard_audit_events() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'AEF_GUARD: audit events are append-only';
  END IF;
  IF NEW.event_hash <> public.aef__event_hash(NEW.subject_id, NEW.seq, NEW.operation_id, NEW.event_type, NEW.from_state,
                                              NEW.to_state, NEW.reason_code, NEW.ref_hash, NEW.occurred_at, NEW.prev_hash) THEN
    RAISE EXCEPTION 'AEF_GUARD: audit event hash mismatch';
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.aef__guard_audit_heads() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'AEF_GUARD: audit heads are never deleted';
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.last_seq <> 0 OR NEW.last_hash <> repeat('0', 64) THEN
      RAISE EXCEPTION 'AEF_GUARD: audit head must start at genesis';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.subject_id <> OLD.subject_id OR NEW.last_seq <> OLD.last_seq + 1
     OR NOT EXISTS (SELECT 1 FROM public.aef_audit_events e
                    WHERE e.subject_id = NEW.subject_id AND e.seq = NEW.last_seq
                      AND e.event_hash = NEW.last_hash AND e.prev_hash = OLD.last_hash) THEN
    RAISE EXCEPTION 'AEF_GUARD: audit head may only advance to the next appended event';
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.aef__guard_truncate() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  RAISE EXCEPTION 'AEF_GUARD: % cannot be truncated', TG_TABLE_NAME;
END $$;

DROP TRIGGER IF EXISTS aef_operations_guard ON public.aef_operations;
CREATE TRIGGER aef_operations_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_operations
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_operations();
DROP TRIGGER IF EXISTS aef_human_gates_guard ON public.aef_human_gates;
CREATE TRIGGER aef_human_gates_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_human_gates
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_gates();
DROP TRIGGER IF EXISTS aef_receipts_guard ON public.aef_receipts;
CREATE TRIGGER aef_receipts_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_receipts
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_receipts();
DROP TRIGGER IF EXISTS aef_audit_events_guard ON public.aef_audit_events;
CREATE TRIGGER aef_audit_events_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_audit_events
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_audit_events();
DROP TRIGGER IF EXISTS aef_audit_heads_guard ON public.aef_audit_heads;
CREATE TRIGGER aef_audit_heads_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_audit_heads
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_audit_heads();

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['aef_operations', 'aef_human_gates', 'aef_receipts', 'aef_audit_events', 'aef_audit_heads'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', t || '_no_truncate', t);
    EXECUTE format('CREATE TRIGGER %I BEFORE TRUNCATE ON public.%I FOR EACH STATEMENT EXECUTE FUNCTION public.aef__guard_truncate()',
                   t || '_no_truncate', t);
  END LOOP;
END $$;

-- ── state-machine helpers (caller holds the operation row lock) ─────────
CREATE OR REPLACE FUNCTION public.aef__op_json(o public.aef_operations) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT jsonb_build_object(
    'operation_id', o.id, 'state', o.state, 'state_reason', o.state_reason,
    'action', o.action, 'tool_id', o.tool_id, 'action_class', o.action_class,
    'binding_hash', o.binding_hash, 'payload_hash', o.payload_hash,
    'policy_version', o.policy_version, 'risk_version', o.risk_version,
    'requires_human_gate', o.requires_human_gate, 'attempt_count', o.attempt_count,
    'expires_at', public.aef__ts(o.expires_at))
$$;

CREATE OR REPLACE FUNCTION public.aef__gate_json(p_op uuid) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT jsonb_build_object('gate_id', g.id, 'state', g.state, 'binding_hash', g.binding_hash,
                            'approver_id', g.approver_id, 'expires_at', public.aef__ts(g.expires_at))
  FROM public.aef_human_gates g WHERE g.operation_id = p_op
$$;

CREATE OR REPLACE FUNCTION public.aef__receipt_json(p_op uuid) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT jsonb_build_object('receipt', r.receipt, 'receipt_hash', r.receipt_hash)
  FROM public.aef_receipts r WHERE r.operation_id = p_op
$$;

CREATE OR REPLACE FUNCTION public.aef__view(p_op uuid) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT jsonb_build_object('operation', public.aef__op_json(o), 'gate', public.aef__gate_json(o.id),
                            'receipt', public.aef__receipt_json(o.id))
  FROM public.aef_operations o WHERE o.id = p_op
$$;

CREATE OR REPLACE FUNCTION public.aef__issue_receipt(p_op uuid) RETURNS void
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE o public.aef_operations; g public.aef_human_gates; v_id uuid := gen_random_uuid(); r jsonb; h text;
BEGIN
  SELECT * INTO o FROM public.aef_operations WHERE id = p_op;
  SELECT * INTO g FROM public.aef_human_gates WHERE operation_id = p_op;
  r := jsonb_build_object(
    'receipt_version', 'aef-receipt/1', 'receipt_id', v_id, 'operation_id', o.id, 'request_id', o.request_id,
    'subject_id', o.subject_id, 'domain', o.domain, 'action', o.action, 'tool_id', o.tool_id,
    'action_class', o.action_class, 'resource_type', o.resource_type, 'resource_id', o.resource_id,
    'binding_hash', o.binding_hash, 'payload_hash', o.payload_hash,
    'policy_version', o.policy_version, 'risk_version', o.risk_version,
    'human_gate_id', g.id, 'approver_id', g.approver_id,
    'policy_decision', CASE WHEN o.authorized_at IS NOT NULL THEN 'ALLOWED' ELSE 'DENIED' END,
    'outcome', public.aef__outcome_for(o.state, o.side_effect_observed),
    'final_state', o.state, 'reason_code', o.state_reason,
    'side_effect_observed', o.side_effect_observed, 'attempt_count', o.attempt_count,
    'registered_at', public.aef__ts(o.created_at), 'authorized_at', public.aef__ts(o.authorized_at),
    'completed_at', public.aef__ts(o.completed_at));
  h := public.aef__sha256(r::text);
  INSERT INTO public.aef_receipts (id, operation_id, subject_id, receipt, receipt_hash)
  VALUES (v_id, o.id, o.subject_id, r, h);
  PERFORM public.aef__audit_append(o.subject_id, o.id, 'RECEIPT_ISSUED', NULL, o.state,
                                   public.aef__outcome_for(o.state, o.side_effect_observed), h);
END $$;

CREATE OR REPLACE FUNCTION public.aef__op_to(p_op uuid, p_to text, p_reason text, p_side_effect boolean DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_from text; v_subject uuid;
BEGIN
  SELECT state, subject_id INTO v_from, v_subject FROM public.aef_operations WHERE id = p_op;
  UPDATE public.aef_operations
     SET state = p_to, state_reason = p_reason,
         side_effect_observed = CASE WHEN p_to IN ('SUCCEEDED', 'FAILED', 'UNKNOWN_OUTCOME') THEN p_side_effect ELSE side_effect_observed END
   WHERE id = p_op;
  PERFORM public.aef__audit_append(v_subject, p_op, 'OPERATION_TRANSITION', v_from, p_to, p_reason);
  IF public.aef__is_terminal(p_to) THEN
    PERFORM public.aef__issue_receipt(p_op);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.aef__gate_to(p_op uuid, p_to text, p_reason text, p_approver uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE g public.aef_human_gates;
BEGIN
  SELECT * INTO g FROM public.aef_human_gates WHERE operation_id = p_op FOR UPDATE;
  IF NOT FOUND OR g.state NOT IN ('REVIEW_REQUIRED', 'AUTHORIZED') THEN
    RETURN;
  END IF;
  UPDATE public.aef_human_gates
     SET state = p_to, state_reason = p_reason,
         approver_id = CASE WHEN p_to IN ('AUTHORIZED', 'REJECTED') THEN p_approver ELSE approver_id END
   WHERE id = g.id;
  PERFORM public.aef__audit_append(g.subject_id, p_op, 'GATE_TRANSITION', g.state, p_to, p_reason);
END $$;

-- Expires a locked, open operation (and its gate) when its deadline passed.
-- Returns true when it expired the operation now.
CREATE OR REPLACE FUNCTION public.aef__expire_if_due(p_op uuid) RETURNS boolean
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE o public.aef_operations; g public.aef_human_gates; v_gate_due boolean := false;
BEGIN
  SELECT * INTO o FROM public.aef_operations WHERE id = p_op;
  IF o.state NOT IN ('AWAITING_APPROVAL', 'AUTHORIZED') THEN
    RETURN false;
  END IF;
  SELECT * INTO g FROM public.aef_human_gates WHERE operation_id = p_op;
  IF FOUND AND g.state IN ('REVIEW_REQUIRED', 'AUTHORIZED') AND now() >= g.expires_at THEN
    v_gate_due := true;
  END IF;
  IF now() < o.expires_at AND NOT v_gate_due THEN
    RETURN false;
  END IF;
  PERFORM public.aef__gate_to(p_op, 'EXPIRED', 'GATE_EXPIRED');
  PERFORM public.aef__op_to(p_op, 'EXPIRED', CASE WHEN v_gate_due THEN 'GATE_EXPIRED' ELSE 'TTL_EXPIRED' END);
  RETURN true;
END $$;

-- ── RPC: register (create or idempotent replay) ─────────────────────────
CREATE OR REPLACE FUNCTION public.aef_register_operation(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_subject uuid; v_request uuid; v_key text; v_domain text; v_action text; v_tool text; v_class text;
  v_rtype text; v_rid text; v_project uuid; v_payload_hash text; v_payload_bytes int;
  v_policy text; v_risk text; v_gated boolean; v_ttl int; v_gate_ttl int;
  v_key_hash text; v_binding text; v_op_id uuid := gen_random_uuid(); v_rows int;
  v_existing public.aef_operations; v_expires timestamptz;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['subject_id', 'request_id', 'idempotency_key', 'domain', 'action', 'tool_id',
      'action_class', 'resource_type', 'resource_id', 'payload_hash', 'payload_bytes', 'policy_version', 'risk_version',
      'requires_human_gate', 'ttl_seconds', 'gate_ttl_seconds']);
    v_subject := public.aef__uuid(p, 'subject_id', true);
    v_request := public.aef__uuid(p, 'request_id', true);
    v_key := public.aef__text(p, 'idempotency_key', true, 200);
    v_domain := public.aef__text(p, 'domain', true, 16, '^(core|quant|impact|internal)$');
    v_action := public.aef__text(p, 'action', true, 200, '^[a-z][a-z0-9_]*([.][a-z][a-z0-9_]*)+$');
    v_tool := public.aef__text(p, 'tool_id', true, 200);
    v_class := public.aef__text(p, 'action_class', true, 16, '^(READ_ONLY|REVERSIBLE|CONSEQUENTIAL)$');
    v_rtype := public.aef__text(p, 'resource_type', false, 32);
    v_rid := public.aef__text(p, 'resource_id', false, 200);
    v_payload_hash := public.aef__text(p, 'payload_hash', true, 64, '^[0-9a-f]{64}$');
    v_payload_bytes := public.aef__int(p, 'payload_bytes', true, 2, 16384);
    v_policy := public.aef__text(p, 'policy_version', true, 64, '^[a-z0-9._/-]{1,64}$');
    v_risk := public.aef__text(p, 'risk_version', true, 64, '^[a-z0-9._/-]{1,64}$');
    v_gated := public.aef__bool(p, 'requires_human_gate');
    v_ttl := coalesce(public.aef__int(p, 'ttl_seconds', false, 60, 86400), 3600);
    v_gate_ttl := coalesce(public.aef__int(p, 'gate_ttl_seconds', false, 60, 3600), 900);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;

  IF (v_rtype IS NULL) <> (v_rid IS NULL) THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END IF;
  -- Server policy is decided in the AEF service; these re-checks make the
  -- database refuse the combinations the policy must never produce.
  IF v_class = 'CONSEQUENTIAL' AND NOT v_gated THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END IF;
  IF v_domain IN ('quant', 'impact') AND v_class <> 'READ_ONLY' THEN
    PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'POLICY_DENIED');
    RETURN public.aef__err('POLICY_DENIED');
  END IF;

  IF v_rtype IS NOT NULL THEN
    IF v_rtype <> 'project' THEN
      PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'RESOURCE_TYPE_UNSUPPORTED');
      RETURN public.aef__err('RESOURCE_TYPE_UNSUPPORTED');
    END IF;
    IF v_rid !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
      PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'RESOURCE_FORBIDDEN');
      RETURN public.aef__err('RESOURCE_FORBIDDEN');
    END IF;
    v_project := v_rid::uuid;
    v_rid := v_project::text;
    -- Ownership is checked here, server-side, never trusted from the caller.
    -- Not-found and foreign look identical (no existence oracle).
    IF NOT EXISTS (SELECT 1 FROM public.projects WHERE id = v_project AND user_id = v_subject) THEN
      PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'RESOURCE_FORBIDDEN');
      RETURN public.aef__err('RESOURCE_FORBIDDEN');
    END IF;
  END IF;

  v_key_hash := public.aef__sha256('aef-idem/1:' || v_subject::text || ':' || v_key);
  v_binding := public.aef__sha256(jsonb_build_array('aef-binding/1', v_subject, v_domain, v_action, v_tool, v_class,
                                                    v_rtype, v_rid, v_payload_hash, v_policy, v_risk, v_gated)::text);
  v_expires := now() + make_interval(secs => v_ttl);

  -- Admission (Codex Final CF-01, CFV-01): at most 50 open operations per
  -- subject. Checked AFTER the idempotency conflict is resolved, inside a
  -- subtransaction that undoes the insert, so a replay of an existing key
  -- (even one still being committed concurrently) is never refused by it.
  -- Soft limit: concurrent first registrations can overshoot slightly.
  BEGIN
    INSERT INTO public.aef_operations (id, subject_id, request_id, idempotency_key_hash, domain, action, tool_id,
      action_class, resource_type, resource_id, project_id, payload_hash, payload_bytes, binding_hash,
      policy_version, risk_version, requires_human_gate, state, expires_at)
    VALUES (v_op_id, v_subject, v_request, v_key_hash, v_domain, v_action, v_tool,
      v_class, v_rtype, v_rid, v_project, v_payload_hash, v_payload_bytes, v_binding,
      v_policy, v_risk, v_gated, CASE WHEN v_gated THEN 'AWAITING_APPROVAL' ELSE 'AUTHORIZED' END, v_expires)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 1 AND (SELECT count(*) FROM public.aef_operations
                        WHERE subject_id = v_subject AND state IN ('AWAITING_APPROVAL', 'AUTHORIZED', 'EXECUTING')) > 50 THEN
      RAISE EXCEPTION 'AEF_ADMISSION: open operation limit' USING ERRCODE = 'AE002';
    END IF;
  EXCEPTION WHEN SQLSTATE 'AE002' THEN
    PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'OPEN_OPERATION_LIMIT');
    RETURN public.aef__err('OPEN_OPERATION_LIMIT');
  END;

  IF v_rows = 0 THEN
    SELECT * INTO v_existing FROM public.aef_operations
     WHERE subject_id = v_subject AND idempotency_key_hash = v_key_hash FOR UPDATE;
    IF NOT FOUND THEN
      -- request_id already used by another operation: execution replay.
      PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'REQUEST_REPLAYED');
      RETURN public.aef__err('REQUEST_REPLAYED');
    END IF;
    IF v_existing.binding_hash <> v_binding THEN
      PERFORM public.aef__audit_append(v_subject, v_existing.id, 'REQUEST_DENIED', NULL, NULL, 'IDEMPOTENCY_CONFLICT');
      RETURN public.aef__err('IDEMPOTENCY_CONFLICT');
    END IF;
    PERFORM public.aef__expire_if_due(v_existing.id);
    RETURN jsonb_build_object('ok', true, 'outcome', 'REPLAY') || public.aef__view(v_existing.id);
  END IF;

  PERFORM public.aef__audit_append(v_subject, v_op_id, 'OPERATION_REGISTERED', NULL,
                                   CASE WHEN v_gated THEN 'AWAITING_APPROVAL' ELSE 'AUTHORIZED' END, NULL, v_binding);
  IF v_gated THEN
    INSERT INTO public.aef_human_gates (id, operation_id, subject_id, binding_hash, policy_version, state, expires_at)
    VALUES (gen_random_uuid(), v_op_id, v_subject, v_binding, v_policy, 'REVIEW_REQUIRED',
            least(now() + make_interval(secs => v_gate_ttl), v_expires));
    PERFORM public.aef__audit_append(v_subject, v_op_id, 'GATE_REQUESTED', NULL, 'REVIEW_REQUIRED', NULL, v_binding);
  END IF;
  RETURN jsonb_build_object('ok', true, 'outcome', 'CREATED') || public.aef__view(v_op_id);
END $$;

-- ── RPC: human decision ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef_decide_gate(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_gate uuid; v_approver uuid; v_decision text; v_binding text; v_policy text;
  v_op uuid; o public.aef_operations; g public.aef_human_gates;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['gate_id', 'approver_id', 'decision', 'binding_hash', 'policy_version']);
    v_gate := public.aef__uuid(p, 'gate_id', true);
    v_approver := public.aef__uuid(p, 'approver_id', true);
    v_decision := public.aef__text(p, 'decision', true, 8, '^(APPROVE|REJECT)$');
    v_binding := public.aef__text(p, 'binding_hash', true, 64, '^[0-9a-f]{64}$');
    v_policy := public.aef__text(p, 'policy_version', true, 64, '^[a-z0-9._/-]{1,64}$');
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;

  SELECT operation_id INTO v_op FROM public.aef_human_gates WHERE id = v_gate;
  IF NOT FOUND THEN
    RETURN public.aef__err('GATE_NOT_FOUND');
  END IF;
  -- Lock order everywhere: operation row, then gate row, then audit head.
  SELECT * INTO o FROM public.aef_operations WHERE id = v_op FOR UPDATE;
  SELECT * INTO g FROM public.aef_human_gates WHERE id = v_gate FOR UPDATE;

  IF v_approver <> o.subject_id THEN
    -- Recorded in the owner's chain; the caller learns nothing (no oracle).
    PERFORM public.aef__audit_append(o.subject_id, o.id, 'APPROVAL_DENIED', NULL, NULL, 'APPROVER_NOT_AUTHORIZED');
    RETURN public.aef__err('GATE_NOT_FOUND');
  END IF;
  IF public.aef__expire_if_due(o.id) THEN
    RETURN public.aef__err('GATE_EXPIRED', 'EXPIRED');
  END IF;
  IF g.state <> 'REVIEW_REQUIRED' THEN
    RETURN public.aef__err('GATE_NOT_PENDING', g.state);
  END IF;
  IF v_binding <> g.binding_hash THEN
    PERFORM public.aef__audit_append(o.subject_id, o.id, 'APPROVAL_DENIED', NULL, NULL, 'APPROVAL_BINDING_MISMATCH');
    RETURN public.aef__err('APPROVAL_BINDING_MISMATCH');
  END IF;
  IF v_policy <> o.policy_version THEN
    PERFORM public.aef__gate_to(o.id, 'INVALIDATED', 'POLICY_VERSION_CHANGED');
    PERFORM public.aef__op_to(o.id, 'INVALIDATED', 'POLICY_VERSION_CHANGED');
    RETURN public.aef__err('POLICY_VERSION_CHANGED', 'INVALIDATED');
  END IF;

  IF v_decision = 'APPROVE' THEN
    PERFORM public.aef__gate_to(o.id, 'AUTHORIZED', 'APPROVED_BY_SUBJECT', v_approver);
    PERFORM public.aef__op_to(o.id, 'AUTHORIZED', 'APPROVED_BY_SUBJECT');
  ELSE
    PERFORM public.aef__gate_to(o.id, 'REJECTED', 'REJECTED_BY_SUBJECT', v_approver);
    PERFORM public.aef__op_to(o.id, 'REJECTED', 'REJECTED_BY_SUBJECT');
  END IF;
  RETURN jsonb_build_object('ok', true) || public.aef__view(o.id);
END $$;

-- ── RPC: execution claim (the only path to EXECUTING) ───────────────────
CREATE OR REPLACE FUNCTION public.aef_claim_execution(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_op uuid; v_subject uuid; v_binding text; v_policy text; v_lease int;
  o public.aef_operations; g public.aef_human_gates; v_token uuid := gen_random_uuid();
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['operation_id', 'subject_id', 'binding_hash', 'policy_version', 'lease_seconds']);
    v_op := public.aef__uuid(p, 'operation_id', true);
    v_subject := public.aef__uuid(p, 'subject_id', true);
    v_binding := public.aef__text(p, 'binding_hash', true, 64, '^[0-9a-f]{64}$');
    v_policy := public.aef__text(p, 'policy_version', true, 64, '^[a-z0-9._/-]{1,64}$');
    v_lease := public.aef__int(p, 'lease_seconds', true, 5, 300);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;

  SELECT * INTO o FROM public.aef_operations WHERE id = v_op AND subject_id = v_subject FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.aef__err('OPERATION_NOT_FOUND');
  END IF;
  IF public.aef__expire_if_due(o.id) THEN
    RETURN public.aef__err('OPERATION_EXPIRED', 'EXPIRED');
  END IF;
  IF o.state <> 'AUTHORIZED' THEN
    RETURN public.aef__err('NOT_CLAIMABLE', o.state);
  END IF;
  IF v_binding <> o.binding_hash THEN
    RETURN public.aef__err('BINDING_MISMATCH');
  END IF;
  IF v_policy <> o.policy_version THEN
    PERFORM public.aef__gate_to(o.id, 'INVALIDATED', 'POLICY_VERSION_CHANGED');
    PERFORM public.aef__op_to(o.id, 'INVALIDATED', 'POLICY_VERSION_CHANGED');
    RETURN public.aef__err('POLICY_VERSION_CHANGED', 'INVALIDATED');
  END IF;
  IF o.requires_human_gate THEN
    SELECT * INTO g FROM public.aef_human_gates WHERE operation_id = o.id FOR UPDATE;
    IF NOT FOUND OR g.state <> 'AUTHORIZED' OR g.approver_id IS DISTINCT FROM o.subject_id OR g.binding_hash <> o.binding_hash THEN
      RETURN public.aef__err('GATE_NOT_AUTHORIZED');
    END IF;
    UPDATE public.aef_human_gates SET state = 'EXECUTED', state_reason = 'CONSUMED_BY_EXECUTION' WHERE id = g.id;
    PERFORM public.aef__audit_append(o.subject_id, o.id, 'GATE_TRANSITION', 'AUTHORIZED', 'EXECUTED', 'CONSUMED_BY_EXECUTION');
  END IF;
  UPDATE public.aef_operations
     SET state = 'EXECUTING', state_reason = 'EXECUTION_CLAIMED', attempt_count = 1,
         execution_token = v_token, lease_expires_at = now() + make_interval(secs => v_lease)
   WHERE id = o.id;
  PERFORM public.aef__audit_append(o.subject_id, o.id, 'OPERATION_TRANSITION', 'AUTHORIZED', 'EXECUTING', 'EXECUTION_CLAIMED');
  RETURN jsonb_build_object('ok', true, 'execution_token', v_token) || public.aef__view(o.id);
END $$;

-- ── RPC: execution completion ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef_complete_execution(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_op uuid; v_token uuid; v_result text; o public.aef_operations;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['operation_id', 'execution_token', 'result']);
    v_op := public.aef__uuid(p, 'operation_id', true);
    v_token := public.aef__uuid(p, 'execution_token', true);
    v_result := public.aef__text(p, 'result', true, 32,
      '^(SUCCEEDED|FAILED_NO_SIDE_EFFECT|FAILED_AFTER_SIDE_EFFECT|UNKNOWN_OUTCOME)$');
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;

  SELECT * INTO o FROM public.aef_operations WHERE id = v_op FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.aef__err('OPERATION_NOT_FOUND');
  END IF;
  -- A late report after recovery (UNKNOWN_OUTCOME) never rewrites history.
  IF o.state <> 'EXECUTING' OR o.execution_token IS DISTINCT FROM v_token THEN
    RETURN public.aef__err('EXECUTION_TOKEN_INVALID', o.state);
  END IF;
  CASE v_result
    WHEN 'SUCCEEDED' THEN PERFORM public.aef__op_to(o.id, 'SUCCEEDED', 'TOOL_SUCCEEDED', true);
    WHEN 'FAILED_NO_SIDE_EFFECT' THEN PERFORM public.aef__op_to(o.id, 'FAILED', 'TOOL_FAILED_NO_SIDE_EFFECT', false);
    WHEN 'FAILED_AFTER_SIDE_EFFECT' THEN PERFORM public.aef__op_to(o.id, 'FAILED', 'TOOL_FAILED_AFTER_SIDE_EFFECT', true);
    ELSE PERFORM public.aef__op_to(o.id, 'UNKNOWN_OUTCOME', 'TOOL_OUTCOME_UNKNOWN', NULL);
  END CASE;
  RETURN jsonb_build_object('ok', true) || public.aef__view(o.id);
END $$;

-- ── RPC: cancellation (never compensates) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.aef_cancel_operation(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_op uuid; v_subject uuid; o public.aef_operations;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['operation_id', 'subject_id']);
    v_op := public.aef__uuid(p, 'operation_id', true);
    v_subject := public.aef__uuid(p, 'subject_id', true);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;

  SELECT * INTO o FROM public.aef_operations WHERE id = v_op AND subject_id = v_subject FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.aef__err('OPERATION_NOT_FOUND');
  END IF;
  IF public.aef__expire_if_due(o.id) THEN
    RETURN public.aef__err('OPERATION_EXPIRED', 'EXPIRED');
  END IF;
  IF o.state = 'EXECUTING' THEN
    RETURN public.aef__err('CANCEL_NOT_ALLOWED_IN_FLIGHT', o.state);
  END IF;
  IF o.state NOT IN ('AWAITING_APPROVAL', 'AUTHORIZED') THEN
    RETURN public.aef__err('OPERATION_TERMINAL', o.state);
  END IF;
  PERFORM public.aef__gate_to(o.id, 'CANCELLED', 'CANCELLED_BY_SUBJECT');
  PERFORM public.aef__op_to(o.id, 'CANCELLED', 'CANCELLED_BY_SUBJECT');
  RETURN jsonb_build_object('ok', true) || public.aef__view(o.id);
END $$;

-- ── RPC: recovery sweep (expired approvals, crashed executions) ─────────
CREATE OR REPLACE FUNCTION public.aef_recover(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_limit int; o public.aef_operations; v_unknown int := 0; v_expired int := 0;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['limit']);
    v_limit := coalesce(public.aef__int(p, 'limit', false, 1, 500), 100);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;

  FOR o IN
    SELECT op.* FROM public.aef_operations op
     WHERE (op.state = 'EXECUTING' AND op.lease_expires_at <= now())
        OR (op.state IN ('AWAITING_APPROVAL', 'AUTHORIZED')
            AND (op.expires_at <= now()
                 OR EXISTS (SELECT 1 FROM public.aef_human_gates g
                             WHERE g.operation_id = op.id AND g.state IN ('REVIEW_REQUIRED', 'AUTHORIZED')
                               AND g.expires_at <= now())))
     ORDER BY op.created_at
     LIMIT v_limit
     FOR UPDATE OF op SKIP LOCKED
  LOOP
    IF o.state = 'EXECUTING' THEN
      -- A crashed or timed-out execution is never assumed to have
      -- succeeded or failed, and is never retried automatically.
      PERFORM public.aef__op_to(o.id, 'UNKNOWN_OUTCOME', 'LEASE_EXPIRED', NULL);
      v_unknown := v_unknown + 1;
    ELSIF public.aef__expire_if_due(o.id) THEN
      v_expired := v_expired + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'unknown_outcome', v_unknown, 'expired', v_expired);
END $$;

-- ── RPC: read ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef_get_operation(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_op uuid; v_subject uuid;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['operation_id', 'subject_id']);
    v_op := public.aef__uuid(p, 'operation_id', true);
    v_subject := public.aef__uuid(p, 'subject_id', true);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;
  IF NOT EXISTS (SELECT 1 FROM public.aef_operations WHERE id = v_op AND subject_id = v_subject) THEN
    RETURN public.aef__err('OPERATION_NOT_FOUND');
  END IF;
  RETURN jsonb_build_object('ok', true) || public.aef__view(v_op);
END $$;

CREATE OR REPLACE FUNCTION public.aef_record_denial(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_subject uuid; v_code text;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['subject_id', 'reason_code']);
    v_subject := public.aef__uuid(p, 'subject_id', true);
    v_code := public.aef__text(p, 'reason_code', true, 64, '^[A-Z][A-Z0-9_]{0,63}$');
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;
  PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, v_code);
  RETURN jsonb_build_object('ok', true);
END $$;

-- ── RPC: integrity verification ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef_verify_receipt(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_receipt jsonb; v_id uuid; r public.aef_receipts; e public.aef_audit_events;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['receipt']);
    IF jsonb_typeof(p -> 'receipt') IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'AEF_ARGUMENT: receipt object required' USING ERRCODE = 'AE001';
    END IF;
    v_receipt := p -> 'receipt';
    v_id := public.aef__uuid(v_receipt, 'receipt_id', true);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_MALFORMED');
  END;
  SELECT * INTO r FROM public.aef_receipts WHERE id = v_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_UNKNOWN');
  END IF;
  IF r.receipt <> v_receipt THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_MISMATCH');
  END IF;
  IF r.receipt_hash <> public.aef__sha256(r.receipt::text) THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_HASH_INVALID');
  END IF;
  SELECT * INTO e FROM public.aef_audit_events
   WHERE subject_id = r.subject_id AND operation_id = r.operation_id
     AND event_type = 'RECEIPT_ISSUED' AND ref_hash = r.receipt_hash;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_NOT_ANCHORED');
  END IF;
  -- Codex Gate 1 G1-04: the anchor must itself be intact, and so must the
  -- whole chain it belongs to.
  IF e.event_hash <> public.aef__event_hash(e.subject_id, e.seq, e.operation_id, e.event_type, e.from_state, e.to_state,
                                            e.reason_code, e.ref_hash, e.occurred_at, e.prev_hash) THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_ANCHOR_INVALID');
  END IF;
  IF (public.aef_verify_audit_chain(jsonb_build_object('subject_id', r.subject_id)) ->> 'valid')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_CHAIN_INVALID');
  END IF;
  RETURN jsonb_build_object('ok', true, 'valid', true, 'receipt_hash', r.receipt_hash);
END $$;

CREATE OR REPLACE FUNCTION public.aef_verify_audit_chain(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_subject uuid; e public.aef_audit_events; v_prev text := repeat('0', 64); v_seq bigint := 0; h public.aef_audit_heads;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['subject_id']);
    v_subject := public.aef__uuid(p, 'subject_id', true);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;
  FOR e IN SELECT * FROM public.aef_audit_events WHERE subject_id = v_subject ORDER BY seq LOOP
    IF e.seq <> v_seq + 1 THEN
      RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'SEQUENCE_GAP', 'at_seq', v_seq + 1);
    END IF;
    IF e.prev_hash <> v_prev THEN
      RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'CHAIN_BROKEN', 'at_seq', e.seq);
    END IF;
    IF e.event_hash <> public.aef__event_hash(e.subject_id, e.seq, e.operation_id, e.event_type, e.from_state, e.to_state,
                                              e.reason_code, e.ref_hash, e.occurred_at, e.prev_hash) THEN
      RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'EVENT_HASH_INVALID', 'at_seq', e.seq);
    END IF;
    v_prev := e.event_hash;
    v_seq := e.seq;
  END LOOP;
  SELECT * INTO h FROM public.aef_audit_heads WHERE subject_id = v_subject;
  IF (FOUND AND (h.last_seq <> v_seq OR h.last_hash <> v_prev)) OR (NOT FOUND AND v_seq <> 0) THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'HEAD_MISMATCH', 'at_seq', v_seq);
  END IF;
  RETURN jsonb_build_object('ok', true, 'valid', true, 'events', v_seq, 'head', v_prev);
END $$;

-- ── RLS + privileges ────────────────────────────────────────────────────
ALTER TABLE public.aef_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_human_gates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_audit_heads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS aef_operations_owner_read ON public.aef_operations;
CREATE POLICY aef_operations_owner_read ON public.aef_operations FOR SELECT TO authenticated
  USING (subject_id = auth.uid());
DROP POLICY IF EXISTS aef_human_gates_owner_read ON public.aef_human_gates;
CREATE POLICY aef_human_gates_owner_read ON public.aef_human_gates FOR SELECT TO authenticated
  USING (subject_id = auth.uid());
DROP POLICY IF EXISTS aef_receipts_owner_read ON public.aef_receipts;
CREATE POLICY aef_receipts_owner_read ON public.aef_receipts FOR SELECT TO authenticated
  USING (subject_id = auth.uid());
DROP POLICY IF EXISTS aef_audit_events_owner_read ON public.aef_audit_events;
CREATE POLICY aef_audit_events_owner_read ON public.aef_audit_events FOR SELECT TO authenticated
  USING (subject_id = auth.uid());
-- aef_audit_heads: no policy → no end-user access.

REVOKE ALL ON TABLE public.aef_operations, public.aef_human_gates, public.aef_receipts,
                    public.aef_audit_events, public.aef_audit_heads
  FROM PUBLIC, anon, authenticated, service_role;
-- execution_token is never readable by end users.
GRANT SELECT (id, subject_id, request_id, domain, action, tool_id, action_class, resource_type, resource_id,
              project_id, payload_hash, payload_bytes, binding_hash, policy_version, risk_version,
              requires_human_gate, state, state_reason, attempt_count, side_effect_observed, created_at,
              authorized_at, completed_at, updated_at, expires_at)
  ON public.aef_operations TO authenticated;
GRANT SELECT ON public.aef_human_gates, public.aef_receipts, public.aef_audit_events TO authenticated;
-- Codex Gate 1 G1-02/G1-03: service_role gets NO direct write privilege on
-- any AEF table and cannot call the internal aef__* helpers. The ten RPCs
-- below (SECURITY DEFINER, pinned search_path, owned by the migration owner)
-- are the only mutation path; service_role may only read, for operations
-- tooling.
GRANT SELECT ON public.aef_operations, public.aef_human_gates, public.aef_receipts,
                public.aef_audit_events, public.aef_audit_heads TO service_role;

DO $$
DECLARE f regprocedure; v_name text;
BEGIN
  FOR f, v_name IN SELECT p.oid::regprocedure, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_' LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated, service_role', f);
    IF v_name IN ('aef_register_operation', 'aef_decide_gate', 'aef_claim_execution', 'aef_complete_execution',
                  'aef_cancel_operation', 'aef_recover', 'aef_get_operation', 'aef_record_denial',
                  'aef_verify_receipt', 'aef_verify_audit_chain') THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
    END IF;
  END LOOP;
END $$;

-- ── AEF sequences: deny by default (IV-AEF-PRE-RUNTIME-CLOSURE-01, P03) ──
-- Production's default privileges grant every new sequence in public rwU to
-- anon/authenticated/service_role; the audit identity sequence would inherit
-- them. Revoked here, in the migration that creates it, so no exposure window
-- exists between migrations; 20260927000000 re-asserts it with a
-- postcondition (and repairs a database where an earlier revision of this
-- file was applied). The SECURITY DEFINER RPCs need no grant.
DO $$
DECLARE s oid;
BEGIN
  FOR s IN SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'S'
       AND (left(c.relname, 4) = 'aef_' OR EXISTS (
             SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
              WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_'))
  LOOP
    EXECUTE format('REVOKE ALL ON SEQUENCE %s FROM PUBLIC, anon, authenticated, service_role', s::regclass);
  END LOOP;
END $$;
