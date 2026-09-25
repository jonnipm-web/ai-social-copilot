#!/usr/bin/env bash
# Disposable-database SQL tests — INSIGHTVALUES-MODULE-FOUNDATION-AND-ENTITLEMENT-02.
#
# Creates a throwaway database on a LOCAL PostgreSQL, applies the Supabase
# stubs and EVERY migration in order, re-applies the newest migration to
# prove idempotency, then runs the RLS test files. Refuses to run against
# any non-local host, so it can never touch a real Supabase project.
#
# Env: PGHOST (127.0.0.1|localhost), PGPORT, PGUSER, optional PSQL (path).
set -euo pipefail

PSQL="${PSQL:-psql}"
HOST="${PGHOST:-127.0.0.1}"
case "$HOST" in
  127.0.0.1|localhost) ;;
  *) echo "refusing to run against non-local host '$HOST'" >&2; exit 2 ;;
esac

DB="entitlement_ci_$$"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
run() { "$PSQL" -h "$HOST" -v ON_ERROR_STOP=1 -q "$@"; }

UPG="${DB}_upgrade"
run -d postgres -c "CREATE DATABASE $DB;"
run -d postgres -c "CREATE DATABASE $UPG;"
trap 'run -d postgres -c "DROP DATABASE IF EXISTS $DB;" >/dev/null 2>&1 || true; run -d postgres -c "DROP DATABASE IF EXISTS $UPG;" >/dev/null 2>&1 || true' EXIT

# Migrations authored in the Module Lab (applied nowhere else yet); every one
# of them must be idempotent.
LAB_FROM="20260923000000"
MEMORY_MIGRATION="20260924000000_ive_memory_governance.sql"

# --single-transaction: a migration that fails anywhere leaves nothing behind
# (the deploy mode AEF_PRODUCTION_DEPLOYMENT_PRECONDITIONS.md requires).
apply() { run -d "$1" -1 -c "SET search_path = public, extensions;" -f "$2" >/dev/null; }

run -d "$DB" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  apply "$DB" "$m"
  echo "applied $(basename "$m")"
done
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  if [[ "$(basename "$m")" > "$LAB_FROM" || "$(basename "$m")" == "$LAB_FROM"* ]]; then
    apply "$DB" "$m" 2>/dev/null
    echo "re-applied $(basename "$m") (idempotency)"
  fi
done

check() {
  local db="$1" file="$2" marker="$3" out
  shift 3
  out="$(run -d "$db" -tA "$@" -f "$ROOT/supabase/tests/$file")"
  echo "$out" | tail -1
  echo "$out" | grep -qx "$marker"
}
check "$DB" entitlement_subject_roles_rls_test.sql 'SUBJECT_ROLES_RLS: PASS'
check "$DB" ive_memory_rls_test.sql 'IVE_MEMORY_RLS: PASS'
check "$DB" aef_persistence_rls_test.sql 'AEF_PERSISTENCE_RLS: PASS'
check "$DB" aef_hardening_test.sql 'AEF_HARDENING: PASS'
# IV-AEF-HARDENING-01: once purge/erasure/reconciliation evidence exists the
# hardening rollback must refuse (and change nothing).
if run -d "$DB" -f "$ROOT/supabase/rollbacks/20260926000000_aef_hardening.down.sql" >/dev/null 2>&1; then
  echo "hardening rollback did not refuse on a database holding hardening evidence" >&2; exit 1
fi
run -d "$DB" -tA -c "SELECT 1 FROM public.aef_idempotency_tombstones LIMIT 1;" | grep -qx 1
echo "AEF_HARDENING_ROLLBACK_REFUSAL: PASS"
# IV-AEF-PRE-RUNTIME-CLOSURE-01 (P03): sequence contract on the full chain.
check "$DB" aef_sequence_privileges_test.sql 'AEF_SEQUENCE: PASS' -v phase=after

