-- AEF deployment preflight (IV-AEF-PRE-RUNTIME-CLOSURE-01) — READ-ONLY, FAIL-CLOSED.
--
-- Checks, BEFORE any future apply of the AEF migration chain, that the target
-- database is in a state the chain can safely build on. It never applies,
-- grants, alters or writes anything: everything runs inside a READ ONLY
-- transaction that is rolled back, and only catalog / migration-history
-- metadata is read (no user data).
--
-- Exit: psql returns non-zero (EXCEPTION 'AEF_DEPLOY_PREFLIGHT: FAIL …') on any
-- failed check; 'AEF_DEPLOY_PREFLIGHT: PASS …' lists what remains to apply.
-- A PASS is NOT a deploy authorization (AEF_PRODUCTION_DEPLOYMENT_PRECONDITIONS.md).
BEGIN TRANSACTION READ ONLY;

DO $$
DECLARE
  -- Repository migrations that must already be applied, identified by the
  -- NAME recorded in supabase_migrations.schema_migrations (the version
  -- there is the apply time, not the repo file prefix).
  predecessors text[] := ARRAY['baseline_production_pre_x4r', 'x4b_search_path_and_role_protection', 'commercial_ai_quota',
    'stripe_billing', 'stripe_billing_atomic_apply', 'stripe_billing_event_ordering', 'diagnostic_logger',
    'diagnostic_logger_anon_revoke_hardening', 'diagnostic_one_active_session', 'market_intelligence_current_state',
    'project_resource_allocations', 'project_resource_allocations_search_path_hardening', 'ai_quota_idempotency',
    'project_ownership_boundary_closure', 'diagnostic_events_build_sha', 'opportunity_knowledge_links'];
  -- The chain, in the order it must be applied.
  chain text[] := ARRAY['entitlement_subject_roles', 'ive_memory_governance', 'aef_persistence', 'aef_hardening',
    'aef_sequence_privileges'];
  hist text[];
  fails text[] := ARRAY[]::text[];
  applied boolean[] := ARRAY[]::boolean[];
  present boolean[] := ARRAY[]::boolean[];
  remaining text[] := ARRAY[]::text[];
  i int;
  n text;
  v_seq text;
  seq_defaults_permissive boolean;
