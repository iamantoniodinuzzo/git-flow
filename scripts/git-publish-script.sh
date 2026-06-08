#!/bin/bash
# ~/.git-scripts/git-publish.sh
# Push current branch to origin

set -euo pipefail

# ─── Helpers ────────────────────────────────────────────────────
JSON=false

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

emit_error() {
  if [ "$JSON" = true ]; then
    printf '{"status":"error","code":"%s","message":"%s"}\n' \
      "$1" "$(json_escape "$2")"
  else
    printf '❌ %s\n' "$2"
  fi
  exit 1
}

# ─── Flag parsing ────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --json) JSON=true ;;
    *)      emit_error "unknown_flag" "Unknown flag: $arg" ;;
  esac
done

# ─── Get current branch ─────────────────────────────────────────
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ -z "$BRANCH" ]; then
  emit_error "detached_head" "Not on a branch (detached HEAD). Checkout a branch first."
fi

# ─── Push ───────────────────────────────────────────────────────
if [ "$JSON" = true ]; then
  git push origin "$BRANCH" >/dev/null 2>&1 \
    || emit_error "push_failed" "Could not push $BRANCH to origin"
  printf '{"status":"ok","branch":"%s","remote":"origin"}\n' "$BRANCH"
else
  git push origin "$BRANCH" || emit_error "push_failed" "Could not push $BRANCH to origin"
  printf '🚀 Published\n'
fi
