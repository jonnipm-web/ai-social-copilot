-- IV-AEF-HARDENING-01 — retention, erasure, audit growth control,
-- UNKNOWN_OUTCOME reconciliation and ExecutionReceipt v1.1.
--
-- MODULE LAB ONLY. Not applied to production or to any shared database.
-- Additive on top of 20260925000000_aef_persistence.sql (which is not edited):
-- new tables, new RPCs (aef_reconcile, aef_purge, aef_erase_subject) and
-- CREATE OR REPLACE of the functions whose behavior changes:
--   * guards: DELETE allowed only inside purge / erasure (aef.maintenance,
--     set transaction-locally by those two SECURITY DEFINER functions; no API
--     role has any DELETE privilege, so the flag alone grants nothing);
--   * aef__issue_receipt: new receipts are aef-receipt/1.1 (receipt_kind);
--     stored aef-receipt/1 receipts are never rewritten;
--   * aef__audit_append: denial events rate-limited per subject (coalesced,
--     never dropped); the event hash formula is unchanged;
--   * aef_register_operation: retired (tombstoned) keys and request ids;
--   * aef_recover: flushes closed denial windows;
--   * aef__view / verification: reconciliations, checkpoints, coalesced counts.
-- Idempotent; rollback: supabase/rollbacks/20260926000000_aef_hardening.down.sql.

-- ── preconditions (IV-AEF-PRE-RUNTIME-CLOSURE-01, P05) ─────────────────
-- Fail fast, before creating anything, when an object this migration
-- depends on is missing or has an incompatible shape: the complete
-- persistence layer (20260925000000: 5 tables, 10 RPCs), public.subject_roles
-- (20260923000000; used by the operator-reconciliation authority check),
-- auth.users(id uuid) (erasure / operator account) and
-- pg_catalog.hashtextextended(text, bigint) -> bigint (subject advisory lock).
DO $$
DECLARE v_missing text[] := ARRAY[]::text[]; v text;
BEGIN
  FOREACH v IN ARRAY ARRAY['public.aef_operations', 'public.aef_human_gates', 'public.aef_receipts', 'public.aef_audit_events', 'public.aef_audit_heads'] LOOP
    IF to_regclass(v) IS NULL THEN v_missing := v_missing || (v || ' (20260925000000)'); END IF;
  END LOOP;
  FOREACH v IN ARRAY ARRAY['public.aef_register_operation(jsonb)', 'public.aef_decide_gate(jsonb)', 'public.aef_claim_execution(jsonb)', 'public.aef_complete_execution(jsonb)', 'public.aef_cancel_operation(jsonb)', 'public.aef_recover(jsonb)', 'public.aef_get_operation(jsonb)', 'public.aef_record_denial(jsonb)', 'public.aef_verify_receipt(jsonb)', 'public.aef_verify_audit_chain(jsonb)'] LOOP
    IF to_regprocedure(v) IS NULL THEN v_missing := v_missing || (v || ' (20260925000000)'); END IF;
  END LOOP;
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subject_roles'
       AND is_nullable = 'NO' AND ((column_name = 'subject_type' AND data_type = 'text')
                                   OR (column_name = 'subject_id' AND data_type = 'uuid')
                                   OR (column_name = 'role' AND data_type = 'text'))) <> 3 THEN
    v_missing := v_missing || 'public.subject_roles(subject_type text, subject_id uuid, role text) NOT NULL from 20260923000000_entitlement_subject_roles'::text;
  ELSIF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.subject_roles'::regclass AND contype = 'p'
                       AND pg_get_constraintdef(oid) = 'PRIMARY KEY (subject_type, subject_id, role)')
        OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.subject_roles'::regclass AND contype = 'c'
                       AND pg_get_constraintdef(oid) LIKE '%role = ANY%admin%')
        OR NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.subject_roles'::regclass) THEN
    -- Codex G2V-02: the operator-authority check trusts this table, so its
    -- identity (primary key), role domain (CHECK) and RLS must be the ones
    -- 20260923000000 creates, not merely the column names.
    v_missing := v_missing || 'public.subject_roles primary key / role CHECK / RLS as created by 20260923000000'::text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users'
                  AND column_name = 'id' AND data_type = 'uuid') THEN
    v_missing := v_missing || 'auth.users.id uuid'::text;
  END IF;
  IF to_regprocedure('pg_catalog.hashtextextended(text, bigint)') IS NULL
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('pg_catalog.hashtextextended(text, bigint)')) IS DISTINCT FROM 'bigint'::regtype THEN
    v_missing := v_missing || 'pg_catalog.hashtextextended(text, bigint) -> bigint'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'AEF_PRECONDITION (20260926000000_aef_hardening): missing or incompatible: %', array_to_string(v_missing, ', ')
      USING ERRCODE = 'AE010';
  END IF;
END $$;

-- ── new tables ──────────────────────────────────────────────────────────
-- Retention policy: one row, owner-managed (no RPC can change it). Values are
-- PROVISIONAL, conservative defaults pending an Owner/compliance decision
-- (AEF_RETENTION_ERASURE_MODEL.md); they are not legal periods.
CREATE TABLE IF NOT EXISTS public.aef_retention_policy (
  id                              boolean PRIMARY KEY DEFAULT true CHECK (id),
  policy_ref                      text NOT NULL CHECK (policy_ref ~ '^[a-z0-9._/-]{1,64}$'),
  terminal_retention_days         integer NOT NULL CHECK (terminal_retention_days BETWEEN 30 AND 3650),
  audit_retention_days            integer NOT NULL CHECK (audit_retention_days BETWEEN 30 AND 3650),
  denial_window_seconds           integer NOT NULL CHECK (denial_window_seconds BETWEEN 10 AND 3600),
  denial_window_limit             integer NOT NULL CHECK (denial_window_limit BETWEEN 1 AND 1000),
  erasure_blocks_on_unreconciled  boolean NOT NULL,
  -- Codex HCF-01: an operator's reconciliation is a human attestation, not a
  -- machine-checked proof. Disabled until the Owner explicitly enables it;
  -- until then only server-registered verifiers can reconcile.
  operator_reconciliation_enabled boolean NOT NULL DEFAULT false,
  CONSTRAINT aef_retention_audit_outlives_operations CHECK (audit_retention_days >= terminal_retention_days)
);
-- Idempotent across intermediate versions of this migration (Codex HCFV-01).
ALTER TABLE public.aef_retention_policy
  ADD COLUMN IF NOT EXISTS operator_reconciliation_enabled boolean NOT NULL DEFAULT false;
INSERT INTO public.aef_retention_policy (id, policy_ref, terminal_retention_days, audit_retention_days,
                                         denial_window_seconds, denial_window_limit, erasure_blocks_on_unreconciled)
