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

run -d postgres -c "CREATE DATABASE $DB;"
trap 'run -d postgres -c "DROP DATABASE IF EXISTS $DB;" >/dev/null 2>&1 || true' EXIT

run -d "$DB" -f "$ROOT/supabase/tests/support/supabase_stubs.sql"
last=""
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  run -d "$DB" -c "SET search_path = public, extensions;" -f "$m" >/dev/null
  echo "applied $(basename "$m")"
  last="$m"
done
run -d "$DB" -c "SET search_path = public, extensions;" -f "$last" >/dev/null 2>&1
echo "re-applied $(basename "$last") (idempotency)"

out="$(run -d "$DB" -tA -f "$ROOT/supabase/tests/entitlement_subject_roles_rls_test.sql")"
echo "$out" | tail -1
echo "$out" | grep -qx 'SUBJECT_ROLES_RLS: PASS'

# IV-IMPACT-I1-PERSISTENCE-RLS-01 — Impact Lab RLS / invariants (migration 20260924010000).
out="$(run -d "$DB" -tA -f "$ROOT/supabase/tests/impact_lab_rls_test.sql")"
echo "$out" | tail -1
echo "$out" | grep -qE '^IMPACT_LAB_RLS: PASS [0-9]+ checks$'
