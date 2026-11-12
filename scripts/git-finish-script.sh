#!/bin/bash
# ~/.git-scripts/git-finish.sh
# Merge branch with auto-generated message and issue reference

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

json_array() {
  local sep=""
  printf '['
  for item in "$@"; do
    printf '%s"%s"' "$sep" "$item"
    sep=','
  done
  printf ']'
}

# ─── Flag parsing ────────────────────────────────────────────────
AUTO_YES=false
KEEP_WORKTREE=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y)        AUTO_YES=true ;;
    --json)          JSON=true; AUTO_YES=true ;;
    --keep-worktree) KEEP_WORKTREE=true ;;
    *) emit_error "unknown_flag" "Unknown flag: $arg" ;;
  esac
done

# ─── Worktree helpers ────────────────────────────────────────────
abs_dir() { (cd "$1" && pwd -P); }

# Path of the worktree where branch $1 is checked out (empty if none).
worktree_of_branch() {
  git worktree list --porcelain \
    | awk -v ref="refs/heads/$1" '/^worktree /{wt=substr($0,10)} $0=="branch " ref {print wt; exit}'
}

IN_LINKED_WORKTREE=false
if [ "$(abs_dir "$(git rev-parse --git-dir)")" != "$(abs_dir "$(git rev-parse --git-common-dir)")" ]; then
  IN_LINKED_WORKTREE=true
fi
CUR_TOP=$(git rev-parse --show-toplevel)
# The first entry of 'git worktree list' is always the main worktree.
MAIN_WORKTREE=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
WT_REMOVED=false

# ─── Verification of clean working directory ─────────────────────
if ! git diff-index --quiet HEAD --; then
  emit_error "dirty_working_tree" "Clean your working directory before merging. Commit or stash changes."
fi
# A linked worktree is removed after the merge; 'git worktree remove' refuses on
# untracked files, so catch them now instead of failing after the merge landed.
if [ "$IN_LINKED_WORKTREE" = true ] && [ "$KEEP_WORKTREE" = false ] \
   && [ -n "$(git status --porcelain)" ]; then
  emit_error "dirty_working_tree" "Linked worktree has untracked files, which would block its removal. Commit, stash or delete them, or pass --keep-worktree."
fi

CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ -z "$CURRENT" ]; then
  emit_error "not_on_branch" "Not in a valid git branch."
fi

# Determine main branch (main or master)
if git show-ref --verify --quiet refs/heads/main; then
  MAIN_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
  MAIN_BRANCH="master"
else
  emit_error "no_main_branch" "Neither 'main' nor 'master' branch found."
fi

# Refuse to run on a protected branch (main/master/develop). This is not a flow
# branch, and re-deriving TYPE/NAME from it silently misroutes the merge,
# tag, and cleanup steps (see issue #10). If a release/hotfix merge conflict
# left you here, finish it manually instead of re-running 'git finish'.
if [ "$CURRENT" = "$MAIN_BRANCH" ] || [ "$CURRENT" = "develop" ]; then
  emit_error "on_protected_branch" "Refusing to run 'git finish' on '$CURRENT' (not a flow branch). If you just resolved a release/hotfix merge conflict here: 1) finish the merge with 'git commit' if one is still in progress; 2) tag and push manually: git tag -a <version> -m <message> && git push origin $CURRENT --tags. Otherwise checkout your release/hotfix/feature branch before re-running 'git finish'."
fi

TYPE=$(echo "$CURRENT" | cut -d/ -f1)
NAME=$(echo "$CURRENT" | cut -d/ -f2-)

# Extract issue numbers (e.g. feature/44-45_dark → 44 45 ; feature/123_x → 123)
ISSUE_NUMS=()
if [[ "$NAME" =~ ^([0-9]+([-_][0-9]+)*)_ ]]; then
  IFS='-_' read -ra ISSUE_NUMS <<< "${BASH_REMATCH[1]}"
fi