VALUES (true, 'aef-retention/2026-09-26.1-provisional', 365, 730, 60, 20, true)
ON CONFLICT (id) DO NOTHING;

-- Legal / compliance hold: blocks purge and erasure for a subject. Owner-managed.
CREATE TABLE IF NOT EXISTS public.aef_legal_holds (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id   uuid NOT NULL,
  reason_code  text NOT NULL CHECK (reason_code ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  placed_at    timestamptz NOT NULL DEFAULT now(),
  released_at  timestamptz
);
CREATE INDEX IF NOT EXISTS aef_legal_holds_active_idx ON public.aef_legal_holds (subject_id) WHERE released_at IS NULL;

-- A purged operation leaves a tombstone: its idempotency key and request id
-- can never start a new operation (no re-execution after purge).
CREATE TABLE IF NOT EXISTS public.aef_idempotency_tombstones (
  subject_id            uuid NOT NULL,
  idempotency_key_hash  text NOT NULL CHECK (idempotency_key_hash ~ '^[0-9a-f]{64}$'),
  request_id            uuid NOT NULL UNIQUE,
  operation_id          uuid NOT NULL UNIQUE,
  final_state           text NOT NULL,
  receipt_hash          text CHECK (receipt_hash IS NULL OR receipt_hash ~ '^[0-9a-f]{64}$'),
  purged_at             timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (subject_id, idempotency_key_hash)
);

-- Server-registered reconciliation verifiers (per tool). EMPTY by default:
-- with no registered verifier and the operator path disabled (default),
-- nothing can be reconciled (fail closed).
CREATE TABLE IF NOT EXISTS public.aef_reconciliation_verifiers (
  verifier_id    text PRIMARY KEY CHECK (verifier_id ~ '^[a-z][a-z0-9_.-]{2,63}$'),
  tool_id        text NOT NULL CHECK (length(tool_id) BETWEEN 1 AND 200),
  enabled        boolean NOT NULL DEFAULT true,
  registered_at  timestamptz NOT NULL DEFAULT now()
);

-- Reconciliation of an UNKNOWN_OUTCOME operation: append-only, one per
-- operation, with its own receipt (aef-receipt/1.1, kind RECONCILIATION).
-- The operation and its original receipt are never modified.
CREATE TABLE IF NOT EXISTS public.aef_reconciliations (
  id               uuid PRIMARY KEY,
  operation_id     uuid NOT NULL UNIQUE REFERENCES public.aef_operations (id),
  subject_id       uuid NOT NULL,
  verdict          text NOT NULL CHECK (verdict IN ('CONFIRMED_APPLIED', 'CONFIRMED_NOT_APPLIED')),
  reconciler_kind  text NOT NULL CHECK (reconciler_kind IN ('VERIFIER', 'OPERATOR')),
  reconciler_id    text CHECK (reconciler_id IS NULL OR length(reconciler_id) BETWEEN 1 AND 64),
  evidence_kind    text NOT NULL CHECK (evidence_kind ~ '^[A-Z][A-Z0-9_]{0,63}$'),
  evidence_hash    text NOT NULL CHECK (evidence_hash ~ '^[0-9a-f]{64}$'),
  policy_version   text NOT NULL CHECK (policy_version ~ '^[a-z0-9._/-]{1,64}$'),
  risk_version     text NOT NULL CHECK (risk_version ~ '^[a-z0-9._/-]{1,64}$'),
  receipt          jsonb NOT NULL,
  receipt_hash     text NOT NULL CHECK (receipt_hash ~ '^[0-9a-f]{64}$'),
  reconciled_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS aef_reconciliations_subject_idx ON public.aef_reconciliations (subject_id);

-- Audit growth control: per-subject denial window and durable pending
-- counters. Nothing is dropped: over the limit, denials become counters that
-- are later flushed into the chain as DENIALS_COALESCED events whose ref_hash
-- commits to the aef_audit_coalesced row (type, code, count, window).
CREATE TABLE IF NOT EXISTS public.aef_audit_windows (
  subject_id    uuid PRIMARY KEY,
  window_start  timestamptz NOT NULL,
  recorded      integer NOT NULL DEFAULT 0 CHECK (recorded >= 0)
);
CREATE TABLE IF NOT EXISTS public.aef_audit_pending (
  subject_id   uuid NOT NULL,
  event_type   text NOT NULL,
  reason_code  text NOT NULL,
  count        bigint NOT NULL CHECK (count >= 1),
  first_at     timestamptz NOT NULL,
  PRIMARY KEY (subject_id, event_type, reason_code)
);
CREATE TABLE IF NOT EXISTS public.aef_audit_coalesced (
  subject_id    uuid NOT NULL,
  seq           bigint NOT NULL,
  event_type    text NOT NULL,
  reason_code   text NOT NULL,
  count         bigint NOT NULL CHECK (count >= 1),
  window_start  timestamptz NOT NULL,
  window_end    timestamptz NOT NULL,
  PRIMARY KEY (subject_id, seq)
);
-- Audit prefix pruning keeps verifiability: verification restarts from the
-- last pruned event's hash.
CREATE TABLE IF NOT EXISTS public.aef_audit_checkpoints (
  subject_id  uuid PRIMARY KEY,
  seq         bigint NOT NULL CHECK (seq >= 1),
  event_hash  text NOT NULL CHECK (event_hash ~ '^[0-9a-f]{64}$'),
  pruned_at   timestamptz NOT NULL DEFAULT now()
);
-- Minimized erasure log (pseudonymous subject reference, counts only).
CREATE TABLE IF NOT EXISTS public.aef_erasures (
  id           uuid PRIMARY KEY,
  subject_ref  text NOT NULL UNIQUE CHECK (subject_ref ~ '^[0-9a-f]{64}$'),
  erased_at    timestamptz NOT NULL DEFAULT now(),
  counts       jsonb NOT NULL
);

-- ── per-subject serialization (Codex HG1-01, HG2-02) ───────────────────
-- Transaction-scoped advisory lock per subject: erasure takes it exclusive
-- (blocking), registration shared (blocking), legal-hold writes exclusive
-- (trigger), purge exclusive with try-lock only (never waits → no deadlock).
CREATE OR REPLACE FUNCTION public.aef__subject_lock_key(p_subject uuid) RETURNS bigint
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT hashtextextended('aef-subject:' || p_subject::text, 0)
$$;

CREATE OR REPLACE FUNCTION public.aef__erased(p_subject uuid) RETURNS boolean
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM public.aef_erasures
                  WHERE subject_ref = public.aef__sha256('aef-erasure/1:' || p_subject::text))
$$;

-- Closed set of denial codes (Codex HG1-03): aef_record_denial accepts only
-- these, and coalescing maps anything else to UNLISTED, so the number of
-- pending counters per subject is bounded by this list.
CREATE OR REPLACE FUNCTION public.aef__denial_codes() RETURNS text[]
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT ARRAY['INVALID_REQUEST', 'DELEGATION_UNSUPPORTED', 'CLIENT_APPROVAL_REJECTED', 'IDEMPOTENCY_KEY_REQUIRED',
               'RESOURCE_TYPE_UNSUPPORTED', 'UNKNOWN_TOOL', 'POLICY_DENIED', 'PAYLOAD_INVALID', 'PAYLOAD_TOO_LARGE',
               'RESOURCE_FORBIDDEN', 'REQUEST_REPLAYED', 'IDEMPOTENCY_CONFLICT', 'OPEN_OPERATION_LIMIT',
               'IDEMPOTENCY_KEY_RETIRED', 'APPROVER_NOT_AUTHORIZED', 'APPROVAL_BINDING_MISMATCH']
$$;

CREATE OR REPLACE FUNCTION public.aef__guard_legal_holds() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  -- Serialize with purge / erasure of the same subject: a hold committed
  -- before they take the subject lock is always seen by their re-check.
  PERFORM pg_advisory_xact_lock(public.aef__subject_lock_key(CASE WHEN TG_OP = 'DELETE' THEN OLD.subject_id ELSE NEW.subject_id END));
  IF TG_OP = 'UPDATE' AND NEW.subject_id <> OLD.subject_id THEN
    RAISE EXCEPTION 'AEF_GUARD: a legal hold cannot move to another subject';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

-- ── maintenance flag (purge / erasure only) ─────────────────────────────
CREATE OR REPLACE FUNCTION public.aef__maintenance() RETURNS boolean
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT coalesce(current_setting('aef.maintenance', true), '') = 'on'
$$;

-- ── audit chain append (raw) + coalescing wrapper ───────────────────────
CREATE OR REPLACE FUNCTION public.aef__chain_append(
  p_subject uuid, p_op uuid, p_event text, p_from text, p_to text, p_reason text, p_ref text) RETURNS bigint
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
  RETURN v_seq;
END $$;

CREATE OR REPLACE FUNCTION public.aef__coalesced_ref(
  p_subject uuid, p_event text, p_reason text, p_count bigint, p_start timestamptz, p_end timestamptz) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT public.aef__sha256(jsonb_build_array('aef-coalesced/1', p_subject, p_event, p_reason, p_count,
                                              public.aef__ts(p_start), public.aef__ts(p_end))::text)
$$;

-- Flushes a subject's pending counters into the chain. Caller holds the
-- subject's window row lock (lock order: window → head).
CREATE OR REPLACE FUNCTION public.aef__flush_window(p_subject uuid) RETURNS integer
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE r record; v_end timestamptz := clock_timestamp(); v_ref text; v_seq bigint; v_n integer := 0;
BEGIN
  FOR r IN DELETE FROM public.aef_audit_pending WHERE subject_id = p_subject
           RETURNING event_type, reason_code, count, first_at LOOP
    v_ref := public.aef__coalesced_ref(p_subject, r.event_type, r.reason_code, r.count, r.first_at, v_end);
    v_seq := public.aef__chain_append(p_subject, NULL, 'DENIALS_COALESCED', NULL, NULL, r.reason_code, v_ref);
    INSERT INTO public.aef_audit_coalesced (subject_id, seq, event_type, reason_code, count, window_start, window_end)
    VALUES (p_subject, v_seq, r.event_type, r.reason_code, r.count, r.first_at, v_end);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $$;

-- Same signature as before; denial events are now rate-limited per subject.
-- Only REQUEST_DENIED / APPROVAL_DENIED are coalescible; state transitions,
-- receipts, reconciliations, purges and erasures are never coalesced.
CREATE OR REPLACE FUNCTION public.aef__audit_append(
  p_subject uuid, p_op uuid, p_event text, p_from text, p_to text, p_reason text, p_ref text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE w public.aef_audit_windows; pol public.aef_retention_policy;
BEGIN
  IF p_event IN ('REQUEST_DENIED', 'APPROVAL_DENIED') THEN
    SELECT * INTO pol FROM public.aef_retention_policy WHERE id;
    INSERT INTO public.aef_audit_windows (subject_id, window_start, recorded)
    VALUES (p_subject, clock_timestamp(), 0) ON CONFLICT (subject_id) DO NOTHING;
    SELECT * INTO w FROM public.aef_audit_windows WHERE subject_id = p_subject FOR UPDATE;
    IF clock_timestamp() >= w.window_start + make_interval(secs => pol.denial_window_seconds) THEN
      PERFORM public.aef__flush_window(p_subject);
      UPDATE public.aef_audit_windows SET window_start = clock_timestamp(), recorded = 0 WHERE subject_id = p_subject;
      w.recorded := 0;
    END IF;
    IF w.recorded >= pol.denial_window_limit THEN
      INSERT INTO public.aef_audit_pending (subject_id, event_type, reason_code, count, first_at)
      VALUES (p_subject, p_event,
              CASE WHEN p_reason = ANY (public.aef__denial_codes()) THEN p_reason ELSE 'UNLISTED' END, 1, clock_timestamp())
      ON CONFLICT (subject_id, event_type, reason_code) DO UPDATE SET count = public.aef_audit_pending.count + 1;
      RETURN;
    END IF;
    UPDATE public.aef_audit_windows SET recorded = recorded + 1 WHERE subject_id = p_subject;
  END IF;
  PERFORM public.aef__chain_append(p_subject, p_op, p_event, p_from, p_to, p_reason, p_ref);
END $$;

-- ── guards for the new tables ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef__guard_reconciliations() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE o public.aef_operations; r public.aef_receipts;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF public.aef__maintenance() THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'AEF_GUARD: reconciliations are append-only';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'AEF_GUARD: reconciliations are append-only';
  END IF;
  SELECT * INTO o FROM public.aef_operations WHERE id = NEW.operation_id;
  SELECT * INTO r FROM public.aef_receipts WHERE operation_id = NEW.operation_id;
  -- Codex HG3-02: bound to the operation's original receipt; HG3-03: no raw operator id.
  IF NOT FOUND OR NEW.receipt ->> 'original_receipt_id' IS DISTINCT FROM r.id::text
     OR NEW.receipt ->> 'original_receipt_hash' IS DISTINCT FROM r.receipt_hash
     OR (NEW.reconciler_kind = 'OPERATOR' AND NEW.reconciler_id IS NOT NULL) THEN
    RAISE EXCEPTION 'AEF_GUARD: reconciliation is not bound to the original receipt';
  END IF;
  IF NOT FOUND OR o.state <> 'UNKNOWN_OUTCOME' OR NEW.subject_id <> o.subject_id
     OR NEW.receipt ->> 'receipt_id' IS DISTINCT FROM NEW.id::text
     OR NEW.receipt ->> 'receipt_kind' IS DISTINCT FROM 'RECONCILIATION'
     OR NEW.receipt ->> 'operation_id' IS DISTINCT FROM o.id::text
     OR NEW.receipt ->> 'subject_id' IS DISTINCT FROM o.subject_id::text
     OR NEW.receipt ->> 'binding_hash' IS DISTINCT FROM o.binding_hash
     OR NEW.receipt ->> 'verdict' IS DISTINCT FROM NEW.verdict
     OR NEW.receipt_hash <> public.aef__sha256(NEW.receipt::text) THEN
    RAISE EXCEPTION 'AEF_GUARD: reconciliation does not match an UNKNOWN_OUTCOME operation';
  END IF;
  NEW.reconciled_at := now();
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.aef__guard_maintenance_only() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF public.aef__maintenance() THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;
  RAISE EXCEPTION 'AEF_GUARD: % on % only by retention purge or erasure', TG_OP, TG_TABLE_NAME;
END $$;

CREATE OR REPLACE FUNCTION public.aef__guard_append_only() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN RETURN NEW; END IF;
  IF TG_OP = 'DELETE' AND public.aef__maintenance() THEN RETURN OLD; END IF;
  RAISE EXCEPTION 'AEF_GUARD: % is append-only', TG_TABLE_NAME;
END $$;

CREATE OR REPLACE FUNCTION public.aef__guard_erasures() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' AND public.aef__maintenance() THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'AEF_GUARD: the erasure log is written only by erasure and never changed';
END $$;

DROP TRIGGER IF EXISTS aef_legal_holds_guard ON public.aef_legal_holds;
CREATE TRIGGER aef_legal_holds_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_legal_holds
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_legal_holds();
DROP TRIGGER IF EXISTS aef_reconciliations_guard ON public.aef_reconciliations;
CREATE TRIGGER aef_reconciliations_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_reconciliations
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_reconciliations();
DROP TRIGGER IF EXISTS aef_idempotency_tombstones_guard ON public.aef_idempotency_tombstones;
CREATE TRIGGER aef_idempotency_tombstones_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_idempotency_tombstones
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_maintenance_only();
DROP TRIGGER IF EXISTS aef_audit_checkpoints_guard ON public.aef_audit_checkpoints;
CREATE TRIGGER aef_audit_checkpoints_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_audit_checkpoints
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_maintenance_only();
DROP TRIGGER IF EXISTS aef_audit_coalesced_guard ON public.aef_audit_coalesced;
CREATE TRIGGER aef_audit_coalesced_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_audit_coalesced
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_append_only();
DROP TRIGGER IF EXISTS aef_erasures_guard ON public.aef_erasures;
CREATE TRIGGER aef_erasures_guard BEFORE INSERT OR UPDATE OR DELETE ON public.aef_erasures
  FOR EACH ROW EXECUTE FUNCTION public.aef__guard_erasures();

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['aef_reconciliations', 'aef_idempotency_tombstones', 'aef_audit_checkpoints',
                           'aef_audit_coalesced', 'aef_erasures', 'aef_audit_windows', 'aef_audit_pending',
                           'aef_retention_policy', 'aef_legal_holds', 'aef_reconciliation_verifiers'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', t || '_no_truncate', t);
    EXECUTE format('CREATE TRIGGER %I BEFORE TRUNCATE ON public.%I FOR EACH STATEMENT EXECUTE FUNCTION public.aef__guard_truncate()',
                   t || '_no_truncate', t);
  END LOOP;
END $$;

-- ── views (adds the reconciliation) ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aef__reconciliation_json(p_op uuid) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT jsonb_build_object('receipt', r.receipt, 'receipt_hash', r.receipt_hash)
  FROM public.aef_reconciliations r WHERE r.operation_id = p_op
$$;

CREATE OR REPLACE FUNCTION public.aef__view(p_op uuid) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT jsonb_build_object('operation', public.aef__op_json(o), 'gate', public.aef__gate_json(o.id),
                            'receipt', public.aef__receipt_json(o.id),
                            'reconciliation', public.aef__reconciliation_json(o.id))
  FROM public.aef_operations o WHERE o.id = p_op
$$;

-- ── RPC: reconciliation of UNKNOWN_OUTCOME ──────────────────────────────
-- Never re-executes, never rewrites the operation or its receipt, never
-- trusts the subject: the reconciler is a server-registered verifier for the
-- operation's tool, or an operator holding the admin role who is not the
-- subject. One reconciliation per operation, final.
CREATE OR REPLACE FUNCTION public.aef_reconcile(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_op uuid; v_verdict text; v_kind text; v_reconciler text; v_evidence_kind text; v_evidence_ref text;
  v_policy text; v_risk text; o public.aef_operations; r public.aef_receipts; v_operator uuid;
  v_id uuid := gen_random_uuid(); v_receipt jsonb; v_hash text; v_at timestamptz := now();
  pol public.aef_retention_policy;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['operation_id', 'verdict', 'reconciler_kind', 'reconciler_id',
      'evidence_kind', 'evidence_ref', 'policy_version', 'risk_version']);
    v_op := public.aef__uuid(p, 'operation_id', true);
    v_verdict := public.aef__text(p, 'verdict', true, 32, '^(CONFIRMED_APPLIED|CONFIRMED_NOT_APPLIED)$');
    v_kind := public.aef__text(p, 'reconciler_kind', true, 16, '^(VERIFIER|OPERATOR)$');
    v_reconciler := public.aef__text(p, 'reconciler_id', true, 64);
    v_evidence_kind := public.aef__text(p, 'evidence_kind', true, 64, '^[A-Z][A-Z0-9_]{0,63}$');
    v_evidence_ref := public.aef__text(p, 'evidence_ref', true, 200);
    v_policy := public.aef__text(p, 'policy_version', true, 64, '^[a-z0-9._/-]{1,64}$');
    v_risk := public.aef__text(p, 'risk_version', true, 64, '^[a-z0-9._/-]{1,64}$');
    IF v_kind = 'OPERATOR' THEN
      v_operator := public.aef__uuid(p, 'reconciler_id', true);
      v_reconciler := v_operator::text;
    ELSIF v_reconciler !~ '^[a-z][a-z0-9_.-]{2,63}$' THEN
      RAISE EXCEPTION 'AEF_ARGUMENT: verifier id' USING ERRCODE = 'AE001';
    END IF;
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;

  SELECT * INTO o FROM public.aef_operations WHERE id = v_op FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.aef__err('OPERATION_NOT_FOUND');
  END IF;
  IF o.state <> 'UNKNOWN_OUTCOME' THEN
    RETURN public.aef__err('NOT_RECONCILABLE', o.state);
  END IF;
  IF EXISTS (SELECT 1 FROM public.aef_reconciliations WHERE operation_id = o.id) THEN
    RETURN public.aef__err('ALREADY_RECONCILED', o.state);
  END IF;

  SELECT * INTO pol FROM public.aef_retention_policy WHERE id;
  IF v_kind = 'OPERATOR' AND pol.operator_reconciliation_enabled IS NOT TRUE THEN
    PERFORM public.aef__audit_append(o.subject_id, o.id, 'RECONCILIATION_DENIED', NULL, NULL, 'OPERATOR_PATH_DISABLED');
    RETURN public.aef__err('RECONCILER_NOT_AUTHORIZED');
  END IF;
  IF (v_kind = 'VERIFIER' AND NOT EXISTS (SELECT 1 FROM public.aef_reconciliation_verifiers
                                           WHERE verifier_id = v_reconciler AND tool_id = o.tool_id AND enabled))
     OR (v_kind = 'OPERATOR' AND (v_operator = o.subject_id
         OR NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_operator)
         OR public.aef__erased(v_operator)
         OR NOT EXISTS (SELECT 1 FROM public.subject_roles
                         WHERE subject_type = 'user' AND subject_id = v_operator AND role = 'admin'))) THEN
    PERFORM public.aef__audit_append(o.subject_id, o.id, 'RECONCILIATION_DENIED', NULL, NULL, 'RECONCILER_NOT_AUTHORIZED');
    RETURN public.aef__err('RECONCILER_NOT_AUTHORIZED');
  END IF;

  SELECT * INTO r FROM public.aef_receipts WHERE operation_id = o.id;
  v_receipt := jsonb_build_object(
    'receipt_version', 'aef-receipt/1.1', 'receipt_kind', 'RECONCILIATION', 'receipt_id', v_id,
    'operation_id', o.id, 'request_id', o.request_id, 'subject_id', o.subject_id,
    'action', o.action, 'tool_id', o.tool_id, 'binding_hash', o.binding_hash,
    'original_receipt_id', r.id, 'original_receipt_hash', r.receipt_hash, 'original_outcome', 'UNKNOWN_OUTCOME',
    'verdict', v_verdict, 'reconciler_kind', v_kind,
    'reconciler_ref', public.aef__sha256('aef-reconciler/1:' || v_kind || ':' || v_reconciler),
    'evidence_kind', v_evidence_kind, 'evidence_hash', public.aef__sha256('aef-evidence/1:' || v_evidence_ref),
    'operation_policy_version', o.policy_version, 'operation_risk_version', o.risk_version,
    'policy_version', v_policy, 'risk_version', v_risk,
    'reconciled_at', public.aef__ts(v_at));
  v_hash := public.aef__sha256(v_receipt::text);
  INSERT INTO public.aef_reconciliations (id, operation_id, subject_id, verdict, reconciler_kind, reconciler_id,
    evidence_kind, evidence_hash, policy_version, risk_version, receipt, receipt_hash)
  VALUES (v_id, o.id, o.subject_id, v_verdict, v_kind, CASE WHEN v_kind = 'OPERATOR' THEN NULL ELSE v_reconciler END, v_evidence_kind,
    v_receipt ->> 'evidence_hash', v_policy, v_risk, v_receipt, v_hash);
  PERFORM public.aef__audit_append(o.subject_id, o.id, 'RECONCILIATION_RECORDED', 'UNKNOWN_OUTCOME', v_verdict, v_kind, v_hash);
  RETURN jsonb_build_object('ok', true) || public.aef__view(o.id);
END $$;

-- ── RPC: retention purge ────────────────────────────────────────────────
-- Purges terminal operations past retention (never open ones, never an
-- unreconciled UNKNOWN_OUTCOME, never under legal hold), leaving an
-- idempotency tombstone and an OPERATION_PURGED audit event; then prunes the
-- oldest audit events of a subject behind a checkpoint, never past an event
-- of an operation that still exists.
CREATE OR REPLACE FUNCTION public.aef_purge(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_limit int; pol public.aef_retention_policy; o public.aef_operations; v_rh text; v_ops int := 0; v_events int := 0;
  s uuid; v_cut bigint; v_last bigint; v_hash text; v_n int;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['limit']);
    v_limit := coalesce(public.aef__int(p, 'limit', false, 1, 1000), 200);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;
  PERFORM set_config('aef.maintenance', 'on', true);
  SELECT * INTO pol FROM public.aef_retention_policy WHERE id;

  FOR o IN
    SELECT op.* FROM public.aef_operations op
     WHERE public.aef__is_terminal(op.state)
       AND op.completed_at < now() - make_interval(days => pol.terminal_retention_days)
       AND NOT EXISTS (SELECT 1 FROM public.aef_legal_holds h WHERE h.subject_id = op.subject_id AND h.released_at IS NULL)
       AND (op.state <> 'UNKNOWN_OUTCOME'
            OR EXISTS (SELECT 1 FROM public.aef_reconciliations rc WHERE rc.operation_id = op.id
                        AND rc.reconciled_at < now() - make_interval(days => pol.terminal_retention_days)))
     ORDER BY op.completed_at
     LIMIT v_limit
     FOR UPDATE OF op SKIP LOCKED
  LOOP
    -- Codex HG1-01: serialize with legal holds / erasure; never wait (skip).
    IF NOT pg_try_advisory_xact_lock(public.aef__subject_lock_key(o.subject_id))
       OR EXISTS (SELECT 1 FROM public.aef_legal_holds h WHERE h.subject_id = o.subject_id AND h.released_at IS NULL) THEN
      CONTINUE;
    END IF;
    SELECT receipt_hash INTO v_rh FROM public.aef_receipts WHERE operation_id = o.id;
    DELETE FROM public.aef_reconciliations WHERE operation_id = o.id;
    DELETE FROM public.aef_receipts WHERE operation_id = o.id;
    DELETE FROM public.aef_human_gates WHERE operation_id = o.id;
    DELETE FROM public.aef_operations WHERE id = o.id;
    INSERT INTO public.aef_idempotency_tombstones (subject_id, idempotency_key_hash, request_id, operation_id, final_state, receipt_hash)
    VALUES (o.subject_id, o.idempotency_key_hash, o.request_id, o.id, o.state, v_rh);
    PERFORM public.aef__chain_append(o.subject_id, o.id, 'OPERATION_PURGED', o.state, NULL, 'RETENTION_EXPIRED', v_rh);
    v_ops := v_ops + 1;
  END LOOP;

  FOR s IN
    SELECT h.subject_id FROM public.aef_audit_heads h
     WHERE EXISTS (SELECT 1 FROM public.aef_audit_events e WHERE e.subject_id = h.subject_id
                    AND e.occurred_at < now() - make_interval(days => pol.audit_retention_days))
       AND NOT EXISTS (SELECT 1 FROM public.aef_legal_holds lh WHERE lh.subject_id = h.subject_id AND lh.released_at IS NULL)
     LIMIT v_limit
     FOR UPDATE OF h SKIP LOCKED
  LOOP
    IF NOT pg_try_advisory_xact_lock(public.aef__subject_lock_key(s))
       OR EXISTS (SELECT 1 FROM public.aef_legal_holds lh WHERE lh.subject_id = s AND lh.released_at IS NULL) THEN
      CONTINUE;
    END IF;
    SELECT last_seq INTO v_last FROM public.aef_audit_heads WHERE subject_id = s;
    SELECT min(e.seq) - 1 INTO v_cut FROM public.aef_audit_events e
     WHERE e.subject_id = s
       AND (e.occurred_at >= now() - make_interval(days => pol.audit_retention_days)
            OR (e.operation_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.aef_operations x WHERE x.id = e.operation_id)));
    v_cut := coalesce(v_cut, v_last);
    IF v_cut >= 1 AND EXISTS (SELECT 1 FROM public.aef_audit_events WHERE subject_id = s AND seq = v_cut) THEN
      SELECT event_hash INTO v_hash FROM public.aef_audit_events WHERE subject_id = s AND seq = v_cut;
      DELETE FROM public.aef_audit_coalesced WHERE subject_id = s AND seq <= v_cut;
      DELETE FROM public.aef_audit_events WHERE subject_id = s AND seq <= v_cut;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_events := v_events + v_n;
      INSERT INTO public.aef_audit_checkpoints (subject_id, seq, event_hash, pruned_at) VALUES (s, v_cut, v_hash, now())
      ON CONFLICT (subject_id) DO UPDATE SET seq = EXCLUDED.seq, event_hash = EXCLUDED.event_hash, pruned_at = EXCLUDED.pruned_at;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'purged_operations', v_ops, 'pruned_events', v_events,
                            'policy_ref', pol.policy_ref);
