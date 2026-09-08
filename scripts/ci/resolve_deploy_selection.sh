#!/usr/bin/env bash
# IVE-X4R-DG1 -- resolves ONE requested Edge Function name into the exact
# `supabase functions deploy` command that would run, or refuses and exits
# non-zero. Never calls `supabase`, never touches the network, needs no
# secrets -- pure text-processing over .github/deploy-allowlist.tsv, safe
# to run standalone in CI or locally to prove deploy-selection behavior
# without deploying anything. Sourced by
# .github/workflows/deploy-edge-functions.yml for the real deploy, and
# invoked directly by .github/workflows/deploy-selftest.yml (and locally)
# to prove the same logic with no production access.
#
# Usage: resolve_deploy_selection.sh <function_name> [project_ref]
# Output (stdout, only on ALLOW): the exact argv for `supabase functions
# deploy`, one arg per line, in order -- e.g.:
#   functions
#   deploy
#   analyze-website
#   --no-verify-jwt
#   --project-ref
#   nzngvbajrnruknpzzjbf
# On DENY: nothing on stdout, a "DENIED: <reason>" line on stderr, exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALLOWLIST="$REPO_ROOT/.github/deploy-allowlist.tsv"

FUNCTION_NAME="${1:-}"
PROJECT_REF="${2:-nzngvbajrnruknpzzjbf}"

deny() {
  echo "DENIED: $1" >&2
  exit 1
}

# 1. Must be non-empty.
[ -n "$FUNCTION_NAME" ] || deny "no function was explicitly selected"

# 2. Strict format check BEFORE any other use of the value -- blocks
#    wildcards ("*", "all", "supabase/functions/*"), path traversal,
#    flags disguised as a name ("--project-ref=evil"), and shell
#    metacharacters. Only lowercase letters, digits, and hyphens.
case "$FUNCTION_NAME" in
  *[!a-z0-9-]*|-*|*-|"")
    deny "'$FUNCTION_NAME' is not a valid function name (must match [a-z0-9]([a-z0-9-]*[a-z0-9])?)"
    ;;
esac

# 3. Explicit hard block, independent of the allowlist file's contents --
#    even if a future edit accidentally added this name to the allowlist,
#    this check still refuses it.
if [ "$FUNCTION_NAME" = "ive-agent-runner" ]; then
  deny "ive-agent-runner is FROZEN -- not deployable through this workflow (no future mission has authorized it)"
fi

# 4. Must exist in the repo-controlled allowlist (skip comments/blank lines).
[ -f "$ALLOWLIST" ] || deny "allowlist file missing: $ALLOWLIST"

MATCH_LINE=""
while IFS=$'\t' read -r name jwt_flag || [ -n "${name:-}" ]; do
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  if [ "$name" = "$FUNCTION_NAME" ]; then
    MATCH_LINE="found"
    JWT_FLAG="${jwt_flag:-}"
    break
  fi
done < "$ALLOWLIST"

[ "$MATCH_LINE" = "found" ] || deny "'$FUNCTION_NAME' is not on the deploy allowlist ($ALLOWLIST)"

# 5. Emit the exact, single-function argv. No loop, no wildcard, ever.
echo "functions"
echo "deploy"
echo "$FUNCTION_NAME"
if [ -n "${JWT_FLAG:-}" ]; then
  echo "$JWT_FLAG"
fi
echo "--project-ref"
echo "$PROJECT_REF"
