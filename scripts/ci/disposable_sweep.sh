#!/usr/bin/env bash
# Reclaims disposable resources left behind when a run could not clean up
# (SIGKILL, host loss) — IV-IVE-AEF-RUNTIME-INTEGRATION-01, Codex RG3-03.
#
#   disposable_sweep.sh --prefix <aef…> --older-than-minutes <N> [--apply]
#
# Dry-run by default. With --apply it drops ONLY a database/role that:
#   - is named <prefix>_<run-id>_<suffix>, and
#   - carries the library's ownership marker 'aef-disposable:<run-id>' for
#     that SAME run id (so the marker was set by scripts/ci/lib_disposable.sh
#     for exactly this resource), and
#   - is older than N minutes (the run id starts with the creation epoch).
# Anything else with the prefix (unmarked, or marked for another run id) is
# reported and never dropped. LOCAL PostgreSQL only.
set -euo pipefail

PSQL="${PSQL:-psql}"
HOST="${PGHOST:-127.0.0.1}"
case "$HOST" in
  127.0.0.1|localhost) ;;
  *) echo "refusing to run against non-local host '$HOST'" >&2; exit 2 ;;
esac
run() { "$PSQL" -h "$HOST" -v ON_ERROR_STOP=1 -q "$@"; }

PREFIX=""; AGE=""; APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --older-than-minutes) AGE="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
[[ "$PREFIX" =~ ^aef[a-z]{1,8}$ ]] || { echo "--prefix must be a lib_disposable prefix (aef…)" >&2; exit 2; }
[[ "$AGE" =~ ^[0-9]+$ ]] || { echo "--older-than-minutes N required" >&2; exit 2; }
if [[ "$(run -d postgres -tA -c "SELECT (SELECT count(*) FROM pg_roles WHERE rolname = 'authenticator') + (SELECT count(*) FROM pg_namespace WHERE nspname IN ('storage', 'supabase_migrations'));")" != "0" ]]; then
  echo "refusing: the target looks like a real Supabase project" >&2; exit 2
fi
now="$(date +%s)"

sweep() {  # kind: database|role
  local kind="$1" q name mark runid epoch
  if [[ "$kind" == "database" ]]; then
    q="SELECT datname || '|' || coalesce(shobj_description(oid, 'pg_database'), '') FROM pg_database WHERE datname LIKE '${PREFIX}\\_%'"
  else
    q="SELECT rolname || '|' || coalesce(shobj_description(oid, 'pg_authid'), '') FROM pg_roles WHERE rolname LIKE '${PREFIX}\\_%'"
  fi
  while IFS='|' read -r name mark; do
    [[ -n "$name" ]] || continue
    mark="${mark%[[:cntrl:]]}"  # psql on Windows ends lines with CRLF
    runid="${mark#aef-disposable:}"
    if [[ "$mark" != aef-disposable:* || ! "$runid" =~ ^[0-9]{10}[0-9a-f]+$ || "$name" != "${PREFIX}_${runid}_"* ]]; then
      echo "SWEEP: KEEP $kind $name — no matching ownership marker (never dropped automatically)"
      continue
    fi
    epoch="${runid:0:10}"
    if (( now - epoch < AGE * 60 )); then
      echo "SWEEP: KEEP $kind $name — younger than $AGE min (its run may still be alive)"
      continue
    fi
    if [[ $APPLY -eq 1 ]]; then
      if [[ "$kind" == "database" ]]; then run -d postgres -c "DROP DATABASE IF EXISTS $name WITH (FORCE);" >/dev/null
      else run -d postgres -c "DROP ROLE IF EXISTS $name;" >/dev/null; fi
      echo "SWEEP: DROPPED $kind $name"
    else
      echo "SWEEP: WOULD DROP $kind $name"
    fi
  done < <(run -d postgres -tA -c "$q")
}
sweep database
sweep role
