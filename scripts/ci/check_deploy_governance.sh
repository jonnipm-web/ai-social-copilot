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
# Check 5 (IVE-COMMERCIAL-AUTH-01, narrowed by IV-SECURITY-REMEDIATION-03):
# no function on the deploy allowlist may carry --no-verify-jwt, EXCEPT
# the single, explicit, named exception(s) below. Before AUTH-01, 15
# Groq-dependent functions deployed with verify_jwt=false and no internal
# auth -- any anonymous caller could consume the shared, paid
# GROQ_API_KEY directly. All Groq-dependent functions now require a real
# authenticated user (platform verify_jwt=true, enforced code-side by
# supabase/functions/_shared/auth.ts's resolveAuthenticatedUser(), which
# fails closed even against the anon/publishable key).
#
# IVE-COMMERCIAL-BILLING-01 later added one deliberate, reviewed
# exception: stripe-webhook. Stripe calls it directly and never sends a
# Supabase-issued JWT, so verify_jwt=true would reject every legitimate
# delivery -- its real trust boundary is the manual HMAC-SHA256
# Stripe-Signature verification in supabase/functions/_shared/stripe.ts,
# checked before any JSON parsing or DB write. That mission updated
# .github/deploy-allowlist.tsv and supabase/config.toml but never taught
# this check about the exception, so it has failed on every run since --
# a real governance defect, unrelated to any later mission, fixed here
# (IV-SECURITY-REMEDIATION-03).
#
# This exception list is intentionally a single hardcoded name, not a
# pattern, a wildcard, or anything read from an unreviewed input --
# adding to it requires editing this script in a reviewed PR, the same
# as any other invariant here. It is NOT a blanket allowance: every name
# below is cross-checked against BOTH .github/deploy-allowlist.tsv AND
# supabase/config.toml, in both directions, so the two files can never
# silently drift apart, and no other function -- including a
# similarly-named one, a future one, or ive-agent-runner -- can ever
# reuse it.
# ---------------------------------------------------------------------
ALLOWLIST="$REPO_ROOT/.github/deploy-allowlist.tsv"
CONFIG_TOML="$REPO_ROOT/supabase/config.toml"
NO_VERIFY_JWT_EXCEPTIONS=("stripe-webhook")

is_allowed_exception() {
  local candidate="$1"
  local allowed
  for allowed in "${NO_VERIFY_JWT_EXCEPTIONS[@]}"; do
    [ "$candidate" = "$allowed" ] && return 0
  done
  return 1
}

if [ -f "$ALLOWLIST" ]; then
  while IFS=$'\t' read -r name jwt_flag || [ -n "${name:-}" ]; do
    name="${name%$'\r'}"
    jwt_flag="${jwt_flag%$'\r'}"
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    if [ -n "${jwt_flag:-}" ]; then
      if ! is_allowed_exception "$name"; then
        fail "'$name' carries a jwt_flag ('$jwt_flag') in $ALLOWLIST but is not on the explicit no-verify-jwt exception list (${NO_VERIFY_JWT_EXCEPTIONS[*]}) -- IVE-COMMERCIAL-AUTH-01 requires verify_jwt=true for every function not explicitly, individually exempted here"
      elif [ "$jwt_flag" != "--no-verify-jwt" ]; then
        fail "'$name' is an approved no-verify-jwt exception but carries an unexpected flag value ('$jwt_flag') in $ALLOWLIST -- expected exactly '--no-verify-jwt'"
      fi
    fi
  done < "$ALLOWLIST"
else
  fail "$ALLOWLIST does not exist -- cannot verify the no-verify-jwt invariant at all; treat a missing allowlist as a governance failure, not a pass"
fi

# Reverse direction: every declared exception must actually be present,
# with the exact expected flag, in BOTH the allowlist and config.toml --
# catches silent drift (e.g. the exception quietly dropped from one file
# but not the other) that a one-directional check would miss. Both files
# are REQUIRED to exist for this to be checkable at all -- a missing file
# fails closed (a prior version of this check silently skipped a missing
# file instead, which a Codex adversarial review correctly flagged as a
# fail-open gap, IV-SECURITY-REMEDIATION-03).
if [ ! -f "$CONFIG_TOML" ]; then
  fail "$CONFIG_TOML does not exist -- cannot verify allowlist/config.toml consistency for the no-verify-jwt exception(s)"
fi
for exception in "${NO_VERIFY_JWT_EXCEPTIONS[@]}"; do
  if [ -f "$ALLOWLIST" ] && ! grep -qP "^${exception}\t--no-verify-jwt\r?$" "$ALLOWLIST"; then
    fail "'$exception' is declared as a no-verify-jwt exception in $0 but is missing (or has the wrong flag) in $ALLOWLIST"
  fi
  if [ -f "$CONFIG_TOML" ]; then
    # Strip full-line comments before matching -- a commented-out
    # 'verify_jwt = false' must not count as the real setting (Codex
    # adversarial review, IV-SECURITY-REMEDIATION-03).
    if ! grep -q "^\[functions\.${exception}\]$" "$CONFIG_TOML"; then
      fail "'$exception' is declared as a no-verify-jwt exception in $0 but has no [functions.${exception}] section in $CONFIG_TOML"
    elif ! awk -v sec="[functions.${exception}]" '
      /^[[:space:]]*#/ { next }
      $0 == sec { found=1; next }
      found && /^\[/ { found=0 }
      found && /verify_jwt[[:space:]]*=[[:space:]]*false/ { ok=1 }
      END { exit ok ? 0 : 1 }
    ' "$CONFIG_TOML"; then
      fail "'$exception' has a [functions.${exception}] section in $CONFIG_TOML but it does not set verify_jwt = false (or only sets it in a commented-out line) -- allowlist/config.toml drift"
    fi
  fi
done

if [ "$FAIL" = "1" ]; then
  echo "" >&2
  echo "One or more deploy-governance invariants were violated. See GOVERNANCE FAILURE lines above." >&2
  exit 1
fi

echo "OK: deploy governance invariants hold (single canonical deploy route, no unsafe context-copilot JWT deploy, no ive-agent-runner deploy path, no bulk/wildcard deploy loop, no --no-verify-jwt outside the explicit exception list (${NO_VERIFY_JWT_EXCEPTIONS[*]}), allowlist/config.toml in sync for every exception)."
