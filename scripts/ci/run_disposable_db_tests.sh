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

# IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01 — registry snapshots, lineage columns,
# registry conflicts, REGISTRY_RECORD evidence, RLS (migration 20260925010000).
out="$(run -d "$DB" -tA -f "$ROOT/supabase/tests/impact_registry_rls_test.sql")"
echo "$out" | tail -1
echo "$out" | grep -qE '^IMPACT_REGISTRY_RLS: PASS [0-9]+ checks$'

# IV-IMPACT-I3-EVIDENCE-COLLECTION-01 — artifacts, evidence candidates,
# human review → promotion, RLS (migration 20260926010000).
out="$(run -d "$DB" -tA -f "$ROOT/supabase/tests/impact_evidence_rls_test.sql")"
echo "$out" | tail -1
echo "$out" | grep -qE '^IMPACT_EVIDENCE_RLS: PASS [0-9]+ checks$'
# Codex I3F-01 / I3V-01: concurrent writers (artifact vs evidence; review vs promotion), two sessions, both orders.
out="$(bash "$ROOT/supabase/tests/impact_evidence_race_test.sh" "$PSQL" -h "$HOST" -v ON_ERROR_STOP=1 -q -d "$DB" 2>&1)" || { echo "$out"; exit 1; }
echo "$out" | tail -1
echo "$out" | grep -qx 'IMPACT_EVIDENCE_RACE: PASS 4 orders'

# IV-IMPACT-I4-VERIFICATION-DOSSIER-01 — atomic ingestion (I3F-03), dossier
# snapshot register, RLS (migration 20260927010000), then two-session races.
out="$(run -d "$DB" -tA -f "$ROOT/supabase/tests/impact_dossier_rls_test.sql")"
echo "$out" | tail -1
echo "$out" | grep -qE '^IMPACT_DOSSIER_RLS: PASS [0-9]+ checks$'
out="$(bash "$ROOT/supabase/tests/impact_dossier_race_test.sh" "$PSQL" -h "$HOST" -v ON_ERROR_STOP=1 -q -d "$DB" 2>&1)" || { echo "$out"; exit 1; }
echo "$out" | tail -1
echo "$out" | grep -qx 'IMPACT_DOSSIER_RACE: PASS 2 races'

# IV-IMPACT-I1 — engine → database parity: rows produced by the REAL Lab flow
# (engine + store row mappers) must satisfy every database invariant.
if command -v deno >/dev/null 2>&1; then
  rows="$(mktemp)"
  deno run --allow-read "$ROOT/supabase/tests/impact_lab_engine_rows.ts" > "$rows"
  out="$(run -d "$DB" -tA -f "$rows")"
  rm -f "$rows"
  echo "$out" | tail -1
  echo "$out" | grep -qE '^IMPACT_ENGINE_ROWS: PASS '
elif [ "${CI:-}" = "true" ]; then
  echo "deno is required in CI for the Impact engine-rows parity test" >&2; exit 1
else
  echo "IMPACT_ENGINE_ROWS: skipped locally (deno not on PATH)"
fi
