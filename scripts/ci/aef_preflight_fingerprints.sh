#!/usr/bin/env bash
# Maintainer tool (IV-AEF-PRE-RUNTIME-CLOSURE-01, Codex G2V-01 / G3V-03).
#
# Computes the expected structural fingerprints embedded in
# supabase/preflight/aef_deploy_preflight.sql by applying the repository
# migrations to a throwaway LOCAL database and running the preflight's own
# fingerprint query (extracted from the file, so there is one source of truth).
# With --write it updates the four constants in the preflight file.
#
# Never touches a real project: refuses any non-local host.
# Env: PGHOST (127.0.0.1|localhost), PGPORT, PGUSER, optional PSQL.
set -euo pipefail

PSQL="${PSQL:-psql}"
# Migrations are UTF-8 (function bodies carry non-ASCII comments): never let the
# client encoding default to the OS code page, or prosrc — and the preflight
# fingerprints — would differ from a UTF-8 production apply.
export PGCLIENTENCODING=UTF8
HOST="${PGHOST:-127.0.0.1}"
case "$HOST" in
  127.0.0.1|localhost) ;;
  *) echo "refusing to run against non-local host '$HOST'" >&2; exit 2 ;;
esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREFLIGHT="$ROOT/supabase/preflight/aef_deploy_preflight.sql"
DB="aef_fp_$$"
run() { PGOPTIONS="-c client_min_messages=warning" "$PSQL" -h "$HOST" -v ON_ERROR_STOP=1 -q "$@"; }
apply() { run -d "$DB" -1 -c "SET search_path = public, extensions;" -f "$1" >/dev/null; }

# Refuse a real Supabase project even when reached through a local address
# (port forward, hosts entry): those always carry the authenticator role and
# the storage / supabase_migrations schemas; a disposable cluster never does.
if [[ "$(run -d postgres -tA -c "SELECT (SELECT count(*) FROM pg_roles WHERE rolname = 'authenticator') + (SELECT count(*) FROM pg_namespace WHERE nspname IN ('storage', 'supabase_migrations'));")" != "0" ]]; then
  echo "refusing: the target looks like a real Supabase project" >&2; exit 2
fi
# CREATE fails (and nothing is dropped: the trap is set after it) if the name exists.
run -d postgres -c "CREATE DATABASE $DB;"
trap 'run -d postgres -c "DROP DATABASE IF EXISTS $DB;" >/dev/null 2>&1 || true' EXIT

FP_SQL="$(awk '/fp_sql constant text := \$fp\$/{f=1; next} /^ *\$fp\$;/{f=0} f' "$PREFLIGHT")"
[[ -n "$FP_SQL" ]] || { echo "fingerprint query not found in the preflight" >&2; exit 1; }
fp() {  # tables-sql pattern cols-sql  (the table list is materialized first: EXECUTE takes no subquery)
  run -d "$DB" -tA <<SQL | tail -1
SET search_path = pg_catalog;
SELECT ($1)::text AS fp_tables \gset
PREPARE fp(text[], text, text[]) AS $FP_SQL;
EXECUTE fp(:'fp_tables'::text[], '$2', $3);
SQL
}
AEF_TABLES="SELECT coalesce(array_agg(c.relname::text), ARRAY[]::text[]) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p') AND left(c.relname, 4) = 'aef_'"
MEMORY_COLS="ARRAY['scope', 'origin', 'status', 'dedup_key', 'superseded_by', 'updated_at', 'expires_at']"

run -d "$DB" -f "$ROOT/supabase/tests/support/supabase_stubs.sql" >/dev/null
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  [[ "$(basename "$m")" < "20260926000000" ]] && apply "$m"
done
FP_ENTITLEMENT="$(fp "ARRAY['subject_roles']" 'subject\_roles%' 'NULL::text[]')"
FP_MEMORY="$(fp "ARRAY['business_memory']" 'business\_memory\_derive\_scope' "$MEMORY_COLS")"
FP_AEF_PERSISTENCE="$(fp "$AEF_TABLES" 'aef%' 'NULL::text[]')"
for m in $(ls "$ROOT"/supabase/migrations/*.sql | sort); do
  [[ "$(basename "$m")" > "20260926000000" || "$(basename "$m")" == 20260926000000* ]] && apply "$m"
done
FP_AEF_FULL="$(fp "$AEF_TABLES" 'aef%' 'NULL::text[]')"

echo "FP_ENTITLEMENT=$FP_ENTITLEMENT"
echo "FP_MEMORY=$FP_MEMORY"
echo "FP_AEF_PERSISTENCE=$FP_AEF_PERSISTENCE"
echo "FP_AEF_FULL=$FP_AEF_FULL"

if [[ "${1:-}" == "--write" ]]; then
  for k in ENTITLEMENT MEMORY AEF_PERSISTENCE AEF_FULL; do
    v="FP_$k"; lc="$(echo "$k" | tr 'A-Z' 'a-z')"
    sed -i -E "s/^(  fp_${lc} constant text := ')[^']*(';)/\1${!v}\2/" "$PREFLIGHT"
  done
  echo "preflight updated"
fi
