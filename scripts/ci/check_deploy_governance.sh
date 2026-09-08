#!/usr/bin/env bash
# IVE-X4R-DG2 -- static governance gate over .github/workflows/. Fails if
# a workflow reintroduces a deployment pattern DG2 closed: a second real
# `supabase functions deploy` route, --no-verify-jwt on context-copilot,
# ive-agent-runner deploy capability, or a bulk/wildcard deploy loop.
#
# Every allowed match below is an EXPLAINED exception, not a blanket
# suppression -- add a new one only with the same level of justification,
# never to silence a real regression. No production access, no secrets,
# safe to run anywhere.
#
# Usage: check_deploy_governance.sh   (run from anywhere; resolves repo root itself)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$REPO_ROOT/.github/workflows"

FAIL=0

fail() {
  echo "GOVERNANCE FAILURE: $1" >&2
  FAIL=1
}

# ---------------------------------------------------------------------
# Check 1: only one file may contain a real `supabase functions deploy`
# invocation -- the canonical route. deploy-show-01a.yml is a retired,
# trigger-disabled (`on: {}`) historical record of a past release gate;
# it is explicitly allowed to keep the text as a non-runnable artifact.
# ---------------------------------------------------------------------
ALLOWED_DEPLOY_FILES="deploy-edge-functions.yml deploy-show-01a.yml"
while IFS= read -r f; do
  base="$(basename "$f")"
  allowed=0
  for a in $ALLOWED_DEPLOY_FILES; do
    [ "$base" = "$a" ] && allowed=1
  done
  if [ "$allowed" != "1" ]; then
    fail "'$base' contains a live 'supabase functions deploy' invocation -- only deploy-edge-functions.yml (canonical) may deploy; deploy-show-01a.yml is the one documented, trigger-disabled historical exception"
  fi
done < <(grep -rl "supabase functions deploy" "$WORKFLOWS" 2>/dev/null || true)

# ---------------------------------------------------------------------
# Check 2: no workflow may combine a context-copilot deploy with
# --no-verify-jwt (context-copilot's canonical policy is verify_jwt=true,
# enforced by .github/deploy-allowlist.tsv). Checked as a 3-line proximity
# window so an unrelated mention of either token elsewhere in the same
# file (comments, other functions) does not false-positive.
# ---------------------------------------------------------------------
while IFS= read -r f; do
  if grep -A2 "functions deploy context-copilot" "$f" 2>/dev/null | grep -q -- "--no-verify-jwt"; then
    fail "'$(basename "$f")' deploys context-copilot with --no-verify-jwt -- contradicts canonical JWT policy"
  fi
done < <(grep -rl "functions deploy context-copilot" "$WORKFLOWS" 2>/dev/null || true)

# ---------------------------------------------------------------------
# Check 3: no workflow may contain a real deploy invocation for
# ive-agent-runner (frozen since X4A). The resolver's own hard block and
# its comments/test-case names legitimately mention the string without
# deploying it -- only flag an actual `functions deploy ive-agent-runner`
# shape.
# ---------------------------------------------------------------------
while IFS= read -r f; do
  fail "'$(basename "$f")' contains a real 'functions deploy ive-agent-runner' invocation -- ive-agent-runner must never be deployable through any workflow"
done < <(grep -rl "functions deploy ive-agent-runner" "$WORKFLOWS" 2>/dev/null || true)

# ---------------------------------------------------------------------
# Check 4: no bulk/wildcard/directory-loop deploy pattern
# (e.g. `for fn in supabase/functions/*/`). deploy-selftest.yml's own
# negative-test-input literal ('supabase/functions/*' as a string being
# fed to the resolver to prove it gets DENIED) is not a loop and is
# explicitly allowed.
# ---------------------------------------------------------------------
while IFS= read -r f; do
  base="$(basename "$f")"
  if [ "$base" = "deploy-selftest.yml" ]; then
    continue
  fi
  fail "'$base' contains a directory-loop deploy pattern ('for ... in supabase/functions/*/') -- bulk deploy is prohibited"
done < <(grep -rl "for .* in .*supabase/functions/\*" "$WORKFLOWS" 2>/dev/null || true)

if [ "$FAIL" = "1" ]; then
  echo "" >&2
  echo "One or more deploy-governance invariants were violated. See GOVERNANCE FAILURE lines above." >&2
  exit 1
fi

echo "OK: deploy governance invariants hold (single canonical deploy route, no unsafe context-copilot JWT deploy, no ive-agent-runner deploy path, no bulk/wildcard deploy loop)."
