-- IV-ECOSYSTEM-COMMERCIAL-RELEASE-SUPERMACRO-01 — Migration 00013
-- EA-01 resolution: replace GUC service_role_key with Vault-stored secret.
--
-- PROBLEM (Codex CLASS D adversarial finding, confirmed BLOCKED_OWNER):
--   invoke_entitlement_reconciler reads app.service_role_key via current_setting().
--   That GUC is set via ALTER DATABASE SET ... which persists the service_role_key
--   in pg_settings, readable by any connected session (including authenticated users
--   with EXECUTE on set-returning functions or pg_settings views).
--
-- DECISION (Agente Martins + Paulo, 2026-10-09):
--   Use Supabase Vault for the reconciler credential. Use a DEDICATED secret key
--   (not the service_role_key) so a compromise of this credential does not
--   expose the entire service_role. The Vault is the authoritative secret store;
--   the GUC path is REMOVED.
--
-- VAULT SECRETS REQUIRED (Owner must create before applying migrations in production):
--
--   1. Secret named 'entitlement_reconcile_secret' — a strong random string
--      (minimum 32 characters) used exclusively to authenticate the
--      pg_cron → entitlement-reconcile Edge Function call. Example:
--        SELECT vault.create_secret(
--          'REPLACE_WITH_STRONG_RANDOM_SECRET_MIN_32_CHARS',
--          'entitlement_reconcile_secret',
--          'Dedicated auth token for pg_cron → entitlement-reconcile Edge Function'
--        );
--
--   2. Supabase project URL remains in app.supabase_project_url (not sensitive —
--      this is the public project URL, not a credential). Keep it in the GUC.
--
--   3. Edge Function ENTITLEMENT_RECONCILE_SECRET env var must be set to the
--      same value as the Vault secret before deploying entitlement-reconcile.
--
-- SECURITY PROPERTIES:
--   - Secret readable only by Vault-privileged roles (vault.decrypted_secrets
--     requires vault_read role, not available to anon/authenticated).
--   - Dedicated credential: compromise of this token does not expose service_role.
--   - Fail closed: missing Vault secret → HTTP enqueue skipped, SQL backstop runs.
--   - Secret value never appears in function return values or logs.
--
-- REMOVAL:
--   After applying this migration, the Owner should run:
--     ALTER DATABASE <db> RESET app.service_role_key;
--   to remove the GUC from pg_settings. This migration intentionally does NOT
--   do this automatically (the DBA must confirm no other function depends on it).
--
-- IDEMPOTENT: safe to re-run (CREATE OR REPLACE).
-- PRODUCTION PROTECTION: NOT applied without AM+Paulo gate.

SET search_path = public, pg_catalog, pg_temp;

-- ── Revised invoke_entitlement_reconciler: reads credential from Vault ────────
CREATE OR REPLACE FUNCTION public.invoke_entitlement_reconciler(
  p_batch_size int DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_project_url    text;
  v_secret         text;
  v_sql_result     jsonb;
  v_http_enqueued  boolean := false;
BEGIN
  -- Project URL: public, stored in GUC (not sensitive)
  v_project_url := current_setting('app.supabase_project_url', true);

  -- Reconciler credential: read from Vault (never from GUC).
  -- vault.decrypted_secrets requires vault_read role; anon/authenticated cannot read.
  -- Returns NULL if the secret does not exist yet — handled below.
  BEGIN
    SELECT vs.decrypted_secret INTO v_secret
    FROM   vault.decrypted_secrets vs
    WHERE  vs.name = 'entitlement_reconcile_secret'
    LIMIT  1;
  EXCEPTION WHEN OTHERS THEN
    -- vault extension not installed, or vault_read not granted to this role.
    v_secret := NULL;
  END;

  -- Test invariant: secret must not appear in any output path.
  -- (enforced by never including v_secret in RETURN statements)

  IF v_project_url IS NOT NULL AND v_project_url <> ''
     AND v_secret IS NOT NULL AND v_secret <> ''
     AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
  THEN
    -- Preferred path: invoke Edge Function via HTTP using dedicated Vault secret.
    BEGIN
      PERFORM net.http_post(
        url     := v_project_url || '/functions/v1/entitlement-reconcile?batch=' || p_batch_size,
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_secret
        ),
        body    := (jsonb_build_object('batch', p_batch_size))::text::bytea
      );
      v_http_enqueued := true;
    EXCEPTION WHEN OTHERS THEN
      v_http_enqueued := false;
    END;

    -- SQL backstop always runs (idempotent, uses SELECT FOR UPDATE SKIP LOCKED).
    SELECT public.process_pending_entitlement_events(p_batch_size) INTO v_sql_result;
    RETURN jsonb_build_object(
      'invocation',    'edge_function_with_sql_backstop',
      'http_enqueued', v_http_enqueued,
      'batch',         p_batch_size,
      'sql_result',    v_sql_result
      -- NOTE: v_secret is intentionally NOT included in the result.
    );

  ELSIF v_secret IS NULL OR v_secret = '' THEN
    -- Vault secret missing: fail closed on HTTP enqueue, run SQL backstop only.
    -- This should never happen in production after EA-01 is applied and the Vault
    -- secret is created. If it does, pending_retry events are still processed by
    -- the SQL worker — no events are lost, but STRIPE_PRICE_MAP is not synced.
    SELECT public.process_pending_entitlement_events(p_batch_size) INTO v_sql_result;
    RETURN jsonb_build_object(
      'invocation', 'sql_worker_vault_secret_missing',
      'batch',      p_batch_size,
      'result',     v_sql_result
    );

  ELSE
    -- No pg_net or no project URL: SQL worker only.
    SELECT public.process_pending_entitlement_events(p_batch_size) INTO v_sql_result;
    RETURN jsonb_build_object('invocation', 'sql_worker', 'batch', p_batch_size, 'result', v_sql_result);
  END IF;
END;
$$;

-- ACL: unchanged (no anon/authenticated execute; called by pg_cron and service_role only)
REVOKE ALL     ON FUNCTION public.invoke_entitlement_reconciler(int) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.invoke_entitlement_reconciler(int) FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.invoke_entitlement_reconciler(int) TO service_role;

COMMENT ON FUNCTION public.invoke_entitlement_reconciler(int) IS
  'EA-01 (2026-10-09): reads dedicated reconciler credential from Supabase Vault '
  '(entitlement_reconcile_secret) instead of app.service_role_key GUC. '
  'Missing Vault secret → fail closed on HTTP, SQL backstop still runs. '
  'Secret value never appears in return values or logs. '
  'PRODUCTION PROTECTION: not applied without AM+Paulo gate.';
