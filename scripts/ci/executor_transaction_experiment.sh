#!/usr/bin/env bash
# Transactional executor experiment (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
# LOCAL / CI disposable PostgreSQL ONLY — never a real project.
#
# Question: when a migration file fails half-way, does the executor leave
# partial DDL behind? A canary migration runs DDL A → DDL B → a deliberate
# error → DDL C. ATOMIC means A, B and C are all absent afterwards and no
# history row is recorded.
#
# Executors:
#   E0 psql -f (plain)               CONTROL: must be NOT_ATOMIC. If the
#                                     checker reports it ATOMIC, the checker
#                                     is broken and the whole experiment
#                                     FAILS (no false PASS).
#   E1 psql --single-transaction -f  the runbook's mode
#   E2 supabase db push --db-url     the Supabase CLI (set SUPABASE_CLI, e.g.
#                                     "npx -y supabase@2.118.0"); single file
#   E3 supabase db push, two files   first OK, second fails: per-file
#                                     atomicity (the first stays applied)
#   MCP apply_migration              cannot run against a local database:
#                                     NOT_VERIFIED here.
# Env: PGHOST (127.0.0.1|localhost), PGPORT, PGUSER, optional PGPASSWORD, PSQL, SUPABASE_CLI.
set -euo pipefail

PSQL="${PSQL:-psql}"
HOST="${PGHOST:-127.0.0.1}"
case "$HOST" in
  127.0.0.1|localhost) ;;
  *) echo "refusing to run against non-local host '$HOST'" >&2; exit 2 ;;
esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
run() { "$PSQL" -h "$HOST" -v ON_ERROR_STOP=1 -q "$@"; }
if [[ "$(run -d postgres -tA -c "SELECT (SELECT count(*) FROM pg_roles WHERE rolname = 'authenticator') + (SELECT count(*) FROM pg_namespace WHERE nspname IN ('storage', 'supabase_migrations'));")" != "0" ]]; then
  echo "refusing: the target looks like a real Supabase project" >&2; exit 2
fi
# shellcheck source=lib_disposable.sh
source "$ROOT/scripts/ci/lib_disposable.sh"
dispo_init aefex
WORK="$(mktemp -d)"

CANARY=$'CREATE TABLE public.canary_a (id int);\nCREATE TABLE public.canary_b (id int);\nSELECT 1 / 0;\nCREATE TABLE public.canary_c (id int);\n'
OKFILE=$'CREATE TABLE public.canary_ok (id int);\n'

# Prints "A B C" presence, e.g. "yes yes no".
presence() {
  run -d "$1" -tA -c "SELECT concat_ws(' ', CASE WHEN to_regclass('public.canary_a') IS NULL THEN 'no' ELSE 'yes' END,
                                       CASE WHEN to_regclass('public.canary_b') IS NULL THEN 'no' ELSE 'yes' END,
                                       CASE WHEN to_regclass('public.canary_c') IS NULL THEN 'no' ELSE 'yes' END);"
}
verdict() {  # label db
  local p; p="$(presence "$2")"
  if [[ "$p" == "no no no" ]]; then echo "$1: ATOMIC ($p)"; else echo "$1: NOT_ATOMIC (A B C = $p)"; fi
}
url() { printf 'postgresql://%s%s@%s:%s/%s?sslmode=disable' "${PGUSER:-postgres}" "${PGPASSWORD:+:$PGPASSWORD}" "$HOST" "${PGPORT:-5432}" "$1"; }

printf '%s' "$CANARY" > "$WORK/canary.sql"

# E0 control — plain psql must NOT be atomic.
dispo_db e0; E0="$DISPO_LAST"
run -d "$E0" -f "$WORK/canary.sql" >/dev/null 2>&1 && { echo "E0: the canary did not fail" >&2; exit 1; }
r0="$(verdict "EXECUTOR_PSQL_PLAIN" "$E0")"; echo "$r0"
[[ "$r0" == *"NOT_ATOMIC (A B C = yes yes no)"* ]] || { echo "CONTROL FAILED: the checker cannot see partial DDL — no verdict is trustworthy" >&2; exit 1; }

# E1 — psql --single-transaction.
dispo_db e1; E1="$DISPO_LAST"
run -d "$E1" -1 -f "$WORK/canary.sql" >/dev/null 2>&1 && { echo "E1: the canary did not fail" >&2; exit 1; }
r1="$(verdict "EXECUTOR_PSQL_SINGLE_TRANSACTION" "$E1")"; echo "$r1"
[[ "$r1" == *": ATOMIC"* ]] || { echo "E1: psql --single-transaction left partial DDL" >&2; exit 1; }

