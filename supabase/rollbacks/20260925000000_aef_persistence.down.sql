-- Rollback for migration 20260925000000_aef_persistence.sql (IV-AEF-PERSISTENCE-01).
--
-- NOT a migration: the Supabase CLI never runs this directory. It exists so a
-- rollback is a reviewed, tested script rather than an improvised one
-- (Codex Gate 1 G1-05). Tested on a disposable database by
-- scripts/ci/run_disposable_db_tests.sh (down, verify, up again).
--
-- Scope (Codex Final CF-02): drops ONLY the 5 tables and 36 functions this
-- migration creates, by exact name — never anything else that happens to
-- start with "aef_".
--
-- DESTRUCTIVE: drops every AEF operation, gate, receipt and audit event.
-- Run only with explicit owner approval, as the table owner. The
-- append-only triggers block DELETE/TRUNCATE by design, so rollback is
-- DROP TABLE (which those triggers do not intercept).
BEGIN;

-- Order matters: aef__op_json takes the aef_operations row type as an
-- argument (blocks DROP TABLE), so it goes first; then the tables (their
-- triggers go with them); then every remaining function.
DROP FUNCTION IF EXISTS public.aef__view(uuid);
DROP FUNCTION IF EXISTS public.aef__op_json(public.aef_operations);

DROP TABLE IF EXISTS public.aef_receipts;
DROP TABLE IF EXISTS public.aef_human_gates;
DROP TABLE IF EXISTS public.aef_audit_events;
DROP TABLE IF EXISTS public.aef_audit_heads;
DROP TABLE IF EXISTS public.aef_operations;

DROP FUNCTION IF EXISTS public.aef_register_operation(jsonb);
DROP FUNCTION IF EXISTS public.aef_decide_gate(jsonb);
DROP FUNCTION IF EXISTS public.aef_claim_execution(jsonb);
DROP FUNCTION IF EXISTS public.aef_complete_execution(jsonb);
DROP FUNCTION IF EXISTS public.aef_cancel_operation(jsonb);
DROP FUNCTION IF EXISTS public.aef_recover(jsonb);
DROP FUNCTION IF EXISTS public.aef_get_operation(jsonb);
DROP FUNCTION IF EXISTS public.aef_record_denial(jsonb);
DROP FUNCTION IF EXISTS public.aef_verify_receipt(jsonb);
DROP FUNCTION IF EXISTS public.aef_verify_audit_chain(jsonb);
DROP FUNCTION IF EXISTS public.aef__expire_if_due(uuid);
DROP FUNCTION IF EXISTS public.aef__gate_to(uuid, text, text, uuid);
DROP FUNCTION IF EXISTS public.aef__op_to(uuid, text, text, boolean);
DROP FUNCTION IF EXISTS public.aef__issue_receipt(uuid);
DROP FUNCTION IF EXISTS public.aef__receipt_json(uuid);
DROP FUNCTION IF EXISTS public.aef__gate_json(uuid);
DROP FUNCTION IF EXISTS public.aef__guard_truncate();
DROP FUNCTION IF EXISTS public.aef__guard_audit_heads();
DROP FUNCTION IF EXISTS public.aef__guard_audit_events();
DROP FUNCTION IF EXISTS public.aef__guard_receipts();
DROP FUNCTION IF EXISTS public.aef__guard_gates();
DROP FUNCTION IF EXISTS public.aef__guard_operations();
DROP FUNCTION IF EXISTS public.aef__audit_append(uuid, uuid, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.aef__event_hash(uuid, bigint, uuid, text, text, text, text, text, timestamptz, text);
DROP FUNCTION IF EXISTS public.aef__bool(jsonb, text);
DROP FUNCTION IF EXISTS public.aef__int(jsonb, text, boolean, integer, integer);
DROP FUNCTION IF EXISTS public.aef__uuid(jsonb, text, boolean);
DROP FUNCTION IF EXISTS public.aef__text(jsonb, text, boolean, integer, text);
DROP FUNCTION IF EXISTS public.aef__check_keys(jsonb, text[]);
DROP FUNCTION IF EXISTS public.aef__err(text, text);
DROP FUNCTION IF EXISTS public.aef__outcome_for(text, boolean);
DROP FUNCTION IF EXISTS public.aef__is_terminal(text);
DROP FUNCTION IF EXISTS public.aef__ts(timestamptz);
DROP FUNCTION IF EXISTS public.aef__sha256(text);

COMMIT;
