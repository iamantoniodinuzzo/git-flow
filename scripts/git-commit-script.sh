#!/bin/bash
# ~/.git-scripts/git-commit.sh
# Generate a commit message with Gemini CLI (Conventional Commits + issue ref)

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
ISSUE_NUM=$(echo "$NAME" | grep -oE '^[0-9]+' || echo "")

[ -n "$ISSUE_NUM" ] && ISSUE_REF="(ref #$ISSUE_NUM)" || ISSUE_REF=""

# ─── Staged Diff Handling ────────────────────────────────────────
# Limit diff size to avoid API limits (approx 150 lines)
LINE_COUNT=$(git diff --cached | wc -l)
if [ "$LINE_COUNT" -gt 150 ]; then
  DIFF=$(git diff --cached --stat)
  DIFF+=$'\n\n(Diff truncated, showing stats only due to size)'
else
  DIFF=$(git diff --cached)
fi

printf "🤖 Generating message with Gemini...\n"

PROMPT="You are a senior software engineer and Git expert.
Task: Write a high-quality commit message based on the staged diff and branch name.

CONVENTIONS:
- Use Conventional Commits 1.0.0.
- Language: English.
- Format: <type>(<scope>): <description> followed by a body with bullet points.

TYPES:
- feat: A new feature
- fix: A bug fix
- docs: Documentation changes
- style: Formatting, missing semi-colons, etc.
- refactor: Code change that neither fixes a bug nor adds a feature
- perf: Performance improvement
- test: Adding/correcting tests
- chore: Build process, auxiliary tools, etc.

RULES:
1. Subject (first line): <= 72 characters.
2. Scope: Optional, use only if clearly applicable (e.g., 'ui', 'api', 'core').
3. Body: 2 to 6 bullet points describing specific changes.
4. Be concise and technical.
5. NO preamble or explanations. Output ONLY the message.
6. DO NOT include issue references (e.g., #123); they are handled by the script.

CONTEXT:
Branch: $CURRENT
Staged Diff:
$DIFF"

# Capture stdout and stderr, handle potential gemini errors
AI_MSG_RAW=$(gemini -p "$PROMPT" 2>&1 || true)

if echo "$AI_MSG_RAW" | grep -iq "error"; then
  printf "❌ Gemini error: %s\n" "$AI_MSG_RAW"
  exit 1
fi

AI_MSG=$(echo "$AI_MSG_RAW" | tr -d '\r' | sed 's/^[[:space:]]*//')

if [ -z "$AI_MSG" ]; then
  printf "❌ Gemini returned an empty response. Verify your login with: gemini\n"
  exit 1
fi

# Validate format (basic check for conventional commit type)
if ! echo "$AI_MSG" | grep -qE '^(feat|fix|chore|refactor|docs|test|style|perf)(\(.*\))?:'; then
  printf "⚠️  Warning: Gemini response might not follow Conventional Commits format.\n"
fi

# Final message with issue ref on the FIRST line
SUBJECT=$(echo "$AI_MSG" | head -n 1)
BODY=$(echo "$AI_MSG" | tail -n +2)
if [ -n "$ISSUE_REF" ]; then
  FULL_MSG="${SUBJECT} ${ISSUE_REF}${BODY}"
else
  FULL_MSG="$AI_MSG"
fi

# ─── User Confirmation ──────────────────────────────────────────
printf "\n💬 Suggested message:\n"
printf "   %s\n\n" "$(echo "$FULL_MSG" | sed 's/^/   /')"
printf "   Accept? [Y/n/e(dit)] (default: y) → "
read -r CHOICE
CHOICE=${CHOICE:-y}

case "$CHOICE" in
  n|N)
    printf "❌ Commit cancelled.\n"
    exit 0
    ;;
  e|E)
    printf "   Opening editor for manual modification...\n"
    git commit -e -m "$FULL_MSG"
    exit 0
    ;;
esac

if [ -z "$FULL_MSG" ]; then
  printf "❌ Empty message. Commit cancelled.\n"
  exit 1
fi

# ─── Commit ──────────────────────────────────────────────────────
git commit -m "$FULL_MSG"
printf "\n✅ Commit successful: \"%s\"\n" "$(echo "$FULL_MSG" | head -n 1)"