END $$;

-- ── RPC: subject erasure (after account deletion) ───────────────────────
-- Hard-deletes every AEF record of the subject (its hash chain is its own,
-- so no other subject's chain or receipt is affected), detaches it where it
-- acted as operator on others' reconciliations, and leaves only a
-- pseudonymous, count-only erasure record. Idempotent. Refused while the
-- account exists, under legal hold, while an execution is in flight, and
-- (policy flag) while an UNKNOWN_OUTCOME is unreconciled.
CREATE OR REPLACE FUNCTION public.aef_erase_subject(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_subject uuid; v_ref text; pol public.aef_retention_policy; v_counts jsonb := '{}'::jsonb; v_n int;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['subject_id']);
    v_subject := public.aef__uuid(p, 'subject_id', true);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;
  -- Codex HG2-02: exclusive per-subject lock — registration (shared) and
  -- legal-hold writes serialize with the whole erasure.
  PERFORM pg_advisory_xact_lock(public.aef__subject_lock_key(v_subject));
  PERFORM set_config('aef.maintenance', 'on', true);
  SELECT * INTO pol FROM public.aef_retention_policy WHERE id;
  v_ref := public.aef__sha256('aef-erasure/1:' || v_subject::text);

  IF EXISTS (SELECT 1 FROM auth.users WHERE id = v_subject) THEN
    RETURN public.aef__err('ERASURE_ACCOUNT_ACTIVE');
  END IF;
  IF EXISTS (SELECT 1 FROM public.aef_legal_holds WHERE subject_id = v_subject AND released_at IS NULL) THEN
    RETURN public.aef__err('ERASURE_BLOCKED_HOLD');
  END IF;
  -- Lock order: operations (by id), then the audit head.
  PERFORM 1 FROM public.aef_operations WHERE subject_id = v_subject ORDER BY id FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.aef_operations WHERE subject_id = v_subject AND state = 'EXECUTING') THEN
    RETURN public.aef__err('ERASURE_BLOCKED_ACTIVE');
  END IF;
  IF pol.erasure_blocks_on_unreconciled AND EXISTS (
       SELECT 1 FROM public.aef_operations op WHERE op.subject_id = v_subject AND op.state = 'UNKNOWN_OUTCOME'
          AND NOT EXISTS (SELECT 1 FROM public.aef_reconciliations rc WHERE rc.operation_id = op.id)) THEN
    RETURN public.aef__err('ERASURE_BLOCKED_UNRECONCILED');
  END IF;
  -- Codex HG2-01: same order as every append (window → head).
  PERFORM 1 FROM public.aef_audit_windows WHERE subject_id = v_subject FOR UPDATE;
  PERFORM 1 FROM public.aef_audit_heads WHERE subject_id = v_subject FOR UPDATE;

  DELETE FROM public.aef_reconciliations WHERE subject_id = v_subject; GET DIAGNOSTICS v_n = ROW_COUNT;
  v_counts := v_counts || jsonb_build_object('reconciliations', v_n);
  DELETE FROM public.aef_receipts WHERE subject_id = v_subject; GET DIAGNOSTICS v_n = ROW_COUNT;
  v_counts := v_counts || jsonb_build_object('receipts', v_n);
  DELETE FROM public.aef_human_gates WHERE subject_id = v_subject; GET DIAGNOSTICS v_n = ROW_COUNT;
  v_counts := v_counts || jsonb_build_object('gates', v_n);
  DELETE FROM public.aef_operations WHERE subject_id = v_subject; GET DIAGNOSTICS v_n = ROW_COUNT;
  v_counts := v_counts || jsonb_build_object('operations', v_n);
  DELETE FROM public.aef_audit_coalesced WHERE subject_id = v_subject;
  DELETE FROM public.aef_audit_pending WHERE subject_id = v_subject;
  DELETE FROM public.aef_audit_windows WHERE subject_id = v_subject;
  DELETE FROM public.aef_audit_checkpoints WHERE subject_id = v_subject;
  DELETE FROM public.aef_audit_events WHERE subject_id = v_subject; GET DIAGNOSTICS v_n = ROW_COUNT;
  v_counts := v_counts || jsonb_build_object('audit_events', v_n);
  DELETE FROM public.aef_audit_heads WHERE subject_id = v_subject;
  DELETE FROM public.aef_idempotency_tombstones WHERE subject_id = v_subject; GET DIAGNOSTICS v_n = ROW_COUNT;
  v_counts := v_counts || jsonb_build_object('tombstones', v_n);

  INSERT INTO public.aef_erasures (id, subject_ref, counts) VALUES (gen_random_uuid(), v_ref, v_counts)
  ON CONFLICT (subject_ref) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'outcome', CASE WHEN v_n = 1 THEN 'ERASED' ELSE 'ALREADY_ERASED' END,
                            'counts', v_counts);
