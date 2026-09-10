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
# Check 1: zero tolerance for the literal 'supabase functions deploy'
# string anywhere in .github/workflows/. The canonical route
# (deploy-edge-functions.yml) never spells this out as one substring --
# it builds the argv from separate tokens via
# scripts/ci/resolve_deploy_selection.sh -- so a match here always means
# a second, hand-written deploy invocation exists somewhere it shouldn't.
# (deploy-show-01a.yml, the one historical exception this check used to
# carve out, was removed entirely in DG2 rather than left as inert text
# -- see that commit for why.)
# ---------------------------------------------------------------------
while IFS= read -r f; do
  fail "'$(basename "$f")' contains a live 'supabase functions deploy' invocation -- only deploy-edge-functions.yml (canonical, via scripts/ci/resolve_deploy_selection.sh) may deploy"
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

# ---------------------------------------------------------------------
# Check 5 (IVE-COMMERCIAL-AUTH-01): no function on the deploy allowlist
# may carry --no-verify-jwt. Before this mission, 15 Groq-dependent
# functions deployed with verify_jwt=false and no internal auth -- any
# anonymous caller could consume the shared, paid GROQ_API_KEY directly.
# All 16 functions now require a real authenticated user (platform
# verify_jwt=true, enforced code-side by
# supabase/functions/_shared/auth.ts's resolveAuthenticatedUser(), which
# fails closed even against the anon/publishable key). This check makes
# that a structural invariant, not a one-time fix: any future edit that
# reintroduces --no-verify-jwt anywhere in the allowlist fails CI.
# ---------------------------------------------------------------------
ALLOWLIST="$REPO_ROOT/.github/deploy-allowlist.tsv"
if [ -f "$ALLOWLIST" ]; then
  while IFS=$'\t' read -r name jwt_flag || [ -n "${name:-}" ]; do
    name="${name%$'\r'}"
    jwt_flag="${jwt_flag%$'\r'}"
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    if [ -n "${jwt_flag:-}" ]; then
      fail "'$name' carries a jwt_flag ('$jwt_flag') in $ALLOWLIST -- IVE-COMMERCIAL-AUTH-01 requires verify_jwt=true (no --no-verify-jwt) for every allowlisted function"
    fi
  done < "$ALLOWLIST"
fi

if [ "$FAIL" = "1" ]; then
  echo "" >&2
  echo "One or more deploy-governance invariants were violated. See GOVERNANCE FAILURE lines above." >&2
  exit 1
fi

echo "OK: deploy governance invariants hold (single canonical deploy route, no unsafe context-copilot JWT deploy, no ive-agent-runner deploy path, no bulk/wildcard deploy loop, no --no-verify-jwt anywhere in the allowlist)."