# The AEF governance service end-to-end against a real database (concurrency,
# crash recovery, idempotency, forgery, reconciliation, retention, erasure).
# Needs Deno; skipping must be explicit (AEF_PG_INTEGRATION=skip), never silent.
AEF_PG_DB_NAME="${DB}_aef"
RB="${DB}_rb"
run -d postgres -c "CREATE DATABASE $AEF_PG_DB_NAME;"
run -d postgres -c "CREATE DATABASE $RB;"
SEQB="${DB}_seqb"; NF="${DB}_nf"; PF="${DB}_pf"; PROBE_ROLE="aef_probe_grp_$$"
for d in $SEQB $NF $PF; do run -d postgres -c "CREATE DATABASE $d;"; done
trap 'for d in $DB $UPG $AEF_PG_DB_NAME $RB $SEQB $NF $PF; do run -d postgres -c "DROP DATABASE IF EXISTS $d;" >/dev/null 2>&1 || true; done; run -d postgres -c "DROP ROLE IF EXISTS $PROBE_ROLE;" >/dev/null 2>&1 || true' EXIT
run -d "$AEF_PG_DB_NAME" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do apply "$AEF_PG_DB_NAME" "$m"; done
if [[ "${AEF_PG_INTEGRATION:-run}" == "skip" ]]; then
  echo "AEF_PG_INTEGRATION: SKIPPED (explicit)"
else
  ( cd "$ROOT" && AEF_PG_DB="$AEF_PG_DB_NAME" PGHOST="$HOST" PSQL="$PSQL"       "${DENO:-deno}" test --allow-run --allow-env --allow-read         aef/persistence/governance_pg_test.ts aef/persistence/hardening_pg_test.ts )
  echo "AEF_PG_INTEGRATION: PASS"
fi

# Full cycle on a dedicated database: persistence only → v1 data → hardening
# UP → v1 untouched → hardening DOWN → still verifiable → persistence DOWN
# (scoped: an unrelated aef_* object survives) → both UP → hardening suite.
HARDENING_MIGRATION="20260926000000_aef_hardening.sql"
SEQUENCE_MIGRATION="20260927000000_aef_sequence_privileges.sql"
run -d "$RB" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  [[ "$(basename "$m")" == "$HARDENING_MIGRATION" ]] && continue
  apply "$RB" "$m"
done
check "$RB" aef_hardening_legacy_test.sql 'AEF_LEGACY: SEEDED' -v phase=seed
apply "$RB" "$ROOT/supabase/migrations/$HARDENING_MIGRATION"
check "$RB" aef_hardening_legacy_test.sql 'AEF_LEGACY: PASS' -v phase=verify
# Codex HG1-04: an active legal hold (or a registered verifier / changed
# policy) makes the rollback refuse; nothing changes.
run -d "$RB" -c "INSERT INTO public.aef_legal_holds (subject_id, reason_code) VALUES ('c7000000-0000-4000-8000-00000000000c', 'AUDIT_HOLD');"
if run -d "$RB" -f "$ROOT/supabase/rollbacks/20260926000000_aef_hardening.down.sql" >/dev/null 2>&1; then
  echo "hardening rollback ignored an active legal hold" >&2; exit 1