END $$;

-- ── integrity verification (checkpoints, coalesced counts, reconciliations)
CREATE OR REPLACE FUNCTION public.aef_verify_audit_chain(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_subject uuid; e public.aef_audit_events; v_prev text := repeat('0', 64); v_seq bigint := 0;
  h public.aef_audit_heads; cp public.aef_audit_checkpoints; c public.aef_audit_coalesced;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['subject_id']);
    v_subject := public.aef__uuid(p, 'subject_id', true);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;
  SELECT * INTO cp FROM public.aef_audit_checkpoints WHERE subject_id = v_subject;
  IF FOUND THEN
    v_seq := cp.seq;
    v_prev := cp.event_hash;
  END IF;
  FOR e IN SELECT * FROM public.aef_audit_events WHERE subject_id = v_subject AND seq > v_seq ORDER BY seq LOOP
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
    IF e.event_type = 'DENIALS_COALESCED' THEN
      SELECT * INTO c FROM public.aef_audit_coalesced WHERE subject_id = e.subject_id AND seq = e.seq;
      IF NOT FOUND OR c.reason_code <> e.reason_code
         OR e.ref_hash IS DISTINCT FROM public.aef__coalesced_ref(c.subject_id, c.event_type, c.reason_code, c.count,
                                                                  c.window_start, c.window_end) THEN
        RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'COALESCED_MISMATCH', 'at_seq', e.seq);
      END IF;
    END IF;
    v_prev := e.event_hash;
    v_seq := e.seq;
  END LOOP;
  SELECT * INTO h FROM public.aef_audit_heads WHERE subject_id = v_subject;
  IF (FOUND AND (h.last_seq <> v_seq OR h.last_hash <> v_prev)) OR (NOT FOUND AND v_seq <> 0) THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'HEAD_MISMATCH', 'at_seq', v_seq);
  END IF;
  RETURN jsonb_build_object('ok', true, 'valid', true, 'events', v_seq, 'head', v_prev,
                            'checkpoint_seq', cp.seq);
