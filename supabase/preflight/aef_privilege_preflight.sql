-- AEF production privilege preflight (IV-AEF-HARDENING-01) — READ-ONLY.
--
-- Runs entirely inside a READ ONLY transaction that is rolled back: any
-- attempted write fails. Contains only catalog SELECTs. Safe to run in the
-- Supabase SQL editor of the production project by the Owner. Paste the
-- full output back; nothing here changes grants, schema, RLS or data.
BEGIN TRANSACTION READ ONLY;

-- P01 server / roles
SELECT 'P01' AS check, version() AS postgres_version, current_user, session_user;
SELECT 'P01b' AS check, rolname, rolsuper, rolbypassrls, rolcanlogin, rolinherit
  FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role', 'postgres', 'supabase_admin', 'authenticator')
 ORDER BY rolname;

-- P02 schema public: owner, USAGE / CREATE per role (CREATE must be false for API roles)
SELECT 'P02' AS check, n.nspname, pg_get_userbyid(n.nspowner) AS owner,
       has_schema_privilege('anon', n.oid, 'CREATE') AS anon_create,
       has_schema_privilege('authenticated', n.oid, 'CREATE') AS auth_create,
       has_schema_privilege('service_role', n.oid, 'CREATE') AS service_create,
       has_schema_privilege('anon', n.oid, 'USAGE') AS anon_usage
  FROM pg_namespace n WHERE n.nspname IN ('public', 'auth', 'extensions');

-- P03 default privileges that new AEF objects would inherit
SELECT 'P03' AS check, pg_get_userbyid(d.defaclrole) AS grantor_role, n.nspname AS schema,
       d.defaclobjtype AS object_type, d.defaclacl::text AS acl
  FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
 ORDER BY 2, 3, 4;

-- P04 does anything named aef_* already exist? (expected: nothing)
SELECT 'P04' AS check, c.relkind, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND left(c.relname, 4) = 'aef_';
SELECT 'P04b' AS check, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_';

-- P05 dependencies the AEF migrations reference
SELECT 'P05' AS check,
       to_regclass('public.projects') IS NOT NULL AS has_projects,
       to_regclass('public.subject_roles') IS NOT NULL AS has_subject_roles,
       to_regclass('auth.users') IS NOT NULL AS has_auth_users,
       to_regprocedure('pg_catalog.sha256(bytea)') IS NOT NULL AS has_sha256,
       to_regprocedure('pg_catalog.gen_random_uuid()') IS NOT NULL AS has_gen_random_uuid;
SELECT 'P05b' AS check, column_name, data_type FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'projects' AND column_name IN ('id', 'user_id');

-- P06 existing SECURITY DEFINER functions in public and who can execute them
SELECT 'P06' AS check, p.proname, pg_get_userbyid(p.proowner) AS owner,
       coalesce(array_to_string(p.proconfig, ','), '(no search_path)') AS config,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_exec,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_exec
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prosecdef
 ORDER BY p.proname;

-- P07 functions in public executable by PUBLIC (inherited)
SELECT 'P07' AS check, p.proname
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE')
 ORDER BY p.proname;

-- P08 role-level / database-level search_path settings
SELECT 'P08' AS check, coalesce(r.rolname, '(all)') AS role, coalesce(d.datname, '(all)') AS db, s.setconfig::text
  FROM pg_db_role_setting s LEFT JOIN pg_roles r ON r.oid = s.setrole LEFT JOIN pg_database d ON d.oid = s.setdatabase;

-- P09 RLS state of the tables AEF reads
SELECT 'P09' AS check, c.relname, c.relrowsecurity, c.relforcerowsecurity, pg_get_userbyid(c.relowner) AS owner
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relname IN ('projects', 'subject_roles');

-- P10 migration history visible to the CLI
SELECT 'P10' AS check, version FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 15;

ROLLBACK;