# Determine merge base and targets
case "$TYPE" in
  hotfix)  BASE="$MAIN_BRANCH";    TARGETS=("$MAIN_BRANCH" "develop") ;;
  release) BASE=develop; TARGETS=("$MAIN_BRANCH" "develop") ;;
  support) BASE="$MAIN_BRANCH";    TARGETS=("$MAIN_BRANCH") ;;
  *)       BASE=develop; TARGETS=("develop") ;;
esac

# Outcome tracking
PUSHED=false
DELETED=false

# Check that develop exists (required for all types except support)
if [ "$TYPE" != "support" ] && ! git show-ref --verify --quiet refs/heads/develop; then
  emit_error "develop_missing" "'develop' branch does not exist. Run first: git init-flow"
fi

# A target checked out in another worktree is merged there (git refuses to check
# a branch out twice); that worktree must be clean or the merge would be unsafe.
for TARGET in "${TARGETS[@]}"; do
  TWT=$(worktree_of_branch "$TARGET")
  if [ -n "$TWT" ] && [ "$TWT" != "$CUR_TOP" ] && ! git -C "$TWT" diff-index --quiet HEAD --; then
    emit_error "target_worktree_dirty" "$TARGET is checked out in $TWT, which has uncommitted changes. Commit or stash them there first."
  fi
done

if [ "$JSON" = false ]; then
  printf "🔍 Branch: %s → merge into: %s\n" "$CURRENT" "${TARGETS[*]}"
  printf "\n"
fi

# ─── Branch Diff ──────────────────────────────────────────────────
COMMITS=$(git log "$BASE".."$CURRENT" --oneline 2>/dev/null || echo "")
DIFF=$(git diff "$BASE"..."$CURRENT" --stat 2>/dev/null || echo "")

if [ -z "$COMMITS" ]; then
  emit_error "no_commits" "No commits found compared to $BASE. Have you committed your changes?"
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

# Handle issue reference(s) if present
CLOSE_REF=""
for n in "${ISSUE_NUMS[@]}"; do
  [ -n "$CLOSE_REF" ] && CLOSE_REF+=", "
  CLOSE_REF+="Close #$n"
done

# Compose final message with issue reference
if [ -n "$CLOSE_REF" ]; then
  FULL_MSG=$(printf "%s\n\n%s" "$AI_MSG" "$CLOSE_REF")
else
  FULL_MSG="$AI_MSG"
fi

# ─── User Confirmation ──────────────────────────────────────────
if [ "$JSON" = false ]; then
  printf "\n💬 Merge message:\n"
  printf "%s\n" "$AI_MSG"
  [ -n "$CLOSE_REF" ] && printf "%s\n" "$CLOSE_REF"
fi
if [ "$AUTO_YES" = true ]; then
  CHOICE="y"
else
  printf "\n   Accept? [Y/n/e(dit)] (default: y) → "
  read -r CHOICE
  CHOICE=${CHOICE:-y}
fi

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
  emit_error "empty_message" "Empty message. Operation cancelled."
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
        if [ "$JSON" = false ]; then
          printf "📝 Updated CHANGELOG.md with date %s\n" "$DATE"
        fi
        git add CHANGELOG.md
        git commit -m "chore: update changelog for $TARGET_VER" --quiet
      fi
    fi
  fi
fi

