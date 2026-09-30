#!/usr/bin/env bash
# IV-MAIN-RECONCILIATION-01 — drift detection (RULE 8 / RULE 9).
#
# Detects structural drift between main and production source:
#   1. Warns if the current HEAD is not an ancestor of main (production not
#      traceable to main).
#   2. Warns if any DO_NOT_APPLY migration is referenced in a deploy workflow.
#   3. Lists LAB migrations as informational (not an error by itself).
#
# Usage: bash scripts/ci/drift_detection.sh [--remote]
#   --remote  fetch origin/main before checking (CI mode; default: local check)
#
# Exit codes: 0 = pass, 1 = hard violation, 2 = soft warning only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="${MANIFEST:-$ROOT/supabase/migration_manifest.tsv}"
REMOTE=0
[[ "${1:-}" == "--remote" ]] && REMOTE=1

HARD_FAIL=0
SOFT_WARN=0

fail()  { echo "DRIFT: FAIL — $*" >&2;  HARD_FAIL=1; }
warn()  { echo "DRIFT: WARN — $*" >&2;  SOFT_WARN=1; }
pass()  { echo "DRIFT: OK   — $*"; }
info()  { echo "DRIFT: INFO — $*"; }

# ── 1. Reachability: HEAD must be an ancestor of main ────────────────────────
if [[ $REMOTE -eq 1 ]]; then
  git fetch --quiet origin main 2>/dev/null || warn "could not fetch origin/main; skipping reachability check"
fi

if git rev-parse origin/main >/dev/null 2>&1; then
  MAIN_SHA=$(git rev-parse origin/main)
  HEAD_SHA=$(git rev-parse HEAD)
  if git merge-base --is-ancestor "$HEAD_SHA" "$MAIN_SHA" 2>/dev/null; then
    pass "HEAD ($HEAD_SHA) is an ancestor of main ($MAIN_SHA)"
  else
    # Check if main is ancestor of HEAD (i.e. HEAD is ahead of main — expected for a candidate branch)
    if git merge-base --is-ancestor "$MAIN_SHA" "$HEAD_SHA" 2>/dev/null; then
      info "HEAD is ahead of main (candidate branch in progress) — not an error"
    else
      fail "HEAD ($HEAD_SHA) diverges from main ($MAIN_SHA) — production would not be traceable to main"
    fi
  fi
else
  warn "origin/main not available for reachability check"
fi

# ── 2. DO_NOT_APPLY migrations must not appear in deploy workflows ────────────
if [[ -f "$MANIFEST" ]]; then
  while IFS=$'\t' read -r name _sum status; do
    [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
    [[ "$status" == "DO_NOT_APPLY" ]] || continue
    # Check if this migration name appears in any deploy workflow, script, or preflight SQL
    if grep -r \
         --include="*.yml" --include="*.yaml" --include="*.sh" --include="*.sql" \
         -l "$name" \
         "$ROOT/.github/workflows/" "$ROOT/scripts/" "$ROOT/supabase/preflight/" \
         2>/dev/null | grep -v "drift_detection" | grep -q .; then
      fail "DO_NOT_APPLY migration $name is referenced in a deploy workflow or preflight"
    else
      pass "DO_NOT_APPLY migration $name is not referenced in deploy workflows or preflight"
    fi
  done < "$MANIFEST"
else
  warn "migration manifest not found: $MANIFEST"
fi

# ── 3. LAB migrations inventory (informational) ───────────────────────────────
LAB_COUNT=0
if [[ -f "$MANIFEST" ]]; then
  while IFS=$'\t' read -r name _sum status; do
    [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
    [[ "$status" == "LAB" ]] && LAB_COUNT=$((LAB_COUNT + 1))
  done < "$MANIFEST"
  info "$LAB_COUNT LAB migration(s) present (not applied in production)"
fi

# ── Result ─────────────────────────────────────────────────────────────────────
echo ""
if [[ $HARD_FAIL -eq 1 ]]; then
  echo "DRIFT: RESULT=FAIL" >&2
  exit 1
elif [[ $SOFT_WARN -eq 1 ]]; then
  echo "DRIFT: RESULT=WARN"
  exit 2
else
  echo "DRIFT: RESULT=PASS"
  exit 0
fi
