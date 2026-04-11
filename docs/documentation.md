# Technical Documentation

## Overview

`git-ai-flow` is a set of Git aliases and Bash scripts that wrap common Git Flow operations and enhance them with AI-generated commit messages via **Gemini CLI**. The goal is to reduce friction in the commit and merge workflow while enforcing consistent message formatting through [Conventional Commits](https://www.conventionalcommits.org/).

---

## Repository structure

```
git-ai-flow/
├── scripts/
│   ├── git-commit-script.sh   # AI commit message generator (working commits)
│   └── git-finish-script.sh   # AI merge message generator (branch close)
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

### The AI layer — Gemini CLI

Both scripts delegate message generation to **Gemini CLI** using the `-p` flag (non-interactive prompt mode). The integration is hardened to capture errors and handle large diffs.

```bash
# Example from git-commit-script.sh
AI_MSG_RAW=$(gemini -p "$PROMPT" 2>&1 || true)
```

- `gemini -p "$PROMPT" 2>&1` — captures both output and potential errors.
- `tr -d '\r'` — cleans up Windows-style line endings.
- `sed 's/^[[:space:]]*//'` — strips leading whitespace.

The prompt is built dynamically from the Git context (branch name, diff, commit log) before each call.

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
ISSUE_NUM=$(echo "$NAME" | grep -oE '^[0-9]+' || echo "")
```
Splits the branch name on `/`, takes the second part (e.g. `123_dark_mode`), then extracts the leading digits.

**3. Diff collection & truncation**
The script limits the diff size to approximately 150 lines. If the diff is too large, it falls back to `git diff --stat` to avoid Gemini API token limits.

**4. Prompt structure**

The prompt instructs Gemini to produce a message in this format:

```
type(scope): short description (max 72 chars)

- concrete change from the diff
- concrete change from the diff
- concrete change from the diff
```

Key prompt constraints:
- **Always English**
- `scope` only when clearly applicable
- 2–6 bullet points, each referencing real diff content
- No issue reference in the AI output (appended by the script)

**5. Issue reference**

If an issue number was found, it is appended inline on the first line:
```
feat(ui): add dark mode screen (ref #123)
```
`ref #N` links the commit to the issue without closing it.

**6. Confirmation prompt**

```
Accept? [Y/n/e(dit)] (default: y) →
```
`Y`/Enter commits as-is. `e` lets the user retype the subject line.

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

**4. Context collection**
Passes the branch's commit history and a summary of changed files to Gemini.

**5. Issue reference**

At merge time the issue is closed by appending `Close #N` in the commit body:
```
feat: dark mode with system theme support

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
| `git start <type> <name>` | inline shell function | Creates branch from correct base after pulling latest |
| `git c` | `git-commit-script.sh` | AI commit on staged files |
| `git finish` | `git-finish-script.sh` | AI merge + close issue + optional tag |
| `git publish` | inline | Push current branch to origin |
| `git st-flow` | inline grep | List all active flow branches |
| `git sync` | inline | Checkout develop + pull |

---

## Design decisions

**Why Gemini CLI instead of a direct API call?**  
Gemini CLI handles authentication seamlessly and requires no local API key management.

**Why `set -euo pipefail`?**  
Ensures the scripts exit immediately on any error, preventing partial or corrupt Git operations.

**Why `--no-ff` on every merge?**  
Keeps the topology clear by explicitly showing when a branch was merged.

**Why `ref #N` during work and `Close #N` only at finish?**  
Allows linking progress to issues without prematurely closing them.
