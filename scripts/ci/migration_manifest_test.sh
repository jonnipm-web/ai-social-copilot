#!/usr/bin/env bash
# F-01 adversarial tests for scripts/ci/migration_manifest.sh
# (IV-IVE-AEF-RUNTIME-INTEGRATION-01). Works on temporary COPIES only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="$ROOT/scripts/ci/migration_manifest.sh"
PREFLIGHT="$ROOT/supabase/preflight/aef_deploy_preflight.sql"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fresh() {
  rm -rf "$WORK/m" "$WORK/manifest.tsv"
  mkdir -p "$WORK/m"
  cp "$ROOT"/supabase/migrations/*.sql "$WORK/m/"
  cp "$ROOT/supabase/migration_manifest.tsv" "$WORK/manifest.tsv"
}
run() { MIGRATIONS_DIR="$WORK/m" MANIFEST="$WORK/manifest.tsv" bash "$TOOL" "$@" 2>&1; }
expect_pass() { local out; out="$(run --check)" || { echo "F01 $1: expected PASS, got: $out" >&2; exit 1; }; }
expect_fail() {  # label expected-text
  local out
  if out="$(run --check)"; then echo "F01 $1: expected FAIL, got PASS" >&2; exit 1; fi
  echo "$out" | grep -qF "$2" || { echo "F01 $1: unexpected failure: $out" >&2; exit 1; }
}
LAB_FILE="20260925000000_aef_persistence.sql"
APPLIED_FILE="20260918000000_ai_quota_idempotency.sql"

fresh; expect_pass "same name + same content"
fresh; printf '\n-- a harmless-looking edit\n' >> "$WORK/m/$LAB_FILE"; expect_fail "same name + changed content (LAB)" "content changed for LAB migration $LAB_FILE"
fresh; sed -i 's/SECURITY DEFINER/SECURITY INVOKER/' "$WORK/m/$APPLIED_FILE"; expect_fail "same name + changed content (APPLIED)" "content changed for APPLIED_PRODUCTION migration $APPLIED_FILE"
fresh; sed -i 's/$/\r/' "$WORK/m/$LAB_FILE"; expect_pass "CRLF-only difference is canonicalized"
fresh; mv "$WORK/m/$LAB_FILE" "$WORK/m/20260925000000_aef_persistence_v2.sql"; expect_fail "renamed migration" "manifest entry without file (deleted or renamed): $LAB_FILE"
fresh; rm "$WORK/m/$APPLIED_FILE"; expect_fail "deleted migration" "manifest entry without file"
fresh; rm "$WORK/manifest.tsv"; expect_fail "missing manifest" "manifest missing"
fresh; printf '# only comments\n' > "$WORK/manifest.tsv"; expect_fail "empty manifest" "manifest is empty"
fresh; row="$(grep "$LAB_FILE" "$WORK/manifest.tsv")"; printf '%s\n' "$row" >> "$WORK/manifest.tsv"; expect_fail "duplicate manifest entry" "duplicate manifest entry: $LAB_FILE"
fresh; printf -- '-- new\nSELECT 1;\n' > "$WORK/m/20260930000000_unexpected.sql"; expect_fail "unexpected migration" "migration not in manifest (unexpected or renamed): 20260930000000_unexpected.sql"
fresh; sed -i "s/\tLAB$/\tSHIPPED/" "$WORK/manifest.tsv"; expect_fail "unknown status" "unknown status 'SHIPPED'"
fresh; sed -i "0,/\tAPPLIED_PRODUCTION$/s//\tAPPLIED_PRODUCTION\textra/" "$WORK/manifest.tsv"; expect_fail "malformed row" "malformed row"
fresh; sed -i "s/^\(${LAB_FILE}\)\t[0-9a-f]*/\1\tdeadbeef/" "$WORK/manifest.tsv"; expect_fail "malformed digest" "malformed digest"
# --write refuses to launder a changed APPLIED_PRODUCTION migration, and never drops a vanished one.
fresh; printf '\n-- edit\n' >> "$WORK/m/$APPLIED_FILE"
if run --write >/dev/null; then echo "F01 write: laundered an APPLIED_PRODUCTION change" >&2; exit 1; fi
fresh; rm "$WORK/m/$LAB_FILE"
if run --write >/dev/null; then echo "F01 write: silently dropped a vanished migration" >&2; exit 1; fi
# --write accepts a LAB change (visible in the diff) and the result checks clean.
fresh; printf '\n-- lab edit\n' >> "$WORK/m/$LAB_FILE"; run --write >/dev/null; expect_pass "LAB change re-recorded"

# The preflight's history reconciliation matches the manifest exactly:
# APPLIED_PRODUCTION = its predecessors, LAB = its chain (same order).
applied="$(awk -F'\t' '$3=="APPLIED_PRODUCTION"{sub(/^[0-9]+_/,"",$1); sub(/\.sql$/,"",$1); printf "%s ", $1}' "$ROOT/supabase/migration_manifest.tsv")"
lab="$(awk -F'\t' '$3=="LAB"{sub(/^[0-9]+_/,"",$1); sub(/\.sql$/,"",$1); printf "%s ", $1}' "$ROOT/supabase/migration_manifest.tsv")"
pre="$(tr -d '\n' < "$PREFLIGHT" | grep -o "predecessors text\[\] := ARRAY\[[^]]*\]" | grep -o "'[a-z0-9_]*'" | tr -d "'" | tr '\n' ' ')"
chain="$(tr -d '\n' < "$PREFLIGHT" | grep -o "chain text\[\] := ARRAY\[[^]]*\]" | grep -o "'[a-z0-9_]*'" | tr -d "'" | tr '\n' ' ')"
[[ "$applied" == "$pre" ]] || { echo "F01: manifest APPLIED_PRODUCTION ($applied) != preflight predecessors ($pre)" >&2; exit 1; }
[[ "$lab" == "$chain" ]] || { echo "F01: manifest LAB ($lab) != preflight chain ($chain)" >&2; exit 1; }
echo "MIGRATION_MANIFEST_TESTS: PASS"
