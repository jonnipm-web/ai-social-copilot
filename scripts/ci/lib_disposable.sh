# Disposable PostgreSQL resources with provable ownership
# (IV-IVE-AEF-RUNTIME-INTEGRATION-01, F-04). Sourced by the CI runners.
#
# Requires the caller's `run` function (psql wrapper: -v ON_ERROR_STOP=1 -q).
#
#   dispo_init <prefix>        unique run identity (time + pid + 48 random
#                              bits); installs the EXIT/INT/TERM cleanup
#   dispo_db <suffix>          CREATE DATABASE <prefix>_<run-id>_<suffix>;
#                              name in $DISPO_LAST
#   dispo_role <suffix>        CREATE ROLE … NOLOGIN; name in $DISPO_LAST
#   dispo_cleanup              drops ONLY what this run registered AND still
#                              carries this run's ownership marker
#
# Ownership rules:
#   - a resource is registered only after THIS run's CREATE succeeded — a
#     name collision fails the CREATE, so a foreign resource is never
#     registered and therefore never dropped;
#   - every created resource is marked (COMMENT … 'aef-disposable:<run-id>');
#     cleanup re-reads the marker and refuses to drop anything whose marker
#     is missing or different (e.g. recreated by someone else);
#   - roles are created together with their marker (one transaction);
#     CREATE DATABASE cannot run in a transaction, so a database killed
#     between CREATE and COMMENT stays unmarked and is NEVER dropped
#     automatically (scripts/ci/disposable_sweep.sh reports it);
#   - SIGKILL / host loss skip the traps: marked leftovers are reclaimed by
#     scripts/ci/disposable_sweep.sh (dry-run by default, age-bounded);
#   - cleanup failures are reported (DISPOSABLE_CLEANUP: FAILED …) and turn a
#     successful run into a failure; the original exit code is preserved
#     otherwise.

dispo_init() {
  local rnd
  rnd="$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
  DISPO_RUN_ID="$(date +%s)${$}${rnd}"
  DISPO_PREFIX="${1}_${DISPO_RUN_ID}"
  DISPO_MARK="aef-disposable:${DISPO_RUN_ID}"
  DISPO_DBS=()
  DISPO_ROLES=()
  DISPO_LAST=""
  trap 'dispo_on_exit' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

_dispo_name() {
  local name="${DISPO_PREFIX}_$1"
  if [[ ! "$name" =~ ^[a-z][a-z0-9_]{0,62}$ ]]; then
    echo "DISPOSABLE: invalid resource name '$name'" >&2
    return 1
  fi
  printf '%s' "$name"
}

dispo_db() {
  local name
  name="$(_dispo_name "$1")" || return 1
  if ! run -d postgres -c "CREATE DATABASE $name;" >/dev/null 2>&1; then
    echo "DISPOSABLE: refusing — database $name could not be created by this run (collision or error); nothing registered" >&2
    return 1
  fi
  DISPO_DBS+=("$name")
  run -d postgres -c "COMMENT ON DATABASE $name IS '$DISPO_MARK';" >/dev/null
  DISPO_LAST="$name"
}

dispo_role() {
  local name
  name="$(_dispo_name "$1")" || return 1
  # One statement string = one implicit transaction: the role never exists unmarked.
  if ! run -d postgres -c "CREATE ROLE $name NOLOGIN; COMMENT ON ROLE $name IS '$DISPO_MARK';" >/dev/null 2>&1; then
    echo "DISPOSABLE: refusing — role $name could not be created by this run (collision or error); nothing registered" >&2
    return 1
  fi
  DISPO_ROLES+=("$name")
  DISPO_LAST="$name"
}

# Prints: ABSENT | OURS | FOREIGN
_dispo_owner() {  # catalog name
  local cat="$1" name="$2" row
  if [[ "$cat" == "pg_database" ]]; then
    row="$(run -d postgres -tA -c "SELECT coalesce(shobj_description(oid, 'pg_database'), '') FROM pg_database WHERE datname = '$name';" 2>/dev/null)" || { echo "FOREIGN"; return; }
    [[ -z "$(run -d postgres -tA -c "SELECT 1 FROM pg_database WHERE datname = '$name';" 2>/dev/null)" ]] && { echo "ABSENT"; return; }
  else
    row="$(run -d postgres -tA -c "SELECT coalesce(shobj_description(oid, 'pg_authid'), '') FROM pg_roles WHERE rolname = '$name';" 2>/dev/null)" || { echo "FOREIGN"; return; }
    [[ -z "$(run -d postgres -tA -c "SELECT 1 FROM pg_roles WHERE rolname = '$name';" 2>/dev/null)" ]] && { echo "ABSENT"; return; }
  fi
  row="${row%[[:cntrl:]]}"  # psql on Windows ends lines with CRLF
  [[ "$row" == "$DISPO_MARK" ]] && echo "OURS" || echo "FOREIGN"
}

dispo_cleanup() {
  local rc=0 name owner
  for name in "${DISPO_DBS[@]}"; do
    owner="$(_dispo_owner pg_database "$name")"
    case "$owner" in
      ABSENT) ;;
      OURS) run -d postgres -c "DROP DATABASE IF EXISTS $name WITH (FORCE);" >/dev/null 2>&1 \
              || { echo "DISPOSABLE_CLEANUP: FAILED database $name" >&2; rc=1; } ;;
      *) echo "DISPOSABLE_CLEANUP: NOT dropping database $name — ownership marker missing or foreign" >&2; rc=1 ;;
    esac
  done
  for name in "${DISPO_ROLES[@]}"; do
    owner="$(_dispo_owner pg_authid "$name")"
    case "$owner" in
      ABSENT) ;;
      OURS) run -d postgres -c "DROP ROLE IF EXISTS $name;" >/dev/null 2>&1 \
              || { echo "DISPOSABLE_CLEANUP: FAILED role $name" >&2; rc=1; } ;;
      *) echo "DISPOSABLE_CLEANUP: NOT dropping role $name — ownership marker missing or foreign" >&2; rc=1 ;;
    esac
  done
  return $rc
}

dispo_on_exit() {
  local code=$?
  trap - EXIT
  if ! dispo_cleanup; then
    [[ $code -eq 0 ]] && code=1
  fi
  exit $code
}
