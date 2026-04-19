#!/bin/bash
# ~/.git-scripts/git-finish.sh
# Merge branch with auto-generated message and issue reference

set -euo pipefail

# ─── Verification of clean working directory ─────────────────────
if ! git diff-index --quiet HEAD --; then
  printf "❌ Clean your working directory before merging. Commit or stash changes.\n"
  exit 1
fi

CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ -z "$CURRENT" ]; then
  printf "❌ Not in a valid git branch.\n"
  exit 1
fi

TYPE=$(echo "$CURRENT" | cut -d/ -f1)
NAME=$(echo "$CURRENT" | cut -d/ -f2)

# Extract issue number (e.g. feature/123_dark_mode → 123)
if [[ "$NAME" =~ ^([0-9]+)_ ]]; then
  ISSUE_NUM="${BASH_REMATCH[1]}"
else
  ISSUE_NUM=""
fi

# Determine merge base and targets
case "$TYPE" in
  hotfix)  BASE=main;    TARGETS=("main" "develop") ;;
  release) BASE=develop; TARGETS=("main" "develop") ;;
  support) BASE=main;    TARGETS=("main") ;;
  *)       BASE=develop; TARGETS=("develop") ;;
esac

# Check that develop exists (required for all types except support)
if [ "$TYPE" != "support" ] && ! git show-ref --verify --quiet refs/heads/develop; then
  printf "❌ 'develop' branch does not exist. Run first: git init-flow\n"
  exit 1
fi

printf "🔍 Branch: %s → merge into: %s\n" "$CURRENT" "${TARGETS[*]}"
printf "\n"

# ─── Branch Diff ──────────────────────────────────────────────────
COMMITS=$(git log "$BASE".."$CURRENT" --oneline 2>/dev/null || echo "")
DIFF=$(git diff "$BASE"..."$CURRENT" --stat 2>/dev/null || echo "")

if [ -z "$COMMITS" ]; then
  printf "⚠️  No commits found compared to %s. Have you committed your changes?\n" "$BASE"
  exit 1
fi

# ─── Generate merge message ───────────────────────────────────────
case "$TYPE" in
  feature) MSG_TYPE="feat" ;;
  bugfix)  MSG_TYPE="fix" ;;
  release) MSG_TYPE="chore(release)" ;;
  hotfix)  MSG_TYPE="fix(hotfix)" ;;
  support) MSG_TYPE="chore(support)" ;;
  *)       MSG_TYPE="chore" ;;
esac

SUBJECT="${MSG_TYPE}: merge ${CURRENT} into ${TARGETS[*]}"
# Truncate subject to 72 chars
if [ "${#SUBJECT}" -gt 72 ]; then
  SUBJECT="${SUBJECT:0:69}..."
fi

BODY=$(echo "$COMMITS" | sed 's/^/- /')
AI_MSG=$(printf "%s\n\n%s" "$SUBJECT" "$BODY")

# Handle issue reference if present
if [ -n "$ISSUE_NUM" ]; then
  CLOSE_REF="Close #$ISSUE_NUM"
else
  CLOSE_REF=""
fi

# Compose final message with issue reference
if [ -n "$CLOSE_REF" ]; then
  FULL_MSG=$(printf "%s\n\n%s" "$AI_MSG" "$CLOSE_REF")
else
  FULL_MSG="$AI_MSG"
fi

# ─── User Confirmation ──────────────────────────────────────────
printf "\n💬 Merge message:\n"
printf "%s\n" "$AI_MSG"
[ -n "$CLOSE_REF" ] && printf "%s\n" "$CLOSE_REF"
printf "\n   Accept? [Y/n/e(dit)] (default: y) → "
read -r CHOICE
CHOICE=${CHOICE:-y}

case "$CHOICE" in
  n|N)
    printf "❌ Operation cancelled.\n"
    exit 0
    ;;
  e|E)
    printf "   Enter the message (without Close #): "
    read -r AI_MSG
    if [ -n "$CLOSE_REF" ]; then
      FULL_MSG=$(printf "%s\n\n%s" "$AI_MSG" "$CLOSE_REF")
    else
      FULL_MSG="$AI_MSG"
    fi
    ;;
esac