END $$;

CREATE OR REPLACE FUNCTION public.aef_verify_receipt(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_receipt jsonb; v_id uuid; v_stored jsonb; v_hash text; v_subject uuid; v_op uuid; v_anchor text;
  e public.aef_audit_events;
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
  SELECT r.receipt, r.receipt_hash, r.subject_id, r.operation_id INTO v_stored, v_hash, v_subject, v_op
    FROM public.aef_receipts r WHERE r.id = v_id;
  IF FOUND THEN
    v_anchor := 'RECEIPT_ISSUED';
  ELSE
    SELECT r.receipt, r.receipt_hash, r.subject_id, r.operation_id INTO v_stored, v_hash, v_subject, v_op
      FROM public.aef_reconciliations r WHERE r.id = v_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_UNKNOWN');
    END IF;
    v_anchor := 'RECONCILIATION_RECORDED';
    -- Codex HG3-02: the referenced original receipt must exist and match.
    IF NOT EXISTS (SELECT 1 FROM public.aef_receipts o
                    WHERE o.operation_id = v_op AND o.id::text = v_stored ->> 'original_receipt_id'
                      AND o.receipt_hash = v_stored ->> 'original_receipt_hash'
                      AND o.receipt_hash = public.aef__sha256(o.receipt::text)) THEN
      RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_ORIGINAL_MISMATCH');
    END IF;
  END IF;
  IF v_stored <> v_receipt THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_MISMATCH');
  END IF;
  IF v_hash <> public.aef__sha256(v_stored::text) THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_HASH_INVALID');
  END IF;
  SELECT * INTO e FROM public.aef_audit_events
   WHERE subject_id = v_subject AND operation_id = v_op AND event_type = v_anchor AND ref_hash = v_hash;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_NOT_ANCHORED');
  END IF;
  IF e.event_hash <> public.aef__event_hash(e.subject_id, e.seq, e.operation_id, e.event_type, e.from_state, e.to_state,
                                            e.reason_code, e.ref_hash, e.occurred_at, e.prev_hash) THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_ANCHOR_INVALID');
  END IF;
  IF (public.aef_verify_audit_chain(jsonb_build_object('subject_id', v_subject)) ->> 'valid')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'valid', false, 'reason', 'RECEIPT_CHAIN_INVALID');
  END IF;
  RETURN jsonb_build_object('ok', true, 'valid', true, 'receipt_hash', v_hash,
                            'receipt_version', v_stored ->> 'receipt_version');