fi
run -d "$RB" -c "DELETE FROM public.aef_legal_holds;"
run -d "$RB" -f "$ROOT/supabase/rollbacks/20260926000000_aef_hardening.down.sql" >/dev/null
check "$RB" aef_hardening_legacy_test.sql 'AEF_LEGACY: DOWN_OK' -v phase=down
run -d "$RB" -c "DROP TABLE public.aef_legacy_probe;"
run -d "$RB" -c "CREATE FUNCTION public.aef_unrelated_sentinel() RETURNS int LANGUAGE sql AS 'SELECT 1';"
run -d "$RB" -f "$ROOT/supabase/rollbacks/20260925000000_aef_persistence.down.sql" >/dev/null
left="$(run -d "$RB" -tA -c "SELECT (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind = 'r' AND left(c.relname, 4) = 'aef_') || '|' || (SELECT string_agg(p.proname, ',') FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_');")"
# Codex Final CF-02: every AEF object gone, the unrelated sentinel untouched.
[[ "$left" == "0|aef_unrelated_sentinel" ]] || { echo "rollback left: $left" >&2; exit 1; }
run -d "$RB" -c "DROP FUNCTION public.aef_unrelated_sentinel();"
apply "$RB" "$ROOT/supabase/migrations/20260925000000_aef_persistence.sql"
apply "$RB" "$ROOT/supabase/migrations/$HARDENING_MIGRATION"
apply "$RB" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION"
check "$RB" aef_hardening_test.sql 'AEF_HARDENING: PASS'
# 20260927 rollback is a verified no-op (security state kept) and the contract still holds.
run -d "$RB" -f "$ROOT/supabase/rollbacks/20260927000000_aef_sequence_privileges.down.sql" >/dev/null
check "$RB" aef_sequence_privileges_test.sql 'AEF_SEQUENCE: PASS' -v phase=after
apply "$RB" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION"   # re-UP after DOWN
check "$RB" aef_sequence_privileges_test.sql 'AEF_SEQUENCE: PASS' -v phase=after
echo "AEF_ROLLBACK: PASS"

# Legacy-data upgrade (Codex Gate 1 IG1-04): seed with today's schema, then
# apply the memory migration on top of that data.
run -d "$UPG" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  [[ "$(basename "$m")" == "$MEMORY_MIGRATION" ]] && continue
  apply "$UPG" "$m"
done
check "$UPG" ive_memory_legacy_upgrade_test.sql 'IVE_MEMORY_UPGRADE: SEEDED' -v phase=seed
apply "$UPG" "$ROOT/supabase/migrations/$MEMORY_MIGRATION"
check "$UPG" ive_memory_legacy_upgrade_test.sql 'IVE_MEMORY_UPGRADE: PASS' -v phase=verify

# ── IV-AEF-PRE-RUNTIME-CLOSURE-01 ───────────────────────────────────────
# Every migration is applied with --single-transaction (the deploy mode the
# runbook requires), so a failure anywhere in a file leaves nothing behind.
q() { run -d "$1" -tA -c "$2"; }
AEF_SEQ_EXPOSED="SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace CROSS JOIN (VALUES ('anon'), ('authenticated'), ('service_role')) g(r) CROSS JOIN (VALUES ('USAGE'), ('SELECT'), ('UPDATE')) pv(p) WHERE n.nspname = 'public' AND c.relkind = 'S' AND (left(c.relname, 4) = 'aef_' OR EXISTS (SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid = d.refobjid WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.refclassid = 'pg_class'::regclass AND d.deptype IN ('a', 'i') AND left(t.relname, 4) = 'aef_')) AND has_sequence_privilege(g.r, c.oid, pv.p);"

# P03 reproduced. The earlier revision of 20260925 (b38ee2e) did not revoke,
# so its audit sequence kept the rwU grants it inherited from production's
# defaults (S01a proves the inheritance on a fresh identity sequence). That
# pre-fix state is reconstructed with the exact grants inheritance produced,
# then 20260927 must repair it.
run -d "$SEQB" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  [[ "$(basename "$m")" == "$SEQUENCE_MIGRATION" ]] && continue
  apply "$SEQB" "$m"
done
run -d "$SEQB" -c "GRANT ALL ON SEQUENCE public.aef_audit_events_id_seq TO anon, authenticated, service_role;"
check "$SEQB" aef_sequence_privileges_test.sql 'AEF_SEQUENCE: EXPOSED_BEFORE_FIX' -v phase=before
apply "$SEQB" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION"
# operator repair after a rewind: move the sequence past the highest id (as owner)
run -d "$SEQB" -c "SELECT setval('public.aef_audit_events_id_seq', (SELECT max(id) FROM public.aef_audit_events));" >/dev/null
check "$SEQB" aef_sequence_privileges_test.sql 'AEF_SEQUENCE: PASS' -v phase=after
echo "AEF_SEQUENCE_REPAIR: PASS"

# P05 fail-fast: a Lab migration never applies (not even partially) without
# the objects it really depends on.
expect_fail() {  # db file expected-text
  local out
  if out="$(run -d "$1" -1 -c "SET search_path = public, extensions;" -f "$2" 2>&1)"; then
    echo "expected $(basename "$2") to fail on $1" >&2; exit 1
  fi
  echo "$out" | grep -qF "$3" || { echo "unexpected failure for $(basename "$2"): $out" >&2; exit 1; }
}
count_aef() {  # relations + functions + triggers + policies: a failed apply must leave none behind
  q "$1" "SELECT (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND left(c.relname, 4) = 'aef_') + (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_') + (SELECT count(*) FROM pg_trigger WHERE left(tgname, 4) = 'aef_') + (SELECT count(*) FROM pg_policy WHERE left(polname, 4) = 'aef_');"
}
run -d "$NF" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
# 20260923 / 20260924 on a database without their dependencies (no baseline)
expect_fail "$NF" "$ROOT/supabase/migrations/20260923000000_entitlement_subject_roles.sql" "LAB_PRECONDITION (20260923000000_entitlement_subject_roles)"
[[ "$(q "$NF" "SELECT to_regclass('public.subject_roles') IS NULL;")" == "t" ]] || { echo "partial 20260923 state" >&2; exit 1; }
expect_fail "$NF" "$ROOT/supabase/migrations/20260924000000_ive_memory_governance.sql" "LAB_PRECONDITION (20260924000000_ive_memory_governance)"
[[ "$(q "$NF" "SELECT to_regprocedure('public.business_memory_derive_scope()') IS NULL;")" == "t" ]] || { echo "partial 20260924 state" >&2; exit 1; }
expect_fail "$NF" "$ROOT/supabase/migrations/20260925000000_aef_persistence.sql" "AEF_PRECONDITION (20260925000000_aef_persistence)"
[[ "$(count_aef "$NF")" == "0" ]] || { echo "partial AEF state after a failed precondition" >&2; exit 1; }
expect_fail "$NF" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION" "AEF_PRECONDITION"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  [[ "$(basename "$m")" < "20260923000000" ]] && apply "$NF" "$m"
done
apply "$NF" "$ROOT/supabase/migrations/20260925000000_aef_persistence.sql"   # needs no subject_roles
# no exposure window: 20260925 alone already leaves no API-role access to its sequence
[[ "$(q "$NF" "$AEF_SEQ_EXPOSED")" == "0" ]] || { echo "20260925 alone leaves an AEF sequence exposed" >&2; exit 1; }
before="$(count_aef "$NF")"
expect_fail "$NF" "$ROOT/supabase/migrations/$HARDENING_MIGRATION" "public.subject_roles"
[[ "$(count_aef "$NF")" == "$before" ]] || { echo "partial hardening state after a failed precondition" >&2; exit 1; }
apply "$NF" "$ROOT/supabase/migrations/20260923000000_entitlement_subject_roles.sql"
# atomicity: a LATE failure (conflicting function, after the precondition
# passed and many objects were created) leaves nothing behind either
run -d "$NF" -c "CREATE FUNCTION public.aef_purge(p jsonb) RETURNS int LANGUAGE sql AS 'SELECT 1';"
before="$(count_aef "$NF")"
expect_fail "$NF" "$ROOT/supabase/migrations/$HARDENING_MIGRATION" "cannot change return type"
[[ "$(count_aef "$NF")" == "$before" && "$(q "$NF" "SELECT to_regclass('public.aef_retention_policy') IS NULL;")" == "t" ]] \
  || { echo "partial hardening state after a late failure" >&2; exit 1; }
run -d "$NF" -c "DROP FUNCTION public.aef_purge(jsonb);"
apply "$NF" "$ROOT/supabase/migrations/$HARDENING_MIGRATION"
apply "$NF" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION"
echo "AEF_FAIL_FAST: PASS"

# 20260927 postcondition / discovery / rollback verifier (Codex G1-01..03)
# (a) a non-prefixed sequence owned by an AEF table, exposed by the defaults,
#     is found and revoked on re-apply
run -d "$NF" -c "CREATE SEQUENCE public.probe_owned_seq OWNED BY public.aef_legal_holds.reason_code;"
[[ "$(q "$NF" "SELECT has_sequence_privilege('authenticated', 'public.probe_owned_seq', 'UPDATE');")" == "t" ]] \
  || { echo "fixture: owned probe sequence did not inherit the defaults" >&2; exit 1; }
apply "$NF" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION"
[[ "$(q "$NF" "$AEF_SEQ_EXPOSED")" == "0" ]] || { echo "20260927 missed a non-prefixed AEF-owned sequence" >&2; exit 1; }
check "$NF" aef_sequence_privileges_test.sql 'AEF_SEQUENCE: PASS' -v phase=after
# (b) access through a group role cannot be revoked by the owner: the
#     postcondition must fail the migration, and the rollback verifier refuse
run -d postgres -c "CREATE ROLE $PROBE_ROLE NOLOGIN;"
run -d "$NF" -c "GRANT UPDATE ON SEQUENCE public.probe_owned_seq TO $PROBE_ROLE; GRANT $PROBE_ROLE TO anon;"
expect_fail "$NF" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION" "AEF_POSTCONDITION: role anon still has UPDATE on sequence probe_owned_seq"
if run -d "$NF" -f "$ROOT/supabase/rollbacks/20260927000000_aef_sequence_privileges.down.sql" >/dev/null 2>&1; then
  echo "rollback verifier accepted an exposed sequence (group role)" >&2; exit 1
fi
run -d "$NF" -c "REVOKE $PROBE_ROLE FROM anon; DROP SEQUENCE public.probe_owned_seq;"
run -d postgres -c "DROP ROLE $PROBE_ROLE;"
# (c) the rollback verifier covers service_role / SELECT / PUBLIC as well
for g in "SELECT ON SEQUENCE public.aef_audit_events_id_seq TO service_role" "USAGE ON SEQUENCE public.aef_audit_events_id_seq TO PUBLIC"; do
  run -d "$NF" -c "GRANT $g;"
  if run -d "$NF" -f "$ROOT/supabase/rollbacks/20260927000000_aef_sequence_privileges.down.sql" >/dev/null 2>&1; then
    echo "rollback verifier accepted: $g" >&2; exit 1
  fi
  run -d "$NF" -c "REVOKE ${g/ TO / FROM };"
done
run -d "$NF" -f "$ROOT/supabase/rollbacks/20260927000000_aef_sequence_privileges.down.sql" >/dev/null
echo "AEF_SEQUENCE_POSTCONDITION: PASS"

# P10 deploy preflight: read-only, fail-closed, against simulated production
# states (history recorded by NAME, as observed in production).
PREFLIGHT="$ROOT/supabase/preflight/aef_deploy_preflight.sql"
expect_preflight() {  # label PASS|FAIL expected-text
  local out rc=0
  out="$(run -d "$PF" -f "$PREFLIGHT" 2>&1)" || rc=$?
  if [[ "$2" == "PASS" ]]; then
    [[ $rc -eq 0 ]] && echo "$out" | grep -q "AEF_DEPLOY_PREFLIGHT: PASS" && echo "$out" | grep -qF "$3" \
      || { echo "preflight $1: expected PASS/$3, got: $out" >&2; exit 1; }
  else
    [[ $rc -ne 0 ]] && echo "$out" | grep -q "AEF_DEPLOY_PREFLIGHT: FAIL" && echo "$out" | grep -qF "$3" \
      && ! echo "$out" | grep -q "AEF_DEPLOY_PREFLIGHT: PASS" \
      || { echo "preflight $1: expected FAIL/$3, got: $out" >&2; exit 1; }
  fi
}
fail_then() {  # label expected-text break-sql fix-sql
  run -d "$PF" -c "$3" >/dev/null; expect_preflight "$1" FAIL "$2"; run -d "$PF" -c "$4" >/dev/null
}
record() { run -d "$PF" -c "INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('$1', '$2');" >/dev/null; }
run -d "$PF" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
expect_preflight "no history table" FAIL "no supabase_migrations.schema_migrations history table"
# a malformed history table (no name column) is an unexpected error → still FAIL, never PASS
run -d "$PF" -c "CREATE SCHEMA supabase_migrations; CREATE TABLE supabase_migrations.schema_migrations (version text PRIMARY KEY);"
expect_preflight "malformed history table" FAIL "unexpected error"
run -d "$PF" -c "DROP TABLE supabase_migrations.schema_migrations; CREATE TABLE supabase_migrations.schema_migrations (version text PRIMARY KEY, name text, statements text[]);"
expect_preflight "empty history" FAIL "predecessor migration baseline_production_pre_x4r missing"
v=20260101000000
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  b="$(basename "$m" .sql)"
  [[ "$b" < "20260923000000" ]] || continue
  apply "$PF" "$m"; v=$((v + 1)); record "$v" "${b#*_}"
done
expect_preflight "production-like baseline" PASS "entitlement_subject_roles -> ive_memory_governance -> aef_persistence -> aef_hardening -> aef_sequence_privileges"
fail_then "missing predecessor" "predecessor migration opportunity_knowledge_links missing" \
  "UPDATE supabase_migrations.schema_migrations SET name = 'renamed' WHERE name = 'opportunity_knowledge_links';" \
  "UPDATE supabase_migrations.schema_migrations SET name = 'opportunity_knowledge_links' WHERE name = 'renamed';"
fail_then "NULL history name" "row(s) without a name" \
  "INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20269999000090', NULL);" \
  "DELETE FROM supabase_migrations.schema_migrations WHERE version = '20269999000090';"
fail_then "duplicate history name" "duplicate migration names" \
  "INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20269999000091', 'stripe_billing');" \
  "DELETE FROM supabase_migrations.schema_migrations WHERE version = '20269999000091';"
fail_then "history without objects" "aef_persistence is in the history but its objects are absent" \
  "INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20269999000001', 'aef_persistence');" \
  "DELETE FROM supabase_migrations.schema_migrations WHERE version = '20269999000001';"
fail_then "stray aef object" "aef_* objects exist without aef_persistence" \
  "CREATE TABLE public.aef_stray (id int);" "DROP TABLE public.aef_stray;"
fail_then "projects drift" "public.projects(id uuid, user_id uuid NOT NULL) not as expected" \
  "ALTER TABLE public.projects ALTER COLUMN user_id DROP NOT NULL;" "ALTER TABLE public.projects ALTER COLUMN user_id SET NOT NULL;"
apply "$PF" "$ROOT/supabase/migrations/20260923000000_entitlement_subject_roles.sql"; record 20269999000002 entitlement_subject_roles
apply "$PF" "$ROOT/supabase/migrations/20260924000000_ive_memory_governance.sql"; record 20269999000003 ive_memory_governance
apply "$PF" "$ROOT/supabase/migrations/20260925000000_aef_persistence.sql"; record 20269999000004 aef_persistence
fail_then "partial persistence" "aef_persistence is partially present" \
  "ALTER TABLE public.aef_human_gates RENAME TO x_gates;" "ALTER TABLE public.x_gates RENAME TO aef_human_gates;"
apply "$PF" "$ROOT/supabase/migrations/$HARDENING_MIGRATION"; record 20269999000005 aef_hardening
expect_preflight "chain without 20260927 (20260925 revokes itself)" PASS "remaining, in order: aef_sequence_privileges"
fail_then "partial hardening" "aef_hardening is partially present" \
  "ALTER FUNCTION public.aef_purge(jsonb) RENAME TO x_purge;" "ALTER FUNCTION public.x_purge(jsonb) RENAME TO aef_purge;"
fail_then "pre-fix exposed sequence" "AEF sequence exposed to an API role or PUBLIC" \
  "GRANT ALL ON SEQUENCE public.aef_audit_events_id_seq TO anon, authenticated, service_role;" \
  "REVOKE ALL ON SEQUENCE public.aef_audit_events_id_seq FROM anon, authenticated, service_role;"
fail_then "PUBLIC SELECT on the sequence" "aef_audit_events_id_seq PUBLIC" \
  "GRANT SELECT ON SEQUENCE public.aef_audit_events_id_seq TO PUBLIC;" "REVOKE SELECT ON SEQUENCE public.aef_audit_events_id_seq FROM PUBLIC;"
fail_then "extra exposed AEF sequence" "aef_extra_seq anon USAGE" \
  "CREATE SEQUENCE public.aef_extra_seq;" "DROP SEQUENCE public.aef_extra_seq;"
fail_then "non-prefixed AEF-owned sequence" "probe_owned_seq service_role SELECT" \
  "CREATE SEQUENCE public.probe_owned_seq OWNED BY public.aef_legal_holds.reason_code;" "DROP SEQUENCE public.probe_owned_seq;"
fail_then "RPC made SECURITY INVOKER" "RPC aef_get_operation is not SECURITY DEFINER" \
  "ALTER FUNCTION public.aef_get_operation(jsonb) SECURITY INVOKER;" "ALTER FUNCTION public.aef_get_operation(jsonb) SECURITY DEFINER;"
fail_then "search_path unpinned" "aef_get_operation has no pinned search_path" \
  "ALTER FUNCTION public.aef_get_operation(jsonb) RESET search_path;" "ALTER FUNCTION public.aef_get_operation(jsonb) SET search_path = pg_catalog, pg_temp;"
fail_then "RPC executable by anon" "aef_get_operation is executable by anon/authenticated/PUBLIC" \
  "GRANT EXECUTE ON FUNCTION public.aef_get_operation(jsonb) TO anon;" "REVOKE EXECUTE ON FUNCTION public.aef_get_operation(jsonb) FROM anon;"
fail_then "helper executable by service_role" "service_role EXECUTE on aef__view differs from the contract" \
  "GRANT EXECUTE ON FUNCTION public.aef__view(uuid) TO service_role;" "REVOKE EXECUTE ON FUNCTION public.aef__view(uuid) FROM service_role;"
fail_then "API role can write an AEF table" "service_role can write aef_receipts" \
  "GRANT INSERT ON public.aef_receipts TO service_role;" "REVOKE INSERT ON public.aef_receipts FROM service_role;"
fail_then "history claims 20260927 but a sequence is exposed" "aef_sequence_privileges is in the history but an AEF sequence is exposed" \
  "INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20269999000009', 'aef_sequence_privileges'); GRANT UPDATE ON SEQUENCE public.aef_audit_events_id_seq TO authenticated;" \
  "DELETE FROM supabase_migrations.schema_migrations WHERE version = '20269999000009'; REVOKE UPDATE ON SEQUENCE public.aef_audit_events_id_seq FROM authenticated;"
apply "$PF" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION"; record 20269999000006 aef_sequence_privileges
expect_preflight "fully applied chain" PASS "remaining, in order: (none)"
# 20260927 recorded before 20260926 is an accepted order (depends on 20260925 only)
run -d "$PF" -c "UPDATE supabase_migrations.schema_migrations SET version = '20269999000004a' WHERE name = 'aef_sequence_privileges';" >/dev/null
expect_preflight "20260927 before 20260926" PASS "remaining, in order: (none)"
fail_then "20260927 recorded before 20260925" "order: aef_sequence_privileges recorded before aef_persistence" \
  "UPDATE supabase_migrations.schema_migrations SET version = '20269999000003a' WHERE name = 'aef_sequence_privileges';" \
  "UPDATE supabase_migrations.schema_migrations SET version = '20269999000006' WHERE name = 'aef_sequence_privileges';"
fail_then "hardening recorded before entitlement" "order: aef_hardening recorded before one of its dependencies" \
  "UPDATE supabase_migrations.schema_migrations SET version = '20269999000005z' WHERE name = 'entitlement_subject_roles';" \
  "UPDATE supabase_migrations.schema_migrations SET version = '20269999000002' WHERE name = 'entitlement_subject_roles';"
fail_then "hardening without entitlement in the history" "order: aef_hardening applied without entitlement_subject_roles" \
  "UPDATE supabase_migrations.schema_migrations SET name = 'x_entitlement' WHERE name = 'entitlement_subject_roles';" \
  "UPDATE supabase_migrations.schema_migrations SET name = 'entitlement_subject_roles' WHERE name = 'x_entitlement';"
expect_preflight "restored" PASS "remaining, in order: (none)"
# The preflight is read-only by construction: READ ONLY transaction, rolled
# back, and no write statement at all.
grep -q "^BEGIN TRANSACTION READ ONLY;" "$PREFLIGHT" && grep -q "^ROLLBACK;" "$PREFLIGHT" \
  || { echo "preflight is not wrapped in a READ ONLY transaction" >&2; exit 1; }
if grep -qiE "^[[:space:]]*(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|GRANT|REVOKE|TRUNCATE|COMMIT)[[:space:]]" "$PREFLIGHT"; then
  echo "preflight contains a write statement" >&2; exit 1
fi
echo "AEF_DEPLOY_PREFLIGHT_TESTS: PASS"

# SECURITY DEFINER boundary (P06/P07): no AEF code calls the pre-existing
# definer functions (runtime catalog check: S13 in aef_sequence_privileges_test.sql).
if grep -rnE "get_current_user_role|handle_new_user|is_admin_user|validate_asset_" "$ROOT"/aef "$ROOT"/supabase/migrations/2026092[5-9]*.sql; then
  echo "AEF references a pre-existing definer function (P06/P07)" >&2; exit 1
fi
echo "AEF_DEFINER_BOUNDARY: PASS"

# P05: every Lab migration declares its real dependencies up front.
for m in "$ROOT"/supabase/migrations/2026092[3-9]*.sql; do
  grep -qE "(AEF|LAB)_PRECONDITION" "$m" || { echo "$(basename "$m") has no precondition guard" >&2; exit 1; }
done
echo "AEF_MIGRATION_PRECONDITIONS: PASS"