# ─── Execute Merge ───────────────────────────────────────────────
if [ "$JSON" = false ]; then printf "\n"; fi
MERGED=()
LAST_TARGET=""
for TARGET in "${TARGETS[@]}"; do
  # Run git in the worktree that holds the target; if none does, check it out here.
  TWT=$(worktree_of_branch "$TARGET")
  if [ -n "$TWT" ] && [ "$TWT" != "$CUR_TOP" ]; then
    MERGE_DIR="$TWT"
  else
    MERGE_DIR="."
    if [ "$JSON" = true ]; then
      git checkout "$TARGET" >/dev/null 2>&1 \
        || emit_error "checkout_failed" "Could not checkout $TARGET"
    else
      if ! git checkout "$TARGET"; then
        emit_error "checkout_failed" "Could not checkout $TARGET"
      fi
    fi
  fi

  if [ "$JSON" = true ]; then
    MERGE_OK=true
    git -C "$MERGE_DIR" merge --no-ff "$CURRENT" -m "$FULL_MSG" >/dev/null 2>&1 || MERGE_OK=false
  else
    MERGE_OK=true
    git -C "$MERGE_DIR" merge --no-ff "$CURRENT" -m "$FULL_MSG" || MERGE_OK=false
  fi

  if [ "$MERGE_OK" = false ]; then
    # Leave the target untouched: abort the half-done merge and go back to the flow branch.
    if git -C "$MERGE_DIR" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
      git -C "$MERGE_DIR" merge --abort >/dev/null 2>&1 || true
    fi
    if [ "$MERGE_DIR" = "." ]; then
      git checkout "$CURRENT" >/dev/null 2>&1 || true
    fi
    CONFLICT_MSG="Merge into $TARGET aborted due to conflicts; $TARGET is unchanged. Resolve on your branch (git merge $TARGET, fix conflicts, commit), then run 'git finish' again."
    if [ "${#MERGED[@]}" -gt 0 ]; then
      CONFLICT_MSG+=" Already merged locally (not pushed): ${MERGED[*]}."
    fi
    emit_error "merge_conflict" "$CONFLICT_MSG"
  fi

  MERGED+=("$TARGET")
  LAST_TARGET="$TARGET"
  if [ "$JSON" = false ]; then
    printf "✅ Merged into %s\n" "$TARGET"
  fi
done

# Automatic tag for release and hotfix (on the last target's tip; HEAD may not be
# there when that target was merged in another worktree).
if [ "$TYPE" = "release" ] || [ "$TYPE" = "hotfix" ]; then
  if ! git tag -a "$NAME" -m "$FULL_MSG" "$LAST_TARGET"; then
    emit_error "tag_failed" "Tag '$NAME' already exists or could not be created."
  fi
  if [ "$JSON" = false ]; then
    printf "🏷️  Tag '%s' created\n" "$NAME"
  fi
fi

# ─── Push to origin (optional/prompted) ──────────────────────────
if [ "$AUTO_YES" = true ]; then
  PUSH_CHOICE="y"
else
  printf "\n🚀 Push to origin? [Y/n] (default: y) → "
  read -r PUSH_CHOICE
  PUSH_CHOICE=${PUSH_CHOICE:-y}
fi

if [[ "$PUSH_CHOICE" =~ ^[Yy]$ ]]; then
  for TARGET in "${TARGETS[@]}"; do
    if [ "$JSON" = false ]; then
      printf "📤 Pushing %s...\n" "$TARGET"
    fi
    git push origin "$TARGET"
  done
  if [ "$TYPE" = "release" ] || [ "$TYPE" = "hotfix" ]; then
    if [ "$JSON" = false ]; then
      printf "📤 Pushing tags...\n"
    fi
    git push origin --tags
  fi
  PUSHED=true
  if [ "$JSON" = false ]; then
    printf "✅ Push completed\n"
  fi
fi

# ─── Cleanup ─────────────────────────────────────────────────────
# Hard invariant: main/master/develop are never candidates for automatic
# deletion, no matter how TYPE/TARGETS were computed above (defense in depth
# alongside the protected-branch refusal earlier — see issue #10).
if [ "$CURRENT" = "$MAIN_BRANCH" ] || [ "$CURRENT" = "develop" ]; then
  DEL_CHOICE="n"
  if [ "$JSON" = false ]; then
    printf "\n🛡️  '%s' is a protected branch — skipping deletion.\n" "$CURRENT"
  fi
elif [ "$AUTO_YES" = true ]; then
  DEL_CHOICE="y"
else
  printf "\n🗑️  Delete branch '%s'? [Y/n] (default: y) → " "$CURRENT"
  read -r DEL_CHOICE
  DEL_CHOICE=${DEL_CHOICE:-y}
fi

DEL_FLAG="-d"

