-- AEF deployment preflight (IV-AEF-PRE-RUNTIME-CLOSURE-01) — READ-ONLY, FAIL-CLOSED.
--
-- Checks, BEFORE any future apply of the AEF migration chain, that the target
-- database is in a state the chain can safely build on. It never applies,
-- grants, alters or writes anything: everything runs inside a READ ONLY
-- transaction that is rolled back, and only catalog / migration-history
-- metadata is read (no user data). Run it ONLY as `psql -v ON_ERROR_STOP=1 -f`
-- (no wrapper that adds statements).
--
-- Exit: psql returns non-zero with 'AEF_DEPLOY_PREFLIGHT: FAIL …' on any failed
-- check or unexpected error; 'AEF_DEPLOY_PREFLIGHT: PASS …' lists what remains
-- to apply. A PASS is NOT a deploy authorization
-- (AEF_PRODUCTION_DEPLOYMENT_PRECONDITIONS.md).
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
  -- Structural markers: EVERY listed object must exist for a migration to be
  -- "present"; some-but-not-all is partial drift (fail).
  persist_tables text[] := ARRAY['public.aef_operations', 'public.aef_human_gates', 'public.aef_receipts',
    'public.aef_audit_events', 'public.aef_audit_heads'];
  persist_rpcs text[] := ARRAY['aef_register_operation', 'aef_decide_gate', 'aef_claim_execution', 'aef_complete_execution',
    'aef_cancel_operation', 'aef_recover', 'aef_get_operation', 'aef_record_denial', 'aef_verify_receipt',
    'aef_verify_audit_chain'];
  hard_tables text[] := ARRAY['public.aef_retention_policy', 'public.aef_idempotency_tombstones', 'public.aef_audit_checkpoints',
    'public.aef_audit_coalesced', 'public.aef_audit_windows', 'public.aef_audit_pending', 'public.aef_legal_holds',
    'public.aef_erasures', 'public.aef_reconciliation_verifiers', 'public.aef_reconciliations'];
  hard_rpcs text[] := ARRAY['aef_purge', 'aef_erase_subject', 'aef_reconcile'];
  memory_cols text[] := ARRAY['scope', 'origin', 'status', 'dedup_key', 'superseded_by', 'updated_at', 'expires_at'];
  api_roles text[] := ARRAY['anon', 'authenticated', 'service_role'];
  n_rows bigint; n_named bigint; n_distinct bigint;
  hist text[];
  fails text[] := ARRAY[]::text[];
  applied boolean[] := ARRAY[]::boolean[];
  state text[] := ARRAY[]::text[];     -- absent | present | partial
  ver text[] := ARRAY[]::text[];
  remaining text[] := ARRAY[]::text[];
  found int; expected int;
  i int; n text; r text; p text; s oid; f record;
  exposed text[] := ARRAY[]::text[];
  seq_defaults_permissive boolean;
  n_versioned bigint;
  -- Structural fingerprint (Codex G2V-01 / G3V-03): md5 over the ordered
  -- catalog definition of the given tables (columns with position, type,
  -- nullability and default; kind, owner and RLS flags; constraints; indexes;
  -- triggers; policies) and of the functions matching a name pattern (full
  -- argument list with modes and defaults, return type/set, language, kind,
  -- volatility, parallel safety, leakproof, strict, SECURITY DEFINER, owner,
  -- config, body hash — Codex R-01/R-02). ACLs are checked separately below. $3 restricts to the listed columns
  -- of a pre-existing table (only the part a migration owns is compared).
  -- Rendered with search_path = pg_catalog so every name is schema-qualified.
  fp_sql constant text := $fp$
    SELECT md5(coalesce(string_agg(x, E'\n' ORDER BY x COLLATE "C"), '')) FROM (
      SELECT 'col|' || c.relname || '|' || a.attname || '|' || a.attnum || '|' || format_type(a.atttypid, a.atttypmod) || '|' || a.attnotnull
             || '|' || coalesce(pg_get_expr(d.adbin, d.adrelid), '') AS x
        FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
       WHERE n.nspname = 'public' AND c.relname = ANY ($1) AND a.attnum > 0 AND NOT a.attisdropped
         AND ($3 IS NULL OR a.attname = ANY ($3))
      UNION ALL
      SELECT 'rel|' || c.relname || '|' || c.relkind::text || '|' || c.relowner::regrole::text
             || '|' || c.relrowsecurity || '|' || c.relforcerowsecurity
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relname = ANY ($1) AND $3 IS NULL
      UNION ALL
      SELECT 'con|' || c.relname || '|' || co.conname || '|' || pg_get_constraintdef(co.oid)
        FROM pg_constraint co JOIN pg_class c ON c.oid = co.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relname = ANY ($1) AND $3 IS NULL
      UNION ALL
      SELECT 'idx|' || pg_get_indexdef(i.indexrelid)
        FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relname = ANY ($1) AND $3 IS NULL
      UNION ALL
      SELECT 'trg|' || c.relname || '|' || t.tgname || '|' || pg_get_triggerdef(t.oid)
        FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_proc tf ON tf.oid = t.tgfoid
       WHERE n.nspname = 'public' AND c.relname = ANY ($1) AND NOT t.tgisinternal
         AND ($3 IS NULL OR tf.proname LIKE $2)
      UNION ALL
      SELECT 'pol|' || c.relname || '|' || p.polname || '|' || p.polcmd::text || '|' || p.polpermissive
             || '|' || coalesce(pg_get_expr(p.polqual, p.polrelid), '') || '|' || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '')
             || '|' || array_to_string(ARRAY(SELECT CASE WHEN r = 0 THEN 'PUBLIC' ELSE r::regrole::text END
                                               FROM unnest(p.polroles) r ORDER BY 1), ',')
        FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relname = ANY ($1)
      UNION ALL
      SELECT 'fn|' || p.proname || '(' || pg_get_function_arguments(p.oid) || ')|' || p.proretset || '|' || format_type(p.prorettype, NULL)
             || '|' || l.lanname || '|' || p.prokind::text || '|' || p.provolatile::text || '|' || p.proparallel::text
             || '|' || p.proleakproof || '|' || p.proisstrict || '|' || p.prosecdef || '|' || p.proowner::regrole::text
             || '|' || coalesce(array_to_string(p.proconfig, ','), '') || '|' || md5(p.prosrc)
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_language l ON l.oid = p.prolang
       WHERE n.nspname = 'public' AND p.proname LIKE $2
    ) s
  $fp$;
  -- Expected fingerprints of the repository migrations, per install state.
  -- Maintained with scripts/ci/aef_preflight_fingerprints.sh; CI fails when a
  -- migration changes without updating them (fully-applied chain must PASS).
  fp_entitlement constant text := '541564e6be2ec1f3ed6e68c43c6a38e7';
  fp_memory constant text := '76828d82d05cf3f308ba67a78960a09a';
  fp_aef_persistence constant text := '46f3696f5779d806f7cf44824ce00a19';
  fp_aef_full constant text := 'b611c3aa5b66f41af7304588e130c06a';
  fp text;
  aef_tables text[];
