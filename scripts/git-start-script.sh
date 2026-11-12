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
USAGE="Usage: git start <type> <name> [--json] [--no-issue] [--worktree [<path>]]"
TYPE=""
NAME=""
WT_PATH_ARG=""
NO_ISSUE=false
WORKTREE=false
for arg in "$@"; do
  case "$arg" in
    --json)       JSON=true ;;
    --no-issue)   NO_ISSUE=true ;;
    --worktree)   WORKTREE=true ;;
    --worktree=*) WORKTREE=true; WT_PATH_ARG="${arg#--worktree=}" ;;
    -*)           emit_error "unknown_flag" "Unknown flag: $arg" ;;
    *)
      if   [ -z "$TYPE" ]; then TYPE="$arg"
      elif [ -z "$NAME" ]; then NAME="$arg"
      elif [ "$WORKTREE" = true ] && [ -z "$WT_PATH_ARG" ]; then WT_PATH_ARG="$arg"
      else emit_error "too_many_args" "Too many arguments. $USAGE"
      fi
      ;;
  esac
done

if [ -z "$NAME" ]; then
  emit_error "usage" "$USAGE. Example: git start feature 42_foo"
fi

# Warn (non-fatal) when a feature/bugfix name lacks the <issue#>_ prefix that
# git-commit.sh and git-finish.sh rely on for auto issue-ref detection (see
# issue #11). Scoped to feature/bugfix only — release/hotfix/support use
# version-style names (e.g. "1.2.0") with no issue number by design.
# Written to stderr so --json stdout stays a single clean JSON line.
if [ "$NO_ISSUE" = false ]; then
  case "$TYPE" in
    feature|bugfix)
      if ! [[ "$NAME" =~ ^[0-9]+([-_][0-9]+)*_ ]]; then
        printf '⚠️  Branch name "%s" has no <issue#>_ prefix — auto issue-ref in "git c"/"git finish" will be disabled. Use --no-issue to silence this warning.\n' "$NAME" >&2
      fi
      ;;
  esac
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

# ─── Linked worktree detection ──────────────────────────────────
abs_dir() { (cd "$1" && pwd -P); }

IN_LINKED_WORKTREE=false
if [ "$(abs_dir "$(git rev-parse --git-dir)")" != "$(abs_dir "$(git rev-parse --git-common-dir)")" ]; then
  IN_LINKED_WORKTREE=true
fi

# The first entry of 'git worktree list' is always the main worktree.
MAIN_WORKTREE=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

if [ "$WORKTREE" = false ] && [ "$IN_LINKED_WORKTREE" = true ]; then
  emit_error "in_linked_worktree" "Running inside a linked worktree: '$BASE' is probably checked out in the main worktree, so 'git start' cannot check it out here. Use 'git start $TYPE $NAME --worktree' to create the branch in its own worktree, or run it from the main checkout ($MAIN_WORKTREE)."
fi

# ─── Create branch in a new linked worktree ─────────────────────
if [ "$WORKTREE" = true ]; then
  if [ -n "$WT_PATH_ARG" ]; then
    WT_PATH="$WT_PATH_ARG"
  else
    # Default: sibling of the main worktree, <repo-dir>_wt_<name> ('/' in name → '_').
    WT_PATH="$(dirname "$MAIN_WORKTREE")/$(basename "$MAIN_WORKTREE")_wt_${NAME//\//_}"
  fi

  if [ -e "$WT_PATH" ]; then
    emit_error "worktree_path_exists" "Worktree path already exists: $WT_PATH"
  fi

  START_POINT="$BASE"
  if git remote get-url origin >/dev/null 2>&1; then
    git fetch origin "$BASE" >/dev/null 2>&1 \
      || emit_error "fetch_failed" "Could not fetch origin/$BASE"
    # Branch from origin/<base> so the main checkout's <base> is never moved,
    # unless the local base has commits origin lacks (don't drop them silently).
    if git merge-base --is-ancestor "refs/heads/$BASE" "refs/remotes/origin/$BASE" 2>/dev/null; then
      START_POINT="origin/$BASE"
    else
      printf '⚠️  Local %s is ahead of or diverged from origin/%s — branching from local %s.\n' "$BASE" "$BASE" "$BASE" >&2
    fi
  fi

  git worktree add --no-track -b "$TYPE/$NAME" "$WT_PATH" "$START_POINT" >/dev/null 2>&1 \
    || emit_error "worktree_add_failed" "Could not create worktree at $WT_PATH for branch $TYPE/$NAME"

  # Ask git for the path so it matches 'git worktree list' (native form on Windows).
  WT_ABS=$(git -C "$WT_PATH" rev-parse --show-toplevel)
  if [ "$JSON" = true ]; then
    printf '{"status":"ok","branch":"%s","base":"%s","worktree":"%s"}\n' \
      "$TYPE/$NAME" "$BASE" "$(json_escape "$WT_ABS")"
  else
    printf '✅ Branch %s created from %s in worktree %s\n' "$TYPE/$NAME" "$BASE" "$WT_ABS"
    printf '   cd "%s"\n' "$WT_ABS"
  fi
  exit 0
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
