#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$HOME/.git-scripts"
ALIASES_FILE="$REPO_DIR/gitconfig-aliases.ini"

detect_os() {
  case "$OSTYPE" in
    msys*|cygwin*|mingw*) printf "windows" ;;
    darwin*)               printf "macos"   ;;
    *)                     printf "linux"   ;;
  esac
}

OS="$(detect_os)"

# On Windows, git normalizes paths to C:/... format; match that convention
if [[ "$OS" == "windows" ]] && command -v cygpath &>/dev/null; then
  ALIASES_FILE="$(cygpath -m "$ALIASES_FILE")"
fi

printf "git-ai-flow install\n"
printf "===================\n"

# --- scripts ---
mkdir -p "$SCRIPTS_DIR"
cp "$REPO_DIR/scripts/git-commit-script.sh" "$SCRIPTS_DIR/git-commit.sh"
cp "$REPO_DIR/scripts/git-finish-script.sh" "$SCRIPTS_DIR/git-finish.sh"

if [[ "$OS" != "windows" ]]; then
  chmod +x "$SCRIPTS_DIR/git-commit.sh" "$SCRIPTS_DIR/git-finish.sh"
fi

printf "Scripts   -> %s\n" "$SCRIPTS_DIR"

# --- gitconfig aliases (link, idempotent) ---
EXISTING_INCLUDES="$(git config --global --get-all include.path 2>/dev/null || true)"
if printf '%s\n' "$EXISTING_INCLUDES" | grep -qF "$ALIASES_FILE"; then
  printf "Aliases   -> already linked (no change)\n"
else
  git config --global --add include.path "$ALIASES_FILE"
  printf "Aliases   -> linked %s\n" "$ALIASES_FILE"
fi

printf "\nDone. Run 'bash install.sh' from the repo root any time to update.\n"