END $$;

-- ── redefined functions (patched copies) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.aef__guard_operations() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE g public.aef_human_gates;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF public.aef__maintenance() THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'AEF_GUARD: aef_operations rows are deleted only by retention purge or erasure';
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
    IF public.aef__maintenance() THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'AEF_GUARD: aef_human_gates rows are deleted only by retention purge or erasure';
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
  IF TG_OP = 'DELETE' AND public.aef__maintenance() THEN RETURN OLD; END IF;
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
  IF TG_OP = 'DELETE' AND public.aef__maintenance() THEN RETURN OLD; END IF;
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
    IF public.aef__maintenance() THEN RETURN OLD; END IF;
    RAISE EXCEPTION 'AEF_GUARD: audit heads are deleted only by erasure';
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

CREATE OR REPLACE FUNCTION public.aef__issue_receipt(p_op uuid) RETURNS void
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE o public.aef_operations; g public.aef_human_gates; v_id uuid := gen_random_uuid(); r jsonb; h text;
BEGIN
  SELECT * INTO o FROM public.aef_operations WHERE id = p_op;
  SELECT * INTO g FROM public.aef_human_gates WHERE operation_id = p_op;
  r := jsonb_build_object(
    'receipt_version', 'aef-receipt/1.1', 'receipt_kind', 'EXECUTION', 'receipt_id', v_id, 'operation_id', o.id, 'request_id', o.request_id,
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

  PERFORM pg_advisory_xact_lock_shared(public.aef__subject_lock_key(v_subject));
  IF public.aef__erased(v_subject) THEN
    RETURN public.aef__err('SUBJECT_ERASED');
  END IF;

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

  -- IV-AEF-HARDENING-01: a purged operation's key and request id are retired
  -- forever (tombstone); they can never start a new operation.
  IF EXISTS (SELECT 1 FROM public.aef_idempotency_tombstones WHERE subject_id = v_subject AND idempotency_key_hash = v_key_hash) THEN
    PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'IDEMPOTENCY_KEY_RETIRED');
    RETURN public.aef__err('IDEMPOTENCY_KEY_RETIRED');
  END IF;
  IF EXISTS (SELECT 1 FROM public.aef_idempotency_tombstones WHERE request_id = v_request) THEN
    PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'REQUEST_REPLAYED');
    RETURN public.aef__err('REQUEST_REPLAYED');
  END IF;

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
    -- Re-check after the insert (new snapshot): a purge that committed while
    -- this insert waited on the unique index must not let the key revive.
    IF v_rows = 1 AND EXISTS (SELECT 1 FROM public.aef_idempotency_tombstones
                               WHERE (subject_id = v_subject AND idempotency_key_hash = v_key_hash) OR request_id = v_request) THEN
      RAISE EXCEPTION 'AEF_ADMISSION: retired key' USING ERRCODE = 'AE003';
    END IF;
    IF v_rows = 1 AND (SELECT count(*) FROM public.aef_operations
                        WHERE subject_id = v_subject AND state IN ('AWAITING_APPROVAL', 'AUTHORIZED', 'EXECUTING')) > 50 THEN
      RAISE EXCEPTION 'AEF_ADMISSION: open operation limit' USING ERRCODE = 'AE002';
    END IF;
  EXCEPTION WHEN SQLSTATE 'AE002' THEN
    PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'OPEN_OPERATION_LIMIT');
    RETURN public.aef__err('OPEN_OPERATION_LIMIT');
  WHEN SQLSTATE 'AE003' THEN
    PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, 'IDEMPOTENCY_KEY_RETIRED');
    RETURN public.aef__err('IDEMPOTENCY_KEY_RETIRED');
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
  IF NOT (v_code = ANY (public.aef__denial_codes())) THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END IF;
  PERFORM pg_advisory_xact_lock_shared(public.aef__subject_lock_key(v_subject));
  IF public.aef__erased(v_subject) THEN
    RETURN public.aef__err('SUBJECT_ERASED');
  END IF;
  PERFORM public.aef__audit_append(v_subject, NULL, 'REQUEST_DENIED', NULL, NULL, v_code);
  RETURN jsonb_build_object('ok', true);
