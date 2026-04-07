# Technical Documentation

## Overview

`git-ai-flow` is a set of Git aliases and Bash scripts that wrap common Git Flow operations and enhance them with AI-generated commit messages via **Gemini CLI**. The goal is to reduce friction in the commit and merge workflow while enforcing consistent message formatting through [Conventional Commits](https://www.conventionalcommits.org/).

---

## Repository structure

```
git-ai-flow/
├── scripts/
│   ├── git-commit.sh        # AI commit message generator (working commits)
│   └── git-finish.sh        # AI merge message generator (branch close)
├── gitconfig-aliases.ini    # Ready-to-paste Git alias block
├── docs/
│   └── DOCUMENTATION.md     # This file
├── CONTRIBUTING.md
└── README.md
```

---

## How it works

### The AI layer — Gemini CLI

Both scripts delegate message generation to **Gemini CLI** using the `-p` flag (non-interactive prompt mode):

```bash
AI_MSG=$(gemini -p "$PROMPT" 2>/dev/null | tr -d '\n' | sed 's/^[[:space:]]*//')
```

- `gemini -p "$PROMPT"` — sends the prompt and returns the response to stdout
- `tr -d '\n'` — collapses any newlines in the first line to keep it clean
- `sed 's/^[[:space:]]*//'` — strips leading whitespace

The prompt is built dynamically from the Git context (branch name, diff, commit log) before each call.

---

## `git-commit.sh` — Working commit generator

**Alias:** `git c`  
**Triggered when:** you want to commit staged changes during development.

### Step by step

**1. Staged check**
```bash
STAGED=$(git diff --cached --stat 2>/dev/null)
```
Exits immediately if nothing is staged, preventing an empty commit.

**2. Issue extraction**
```bash
NAME=$(echo "$CURRENT" | cut -d/ -f2)
ISSUE_NUM=$(echo "$NAME" | grep -oE '^[0-9]+')
```
Splits the branch name on `/`, takes the second part (e.g. `123_dark_mode`), then extracts the leading digits. Works with any separator after the number.

**3. Diff collection**
```bash
DIFF=$(git diff --cached 2>/dev/null)
```
The full staged diff is passed to the prompt so Gemini can reference specific file names and changed lines.

**4. Prompt structure**

The prompt instructs Gemini to produce a message in this format:

```
type(scope): short description (max 72 chars)

- concrete change from the diff
- concrete change from the diff
- concrete change from the diff
```

Key prompt constraints:
- Always English
- `scope` only when clearly applicable
- 2–6 bullet points, each referencing real diff content
- No issue reference in the AI output (appended by the script)

**5. Issue reference**

If an issue number was found, it is appended inline on the first line:
```
feat(ui): add dark mode screen (ref #123)
```
`ref #N` links the commit to the issue without closing it — that only happens at merge time via `git finish`.

**6. Confirmation prompt**

```
Accept? [Y/n/e(dit)] →
```
`Y`/Enter commits as-is. `e` lets the user retype the subject line while the issue reference is still appended automatically.

---

## `git-finish.sh` — Branch merge & close

**Alias:** `git finish`  
**Triggered when:** the feature/bugfix/release/hotfix is complete and ready to merge.

### Step by step

**1. Branch parsing**
```bash
CURRENT=$(git symbolic-ref --short HEAD)
TYPE=$(echo "$CURRENT" | cut -d/ -f1)   # e.g. feature
NAME=$(echo "$CURRENT" | cut -d/ -f2)   # e.g. 123_dark_mode
ISSUE_NUM=$(echo "$NAME" | grep -oE '^[0-9]+')
```

**2. Merge target resolution**

| Branch type | Base | Targets |
|---|---|---|
| `feature` | `develop` | `develop` |
| `bugfix` | `develop` | `develop` |
| `release` | `develop` | `main develop` |
| `hotfix` | `main` | `main develop` |
| `support` | `main` | `main` |

**3. Context collection**
```bash
COMMITS=$(git log "$BASE".."$CURRENT" --oneline)
DIFF=$(git diff "$BASE"..."$CURRENT" --stat)
```
The `...` (three dots) in the diff command finds the common ancestor — it shows only what changed on this branch, not unrelated changes on `develop`.

**4. Prompt structure**

Similar to `git-commit.sh` but uses the full commit log instead of the staged diff, giving Gemini a higher-level view of the branch's purpose.

**5. Issue reference**

At merge time the issue is closed by appending `Close #N` in the commit body on a separate line, separated by a blank line:
```
feat: dark mode with system theme support

Close #123
```
GitHub automatically closes the referenced issue when this commit lands on `main` or the default branch.

**6. Merge loop**
```bash
for TARGET in $TARGETS; do
  git checkout "$TARGET" && git merge --no-ff "$CURRENT" -m "$FULL_MSG"
done
```
`--no-ff` enforces a merge commit even when a fast-forward would be possible, preserving the branch history in the graph.

**7. Auto-tag for release and hotfix**
```bash
if [ "$TYPE" = "release" ] || [ "$TYPE" = "hotfix" ]; then
  git tag -a "$NAME" -m "$FULL_MSG"
fi
```
The branch name (e.g. `2.1.0` or `789_payment_fix`) is used as the tag name.

**8. Branch cleanup**
```bash
git branch -d "$CURRENT"
```
The local branch is deleted after a successful merge. Remote branches must be deleted manually or via GitHub's "Delete branch" button on the PR.

---

## `.gitconfig` aliases

| Alias | Script / Command | Description |
|---|---|---|
| `git start <type> <name>` | inline shell function | Creates branch from correct base after pulling latest |
| `git c` | `git-commit.sh` | AI commit on staged files |
| `git finish` | `git-finish.sh` | AI merge + close issue + optional tag |
| `git publish` | inline | Push current branch to origin |
| `git st-flow` | inline grep | List all active flow branches |
| `git sync` | inline | Checkout develop + pull |

---

## Design decisions

**Why Gemini CLI instead of a direct API call?**  
Gemini CLI handles authentication via Google account, requires no API key management, and removes the need for `curl` + `python3` — making the setup lighter especially on Windows with Git Bash.

**Why separate scripts instead of inline aliases?**  
Git aliases have limited support for multi-line logic, conditionals, and variables. Bash scripts are easier to read, test, and maintain.

**Why `--no-ff` on every merge?**  
Fast-forward merges erase branch history from the graph. `--no-ff` keeps the topology clear — you can always tell where a feature started and ended.

**Why `ref #N` during work and `Close #N` only at finish?**  
`Close #N` triggers GitHub's automatic issue closing. Closing the issue mid-development would be misleading. `ref #N` keeps the link visible without side effects.