BEGIN
  -- ── migration history ────────────────────────────────────────────────
  IF to_regclass('supabase_migrations.schema_migrations') IS NULL THEN
    RAISE EXCEPTION 'AEF_DEPLOY_PREFLIGHT: FAIL — no supabase_migrations.schema_migrations history table';
  END IF;
  EXECUTE 'SELECT coalesce(array_agg(name ORDER BY version), ARRAY[]::text[]) FROM supabase_migrations.schema_migrations' INTO hist;
  FOREACH n IN ARRAY predecessors LOOP
    IF NOT (n = ANY (hist)) THEN
      fails := fails || format('predecessor migration %s missing from history', n);
    END IF;
  END LOOP;

  -- ── functional presence of what the chain builds on (schema, not names) ─
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'projects'
                  AND column_name = 'id' AND data_type = 'uuid')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'projects'
                  AND column_name = 'user_id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN
    fails := fails || 'drift: public.projects(id uuid, user_id uuid NOT NULL) not as expected'::text;
  END IF;
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles'
       AND column_name IN ('id', 'role')) <> 2 THEN
    fails := fails || 'drift: public.profiles(id, role) required by entitlement_subject_roles'::text;
  END IF;
  IF to_regclass('public.business_memory') IS NULL THEN
    fails := fails || 'drift: public.business_memory required by ive_memory_governance'::text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users'
                  AND column_name = 'id' AND data_type = 'uuid') THEN
    fails := fails || 'drift: auth.users.id uuid'::text;
  END IF;
  IF to_regprocedure('pg_catalog.sha256(bytea)') IS NULL OR to_regprocedure('pg_catalog.gen_random_uuid()') IS NULL
     OR to_regprocedure('pg_catalog.hashtextextended(text, bigint)') IS NULL THEN
    fails := fails || 'drift: required pg_catalog functions missing'::text;
  END IF;

  -- ── chain state: history and schema must agree, in order ─────────────
  v_seq := CASE WHEN to_regclass('public.aef_audit_events') IS NULL THEN NULL
                ELSE pg_get_serial_sequence('public.aef_audit_events', 'id') END;
  FOR i IN 1 .. array_length(chain, 1) LOOP
    applied := applied || (chain[i] = ANY (hist));
    present := present || CASE chain[i]
      WHEN 'entitlement_subject_roles' THEN to_regclass('public.subject_roles') IS NOT NULL
      WHEN 'ive_memory_governance' THEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                                                  AND table_name = 'business_memory' AND column_name = 'scope')
      WHEN 'aef_persistence' THEN to_regclass('public.aef_operations') IS NOT NULL
      WHEN 'aef_hardening' THEN to_regclass('public.aef_retention_policy') IS NOT NULL
      WHEN 'aef_sequence_privileges' THEN v_seq IS NOT NULL
        AND NOT has_sequence_privilege('anon', v_seq, 'USAGE') AND NOT has_sequence_privilege('anon', v_seq, 'UPDATE')
        AND NOT has_sequence_privilege('authenticated', v_seq, 'UPDATE') AND NOT has_sequence_privilege('service_role', v_seq, 'UPDATE')
    END;
    IF applied[i] AND NOT present[i] THEN
      fails := fails || format('drift: %s is in the history but its objects are absent', chain[i]);
    ELSIF present[i] AND NOT applied[i] AND chain[i] <> 'aef_sequence_privileges' THEN
      fails := fails || format('drift: objects of %s exist but it is not in the history', chain[i]);
    END IF;
    IF NOT applied[i] THEN
      remaining := remaining || chain[i];
    END IF;
  END LOOP;
  -- Order, by REAL dependencies (AEF_PRODUCTION_MIGRATION_RECONCILIATION.md),
  -- not by file numbering: aef_hardening needs entitlement_subject_roles and
  -- aef_persistence; aef_sequence_privileges needs aef_persistence.
  -- ive_memory_governance is independent of AEF.
  IF applied[4] AND NOT (applied[1] AND applied[3]) THEN
    fails := fails || 'order: aef_hardening applied without entitlement_subject_roles and aef_persistence'::text;
  END IF;
  IF applied[5] AND NOT applied[3] THEN
    fails := fails || 'order: aef_sequence_privileges applied without aef_persistence'::text;
  END IF;
  -- Stray AEF objects not explained by the history.
  IF NOT ('aef_persistence' = ANY (hist)) AND EXISTS (
       SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND left(c.relname, 4) = 'aef_'
       UNION ALL
       SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_') THEN
    fails := fails || 'drift: aef_* objects exist without aef_persistence in the history'::text;
  END IF;

  -- ── dangerous privilege defaults (P03) ───────────────────────────────
  seq_defaults_permissive := EXISTS (
    SELECT 1 FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace,
           aclexplode(d.defaclacl) a
     WHERE n.nspname = 'public' AND d.defaclobjtype = 'S'
       AND a.grantee IN (SELECT oid FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')));
  IF v_seq IS NOT NULL AND (has_sequence_privilege('anon', v_seq, 'UPDATE') OR has_sequence_privilege('authenticated', v_seq, 'UPDATE')
                            OR has_sequence_privilege('service_role', v_seq, 'UPDATE')) THEN
    fails := fails || 'privilege: the AEF audit sequence is writable by an API role (apply aef_sequence_privileges first)'::text;
  END IF;
  IF seq_defaults_permissive AND 'aef_persistence' = ANY (remaining) AND NOT ('aef_sequence_privileges' = ANY (remaining)) THEN
    fails := fails || 'privilege: permissive sequence defaults but aef_sequence_privileges would not follow aef_persistence'::text;
  END IF;

  IF array_length(fails, 1) > 0 THEN
    RAISE EXCEPTION 'AEF_DEPLOY_PREFLIGHT: FAIL — %', array_to_string(fails, ' | ');
  END IF;
  RAISE NOTICE 'AEF_DEPLOY_PREFLIGHT: PASS — sequence defaults permissive: %; remaining, in order: %',
    seq_defaults_permissive, CASE WHEN array_length(remaining, 1) IS NULL THEN '(none)' ELSE array_to_string(remaining, ' -> ') END;
END $$;

ROLLBACK;