if [ -z "$FULL_MSG" ]; then
  printf "❌ Empty message. Operation cancelled.\n"
  exit 1
fi

# ─── Update CHANGELOG.md (for release/hotfix) ────────────────────
if [ "$TYPE" = "release" ] || [ "$TYPE" = "hotfix" ]; then
  if [ -f "CHANGELOG.md" ]; then
    DATE=$(date +%Y-%m-%d)
    CLEAN_NAME=$(echo "$NAME" | sed 's/^v//')
    TARGET_VER=""
    if grep -q "## \[$NAME\]" CHANGELOG.md; then
      TARGET_VER="$NAME"
    elif grep -q "## \[$CLEAN_NAME\]" CHANGELOG.md; then
      TARGET_VER="$CLEAN_NAME"
    fi

    if [ -n "$TARGET_VER" ]; then
      # Escape periods for sed
      ESC_VER=$(echo "$TARGET_VER" | sed 's/\./\\./g')
      # Check if it already has a date
      if ! grep "## \[$TARGET_VER\]" CHANGELOG.md | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
        sed "s/## \[$ESC_VER\].*/## \[$TARGET_VER\] - $DATE/" CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
        printf "📝 Updated CHANGELOG.md with date %s\n" "$DATE"
        git add CHANGELOG.md
        git commit -m "chore: update changelog for $TARGET_VER" --quiet
      fi
    fi
  fi
fi

# ─── Execute Merge ───────────────────────────────────────────────
printf "\n"
for TARGET in "${TARGETS[@]}"; do
  if ! git checkout "$TARGET"; then
    printf "❌ Could not checkout %s\n" "$TARGET"
    exit 1
  fi

  if ! git merge --no-ff "$CURRENT" -m "$FULL_MSG"; then
    printf "❌ Merge conflict detected in %s. Resolve manually and then run 'git finish' again.\n" "$TARGET"
    exit 1
  fi
  printf "✅ Merged into %s\n" "$TARGET"
done

# Automatic tag for release and hotfix
if [ "$TYPE" = "release" ] || [ "$TYPE" = "hotfix" ]; then
  if ! git tag -a "$NAME" -m "$FULL_MSG"; then
    printf "❌ Tag '%s' already exists or could not be created.\n" "$NAME"
    exit 1
  else
    printf "🏷️  Tag '%s' created\n" "$NAME"
  fi
fi

# ─── Push to origin (optional/prompted) ──────────────────────────
printf "\n🚀 Push to origin? [Y/n] (default: y) → "
read -r PUSH_CHOICE
PUSH_CHOICE=${PUSH_CHOICE:-y}

if [[ "$PUSH_CHOICE" =~ ^[Yy]$ ]]; then
  for TARGET in "${TARGETS[@]}"; do
    printf "📤 Pushing %s...\n" "$TARGET"
    git push origin "$TARGET"
  done
  if [ "$TYPE" = "release" ] || [ "$TYPE" = "hotfix" ]; then
    printf "📤 Pushing tags...\n"
    git push origin --tags
  fi
  printf "✅ Push completed\n"
fi

# ─── Cleanup ─────────────────────────────────────────────────────
printf "\n🗑️  Delete branch '%s'? [Y/n] (default: y) → "
read -r DEL_CHOICE
DEL_CHOICE=${DEL_CHOICE:-y}

if [[ "$DEL_CHOICE" =~ ^[Yy]$ ]]; then
  if ! git branch -d "$CURRENT"; then
    printf "⚠️  Could not delete branch '%s' with -d. Force delete? [y/N] → " "$CURRENT"
    read -r FORCE_DEL
    FORCE_DEL=${FORCE_DEL:-n}
    if [[ "$FORCE_DEL" =~ ^[Yy]$ ]]; then
      git branch -D "$CURRENT"
      printf "🗑️  Branch '%s' deleted (forced)\n" "$CURRENT"
    else
      printf "⚠️  Branch '%s' kept\n" "$CURRENT"
    fi
  else
    printf "🗑️  Branch '%s' deleted\n" "$CURRENT"
  fi
fi

printf "\n🎉 Done! → \"%s\"\n" "$(echo "$FULL_MSG" | head -n 1)"