END $$;

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
  IF o.id IS NULL OR g.id IS NULL THEN
    RETURN public.aef__err('GATE_NOT_FOUND');
  END IF;

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

CREATE OR REPLACE FUNCTION public.aef_recover(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_limit int; o public.aef_operations; v_unknown int := 0; v_expired int := 0; v_flushed int := 0;
  s uuid; pol public.aef_retention_policy;
BEGIN
  BEGIN
    PERFORM public.aef__check_keys(p, ARRAY['limit']);
    v_limit := coalesce(public.aef__int(p, 'limit', false, 1, 500), 100);
  EXCEPTION WHEN SQLSTATE 'AE001' THEN
    RETURN public.aef__err('ARGUMENT_REJECTED');
  END;

  -- IV-AEF-HARDENING-01: flush coalesced denial counters of closed windows
  -- (lock order window → head; SKIP LOCKED, before any operation lock).
  SELECT * INTO pol FROM public.aef_retention_policy WHERE id;
  FOR s IN SELECT w.subject_id FROM public.aef_audit_windows w
            WHERE w.window_start + make_interval(secs => pol.denial_window_seconds) <= clock_timestamp()
              AND EXISTS (SELECT 1 FROM public.aef_audit_pending x WHERE x.subject_id = w.subject_id)
            LIMIT v_limit FOR UPDATE OF w SKIP LOCKED LOOP
    -- A subject being erased is skipped (try-lock, never waits).
    IF NOT pg_try_advisory_xact_lock_shared(public.aef__subject_lock_key(s)) THEN
      CONTINUE;
    END IF;
    v_flushed := v_flushed + public.aef__flush_window(s);
    UPDATE public.aef_audit_windows SET window_start = clock_timestamp(), recorded = 0 WHERE subject_id = s;
  END LOOP;

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
  RETURN jsonb_build_object('ok', true, 'unknown_outcome', v_unknown, 'expired', v_expired, 'coalesced_flushed', v_flushed);
END $$;

-- ── RLS + privileges for the new tables ─────────────────────────────────
ALTER TABLE public.aef_retention_policy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_legal_holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_idempotency_tombstones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_reconciliation_verifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_audit_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_audit_pending ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_audit_coalesced ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_audit_checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aef_erasures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS aef_reconciliations_owner_read ON public.aef_reconciliations;
CREATE POLICY aef_reconciliations_owner_read ON public.aef_reconciliations FOR SELECT TO authenticated
  USING (subject_id = auth.uid());

REVOKE ALL ON TABLE public.aef_retention_policy, public.aef_legal_holds, public.aef_idempotency_tombstones,
                    public.aef_reconciliation_verifiers, public.aef_reconciliations, public.aef_audit_windows,
                    public.aef_audit_pending, public.aef_audit_coalesced, public.aef_audit_checkpoints, public.aef_erasures
  FROM PUBLIC, anon, authenticated, service_role;
-- The operator's raw id is never readable by the subject (receipt carries a hash).
GRANT SELECT (id, operation_id, subject_id, verdict, reconciler_kind, evidence_kind, evidence_hash, policy_version,
              risk_version, receipt, receipt_hash, reconciled_at)
  ON public.aef_reconciliations TO authenticated;
GRANT SELECT ON public.aef_retention_policy, public.aef_legal_holds, public.aef_idempotency_tombstones,
                public.aef_reconciliation_verifiers, public.aef_reconciliations, public.aef_audit_windows,
                public.aef_audit_pending, public.aef_audit_coalesced, public.aef_audit_checkpoints, public.aef_erasures
  TO service_role;

DO $$
DECLARE f regprocedure; v_name text;
BEGIN
  FOR f, v_name IN SELECT p.oid::regprocedure, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_' LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated, service_role', f);
    IF v_name IN ('aef_register_operation', 'aef_decide_gate', 'aef_claim_execution', 'aef_complete_execution',
                  'aef_cancel_operation', 'aef_recover', 'aef_get_operation', 'aef_record_denial',
                  'aef_verify_receipt', 'aef_verify_audit_chain', 'aef_reconcile', 'aef_purge', 'aef_erase_subject') THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
    END IF;
  END LOOP;
END $$;
