-- IVE-X4R-MB2R schema fingerprint.
--
-- Read-only. Produces a structured, diffable dump of every
-- application-owned public-schema object for comparing a local instance
-- against production's captured shape. Run identically against both
-- (locally via `psql -f`, against production via the same read-only
-- catalog-query mechanism used throughout this whole engagement).
--
-- Run with: psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/schema_fingerprint.sql

\pset format unaligned
\pset fieldsep '|'
\pset tuples_only on

\echo '=== TABLES ==='
SELECT c.relname
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY c.relname;

\echo '=== COLUMNS ==='
SELECT table_name || '.' || column_name || '|' || data_type || '|' || is_nullable || '|' || COALESCE(column_default, '<none>')
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

\echo '=== CONSTRAINTS ==='
SELECT conrelid::regclass::text || '|' || conname || '|' || contype::text || '|' || pg_get_constraintdef(oid)
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY conrelid::regclass::text, contype::text, conname;

\echo '=== INDEXES ==='
SELECT tablename || '|' || indexname || '|' || indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

\echo '=== SEQUENCES ==='
SELECT sequence_name || '|' || data_type
FROM information_schema.sequences
WHERE sequence_schema = 'public'
ORDER BY sequence_name;

\echo '=== RLS STATUS ==='
SELECT c.relname || '|' || c.relrowsecurity::text || '|' || c.relforcerowsecurity::text
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY c.relname;

\echo '=== POLICIES ==='
SELECT tablename || '|' || policyname || '|' || cmd || '|' || permissive || '|' || roles::text || '|' || COALESCE(qual, '<none>') || '|' || COALESCE(with_check, '<none>')
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

\echo '=== FUNCTIONS ==='
SELECT p.proname || '|' || l.lanname || '|' || r.rolname || '|' || (CASE WHEN p.prosecdef THEN 'DEFINER' ELSE 'INVOKER' END) || '|' || p.provolatile::text || '|' || COALESCE(array_to_string(p.proconfig, ','), '<none>') || '|' || pg_get_function_result(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_roles r ON r.oid = p.proowner
JOIN pg_language l ON l.oid = p.prolang
WHERE n.nspname = 'public'
ORDER BY p.proname;

\echo '=== FUNCTION EXECUTE GRANTS ==='
SELECT routine_name || '|' || grantee || '|' || privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public' AND grantee IN ('anon','authenticated','service_role','PUBLIC')
ORDER BY routine_name, grantee;

\echo '=== TRIGGERS ==='
-- NOTE: tgrelid::regnamespace is WRONG (tgrelid is a table OID, not a
-- namespace OID -- casting it directly to regnamespace silently returns
-- zero rows) -- a real bug found dynamically via this branch's own CI
-- run and via the equivalent mistake independently caught in a live
-- production query this same session. Fixed by joining pg_class/
-- pg_namespace properly, as verified working against production.
SELECT n.nspname || '.' || c.relname || '|' || t.tgname || '|' || pg_get_triggerdef(t.oid)
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND n.nspname IN ('public','auth')
  AND c.relname !~ '^(schema_migrations|audit_log_entries|refresh_tokens|sessions|mfa_)'
ORDER BY n.nspname, c.relname, t.tgname;

\echo '=== TABLE GRANTS ==='
SELECT table_name || '|' || grantee || '|' || string_agg(privilege_type, ',' ORDER BY privilege_type)
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND grantee IN ('anon','authenticated','service_role')
GROUP BY table_name, grantee
ORDER BY table_name, grantee;

\echo '=== SCHEMA GRANTS (public) ==='
SELECT nspacl::text FROM pg_namespace WHERE nspname = 'public';

\echo '=== DEFAULT PRIVILEGES ==='
SELECT COALESCE(r.rolname, '<none>') || '|' || d.defaclnamespace::regnamespace::text || '|' || d.defaclobjtype::text || '|' || d.defaclacl::text
FROM pg_default_acl d
LEFT JOIN pg_roles r ON r.oid = d.defaclrole
WHERE d.defaclnamespace::regnamespace::text = 'public' OR d.defaclnamespace = 0
ORDER BY d.defaclobjtype;

\echo '=== FINGERPRINT COMPLETE ==='
