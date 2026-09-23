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

# The AEF governance service end-to-end against a real database (concurrency,
# crash recovery, idempotency, forgery, reconciliation, retention, erasure).
# Needs Deno; skipping must be explicit (AEF_PG_INTEGRATION=skip), never silent.
AEF_PG_DB_NAME="${DB}_aef"
RB="${DB}_rb"
run -d postgres -c "CREATE DATABASE $AEF_PG_DB_NAME;"
run -d postgres -c "CREATE DATABASE $RB;"
trap 'for d in $DB $UPG $AEF_PG_DB_NAME $RB; do run -d postgres -c "DROP DATABASE IF EXISTS $d;" >/dev/null 2>&1 || true; done' EXIT
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
check "$RB" aef_hardening_test.sql 'AEF_HARDENING: PASS'
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
