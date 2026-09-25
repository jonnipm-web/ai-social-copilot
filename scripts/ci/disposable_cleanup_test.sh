#!/usr/bin/env bash
# F-04 adversarial tests for scripts/ci/lib_disposable.sh
# (IV-IVE-AEF-RUNTIME-INTEGRATION-01). LOCAL PostgreSQL only (same guards as
# the runner). Never touches a resource it did not create in this script.
# Env: PGHOST (127.0.0.1|localhost), PGPORT, PGUSER, optional PSQL.
set -euo pipefail

PSQL="${PSQL:-psql}"
HOST="${PGHOST:-127.0.0.1}"
case "$HOST" in
  127.0.0.1|localhost) ;;
  *) echo "refusing to run against non-local host '$HOST'" >&2; exit 2 ;;
esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/scripts/ci/lib_disposable.sh"
WORK="$(mktemp -d)"
run() { "$PSQL" -h "$HOST" -v ON_ERROR_STOP=1 -q "$@"; }
exists_db() { [[ -n "$(run -d postgres -tA -c "SELECT 1 FROM pg_database WHERE datname = '$1';")" ]]; }
exists_role() { [[ -n "$(run -d postgres -tA -c "SELECT 1 FROM pg_roles WHERE rolname = '$1';")" ]]; }
# Resources this test creates OUTSIDE the library (the "foreign" ones), removed at the end.
FOREIGN_DBS=(); FOREIGN_ROLES=()
cleanup_test() {
  for d in "${FOREIGN_DBS[@]}"; do run -d postgres -c "DROP DATABASE IF EXISTS $d WITH (FORCE);" >/dev/null 2>&1 || true; done
  for r in "${FOREIGN_ROLES[@]}"; do run -d postgres -c "DROP ROLE IF EXISTS $r;" >/dev/null 2>&1 || true; done
  rm -rf "$WORK"
}
trap cleanup_test EXIT

# A child "run" of the library: $1 = bash body executed after dispo_init.
child() {
  local script
  script="$(mktemp "$WORK/child.XXXXXX")"
  cat > "$script" <<EOF
set -euo pipefail
PSQL="$PSQL"; HOST="$HOST"
run() { "\$PSQL" -h "\$HOST" -v ON_ERROR_STOP=1 -q "\$@"; }
source "$LIB"
dispo_init aefct
$1
EOF
  bash "$script"
}
fail() { echo "F04 $*" >&2; exit 1; }

# 1. normal run: everything created is dropped
child 'dispo_db a; echo "$DISPO_LAST" > '"$WORK"'/n1; dispo_role r; echo "$DISPO_LAST" > '"$WORK"'/r1'
exists_db "$(cat "$WORK/n1")" && fail "normal run left its database"
exists_role "$(cat "$WORK/r1")" && fail "normal run left its role"

# 2. test failure: cleaned, exit code preserved
set +e; child 'dispo_db a; echo "$DISPO_LAST" > '"$WORK"'/n2; exit 3'; rc=$?; set -e
[[ $rc -eq 3 ]] || fail "test failure exit code not preserved ($rc)"
exists_db "$(cat "$WORK/n2")" && fail "failed run left its database"

# 3. process interruption (SIGTERM / SIGINT): cleaned
for sig in TERM INT; do
  set +e; child 'dispo_db a; echo "$DISPO_LAST" > '"$WORK"'/n3; kill -'"$sig"' $$; sleep 5'; rc=$?; set -e
  [[ $rc -ne 0 ]] || fail "SIG$sig run reported success"
  exists_db "$(cat "$WORK/n3")" && fail "SIG$sig left its database"
done

# 4. name collision: a pre-existing database with the exact name is NOT registered, NOT dropped
run -d postgres -c "CREATE DATABASE aefct_collide_x_a;"; FOREIGN_DBS+=(aefct_collide_x_a)
set +e; child 'DISPO_PREFIX=aefct_collide_x; dispo_db a'; rc=$?; set -e
[[ $rc -ne 0 ]] || fail "collision was not refused"
exists_db aefct_collide_x_a || fail "collision dropped a foreign database"

# 5. foreign database / role with the run's prefix (e.g. a bug registers it): never dropped
set +e
child 'run -d postgres -c "CREATE DATABASE ${DISPO_PREFIX}_foreign;"; echo "${DISPO_PREFIX}_foreign" > '"$WORK"'/f5; DISPO_DBS+=("${DISPO_PREFIX}_foreign");
       run -d postgres -c "CREATE ROLE ${DISPO_PREFIX}_frole NOLOGIN;"; echo "${DISPO_PREFIX}_frole" > '"$WORK"'/fr5; DISPO_ROLES+=("${DISPO_PREFIX}_frole")' 2> "$WORK/e5"
rc=$?; set -e
FOREIGN_DBS+=("$(cat "$WORK/f5")"); FOREIGN_ROLES+=("$(cat "$WORK/fr5")")
[[ $rc -ne 0 ]] || fail "refusing a foreign resource must fail the run"
exists_db "$(cat "$WORK/f5")" || fail "a foreign database with the same prefix was dropped"
exists_role "$(cat "$WORK/fr5")" || fail "a foreign role with the same prefix was dropped"
grep -q "NOT dropping database" "$WORK/e5" || fail "foreign database refusal not reported"

# 6. ownership marker tampered (resource re-marked by someone else): not dropped
set +e; child 'dispo_db a; echo "$DISPO_LAST" > '"$WORK"'/n6; run -d postgres -c "COMMENT ON DATABASE $DISPO_LAST IS '"'"'someone-else'"'"';"' 2> "$WORK/e6"; rc=$?; set -e
FOREIGN_DBS+=("$(cat "$WORK/n6")")
[[ $rc -ne 0 ]] || fail "tampered marker must fail the run"
exists_db "$(cat "$WORK/n6")" || fail "a re-marked database was dropped"

# 7. cleanup failure (role still owns objects elsewhere): reported, run fails, nothing else skipped
run -d postgres -c "CREATE DATABASE aefct_owner_host;"; FOREIGN_DBS+=(aefct_owner_host)
set +e
child 'dispo_db a; echo "$DISPO_LAST" > '"$WORK"'/n7; dispo_role r; echo "$DISPO_LAST" > '"$WORK"'/r7;
       run -d aefct_owner_host -c "CREATE TABLE t_$DISPO_RUN_ID (x int); ALTER TABLE t_$DISPO_RUN_ID OWNER TO $DISPO_LAST;"' 2> "$WORK/e7"
rc=$?; set -e
FOREIGN_ROLES+=("$(cat "$WORK/r7")")
[[ $rc -ne 0 ]] || fail "a cleanup failure must fail the run"
grep -q "DISPOSABLE_CLEANUP: FAILED role" "$WORK/e7" || fail "cleanup failure not reported"
exists_db "$(cat "$WORK/n7")" && fail "a cleanup failure skipped the other resources"
run -d aefct_owner_host -c "DROP OWNED BY $(cat "$WORK/r7");" >/dev/null

# 8. parallel identity generation: unique run ids and prefixes
for i in $(seq 1 30); do (child 'echo "$DISPO_PREFIX"' > "$WORK/id_$i") & done; wait
[[ "$(cat "$WORK"/id_* | sort -u | wc -l)" -eq 30 ]] || fail "run identities collided under parallel generation"

echo "DISPOSABLE_CLEANUP_TESTS: PASS"
