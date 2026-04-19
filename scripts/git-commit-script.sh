#!/bin/bash
# ~/.git-scripts/git-commit.sh
# Interactive commit with Conventional Commits template and issue reference

set -euo pipefail

# ─── Verification of staged files ────────────────────────────────
STAGED=$(git diff --cached --stat 2>/dev/null || echo "")
if [ -z "$STAGED" ]; then
  printf "⚠️  No files in staging. Run first: git add <files>\n"
  exit 1
fi

# ─── Branch and issue info ───────────────────────────────────────
CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
NAME=$(echo "$CURRENT" | cut -d/ -f2)

# Extract issue number (e.g. feature/123_dark_mode → 123)
if [[ "$NAME" =~ ^([0-9]+)_ ]]; then
  ISSUE_NUM="${BASH_REMATCH[1]}"
else
  ISSUE_NUM=""
fi

if [ -n "$ISSUE_NUM" ]; then
  ISSUE_REF="(ref #$ISSUE_NUM)"
else
  ISSUE_REF=""
fi

# ─── Detect editor ───────────────────────────────────────────────
COMMIT_EDITOR=$(git var GIT_EDITOR 2>/dev/null || echo "vi")

# ─── Build commit template ───────────────────────────────────────
TMPFILE=$(mktemp "${TMPDIR:-/tmp}/git-commit-msg.XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT

{
  printf "\n"
  printf "# ─── Conventional Commits Guide ──────────────────────────────\n"
  printf "# Format:  <type>(<scope>): <description>   (max 72 chars)\n"
  printf "# Types:   feat | fix | docs | style | refactor | perf | test | chore\n"
  printf "# Scope:   optional, only if clearly applicable (e.g. ui, api, core)\n"
  printf "# Body:    blank line + bullet points describing specific changes\n"
  printf "#\n"
  printf "# Branch:  %s\n" "$CURRENT"
  if [ -n "$ISSUE_NUM" ]; then
    printf "# Issue:   #%s (will be appended automatically as \"%s\")\n" "$ISSUE_NUM" "$ISSUE_REF"
  fi
  printf "#\n"
  printf "# Staged changes:\n"
  echo "$STAGED" | sed 's/^/#   /'
  printf "# ─────────────────────────────────────────────────────────────\n"
} > "$TMPFILE"

# ─── Open editor ─────────────────────────────────────────────────
$COMMIT_EDITOR "$TMPFILE"

# ─── Process user input ──────────────────────────────────────────
# Strip comment lines and normalise whitespace
AI_MSG=$(grep -v '^#' "$TMPFILE" | sed -e '/^[[:space:]]*$/d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -z "$AI_MSG" ]; then
  printf "❌ Empty message. Commit cancelled.\n"
  exit 1
fi

# ─── Validate Conventional Commits format ────────────────────────
if ! echo "$AI_MSG" | head -n 1 | grep -qE '^(feat|fix|chore|refactor|docs|test|style|perf)(\(.*\))?:'; then
  printf "⚠️  Warning: message might not follow Conventional Commits format.\n"
fi

# ─── Inject issue reference into subject line ────────────────────
SUBJECT=$(echo "$AI_MSG" | head -n 1)
BODY=$(echo "$AI_MSG" | tail -n +2)
if [ -n "$ISSUE_REF" ]; then
  FULL_MSG="${SUBJECT} ${ISSUE_REF}${BODY}"
else
  FULL_MSG="$AI_MSG"
fi

# ─── User Confirmation ───────────────────────────────────────────
printf "\n💬 Commit message:\n"
printf "%s\n\n" "$FULL_MSG" | sed 's/^/   /'
printf "   Accept? [Y/n/e(dit)] (default: y) → "
read -r CHOICE
CHOICE=${CHOICE:-y}

case "$CHOICE" in
  n|N)
    printf "❌ Commit cancelled.\n"
    exit 0
    ;;
  e|E)
    printf "   Re-opening editor...\n"
    $COMMIT_EDITOR "$TMPFILE"
    AI_MSG=$(grep -v '^#' "$TMPFILE" | sed -e '/^[[:space:]]*$/d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [ -z "$AI_MSG" ]; then
      printf "❌ Empty message. Commit cancelled.\n"
      exit 1
    fi
    SUBJECT=$(echo "$AI_MSG" | head -n 1)
    BODY=$(echo "$AI_MSG" | tail -n +2)
    if [ -n "$ISSUE_REF" ]; then
      FULL_MSG="${SUBJECT} ${ISSUE_REF}${BODY}"
    else
      FULL_MSG="$AI_MSG"
    fi
    ;;
esac

# ─── Commit ──────────────────────────────────────────────────────
git commit -m "$FULL_MSG"
printf "\n✅ Commit successful: \"%s\"\n" "$(echo "$FULL_MSG" | head -n 1)"
