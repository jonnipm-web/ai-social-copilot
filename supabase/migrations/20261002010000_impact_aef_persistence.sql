-- IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01 — AEF persistence.
--
-- STATUS: Impact Lab only. NOT applied to production by this mission.
--
-- Persists the AEF (Action Execution Framework) governance trail for
-- consequential Impact actions. Every class C action produces:
--   impact_aef_requests    — the original request + caller context
--   impact_aef_decisions   — the policy decision
--   impact_aef_gates       — the human gate (if required)
--   impact_aef_receipts    — immutable receipt for every attempt
--
-- Security:
--   * RLS on every table. authenticated may only SELECT rows for investigations
--     they own. No INSERT/UPDATE from the client tier.
--   * Writes happen only in the impact-lab Edge Function via service_role,
--     AFTER authentication, entitlement and ownership validation.
--   * Receipts are append-only (no UPDATE/DELETE, enforced by trigger).
--   * No secret, JWT, document content or personal data may be stored.
--   * Gate status transitions PENDING → APPROVED/REJECTED/EXPIRED only.
--
-- Rollback (Lab): DROP TABLE public.impact_aef_receipts, public.impact_aef_gates,
--   public.impact_aef_decisions, public.impact_aef_requests CASCADE;
--   then DROP the impact_aef_* functions.
--
-- Idempotent: safe to re-run.

