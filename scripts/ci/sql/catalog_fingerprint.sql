-- Whole-`public`-schema catalog fingerprint (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
-- One md5 over every relation (kind, owner, ACL, RLS), index, column
-- (position, type, nullability, default, column ACL), constraint, trigger,
-- policy (command, permissive, USING, WITH CHECK, roles — Codex RG3W-01),
-- view/matview definition, type (enum labels, domain base/default/checks,
-- composite, range), rule, the public schema (owner, ACL), installed
-- extensions and function (signature, arguments, return type/set, kind,
-- language, volatility, parallel, strict, leakproof, cost, rows, definer,
-- owner, config, ACL, body hash) — Codex RG3V-02 / RG3W-01.
-- Also (Codex RG3X-01): sequence parameters, relation persistence / replica
-- identity / storage options / partition bound, inheritance, index validity,
-- trigger enabled state, extended statistics, comments on public relations /
-- columns / functions / types,
-- default privileges and event triggers.
-- Also (Codex RG3Y-01/02): replica-identity and clustered index selection,
-- column identity / generated / collation / storage / compression / statistics
-- target, full extended-statistics definition (incl. expressions) and target.
-- Constraint validation state is carried by pg_get_constraintdef (it renders
-- NOT VALID) — Codex RG3Z-02, locked by the coverage self-test.
-- Not covered (documented): data (including sequence current values),
-- comments on schemas, roles, extensions and other shared objects (RG3Z-03,
-- documented P2 residual), publications/subscriptions, large objects, objects outside public other
-- than extensions, default privileges and event triggers (which are global).
-- Used to prove that a failed migration left the schema byte-identical (runner atomicity tests, executor experiment).
SET search_path = pg_catalog;
SELECT md5(coalesce(string_agg(x, E'\n' ORDER BY x COLLATE "C"), '')) FROM (
  SELECT 'rel|' || c.relname || '|' || c.relkind::text || '|' || c.relowner::regrole::text || '|' || coalesce(c.relacl::text, '')
         || '|' || c.relrowsecurity || '|' || c.relforcerowsecurity || '|' || c.relpersistence::text || '|' || c.relreplident::text
         || '|' || coalesce(array_to_string(c.reloptions, ','), '') || '|' || coalesce(pg_get_expr(c.relpartbound, c.oid), '') AS x
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace
  UNION ALL SELECT 'idx|' || pg_get_indexdef(i.indexrelid) || '|' || i.indisvalid || '|' || i.indisready
         || '|' || i.indisreplident || '|' || i.indisclustered
    FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid WHERE c.relnamespace = 'public'::regnamespace
  UNION ALL SELECT 'col|' || c.relname || '|' || a.attname || '|' || a.attnum || '|' || format_type(a.atttypid, a.atttypmod)
         || '|' || a.attnotnull || '|' || coalesce(pg_get_expr(d.adbin, d.adrelid), '') || '|' || coalesce(a.attacl::text, '')
         || '|' || a.attidentity::text || '|' || a.attgenerated::text || '|' || coalesce(a.attcollation::regcollation::text, '')
         || '|' || a.attstorage::text || '|' || a.attcompression::text || '|' || coalesce(a.attstattarget::text, '')
    FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
   WHERE c.relnamespace = 'public'::regnamespace AND a.attnum > 0 AND NOT a.attisdropped
  UNION ALL SELECT 'con|' || conrelid::regclass::text || '|' || conname || '|' || pg_get_constraintdef(oid)
    FROM pg_constraint WHERE connamespace = 'public'::regnamespace
  UNION ALL SELECT 'trg|' || pg_get_triggerdef(t.oid) || '|' || t.tgenabled::text
    FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal
  UNION ALL SELECT 'pol|' || polrelid::regclass::text || '|' || polname || '|' || polcmd::text || '|' || polpermissive
         || '|' || coalesce(pg_get_expr(polqual, polrelid), '') || '|' || coalesce(pg_get_expr(polwithcheck, polrelid), '')
         || '|' || array_to_string(ARRAY(SELECT CASE WHEN r = 0 THEN 'PUBLIC' ELSE r::regrole::text END FROM unnest(polroles) r ORDER BY 1), ',')
    FROM pg_policy
  UNION ALL SELECT 'view|' || c.relname || '|' || pg_get_viewdef(c.oid)
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('v', 'm')
  UNION ALL SELECT 'type|' || t.typname || '|' || t.typtype::text || '|' || t.typowner::regrole::text || '|' || coalesce(t.typacl::text, '')
         || '|' || coalesce(format_type(t.typbasetype, t.typtypmod), '') || '|' || t.typnotnull || '|' || coalesce(t.typdefault, '')
         || '|' || coalesce((SELECT string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder) FROM pg_enum e WHERE e.enumtypid = t.oid), '')
         || '|' || coalesce((SELECT string_agg(pg_get_constraintdef(co.oid), ';' ORDER BY co.conname) FROM pg_constraint co WHERE co.contypid = t.oid), '')
    FROM pg_type t WHERE t.typnamespace = 'public'::regnamespace AND t.typtype IN ('e', 'd', 'c', 'r', 'm')
         AND NOT EXISTS (SELECT 1 FROM pg_class c WHERE c.reltype = t.oid AND c.relkind <> 'c')
  UNION ALL SELECT 'rule|' || r.rulename || '|' || pg_get_ruledef(r.oid)
    FROM pg_rewrite r JOIN pg_class c ON c.oid = r.ev_class WHERE c.relnamespace = 'public'::regnamespace AND r.rulename <> '_RETURN'
  UNION ALL SELECT 'nsp|' || n.nspname || '|' || n.nspowner::regrole::text || '|' || coalesce(n.nspacl::text, '')
    FROM pg_namespace n WHERE n.nspname = 'public'
  UNION ALL SELECT 'ext|' || e.extname || '|' || e.extversion || '|' || e.extnamespace::regnamespace::text
    FROM pg_extension e
  -- Codex RG3X-01: sequence parameters (the current value is data, not catalog).
  UNION ALL SELECT 'seq|' || c.relname || '|' || format_type(s.seqtypid, NULL) || '|' || s.seqstart || '|' || s.seqincrement
         || '|' || s.seqmax || '|' || s.seqmin || '|' || s.seqcache || '|' || s.seqcycle
    FROM pg_sequence s JOIN pg_class c ON c.oid = s.seqrelid WHERE c.relnamespace = 'public'::regnamespace
  UNION ALL SELECT 'inh|' || i.inhrelid::regclass::text || '|' || i.inhparent::regclass::text || '|' || i.inhseqno
    FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid WHERE c.relnamespace = 'public'::regnamespace
  UNION ALL SELECT 'stx|' || pg_get_statisticsobjdef(x.oid) || '|' || coalesce(x.stxstattarget::text, '')
    FROM pg_statistic_ext x WHERE x.stxnamespace = 'public'::regnamespace
  UNION ALL SELECT 'com|' || d.classoid::regclass::text || '|' || d.objsubid || '|' || coalesce(c.relname, p.proname, t.typname, '?') || '|' || d.description
    FROM pg_description d
    LEFT JOIN pg_class c ON d.classoid = 'pg_class'::regclass AND c.oid = d.objoid
    LEFT JOIN pg_proc p ON d.classoid = 'pg_proc'::regclass AND p.oid = d.objoid
    LEFT JOIN pg_type t ON d.classoid = 'pg_type'::regclass AND t.oid = d.objoid
   WHERE c.relnamespace = 'public'::regnamespace OR p.pronamespace = 'public'::regnamespace OR t.typnamespace = 'public'::regnamespace
  UNION ALL SELECT 'dacl|' || d.defaclrole::regrole::text || '|' || coalesce(d.defaclnamespace::regnamespace::text, '*') || '|' || d.defaclobjtype::text || '|' || d.defaclacl::text
    FROM pg_default_acl d
  UNION ALL SELECT 'evt|' || e.evtname || '|' || e.evtevent || '|' || e.evtenabled::text || '|' || e.evtfoid::regproc::text
    FROM pg_event_trigger e
  UNION ALL SELECT 'fn|' || p.oid::regprocedure::text || '|' || pg_get_function_arguments(p.oid) || '|' || format_type(p.prorettype, NULL)
         || '|' || p.provolatile::text || '|' || p.prosecdef || '|' || p.proowner::regrole::text
         || '|' || p.prolang::regproc::text || '|' || p.proparallel::text || '|' || p.proisstrict || '|' || p.proleakproof
         || '|' || p.proretset || '|' || p.prokind::text || '|' || p.procost || '|' || p.prorows
         || '|' || coalesce(array_to_string(p.proconfig, ','), '') || '|' || coalesce(p.proacl::text, '') || '|' || md5(p.prosrc)
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
) s;