if [[ -n "${SUPABASE_CLI:-}" ]]; then
  ver="$($SUPABASE_CLI --version 2>/dev/null | tail -1)"
  # E2 — CLI, single failing file.
  dispo_db e2; E2="$DISPO_LAST"
  mkdir -p "$WORK/e2/supabase/migrations"
  printf '%s' "$CANARY" > "$WORK/e2/supabase/migrations/20990101000001_canary_fail.sql"
  if (cd "$WORK/e2" && echo y | $SUPABASE_CLI db push --db-url "$(url "$E2")" --workdir . --yes >"$WORK/e2.log" 2>&1); then
    echo "E2: db push reported success for a failing migration" >&2; cat "$WORK/e2.log" >&2; exit 1
  fi
  r2="$(verdict "EXECUTOR_SUPABASE_CLI_${ver}" "$E2")"; echo "$r2"
  hist="$(run -d "$E2" -tA -c "SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version = '20990101000001';" 2>/dev/null || echo 0)"
  echo "EXECUTOR_SUPABASE_CLI_${ver}_HISTORY_ROW_AFTER_FAILURE: $hist"
  # E3 — CLI, two files: the first succeeds, the second fails.
  dispo_db e3; E3="$DISPO_LAST"
  mkdir -p "$WORK/e3/supabase/migrations"
  printf '%s' "$OKFILE" > "$WORK/e3/supabase/migrations/20990101000000_canary_ok.sql"
  printf '%s' "$CANARY" > "$WORK/e3/supabase/migrations/20990101000001_canary_fail.sql"
  (cd "$WORK/e3" && echo y | $SUPABASE_CLI db push --db-url "$(url "$E3")" --workdir . --yes >"$WORK/e3.log" 2>&1) && { echo "E3: expected failure" >&2; exit 1; }
  ok="$(run -d "$E3" -tA -c "SELECT CASE WHEN to_regclass('public.canary_ok') IS NULL THEN 'no' ELSE 'yes' END;")"
  rows="$(run -d "$E3" -tA -c "SELECT string_agg(version || ':' || name || ':' || coalesce(array_length(statements, 1), 0), ',' ORDER BY version) FROM supabase_migrations.schema_migrations;")"
  r3="$(verdict "EXECUTOR_SUPABASE_CLI_${ver}_MULTI_FILE" "$E3")"; echo "$r3; first file applied: $ok; history: $rows"
  [[ "$r2" == *": ATOMIC"* && "$hist" == "0" ]] || echo "EXECUTOR_SUPABASE_CLI: NOT_ATOMIC — production deploy must stay BLOCKED for this executor" >&2

  # E4 — CLI with a REAL migration (20260926, DO blocks, ~1300 lines) failing
  # late (a conflicting function): nothing of it may survive.
  dispo_db e4; E4="$DISPO_LAST"
  run -d "$E4" -f "$ROOT/supabase/tests/support/supabase_stubs.sql" >/dev/null
  for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
    [[ "$(basename "$m")" < "20260926000000" ]] && run -d "$E4" -1 -c "SET search_path = public, extensions;" -f "$m" >/dev/null
  done
  run -d "$E4" -c "CREATE FUNCTION public.aef_purge(p jsonb) RETURNS int LANGUAGE sql AS 'SELECT 1';" >/dev/null
  mkdir -p "$WORK/e4/supabase/migrations"
  cp "$ROOT/supabase/migrations/20260926000000_aef_hardening.sql" "$WORK/e4/supabase/migrations/"
  before="$(run -d "$E4" -tA -c "SELECT count(*) FROM pg_class WHERE relnamespace = 'public'::regnamespace;")"
  (cd "$WORK/e4" && echo y | $SUPABASE_CLI db push --db-url "$(url "$E4")" --workdir . --yes --include-all >"$WORK/e4.log" 2>&1) && { echo "E4: expected failure" >&2; exit 1; }
  after="$(run -d "$E4" -tA -c "SELECT count(*) FROM pg_class WHERE relnamespace = 'public'::regnamespace;")"
  gone="$(run -d "$E4" -tA -c "SELECT to_regclass('public.aef_retention_policy') IS NULL;")"
  if [[ "$before" == "$after" && "$gone" == "t" ]]; then echo "EXECUTOR_SUPABASE_CLI_${ver}_REAL_MIGRATION_LATE_FAILURE: ATOMIC"; else echo "EXECUTOR_SUPABASE_CLI_${ver}_REAL_MIGRATION_LATE_FAILURE: NOT_ATOMIC ($before -> $after)"; fi

  # E5 — deploy-path rehearsal: a production-like history (apply-time
  # versions, as observed read-only in production) + CLI push of the chain.
  dispo_db e5; E5="$DISPO_LAST"
  run -d "$E5" -f "$ROOT/supabase/tests/support/supabase_stubs.sql" >/dev/null
  run -d "$E5" -c "CREATE SCHEMA supabase_migrations; CREATE TABLE supabase_migrations.schema_migrations (version text PRIMARY KEY, statements text[], name text);" >/dev/null
  v=20260907120000
  for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
    b="$(basename "$m" .sql)"; [[ "$b" < "20260923000000" ]] || continue
    run -d "$E5" -1 -c "SET search_path = public, extensions;" -f "$m" >/dev/null
    v=$((v + 7777)); run -d "$E5" -c "INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('$v', '${b#*_}');" >/dev/null
  done
  mkdir -p "$WORK/e5/supabase/migrations"
  cp "$ROOT"/supabase/migrations/2026092[3-7]*.sql "$WORK/e5/supabase/migrations/"
  if (cd "$WORK/e5" && echo y | $SUPABASE_CLI db push --db-url "$(url "$E5")" --workdir . --yes >"$WORK/e5.log" 2>&1); then
    echo "EXECUTOR_SUPABASE_CLI_${ver}_PRODUCTION_LIKE_HISTORY: APPLIED"
  else
    echo "EXECUTOR_SUPABASE_CLI_${ver}_PRODUCTION_LIKE_HISTORY: REFUSED — $(tr -d '' < "$WORK/e5.log" | grep -iE 'error|remote|version|repair' | head -2 | tr '
' ' ')"
  fi
else
  echo "EXECUTOR_SUPABASE_CLI: NOT_RUN (SUPABASE_CLI not set)"
fi
echo "EXECUTOR_SUPABASE_MCP_APPLY_MIGRATION: NOT_VERIFIED (remote-only executor; never exercised against production)"
rm -rf "$WORK"
echo "EXECUTOR_TRANSACTION_EXPERIMENT: DONE"
