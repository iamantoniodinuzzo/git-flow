#!/bin/bash
# ~/.git-scripts/git-commit.sh
# Interactive commit with Conventional Commits template and issue reference

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
MESSAGE=""
COMMIT_BODY=""
while [ $# -gt 0 ]; do
  case "$1" in
    -m)
      MESSAGE="${2:-}"
      [ -z "$MESSAGE" ] && emit_error "usage" "Missing value for -m. Usage: git c -m <subject> [--body <text>] [--json]"
      shift 2
      ;;
    --body)
      COMMIT_BODY="${2:-}"
      shift 2
      ;;
    --json)
      JSON=true
      shift
      ;;
    *)
      emit_error "unknown_flag" "Unknown flag: $1"
      ;;
  esac
done

if [ "$JSON" = true ] && [ -z "$MESSAGE" ]; then
  emit_error "json_requires_message" "--json requires -m <subject> (an editor cannot be opened in JSON mode)."
fi

# ─── Verification of staged files ────────────────────────────────
STAGED=$(git diff --cached --stat 2>/dev/null || echo "")
if [ -z "$STAGED" ]; then
  emit_error "nothing_staged" "No files in staging. Run first: git add <files>"
fi

# ─── Branch and issue info ───────────────────────────────────────
CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
NAME=$(echo "$CURRENT" | cut -d/ -f2-)

# Extract issue numbers (e.g. feature/44-45_dark → 44 45 ; feature/123_x → 123)
ISSUE_NUMS=()
if [[ "$NAME" =~ ^([0-9]+([-_][0-9]+)*)_ ]]; then
  IFS='-_' read -ra ISSUE_NUMS <<< "${BASH_REMATCH[1]}"
fi

ISSUE_REF=""
if [ ${#ISSUE_NUMS[@]} -gt 0 ]; then
  REFS=""
  for n in "${ISSUE_NUMS[@]}"; do
    [ -n "$REFS" ] && REFS+=" "
    REFS+="#$n"
  done
  ISSUE_REF="(ref $REFS)"
fi

# ─── Non-interactive path (-m given) ──────────────────────────────
if [ -n "$MESSAGE" ]; then
  if ! echo "$MESSAGE" | grep -qE '^(feat|fix|chore|refactor|docs|test|style|perf)(\(.*\))?:'; then
    printf "⚠️  Warning: message might not follow Conventional Commits format.\n" >&2
  fi

  if [ -n "$ISSUE_REF" ]; then
    SUBJECT="${MESSAGE} ${ISSUE_REF}"
  else
    SUBJECT="$MESSAGE"
  fi

  if [ -n "$COMMIT_BODY" ]; then
    FULL_MSG=$(printf "%s\n\n%s" "$SUBJECT" "$COMMIT_BODY")
  else
    FULL_MSG="$SUBJECT"
  fi

  git commit -m "$FULL_MSG" --quiet
  SHA=$(git rev-parse --short HEAD)

  if [ "$JSON" = true ]; then
    printf '{"status":"ok","branch":"%s","sha":"%s","message":"%s"}\n' \
      "$(json_escape "$CURRENT")" "$SHA" "$(json_escape "$SUBJECT")"
  else
    printf "✅ Commit successful: \"%s\"\n" "$SUBJECT"
  fi
  exit 0
fi

# ─── Interactive path ─────────────────────────────────────────────

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
  if [ ${#ISSUE_NUMS[@]} -gt 0 ]; then
    printf "# Issue:   %s (will be appended automatically as \"%s\")\n" "${ISSUE_NUMS[*]/#/#}" "$ISSUE_REF"
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