# Linked worktree: git refuses to delete a branch that is checked out in any
# worktree, so remove this one first (never with --force: it must be clean).
if [ "$IN_LINKED_WORKTREE" = true ] && [[ "$DEL_CHOICE" =~ ^[Yy]$ ]]; then
  if [ "$KEEP_WORKTREE" = true ]; then
    DEL_CHOICE="n"
    if [ "$JSON" = false ]; then
      printf "⚠️  Branch '%s' kept: it is checked out in the worktree you asked to keep.\n" "$CURRENT"
    fi
  else
    cd "$MAIN_WORKTREE"
    if git worktree remove "$CUR_TOP" >/dev/null 2>&1; then
      WT_REMOVED=true
    elif [ -z "$(worktree_of_branch "$CURRENT")" ]; then
      # git unregistered the worktree but could not delete the directory
      # (e.g. on Windows the calling shell's cwd holds it open).
      WT_REMOVED=true
      if [ "$JSON" = false ]; then
        printf "⚠️  Worktree unregistered, but '%s' could not be deleted (is a shell still inside it?). Remove it manually.\n" "$CUR_TOP"
      fi
    else
      DEL_CHOICE="n"
      if [ "$JSON" = false ]; then
        printf "⚠️  Could not remove worktree '%s'. Branch '%s' kept. Then run: git worktree remove \"%s\" && git branch -d %s\n" "$CUR_TOP" "$CURRENT" "$CUR_TOP" "$CURRENT"
      fi
    fi
    if [ "$WT_REMOVED" = true ]; then
      if [ "$JSON" = false ]; then
        printf "🧹 Worktree '%s' removed\n" "$CUR_TOP"
      fi
      # The main worktree's HEAD may not be the target, so 'git branch -d' would
      # judge "merged" against the wrong ref. Verify against the merge target.
      if git merge-base --is-ancestor "$CURRENT" "$LAST_TARGET" 2>/dev/null; then
        DEL_FLAG="-D"
      fi
    fi
  fi
fi

# Never try to delete the branch we are still standing on (happens when every
# target was merged in another worktree and this checkout kept the flow branch).
if [[ "$DEL_CHOICE" =~ ^[Yy]$ ]] \
   && [ "$(git symbolic-ref --short HEAD 2>/dev/null || echo "")" = "$CURRENT" ]; then
  DEL_CHOICE="n"
  if [ "$JSON" = false ]; then
    printf "⚠️  Branch '%s' is still checked out here — kept. Switch branches and run: git branch -d %s\n" "$CURRENT" "$CURRENT"
  fi
fi

if [[ "$DEL_CHOICE" =~ ^[Yy]$ ]]; then
  if ! git branch "$DEL_FLAG" "$CURRENT"; then
    if [ "$AUTO_YES" = true ]; then
      FORCE_DEL="y"
    else
      printf "⚠️  Could not delete branch '%s' with -d. Force delete? [y/N] → " "$CURRENT"
      read -r FORCE_DEL
      FORCE_DEL=${FORCE_DEL:-n}
    fi
    if [[ "$FORCE_DEL" =~ ^[Yy]$ ]]; then
      git branch -D "$CURRENT"
      if [ "$JSON" = false ]; then
        printf "🗑️  Branch '%s' deleted (forced)\n" "$CURRENT"
      fi
      DELETED=true
    else
      if [ "$JSON" = false ]; then
        printf "⚠️  Branch '%s' kept\n" "$CURRENT"
      fi
    fi
  else
    if [ "$JSON" = false ]; then
      printf "🗑️  Branch '%s' deleted\n" "$CURRENT"
    fi
    DELETED=true
  fi
fi

# ─── Output ──────────────────────────────────────────────────────
if [ "$JSON" = true ]; then
  MERGED_JSON=$(json_array "${TARGETS[@]}")
  if [ "$TYPE" = "release" ] || [ "$TYPE" = "hotfix" ]; then
    TAG_JSON="\"$NAME\""
  else
    TAG_JSON="null"
  fi
  printf '{"status":"ok","branch":"%s","merged_into":%s,"tag":%s,"pushed":%s,"deleted":%s,"worktree_removed":%s}\n' \
    "$CURRENT" "$MERGED_JSON" "$TAG_JSON" "$PUSHED" "$DELETED" "$WT_REMOVED"
else
  printf "\n🎉 Done! → \"%s\"\n" "$(echo "$FULL_MSG" | head -n 1)"
fi
