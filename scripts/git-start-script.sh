#!/bin/bash
# ~/.git-scripts/git-start.sh
# Create a typed GitFlow branch from the correct base

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
TYPE=""
NAME=""
for arg in "$@"; do
  case "$arg" in
    --json) JSON=true ;;
    -*)     emit_error "unknown_flag" "Unknown flag: $arg" ;;
    *)
      if   [ -z "$TYPE" ]; then TYPE="$arg"
      elif [ -z "$NAME" ]; then NAME="$arg"
      else emit_error "too_many_args" "Too many arguments. Usage: git start <type> <name> [--json]"
      fi
      ;;
  esac
done

if [ -z "$NAME" ]; then
  emit_error "usage" "Usage: git start <type> <name> [--json]. Example: git start feature 42_foo"
fi

# ─── Detect main branch ─────────────────────────────────────────
if git show-ref --verify --quiet refs/heads/main; then
  MAIN_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
  MAIN_BRANCH="master"
else
  emit_error "no_main_branch" "Neither 'main' nor 'master' branch found."
fi

# ─── Resolve base ───────────────────────────────────────────────
if [ "$TYPE" = "hotfix" ] || [ "$TYPE" = "support" ]; then
  BASE="$MAIN_BRANCH"
else
  BASE="develop"
fi

if [ "$TYPE" != "support" ] && ! git show-ref --verify --quiet refs/heads/develop; then
  emit_error "develop_missing" "'develop' branch does not exist. Run first: git init-flow"
fi

# ─── Create branch ──────────────────────────────────────────────
if [ "$JSON" = true ]; then
  git checkout "$BASE" >/dev/null 2>&1 \
    || emit_error "checkout_failed" "Could not checkout $BASE"
  git pull origin "$BASE" >/dev/null 2>&1 \
    || emit_error "pull_failed" "Could not pull from origin/$BASE"
  git checkout -b "$TYPE/$NAME" >/dev/null 2>&1 \
    || emit_error "branch_create_failed" "Could not create branch $TYPE/$NAME"
else
  git checkout "$BASE" && git pull origin "$BASE"
  git checkout -b "$TYPE/$NAME"
fi

# ─── Output ─────────────────────────────────────────────────────
if [ "$JSON" = true ]; then
  printf '{"status":"ok","branch":"%s","base":"%s"}\n' "$TYPE/$NAME" "$BASE"
else
  printf '✅ Branch %s created from %s\n' "$TYPE/$NAME" "$BASE"
fi
