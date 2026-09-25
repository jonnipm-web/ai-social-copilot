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

apply() { run -d "$1" -c "SET search_path = public, extensions;" -f "$2" >/dev/null; }

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
SEQB="${DB}_seqb"; NF="${DB}_nf"; PF="${DB}_pf"
for d in $SEQB $NF $PF; do run -d postgres -c "CREATE DATABASE $d;"; done
trap 'for d in $DB $UPG $AEF_PG_DB_NAME $RB $SEQB $NF $PF; do run -d postgres -c "DROP DATABASE IF EXISTS $d;" >/dev/null 2>&1 || true; done' EXIT
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
# P03 reproduced: production-equivalent sequence defaults, every migration
# except 20260927 → the audit sequence is exposed and an anon setval breaks
# audit appends. (The fix is proven by 'AEF_SEQUENCE: PASS' above.)
run -d "$SEQB" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  [[ "$(basename "$m")" == "$SEQUENCE_MIGRATION" ]] && continue
  apply "$SEQB" "$m"
done
check "$SEQB" aef_sequence_privileges_test.sql 'AEF_SEQUENCE: EXPOSED_BEFORE_FIX' -v phase=before

# P05 fail-fast: an AEF migration never applies (not even partially) without
# the objects it really depends on.
expect_fail() {  # db file expected-text
  local out
  if out="$(run -d "$1" -c "SET search_path = public, extensions;" -f "$2" 2>&1)"; then
    echo "expected $(basename "$2") to fail on $1" >&2; exit 1
  fi
  echo "$out" | grep -q "$3" || { echo "unexpected failure for $(basename "$2"): $out" >&2; exit 1; }
}
count_aef() {  # relations + functions + triggers: a failed precondition must leave none behind
  run -d "$1" -tA -c "SELECT (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND left(c.relname, 4) = 'aef_') + (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND left(p.proname, 4) = 'aef_') + (SELECT count(*) FROM pg_trigger WHERE left(tgname, 4) = 'aef_');"
}
run -d "$NF" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
expect_fail "$NF" "$ROOT/supabase/migrations/20260925000000_aef_persistence.sql" "AEF_PRECONDITION (20260925000000_aef_persistence)"
[[ "$(count_aef "$NF")" == "0" ]] || { echo "partial AEF state after a failed precondition" >&2; exit 1; }
expect_fail "$NF" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION" "AEF_PRECONDITION"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  [[ "$(basename "$m")" < "20260923000000" ]] && apply "$NF" "$m"
done
apply "$NF" "$ROOT/supabase/migrations/20260925000000_aef_persistence.sql"   # needs no subject_roles
before="$(count_aef "$NF")"
expect_fail "$NF" "$ROOT/supabase/migrations/$HARDENING_MIGRATION" "public.subject_roles"
[[ "$(count_aef "$NF")" == "$before" ]] || { echo "partial hardening state after a failed precondition" >&2; exit 1; }
apply "$NF" "$ROOT/supabase/migrations/20260923000000_entitlement_subject_roles.sql"
apply "$NF" "$ROOT/supabase/migrations/$HARDENING_MIGRATION"
apply "$NF" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION"
echo "AEF_FAIL_FAST: PASS"

# P10 deploy preflight: read-only, fail-closed, against simulated production
# states (history recorded by NAME, as observed in production).
PREFLIGHT="$ROOT/supabase/preflight/aef_deploy_preflight.sql"
preflight() { run -d "$PF" -f "$PREFLIGHT" 2>&1; }
expect_preflight() {  # label PASS|FAIL expected-text
  local out rc=0
  out="$(preflight)" || rc=$?
  if [[ "$2" == "PASS" ]]; then
    [[ $rc -eq 0 ]] && echo "$out" | grep -q "AEF_DEPLOY_PREFLIGHT: PASS" && echo "$out" | grep -q "$3" \
      || { echo "preflight $1: expected PASS/$3, got: $out" >&2; exit 1; }
  else
    [[ $rc -ne 0 ]] && echo "$out" | grep -q "AEF_DEPLOY_PREFLIGHT: FAIL" && echo "$out" | grep -q "$3" \
      || { echo "preflight $1: expected FAIL/$3, got: $out" >&2; exit 1; }
  fi
}
record() { run -d "$PF" -c "INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('$1', '$2');" >/dev/null; }
run -d "$PF" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
run -d "$PF" -c "CREATE SCHEMA supabase_migrations; CREATE TABLE supabase_migrations.schema_migrations (version text PRIMARY KEY, name text, statements text[]);"
v=20260101000000
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  b="$(basename "$m" .sql)"
  [[ "$b" < "20260923000000" ]] || continue
  apply "$PF" "$m"; v=$((v + 1)); record "$v" "${b#*_}"
