-- Whole-`public`-schema catalog fingerprint (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
-- One md5 over every relation (kind, owner, ACL, RLS), index, column
-- (position, type, nullability, default), constraint, trigger, policy,
-- view/matview definition, type (enum labels, domain base/default/checks,
-- composite, range), rule, the public schema (owner, ACL), installed
-- extensions and function (signature, arguments, return type, volatility,
-- definer, owner, config, ACL, body hash) — Codex RG3V-02.
-- Not covered (documented): comments, statistics, storage parameters,
-- event triggers, publications, objects outside public other than extensions.
-- Used to prove that a failed migration left the schema byte-identical (runner atomicity tests, executor experiment).
SET search_path = pg_catalog;
SELECT md5(coalesce(string_agg(x, E'\n' ORDER BY x COLLATE "C"), '')) FROM (
  SELECT 'rel|' || c.relname || '|' || c.relkind::text || '|' || c.relowner::regrole::text || '|' || coalesce(c.relacl::text, '')
         || '|' || c.relrowsecurity || '|' || c.relforcerowsecurity AS x
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace
  UNION ALL SELECT 'idx|' || pg_get_indexdef(i.indexrelid)
    FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid WHERE c.relnamespace = 'public'::regnamespace
  UNION ALL SELECT 'col|' || c.relname || '|' || a.attname || '|' || a.attnum || '|' || format_type(a.atttypid, a.atttypmod)
         || '|' || a.attnotnull || '|' || coalesce(pg_get_expr(d.adbin, d.adrelid), '')
    FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
   WHERE c.relnamespace = 'public'::regnamespace AND a.attnum > 0 AND NOT a.attisdropped
  UNION ALL SELECT 'con|' || conrelid::regclass::text || '|' || conname || '|' || pg_get_constraintdef(oid)
    FROM pg_constraint WHERE connamespace = 'public'::regnamespace
  UNION ALL SELECT 'trg|' || pg_get_triggerdef(t.oid)
    FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal
  UNION ALL SELECT 'pol|' || polrelid::regclass::text || '|' || polname || '|' || coalesce(pg_get_expr(polqual, polrelid), '')
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
  UNION ALL SELECT 'fn|' || p.oid::regprocedure::text || '|' || pg_get_function_arguments(p.oid) || '|' || format_type(p.prorettype, NULL)
         || '|' || p.provolatile::text || '|' || p.prosecdef || '|' || p.proowner::regrole::text
         || '|' || coalesce(array_to_string(p.proconfig, ','), '') || '|' || coalesce(p.proacl::text, '') || '|' || md5(p.prosrc)
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
) s;
