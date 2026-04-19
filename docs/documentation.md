# Technical Documentation

## Overview

`git-ai-flow` is a set of Git aliases and Bash scripts that wrap common GitFlow operations and provide Conventional Commits automation with interactive commit workflows. The goal is to reduce friction in the commit and merge workflow while enforcing consistent message formatting through [Conventional Commits](https://www.conventionalcommits.org/).

---

## Repository structure

```text
git-ai-flow/
├── scripts/
│   ├── git-commit-script.sh   # Interactive commit with CC template
│   └── git-finish-script.sh   # Auto-generated merge message + branch close
├── gitconfig-aliases.ini      # Ready-to-paste Git alias block
├── docs/
│   └── documentation.md       # This file
├── CONTRIBUTING.md
├── LICENSE
├── CHANGELOG.md
└── README.md
```

---

## How it works

### Commit message generation

`git c` opens the user's configured editor with a pre-populated template. The template contains Conventional Commits guidance and branch context as `#` comment lines (stripped automatically before committing), followed by a blank area where the user writes the actual message.

`git finish` auto-generates a merge message from branch metadata (type, name) and the commit history between the base branch and the current branch — no external tool required.

---

## `git-commit-script.sh` — Working commit generator

**Alias:** `git c`  
**Triggered when:** you want to commit staged changes during development.

### Step by step

**1. Staged check**
```bash
STAGED=$(git diff --cached --stat 2>/dev/null || echo "")
```
Exits immediately if nothing is staged, preventing an empty commit.

**2. Issue extraction**
```bash
NAME=$(echo "$CURRENT" | cut -d/ -f2)

# Extract issue number (e.g. feature/123_dark_mode → 123)
if [[ "$NAME" =~ ^([0-9]+)_ ]]; then
  ISSUE_NUM="${BASH_REMATCH[1]}"
fi
```
Splits the branch name on `/`, takes the second part (e.g. `123_dark_mode`), then extracts the leading digits only if followed by an underscore.

**3. Editor detection**
```bash
COMMIT_EDITOR=$(git var GIT_EDITOR 2>/dev/null || echo "vi")
```
Respects the user's configured editor via `GIT_EDITOR` env var, `core.editor` git config, `VISUAL`, `EDITOR`, then falls back to `vi`.

**4. Template creation**

A temp file is written containing `#` comment lines with:
- Conventional Commits type guide
- Current branch name
- Issue reference hint (if applicable)
- `git diff --cached --stat` output

The user writes their commit message above or below the comments; all `#` lines are stripped before committing.

**5. Issue reference**

If an issue number was found, it is appended inline on the first line:
```text
feat(ui): add dark mode screen (ref #123)
```
`ref #N` links the commit to the issue without closing it.

**6. Confirmation prompt**

```text
Accept? [Y/n/e(dit)] (default: y) →
```
`Y`/Enter commits as-is. `e` re-opens the editor. `n` cancels.

---

## `git-finish-script.sh` — Branch merge & close

**Alias:** `git finish`  
**Triggered when:** the feature/bugfix/release/hotfix is complete and ready to merge.

### Step by step

**1. Clean check**
```bash
if ! git diff-index --quiet HEAD --; then
  # Exits if there are uncommitted changes
fi
```

**2. Branch parsing**
Identifies the branch type (`feature`, `bugfix`, `release`, `hotfix`, `support`) to determine the merge strategy.

**3. Merge target resolution**

| Branch type | Base | Targets |
|---|---|---|
| `feature` | `develop` | `develop` |
| `bugfix` | `develop` | `develop` |
| `release` | `develop` | `main develop` |
| `hotfix` | `main` | `main develop` |
| `support` | `main` | `main` |

**4. Message generation**

The merge message is auto-generated from branch metadata and commit history:

```bash
case "$TYPE" in
  feature) MSG_TYPE="feat" ;;
  bugfix)  MSG_TYPE="fix" ;;
  release) MSG_TYPE="chore(release)" ;;
  hotfix)  MSG_TYPE="fix(hotfix)" ;;
  support) MSG_TYPE="chore(support)" ;;
esac

SUBJECT="${MSG_TYPE}: merge ${CURRENT} into ${TARGETS[*]}"
BODY=$(echo "$COMMITS" | sed 's/^/- /')
```

**5. Issue reference**

At merge time the issue is closed by appending `Close #N` in the commit body:
```text
feat: merge feature/123_dark_mode into develop

- abc1234 feat(ui): add dark mode toggle
- def5678 fix(ui): handle system theme preference

Close #123
```

**6. Merge loop & error handling**
The script iterates through the targets, performing a `--no-ff` merge. If a conflict is detected, it stops and prompts the user for manual resolution.

**7. Auto-tag for release and hotfix**
Creates an annotated tag using the branch name (e.g., `v1.2.0`). If the tag already exists, the script exits with an error to prevent accidental overwrites.

**8. Branch cleanup**
Deletes the local branch after successful merges.

---

## `.gitconfig` aliases

| Alias | Script / Command | Description |
|---|---|---|
| `git init-flow` | inline shell function | Creates `develop` branch from `main` and pushes to origin |
| `git start <type> <name>` | inline shell function | Creates branch from correct base after pulling latest |
| `git c` | `git-commit-script.sh` | Interactive CC commit with editor template |
| `git finish` | `git-finish-script.sh` | Auto-generated merge message + close issue + optional tag |
| `git publish` | inline | Push current branch to origin |
| `git st-flow` | inline grep | List all active flow branches |
| `git sync` | inline | Checkout develop + pull |

---

## Design decisions

**Why an editor template instead of inline prompts?**  
The editor gives users full control over multi-line messages with Conventional Commits guidance visible as comments. It respects Git's configured editor (`core.editor`) and feels native to Git workflows. Users who prefer VS Code, Neovim, or any other editor get the same experience.

**Why auto-generate merge messages from metadata?**  
Merge messages are more formulaic than commit messages — the branch type, name, and commit list contain all the information needed. A deterministic, metadata-driven approach eliminates the external dependency while preserving the most important information.

**Why `set -euo pipefail`?**  
Ensures the scripts exit immediately on any error, preventing partial or corrupt Git operations.

**Why `--no-ff` on every merge?**  
Keeps the topology clear by explicitly showing when a branch was merged.

**Why `ref #N` during work and `Close #N` only at finish?**  
Allows linking progress to issues without prematurely closing them.