done
expect_preflight "production-like baseline" PASS "entitlement_subject_roles -> ive_memory_governance -> aef_persistence -> aef_hardening -> aef_sequence_privileges"
run -d "$PF" -c "UPDATE supabase_migrations.schema_migrations SET name = 'renamed' WHERE name = 'opportunity_knowledge_links';"
expect_preflight "missing predecessor" FAIL "predecessor migration opportunity_knowledge_links missing"
run -d "$PF" -c "UPDATE supabase_migrations.schema_migrations SET name = 'opportunity_knowledge_links' WHERE name = 'renamed';"
record 20269999000001 aef_persistence
expect_preflight "history without objects" FAIL "aef_persistence is in the history but its objects are absent"
run -d "$PF" -c "DELETE FROM supabase_migrations.schema_migrations WHERE version = '20269999000001';"
run -d "$PF" -c "CREATE TABLE public.aef_stray (id int);"
expect_preflight "stray aef object" FAIL "aef_\* objects exist without aef_persistence"
run -d "$PF" -c "DROP TABLE public.aef_stray;"
run -d "$PF" -c "ALTER TABLE public.projects ALTER COLUMN user_id DROP NOT NULL;"
expect_preflight "projects drift" FAIL "public.projects(id uuid, user_id uuid NOT NULL) not as expected"
run -d "$PF" -c "ALTER TABLE public.projects ALTER COLUMN user_id SET NOT NULL;"
apply "$PF" "$ROOT/supabase/migrations/20260923000000_entitlement_subject_roles.sql"; record 20269999000002 entitlement_subject_roles
apply "$PF" "$ROOT/supabase/migrations/20260924000000_ive_memory_governance.sql"; record 20269999000003 ive_memory_governance
apply "$PF" "$ROOT/supabase/migrations/20260925000000_aef_persistence.sql"; record 20269999000004 aef_persistence
apply "$PF" "$ROOT/supabase/migrations/$HARDENING_MIGRATION"; record 20269999000005 aef_hardening
expect_preflight "sequence exposed (stopped before 20260927)" FAIL "AEF audit sequence is writable by an API role"
record 20269999000009 aef_sequence_privileges
expect_preflight "history claims 20260927 but sequence still exposed" FAIL "aef_sequence_privileges is in the history but its objects are absent"
run -d "$PF" -c "DELETE FROM supabase_migrations.schema_migrations WHERE version = '20269999000009';"
apply "$PF" "$ROOT/supabase/migrations/$SEQUENCE_MIGRATION"; record 20269999000006 aef_sequence_privileges
expect_preflight "fully applied chain" PASS "remaining, in order: (none)"
run -d "$PF" -c "DELETE FROM supabase_migrations.schema_migrations WHERE name = 'entitlement_subject_roles';"
expect_preflight "order: hardening without entitlement" FAIL "order: aef_hardening applied without entitlement_subject_roles"
# The preflight is read-only by construction: READ ONLY transaction, rolled
# back, and no write statement at all.
grep -q "BEGIN TRANSACTION READ ONLY" "$PREFLIGHT" && grep -q "^ROLLBACK;" "$PREFLIGHT" \
  || { echo "preflight is not wrapped in a READ ONLY transaction" >&2; exit 1; }
if grep -qiE "^[[:space:]]*(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|GRANT|REVOKE|TRUNCATE|COMMIT)[[:space:]]" "$PREFLIGHT"; then
  echo "preflight contains a write statement" >&2; exit 1
fi
echo "AEF_DEPLOY_PREFLIGHT_TESTS: PASS"

# SECURITY DEFINER boundary (P06/P07): no AEF code calls the pre-existing
# definer functions for authority.
if grep -rnE "get_current_user_role|handle_new_user|is_admin_user|validate_asset_" "$ROOT"/aef "$ROOT"/supabase/migrations/2026092[5-9]*.sql; then
  echo "AEF references a pre-existing definer function (P06/P07)" >&2; exit 1
fi
echo "AEF_DEFINER_BOUNDARY: PASS"

# P05: every AEF migration declares its real dependencies up front.
for m in "$ROOT"/supabase/migrations/2026092[5-9]*_aef_*.sql; do
  grep -q "AEF_PRECONDITION" "$m" || { echo "$(basename "$m") has no AEF_PRECONDITION guard" >&2; exit 1; }
done
echo "AEF_MIGRATION_PRECONDITIONS: PASS"