-- ── helpers ──────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.impact_aef_is_uuid(v text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT v ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
$$;

CREATE OR REPLACE FUNCTION public.impact_aef_is_hex64(v text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT v ~ '^[0-9a-f]{64}$'
$$;

-- ── impact_aef_requests ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_aef_requests (
  request_id         uuid PRIMARY KEY,
  correlation_id     text NOT NULL CHECK (length(correlation_id) BETWEEN 1 AND 128),
  caller_user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id         uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  service_id         text NOT NULL CHECK (service_id IN ('impact-lab', 'impact-monitor')),
  intent_kind        text NOT NULL CHECK (intent_kind IN (
                       'REQUEST_MANUAL_VERIFICATION',
                       'APPROVE_DOSSIER_PUBLICATION',
                       'ACKNOWLEDGE_CONFLICT',
                       'MARK_INVESTIGATION_REVIEWED'
                     )),
  investigation_id   uuid NOT NULL REFERENCES public.impact_investigations(id) ON DELETE CASCADE,
  idempotency_key    uuid NOT NULL,
  classification     text NOT NULL CHECK (classification IN ('READ_ONLY','REVERSIBLE','CONSEQUENTIAL','IRREVERSIBLE')),
  requested_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT impact_aef_requests_idempotency
    UNIQUE (caller_user_id, intent_kind, idempotency_key)
);

ALTER TABLE public.impact_aef_requests ENABLE ROW LEVEL SECURITY;

-- authenticated users may read their own requests
DROP POLICY IF EXISTS impact_aef_requests_select ON public.impact_aef_requests;
CREATE POLICY impact_aef_requests_select ON public.impact_aef_requests
  FOR SELECT TO authenticated
  USING (caller_user_id = (SELECT auth.uid()));

-- only service_role may write
REVOKE INSERT, UPDATE, DELETE ON public.impact_aef_requests FROM authenticated, anon;

-- ── impact_aef_decisions ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_aef_decisions (
  request_id      uuid PRIMARY KEY REFERENCES public.impact_aef_requests(request_id) ON DELETE CASCADE,
  outcome         text NOT NULL CHECK (outcome IN ('AUTHORIZED','DENIED','REQUIRES_HUMAN_REVIEW')),
  policy_version  text NOT NULL CHECK (length(policy_version) BETWEEN 1 AND 128),
  reason          text NOT NULL CHECK (length(reason) BETWEEN 1 AND 256),
  decided_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.impact_aef_decisions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS impact_aef_decisions_select ON public.impact_aef_decisions;
CREATE POLICY impact_aef_decisions_select ON public.impact_aef_decisions
  FOR SELECT TO authenticated
  USING (
    request_id IN (
      SELECT request_id FROM public.impact_aef_requests
      WHERE caller_user_id = (SELECT auth.uid())
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.impact_aef_decisions FROM authenticated, anon;

-- ── impact_aef_gates ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_aef_gates (
  gate_id        uuid PRIMARY KEY,
  request_id     uuid NOT NULL UNIQUE REFERENCES public.impact_aef_requests(request_id) ON DELETE CASCADE,
  -- Opaque approver reference — never a real name, email or user id.
  approver_ref   text CHECK (approver_ref IS NULL OR (length(approver_ref) BETWEEN 1 AND 64)),
  status         text NOT NULL DEFAULT 'PENDING'
                   CHECK (status IN ('PENDING','APPROVED','REJECTED','EXPIRED')),
  expires_at     timestamptz NOT NULL,
  resolved_at    timestamptz,
  -- SHA-256 of the request state at approval time. Any state change invalidates it.
  binding_hash   text CHECK (binding_hash IS NULL OR public.impact_aef_is_hex64(binding_hash)),
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- Gate status transitions: PENDING → terminal only, no direct client writes.
CREATE OR REPLACE FUNCTION public.impact_aef_gate_transitions() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Reject transition from a terminal state
  IF OLD.status <> 'PENDING' THEN
    RAISE EXCEPTION 'IMPACT_AEF_GATE_ALREADY_RESOLVED: gate % is already %', OLD.gate_id, OLD.status;
  END IF;
  -- Must transition to a terminal state
  IF NEW.status = 'PENDING' THEN
    RAISE EXCEPTION 'IMPACT_AEF_GATE_INVALID_TRANSITION: cannot remain PENDING on update';
  END IF;
  -- resolved_at must be set for terminal states
  IF NEW.resolved_at IS NULL THEN
    RAISE EXCEPTION 'IMPACT_AEF_GATE_MISSING_RESOLVED_AT';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS impact_aef_gate_transitions_trg ON public.impact_aef_gates;
CREATE TRIGGER impact_aef_gate_transitions_trg
  BEFORE UPDATE ON public.impact_aef_gates
  FOR EACH ROW EXECUTE FUNCTION public.impact_aef_gate_transitions();

ALTER TABLE public.impact_aef_gates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS impact_aef_gates_select ON public.impact_aef_gates;
CREATE POLICY impact_aef_gates_select ON public.impact_aef_gates
  FOR SELECT TO authenticated
  USING (
    request_id IN (
      SELECT request_id FROM public.impact_aef_requests
      WHERE caller_user_id = (SELECT auth.uid())
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.impact_aef_gates FROM authenticated, anon;

-- ── impact_aef_receipts ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.impact_aef_receipts (
  receipt_id          uuid PRIMARY KEY,
  request_id          uuid NOT NULL REFERENCES public.impact_aef_requests(request_id) ON DELETE CASCADE,
  correlation_id      text NOT NULL CHECK (length(correlation_id) BETWEEN 1 AND 128),
  caller_user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id          uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  service_id          text NOT NULL CHECK (service_id IN ('impact-lab', 'impact-monitor', 'aef-gate-resolver')),
  intent_kind         text NOT NULL CHECK (intent_kind IN (
                        'REQUEST_MANUAL_VERIFICATION',
                        'APPROVE_DOSSIER_PUBLICATION',
                        'ACKNOWLEDGE_CONFLICT',
                        'MARK_INVESTIGATION_REVIEWED'
                      )),
  investigation_id    uuid NOT NULL,
  idempotency_key     uuid NOT NULL,
  classification      text NOT NULL CHECK (classification IN ('READ_ONLY','REVERSIBLE','CONSEQUENTIAL','IRREVERSIBLE')),
  policy_version      text NOT NULL CHECK (length(policy_version) BETWEEN 1 AND 128),
  policy_outcome      text NOT NULL CHECK (policy_outcome IN ('AUTHORIZED','DENIED','REQUIRES_HUMAN_REVIEW')),
  execution_outcome   text NOT NULL CHECK (execution_outcome IN ('AUTHORIZED','DENIED','REQUIRES_HUMAN_REVIEW','EXECUTED','FAILED','CANCELLED')),
  human_gate_id       uuid REFERENCES public.impact_aef_gates(gate_id) ON DELETE SET NULL,
  error_code          text CHECK (error_code IS NULL OR length(error_code) <= 64),
  issued_at           timestamptz NOT NULL DEFAULT now(),
  -- SHA-256 of the canonical receipt fields (integrity, not crypto-proof).
  receipt_hash        text NOT NULL CHECK (public.impact_aef_is_hex64(receipt_hash))
);

-- Receipts are append-only — no UPDATE, no DELETE.
CREATE OR REPLACE FUNCTION public.impact_aef_receipt_immutable() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'IMPACT_AEF_RECEIPT_IMMUTABLE: receipts cannot be modified or deleted';
END;
$$;

DROP TRIGGER IF EXISTS impact_aef_receipt_no_update ON public.impact_aef_receipts;
CREATE TRIGGER impact_aef_receipt_no_update
  BEFORE UPDATE ON public.impact_aef_receipts
  FOR EACH ROW EXECUTE FUNCTION public.impact_aef_receipt_immutable();

DROP TRIGGER IF EXISTS impact_aef_receipt_no_delete ON public.impact_aef_receipts;
CREATE TRIGGER impact_aef_receipt_no_delete
  BEFORE DELETE ON public.impact_aef_receipts
  FOR EACH ROW EXECUTE FUNCTION public.impact_aef_receipt_immutable();

ALTER TABLE public.impact_aef_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS impact_aef_receipts_select ON public.impact_aef_receipts;
CREATE POLICY impact_aef_receipts_select ON public.impact_aef_receipts
  FOR SELECT TO authenticated
  USING (caller_user_id = (SELECT auth.uid()));

REVOKE INSERT, UPDATE, DELETE ON public.impact_aef_receipts FROM authenticated, anon;

-- ── indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_aef_requests_user ON public.impact_aef_requests(caller_user_id);
CREATE INDEX IF NOT EXISTS idx_aef_receipts_request ON public.impact_aef_receipts(request_id);
CREATE INDEX IF NOT EXISTS idx_aef_receipts_user ON public.impact_aef_receipts(caller_user_id);
CREATE INDEX IF NOT EXISTS idx_aef_gates_request ON public.impact_aef_gates(request_id);
