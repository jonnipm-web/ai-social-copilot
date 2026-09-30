#!/usr/bin/env bash
# F-03 static lint (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
#
# Any Lab migration (status LAB in supabase/migration_manifest.tsv, or a file
# not yet in it) that creates a sequence — identity column, serial type or
# CREATE SEQUENCE — and touches aef_* objects must carry the canonical
# deny-by-default block for AEF sequences:
#   REVOKE ALL ON SEQUENCE %s FROM PUBLIC, anon, authenticated, service_role
# (see 20260925 / 20260927). This is the author-time check; the catalog scan
# (supabase/tests/aef_sequence_catalog_scan.sql) is the database-time proof.
# Env overrides (tests): MIGRATIONS_DIR, MANIFEST.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-$ROOT/supabase/migrations}"
MANIFEST="${MANIFEST:-$ROOT/supabase/migration_manifest.tsv}"
MARKER="REVOKE ALL ON SEQUENCE %s FROM PUBLIC, anon, authenticated, service_role"

applied() { [[ -f "$MANIFEST" ]] && awk -F'\t' -v n="$1" '$1==n && $3=="APPLIED_PRODUCTION"{f=1} END{exit !f}' "$MANIFEST"; }

bad=0
for f in "$MIGRATIONS_DIR"/*.sql; do
  [[ -e "$f" ]] || continue
  name="$(basename "$f")"
  applied "$name" && continue
  body="$(tr -d '\r' < "$f")"
  if grep -qiE 'GENERATED[[:space:]]+(ALWAYS|BY[[:space:]]+DEFAULT)[[:space:]]+AS[[:space:]]+IDENTITY|[[:space:]](big|small)?serial([[:space:]]|,|\))|CREATE[[:space:]]+SEQUENCE' <<< "$body" \
     && grep -qE 'aef_' <<< "$body"; then
    if ! grep -qF "$MARKER" <<< "$body"; then
      echo "AEF_SEQUENCE_LINT: FAIL — $name creates a sequence for aef_* objects without the deny-by-default REVOKE block" >&2
      bad=1
    fi
  fi
done
[[ $bad -eq 0 ]] || exit 1
echo "AEF_SEQUENCE_LINT: PASS"
