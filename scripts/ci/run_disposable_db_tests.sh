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