BEGIN
 BEGIN
  -- Deterministic, schema-qualified catalog rendering for the fingerprints
  -- (a session setting, not a write; reverted with the transaction).
  PERFORM set_config('search_path', 'pg_catalog', true);
  -- ── migration history (Codex G3-01/G3-04) ────────────────────────────
  IF to_regclass('supabase_migrations.schema_migrations') IS NULL THEN
    RAISE EXCEPTION 'AEF_DEPLOY_PREFLIGHT: FAIL — no supabase_migrations.schema_migrations history table';
  END IF;
  EXECUTE 'SELECT count(*), count(name), count(DISTINCT name), count(version) FROM supabase_migrations.schema_migrations'
    INTO n_rows, n_named, n_distinct, n_versioned;
  IF n_versioned <> n_rows THEN
    fails := fails || format('history: %s row(s) without a version — cannot check order', n_rows - n_versioned);
  END IF;
  IF n_named <> n_rows THEN
    fails := fails || format('history: %s row(s) without a name — cannot reconcile by name', n_rows - n_named);
  END IF;
  IF n_distinct <> n_named THEN
    fails := fails || 'history: duplicate migration names — cannot reconcile by name'::text;
  END IF;
  EXECUTE 'SELECT coalesce(array_agg(name ORDER BY version), ARRAY[]::text[]) FROM supabase_migrations.schema_migrations WHERE name IS NOT NULL'
    INTO hist;
  FOREACH n IN ARRAY predecessors LOOP
    IF (n = ANY (hist)) IS NOT TRUE THEN
      fails := fails || format('predecessor migration %s missing from history', n);
    END IF;
  END LOOP;

  -- ── roles the privilege checks rely on ───────────────────────────────
  IF (SELECT count(*) FROM pg_roles WHERE rolname = ANY (api_roles)) <> 3 THEN
    RAISE EXCEPTION 'AEF_DEPLOY_PREFLIGHT: FAIL — roles anon/authenticated/service_role missing';
  END IF;

  -- ── functional presence of what the chain builds on (schema, not names) ─
  -- Codex G3V-01: types, nullability and keys, not only names.
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'projects'
                  AND column_name = 'id' AND data_type = 'uuid')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'projects'
                  AND column_name = 'user_id' AND data_type = 'uuid' AND is_nullable = 'NO')
     OR to_regclass('public.projects') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass('public.projects') AND contype = 'p'
                     AND pg_get_constraintdef(oid) = 'PRIMARY KEY (id)')
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass('public.projects') AND contype = 'f'
                     AND pg_get_constraintdef(oid) = 'FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE') THEN
    fails := fails || 'drift: public.projects(id uuid, user_id uuid NOT NULL) not as expected'::text;
  END IF;
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND is_nullable = 'NO'
       AND ((column_name = 'id' AND data_type = 'uuid') OR (column_name = 'role' AND data_type = 'text'))) <> 2
     OR to_regclass('public.profiles') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass('public.profiles') AND contype = 'p'
                     AND pg_get_constraintdef(oid) = 'PRIMARY KEY (id)') THEN
    fails := fails || 'drift: public.profiles(id uuid PRIMARY KEY, role text NOT NULL) required by entitlement_subject_roles'::text;
  END IF;
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'business_memory'
       AND ((column_name = 'user_id' AND data_type = 'uuid' AND is_nullable = 'NO') OR (column_name = 'project_id' AND data_type = 'uuid')
            OR (column_name = 'source' AND data_type = 'text') OR (column_name = 'content' AND data_type = 'text'))) <> 4 THEN
    fails := fails || 'drift: public.business_memory(user_id uuid NOT NULL, project_id uuid, source text, content text) required by ive_memory_governance'::text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users'
                  AND column_name = 'id' AND data_type = 'uuid') THEN
    fails := fails || 'drift: auth.users.id uuid'::text;
  END IF;
  IF (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('auth.uid()')) IS DISTINCT FROM 'uuid'::regtype
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('pg_catalog.sha256(bytea)')) IS DISTINCT FROM 'bytea'::regtype
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('pg_catalog.gen_random_uuid()')) IS DISTINCT FROM 'uuid'::regtype
     OR (SELECT prorettype FROM pg_proc WHERE oid = to_regprocedure('pg_catalog.hashtextextended(text, bigint)')) IS DISTINCT FROM 'bigint'::regtype THEN
    fails := fails || 'drift: auth.uid() / sha256 / gen_random_uuid / hashtextextended missing or with an unexpected return type'::text;
  END IF;

  -- ── chain state: history and full structure must agree (Codex G3-02) ─
  FOR i IN 1 .. array_length(chain, 1) LOOP
    applied := applied || coalesce(chain[i] = ANY (hist), false);
    EXECUTE 'SELECT max(version)::text FROM supabase_migrations.schema_migrations WHERE name = $1' INTO n USING chain[i];
    ver := ver || n;
    CASE chain[i]
      WHEN 'entitlement_subject_roles' THEN
        expected := 3;
        SELECT count(*) INTO found FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subject_roles'
           AND is_nullable = 'NO' AND ((column_name = 'subject_type' AND data_type = 'text')
                                       OR (column_name = 'subject_id' AND data_type = 'uuid')
                                       OR (column_name = 'role' AND data_type = 'text'));
        IF to_regclass('public.subject_roles') IS NOT NULL AND found = 0 THEN found := 1; expected := 3; END IF;
      WHEN 'ive_memory_governance' THEN
        expected := array_length(memory_cols, 1) + 1;
        SELECT count(*) INTO found FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'business_memory'
           AND column_name = ANY (memory_cols);
        found := found + CASE WHEN to_regprocedure('public.business_memory_derive_scope()') IS NULL THEN 0 ELSE 1 END;
      WHEN 'aef_persistence' THEN
        expected := array_length(persist_tables, 1) + array_length(persist_rpcs, 1);
        SELECT (SELECT count(*) FROM unnest(persist_tables) t WHERE to_regclass(t) IS NOT NULL)
             + (SELECT count(*) FROM unnest(persist_rpcs) q WHERE to_regprocedure('public.' || q || '(jsonb)') IS NOT NULL)
          INTO found;
      WHEN 'aef_hardening' THEN
        expected := array_length(hard_tables, 1) + array_length(hard_rpcs, 1);
        SELECT (SELECT count(*) FROM unnest(hard_tables) t WHERE to_regclass(t) IS NOT NULL)
             + (SELECT count(*) FROM unnest(hard_rpcs) q WHERE to_regprocedure('public.' || q || '(jsonb)') IS NOT NULL)
          INTO found;
      WHEN 'aef_sequence_privileges' THEN
        -- no object of its own: "present" = the audit sequence exists and no AEF sequence is exposed (checked below)
        expected := 1;
        found := CASE WHEN to_regclass('public.aef_audit_events') IS NOT NULL
                       AND pg_get_serial_sequence('public.aef_audit_events', 'id') IS NOT NULL THEN 1 ELSE 0 END;
    END CASE;
    state := state || CASE WHEN found = 0 THEN 'absent' WHEN found >= expected THEN 'present' ELSE 'partial' END;
    IF state[i] = 'partial' THEN
      fails := fails || format('drift: %s is partially present (%s of %s structural markers)', chain[i], found, expected);
    ELSIF applied[i] AND state[i] = 'absent' THEN
      fails := fails || format('drift: %s is in the history but its objects are absent', chain[i]);
    ELSIF state[i] = 'present' AND NOT applied[i] AND chain[i] <> 'aef_sequence_privileges' THEN
      fails := fails || format('drift: objects of %s exist but it is not in the history', chain[i]);
    END IF;
    IF NOT applied[i] THEN
      remaining := remaining || chain[i];
    END IF;
  END LOOP;

  -- ── order, by REAL dependencies (AEF_PRODUCTION_MIGRATION_RECONCILIATION.md) ─
  -- aef_hardening needs entitlement_subject_roles and aef_persistence;
  -- aef_sequence_privileges needs aef_persistence (it may precede or follow
  -- aef_hardening: 20260925 already revokes, 20260927 re-asserts).
  -- ive_memory_governance is independent of AEF.
  IF applied[4] AND NOT (applied[1] AND applied[3]) THEN
    fails := fails || 'order: aef_hardening applied without entitlement_subject_roles and aef_persistence'::text;
  ELSIF applied[4] AND coalesce(ver[1] > ver[4] OR ver[3] > ver[4], true) THEN
    fails := fails || 'order: aef_hardening recorded before one of its dependencies'::text;
  END IF;
  IF applied[5] AND NOT applied[3] THEN
    fails := fails || 'order: aef_sequence_privileges applied without aef_persistence'::text;
  ELSIF applied[5] AND coalesce(ver[3] > ver[5], true) THEN
    fails := fails || 'order: aef_sequence_privileges recorded before aef_persistence'::text;
  END IF;
  -- Stray AEF objects not explained by the history.
  IF NOT applied[3] AND EXISTS (
       SELECT 1 FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace WHERE ns.nspname = 'public' AND left(c.relname, 4) = 'aef_'
       UNION ALL
       SELECT 1 FROM pg_proc q JOIN pg_namespace ns ON ns.oid = q.pronamespace WHERE ns.nspname = 'public' AND left(q.proname, 4) = 'aef_') THEN
    fails := fails || 'drift: aef_* objects exist without aef_persistence in the history'::text;
  END IF;

  -- ── structural equivalence of installed chain migrations (Codex G2V-01 / G3V-03) ─
  IF state[1] = 'present' THEN
    EXECUTE fp_sql INTO fp USING ARRAY['subject_roles'], 'subject\_roles%', NULL::text[];
    IF fp IS DISTINCT FROM fp_entitlement THEN
      fails := fails || format('drift: entitlement_subject_roles structure differs from the repository (fingerprint %s)', fp);
    END IF;
  END IF;
  IF state[2] = 'present' THEN
    EXECUTE fp_sql INTO fp USING ARRAY['business_memory'], 'business\_memory\_derive\_scope', memory_cols;
    IF fp IS DISTINCT FROM fp_memory THEN
      fails := fails || format('drift: ive_memory_governance structure differs from the repository (fingerprint %s)', fp);
    END IF;
  END IF;
  IF state[3] = 'present' THEN
    -- every aef_* table present (a stray or extra table changes the fingerprint)
    SELECT coalesce(array_agg(c.relname::text), ARRAY[]::text[]) INTO aef_tables
      FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
     WHERE ns.nspname = 'public' AND c.relkind IN ('r', 'p') AND left(c.relname, 4) = 'aef_';
    EXECUTE fp_sql INTO fp USING aef_tables, 'aef%', NULL::text[];
    IF fp IS DISTINCT FROM (CASE WHEN state[4] = 'present' THEN fp_aef_full ELSE fp_aef_persistence END) THEN
      fails := fails || format('drift: AEF structure differs from the repository for the installed state (%s; fingerprint %s)',
                               CASE WHEN state[4] = 'present' THEN 'persistence+hardening' ELSE 'persistence only' END, fp);
    END IF;
  END IF;

  -- ── privilege contract of an existing AEF install (Codex G3-02) ──────
  IF state[3] = 'present' THEN
    FOR f IN SELECT q.oid, q.proname, q.prosecdef, q.proconfig FROM pg_proc q JOIN pg_namespace ns ON ns.oid = q.pronamespace
              WHERE ns.nspname = 'public' AND left(q.proname, 4) = 'aef_' LOOP
      IF f.proconfig IS NULL OR NOT ('search_path=pg_catalog, pg_temp' = ANY (f.proconfig)) THEN
        fails := fails || format('privilege: %s has no pinned search_path', f.proname);
      END IF;
      IF left(f.proname, 5) <> 'aef__' AND NOT f.prosecdef THEN
        fails := fails || format('privilege: RPC %s is not SECURITY DEFINER', f.proname);
      END IF;
      IF has_function_privilege('anon', f.oid, 'EXECUTE') OR has_function_privilege('authenticated', f.oid, 'EXECUTE')
         OR EXISTS (SELECT 1 FROM pg_proc x, aclexplode(coalesce(x.proacl, acldefault('f', x.proowner))) a
                     WHERE x.oid = f.oid AND a.grantee = 0) THEN
        fails := fails || format('privilege: %s is executable by anon/authenticated/PUBLIC', f.proname);
      END IF;
      IF has_function_privilege('service_role', f.oid, 'EXECUTE') <> (f.proname = ANY (persist_rpcs || hard_rpcs)) THEN
        fails := fails || format('privilege: service_role EXECUTE on %s differs from the contract', f.proname);
      END IF;
    END LOOP;
    FOR f IN SELECT c.oid, c.relname FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
              WHERE ns.nspname = 'public' AND c.relkind IN ('r', 'p') AND left(c.relname, 4) = 'aef_' LOOP
      FOREACH r IN ARRAY api_roles LOOP
        IF has_table_privilege(r, f.oid, 'INSERT') OR has_table_privilege(r, f.oid, 'UPDATE')
           OR has_table_privilege(r, f.oid, 'DELETE') OR has_table_privilege(r, f.oid, 'TRUNCATE') THEN
          fails := fails || format('privilege: %s can write %s', r, f.relname);
        END IF;
      END LOOP;
    END LOOP;
  END IF;

  -- ── sequences (P03, Codex G3-03): every AEF sequence, every privilege, PUBLIC ─
  FOR s IN SELECT c.oid FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
            WHERE ns.nspname = 'public' AND c.relkind = 'S'
              AND (left(c.relname, 4) = 'aef_' OR EXISTS (
                    SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid
                     WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass
                       AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_')) LOOP
    FOREACH r IN ARRAY api_roles LOOP
      FOREACH p IN ARRAY ARRAY['USAGE', 'SELECT', 'UPDATE'] LOOP
        IF has_sequence_privilege(r, s, p) THEN
          exposed := exposed || format('%s %s %s', s::regclass, r, p);
        END IF;
      END LOOP;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_class c, aclexplode(coalesce(c.relacl, acldefault('s', c.relowner))) a
                WHERE c.oid = s AND a.grantee = 0) THEN
      exposed := exposed || format('%s PUBLIC', s::regclass);
    END IF;
  END LOOP;
  IF array_length(exposed, 1) > 0 THEN
    fails := fails || format('privilege: AEF sequence exposed to an API role or PUBLIC (%s)', array_to_string(exposed, ', '));
    IF applied[5] THEN
      fails := fails || 'drift: aef_sequence_privileges is in the history but an AEF sequence is exposed'::text;
    END IF;
  END IF;
  seq_defaults_permissive := EXISTS (
    SELECT 1 FROM pg_default_acl d JOIN pg_namespace ns ON ns.oid = d.defaclnamespace,
           aclexplode(d.defaclacl) a
     WHERE ns.nspname = 'public' AND d.defaclobjtype = 'S'
       AND (a.grantee = 0 OR a.grantee IN (SELECT oid FROM pg_roles WHERE rolname = ANY (api_roles))));
  IF seq_defaults_permissive AND 'aef_persistence' = ANY (remaining) AND NOT ('aef_sequence_privileges' = ANY (remaining)) THEN
    fails := fails || 'privilege: permissive sequence defaults but aef_sequence_privileges would not follow aef_persistence'::text;
  END IF;

  IF array_length(fails, 1) > 0 THEN
    RAISE EXCEPTION 'AEF_DEPLOY_PREFLIGHT: FAIL — %', array_to_string(fails, ' | ');
  END IF;
  RAISE NOTICE 'AEF_DEPLOY_PREFLIGHT: PASS — sequence defaults permissive: %; remaining, in order: %',
    seq_defaults_permissive, CASE WHEN array_length(remaining, 1) IS NULL THEN '(none)' ELSE array_to_string(remaining, ' -> ') END;
 EXCEPTION WHEN OTHERS THEN
  -- Fail closed with the FAIL marker on ANY error, never a silent pass.
  IF SQLERRM LIKE 'AEF_DEPLOY_PREFLIGHT: FAIL%' THEN
    RAISE;
  END IF;
  RAISE EXCEPTION 'AEF_DEPLOY_PREFLIGHT: FAIL — unexpected error: % (%)', SQLERRM, SQLSTATE;
 END;
END $$;

ROLLBACK;
