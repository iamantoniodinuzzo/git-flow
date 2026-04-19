# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

**git-ai-flow** is a GitFlow automation toolkit for Git that provides Conventional Commits automation and interactive commit workflows. It is distributed as Bash scripts and Git alias configuration — not a compiled application.

## Commands

**Lint (shell scripts):**
```bash
shellcheck scripts/*.sh
```

**Install locally for testing:**
```bash
mkdir -p ~/.git-scripts
cp scripts/git-commit-script.sh ~/.git-scripts/git-commit.sh
cp scripts/git-finish-script.sh ~/.git-scripts/git-finish.sh
chmod +x ~/.git-scripts/*.sh  # macOS/Linux only
```

**Manual testing checklist (from CONTRIBUTING.md):**
```bash
git start feature 123_test    # branch creation
git c                          # interactive commit
git finish                     # merge + close
git start hotfix 1.2.1_fix
git finish
```

## Architecture

### Core Files

- `scripts/git-commit-script.sh` — invoked by `git c` alias; opens the user's editor with a Conventional Commits template, validates the message, injects issue references, and commits
- `scripts/git-finish-script.sh` — invoked by `git finish`; auto-generates a merge message from branch metadata and commit history, then merges, tags, and cleans up
- `gitconfig-aliases.ini` — Git aliases installed to `~/.gitconfig`; defines `git start`, `git finish`, `git c`, `git publish`, `git sync`, `git st-flow`, `git init-flow`
- Installation is manual: copy scripts to `~/.git-scripts/` and patch `~/.gitconfig`

### Commit Workflow (`git c`)

1. Validates staged files exist
2. Extracts issue number from branch name (e.g., `feature/123_dark_mode` → `#123`)
3. Detects editor via `git var GIT_EDITOR`
4. Creates a temp file with a Conventional Commits template (CC types guide, branch info, staged stats as `#` comments)
5. Opens the editor; user writes the message
6. Strips `#` comment lines, validates non-empty, warns if not CC format
7. Injects `(ref #N)` into the subject line if issue number was found
8. Shows the final message and asks `Accept? [Y/n/e(dit)]` — Y=commit, n=cancel, e=reopen editor
9. Executes `git commit -m "$FULL_MSG"`

### Merge Workflow (`git finish`)

1. Validates clean working directory
2. Parses branch type and name, extracts issue number
3. Resolves merge targets by branch type:
   - `feature/*`, `bugfix/*` → `develop` only
   - `release/*`, `hotfix/*` → `main` + `develop`, creates version tag, updates CHANGELOG
   - `support/*` → `main` only
4. Auto-generates a merge message: CC type prefix (`feat`/`fix`/`chore(release)` etc.) + subject from branch name + bullet-point commit list
5. Appends `Close #N` footer if issue number is present
6. Shows the message and asks `Accept? [Y/n/e(dit)]`
7. Updates CHANGELOG with today's date for release/hotfix, auto-commits
8. Executes `git merge --no-ff` for each target
9. Creates annotated tag for release/hotfix
10. Prompts push to origin and branch deletion

### Branch and Merge Logic

Merge targets depend on branch type:
- `feature/*`, `bugfix/*` → `develop` only
- `release/*`, `hotfix/*` → `main` + `develop`, creates a version tag, updates CHANGELOG
- `support/*` → `main` only

Issue numbers are extracted from branch names (e.g., `feature/123_dark_mode` → `#123`) and injected into commit/merge messages.

### Error Handling

Scripts use `set -euo pipefail`. They validate Git state (clean working tree, correct branch, commits present) before any operation.

## Code Style

- Bash 4.0+; use `[[ ]]` for conditionals, `$(...)` for substitution
- All user-facing strings in English
- ShellCheck must pass with no warnings before merging
- Follow Conventional Commits for commit messages in this repo itself
