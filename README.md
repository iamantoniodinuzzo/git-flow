# git-flow

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A lightweight GitFlow toolkit with Conventional Commits automation and interactive commit workflows.

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Command Reference](#command-reference)
- [Troubleshooting](#troubleshooting)

## Features
- **Smart Commits:** Opens your editor with a Conventional Commits template pre-filled with branch context and staged file summary.
- **Automated Merges:** Auto-generates merge messages from branch metadata and commit history, with issue references (e.g., `Close #123`).
- **Clean GitFlow:** Ready-to-use aliases for starting and finishing features, bugfixes, releases, and hotfixes.
- **CI/Automation Ready:** `git finish --yes` skips all interactive prompts for use in pipelines, AI agents, or scripts.
- **Issue Integration:** Automatically extracts issue numbers from branch names (e.g., `feature/123_dark_mode` → `#123`).

## Requirements

| Requirement | macOS / Linux | Windows |
|---|---|---|
| Git | 2.20+ | 2.20+ (via [Git for Windows](https://gitforwindows.org/)) |
| Bash | 4.0+ (`brew install bash` on macOS) | Included with Git for Windows (Git Bash) |
| ShellCheck (dev only) | `brew install shellcheck` / `apt install shellcheck` | `scoop install shellcheck` or [download](https://github.com/koalaman/shellcheck) |

> **Windows note:** The scripts are executed via Git Bash. PowerShell alone is not sufficient — you must have Git for Windows installed, which bundles Git Bash.

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/iamantoniodinuzzo/git-flow.git
cd git-flow
```

### 2. Run the install script

#### Windows (PowerShell or CMD)

```powershell
.\install.bat
```

#### macOS / Linux

```bash
bash install.sh
```

The script:
- Copies the scripts to `~/.git-scripts/`
- Sets executable permissions (macOS / Linux only)
- Links `gitconfig-aliases.ini` to your `~/.gitconfig` via `include.path` — run it once and all future alias changes are picked up automatically
- Installs a [Claude Code](https://claude.ai/code) skill to `~/.claude/skills/git-workflow/` so Claude can drive the git-flow commands in any repo

> **Updating:** Re-run the same command any time after pulling changes to refresh the installed scripts and skill.

### 3. Set your editor

The `git c` command opens the editor defined by `core.editor` in your Git config.

#### macOS / Linux

```bash
# nano
git config --global core.editor "nano"

# VS Code
git config --global core.editor "code --wait"

# Vim
git config --global core.editor "vim"
```

#### Windows

```bash
# VS Code (Git Bash)
git config --global core.editor "code --wait"

# Notepad++
git config --global core.editor "'C:/Program Files/Notepad++/notepad++.exe' -multiInst -notabbar -nosession -noPlugin"

# Vim (bundled with Git for Windows)
git config --global core.editor "vim"
```

### 4. Claude Code integration (optional)

`install.sh` automatically installs a Claude Code skill to `~/.claude/skills/git-workflow/`.
Once installed, Claude knows:

- When and how to use each alias (`git start`, `git c`, `git finish`, `git publish`, etc.)
- Branch routing rules and naming conventions
- The `--json` flag for structured, non-interactive output (preferred in AI-agent flows)

When operating programmatically, Claude will use `--json` so it can parse results and errors reliably:

```bash
git start feature 42_foo --json
# {"status":"ok","branch":"feature/42_foo","base":"develop"}

git finish --json
# {"status":"ok","branch":"feature/42_foo","merged_into":["develop"],"tag":null,"pushed":true,"deleted":true}
```

> **Requires [Claude Code](https://claude.ai/code).** If you do not use Claude Code, this step has no effect.

---

## Usage

### Initialize Flow

If your project only has a `main` or `master` branch, create `develop`:

```
$ git init-flow
✅ Branch develop created and pushed to origin
```

### Start a Task

```
$ git start feature 123_dark_mode
✅ Branch feature/123_dark_mode created from develop

$ git start hotfix 1.2.1_urgent_fix
✅ Branch hotfix/1.2.1_urgent_fix created from main
```

Branch naming convention: `<type>/<issue_number>_<description>`

Supported types: `feature`, `bugfix`, `release`, `hotfix`, `support`

For `feature`/`bugfix`, `git start` warns (non-fatal, printed to stderr) if the
`<issue_number>_` prefix is missing — the branch is still created, but auto
issue-ref detection in `git c`/`git finish` won't fire. Pass `--no-issue` to
silence the warning. `release`/`hotfix`/`support` use version-style names and
are never checked.

### Commit

```
$ git add src/theme.js
$ git c
```

Your editor opens with a pre-filled template:

```
                                              ← write your message here
# ─── Conventional Commits Guide ──────────────────────────────
# Format:  <type>(<scope>): <description>   (max 72 chars)
# Types:   feat | fix | docs | style | refactor | perf | test | chore
# Scope:   optional, only if clearly applicable (e.g. ui, api, core)
# Body:    blank line + bullet points describing specific changes
#
# Branch:  feature/123_dark_mode
# Issue:   #123 (will be appended automatically as "(ref #123)")
#
# Staged changes:
#    src/theme.js | 14 ++++++++++----
# ─────────────────────────────────────────────────────────────
```

Save and close the editor. The tool then shows a preview and asks for confirmation:

```
💬 Commit message:
   feat(ui): add dark mode toggle (ref #123)

   Accept? [Y/n/e(dit)] (default: y) → y
✅ Commit successful: "feat(ui): add dark mode toggle (ref #123)"
```

**Options at the prompt:**
- `Y` (default) — commit
- `n` — cancel without committing
- `e` — reopen the editor to edit the message

**Error — no staged files:**
```
$ git c
❌ No files in staging. Run first: git add <files>
```

**Non-interactive mode (`-m`) — for AI agents / CI:**

```
$ git c -m "feat(ui): add dark mode toggle" --json
{"status":"ok","branch":"feature/123_dark_mode","sha":"a1b2c3d","message":"feat(ui): add dark mode toggle (ref #123)"}
```

- Skips the editor entirely; still validates staged files exist and auto-appends `(ref #N)`.
- `--body "<text>"` adds a blank-line-separated body.
- `--json` requires `-m` (there's no editor to fall back to in JSON mode).

### Finish and Merge

```
$ git finish
🔍 Branch: feature/123_dark_mode → merge into: develop

💬 Merge message:
feat: merge feature/123_dark_mode into develop

- a1b2c3d feat(ui): add dark mode toggle (ref #123)
Close #123

   Accept? [Y/n/e(dit)] (default: y) → y
✅ Merged into develop

🚀 Push to origin? [Y/n] (default: y) → y
📤 Pushing develop...
✅ Push completed

🗑️  Delete branch 'feature/123_dark_mode'? [Y/n] (default: y) → y
🗑️  Branch 'feature/123_dark_mode' deleted

🎉 Done! → "feat: merge feature/123_dark_mode into develop"
```

**Non-interactive mode (`--yes` / `-y`):**

Use `git finish --yes` to skip all prompts — useful in CI pipelines, AI agents, or scripts:

```
$ git finish --yes
🔍 Branch: feature/123_dark_mode → merge into: develop
...
✅ Merged into develop
📤 Pushing develop...
✅ Push completed
🗑️  Branch 'feature/123_dark_mode' deleted
🎉 Done! → "feat: merge feature/123_dark_mode into develop"
```

**Error — uncommitted changes:**
```
$ git finish
❌ Clean your working directory before merging. Commit or stash changes.
```

**Error — no commits on branch:**
```
$ git finish
⚠️  No commits found compared to develop. Have you committed your changes?
```

**Error — run on a protected branch:**
```
$ git finish
❌ Refusing to run 'git finish' on 'main' (not a flow branch). If you just resolved a release/hotfix merge conflict here: 1) finish the merge with 'git commit' if one is still in progress; 2) tag and push manually: git tag -a <version> -m <message> && git push origin main --tags. Otherwise checkout your release/hotfix/feature branch before re-running 'git finish'.
```
`git finish` never merges, tags, or deletes `main`/`master`/`develop` — if a merge conflict left you checked out on one of them, finish it manually.

**JSON output (`--json`):**

Pass `--json` to any command to get machine-readable output on stdout. Human-readable text is suppressed. `--json` implies `--yes` for `git finish` (interactive prompts would corrupt the JSON stream). For `git c`, `--json` requires `-m` (no editor in JSON mode).

```
$ git start feature 42_foo --json
{"status":"ok","branch":"feature/42_foo","base":"develop"}

$ git c -m "feat(auth): add login retry" --json
{"status":"ok","branch":"feature/42_foo","sha":"abc123","message":"feat(auth): add login retry (ref #42)"}

$ git publish --json
{"status":"ok","branch":"feature/42_foo","remote":"origin"}

$ git finish --json
{"status":"ok","branch":"feature/42_foo","merged_into":["develop"],"tag":null,"pushed":true,"deleted":true}
```

On error, every command returns a structured object with `status`, `code`, and `message`:
```
$ git finish --json
{"status":"error","code":"dirty_working_tree","message":"Clean your working directory before merging. Commit or stash changes."}
```

Exit codes are always meaningful: `0` on success, non-zero on error — regardless of `--json`.

### Release & Hotfix Workflow

#### 1. Prepare the Changelog

Before starting a release or hotfix, add the version header to `CHANGELOG.md` — **without a date** (the date is added automatically by `git finish`):

```markdown
## [1.2.0]

### Added
- Dark mode support
```

#### 2. Start the branch

```
$ git start release 1.2.0
✅ Branch release/1.2.0 created from develop

# Or for an urgent fix:
$ git start hotfix 1.2.1
✅ Branch hotfix/1.2.1 created from main
```

#### 3. Commit your changes

```
$ git add .
$ git c
```

#### 4. Finish

```
$ git finish
📝 Updated CHANGELOG.md with date 2026-04-27
🔍 Branch: release/1.2.0 → merge into: main develop

💬 Merge message:
chore(release): merge release/1.2.0 into main develop

- f3e2d1c chore: bump version to 1.2.0
Close #456

   Accept? [Y/n/e(dit)] (default: y) → y
✅ Merged into main
✅ Merged into develop
🏷️  Tag '1.2.0' created

🚀 Push to origin? [Y/n] (default: y) → y
📤 Pushing main...
📤 Pushing develop...
📤 Pushing tags...
✅ Push completed

🗑️  Delete branch 'release/1.2.0'? [Y/n] (default: y) → y
🗑️  Branch 'release/1.2.0' deleted

🎉 Done! → "chore(release): merge release/1.2.0 into main develop"
```

---

## Command Reference

| Command | Description |
|---|---|
| `git init-flow` | Creates `develop` from `main` or `master` and pushes to origin |
| `git start <type> <name>` | Creates `type/name` from the correct base branch (`develop` or `main`/`master`); warns if `feature`/`bugfix` name has no `<issue#>_` prefix |
| `git c` | Interactive commit with Conventional Commits template |
| `git c -m "<subject>" [--body "<text>"] [--json]` | Non-interactive commit, auto issue-ref, machine-readable output |
| `git finish` | Merges the current branch, tags if release/hotfix, cleans up (interactive); refuses on `main`/`master`/`develop` |
| `git finish --yes` | Same as above but skips all prompts (non-interactive mode) |
| `git finish --json` | Non-interactive, outputs structured JSON result to stdout |
| `git publish` | Pushes the current branch to origin |
| `git publish --json` | Push, outputs structured JSON result to stdout |
| `git start <type> <name> --json` | Branch creation, outputs structured JSON result to stdout |
| `git sync` | Checks out `develop` and pulls latest |
| `git st-flow` | Lists all active GitFlow branches |

**Merge targets by branch type:**

| Branch type | Merges into | Tag created |
|---|---|---|
| `feature/*` | `develop` | No |
| `bugfix/*` | `develop` | No |
| `release/*` | `main`/`master` + `develop` | Yes |
| `hotfix/*` | `main`/`master` + `develop` | Yes |
| `support/*` | `main`/`master` | No |

---

## Troubleshooting

**Editor does not open**
Ensure `core.editor` is set in your `~/.gitconfig`. VS Code users must use `code --wait`.

**Permission denied (macOS/Linux)**
Run `chmod +x ~/.git-scripts/*.sh`.

**`bash: command not found` or scripts don't run (Windows)**
Ensure Git for Windows is installed. The aliases call `bash`, which must be on your PATH. Open a new Git Bash terminal after installation. To install or update the scripts from PowerShell, use `.\install.bat` instead of `bash install.sh`.

**Alias conflict**
Check `~/.gitconfig` for existing aliases that might conflict with `c`, `finish`, or `start`. Rename the conflicting alias.

**`develop` branch does not exist**
Run `git init-flow` before using `git start` for any branch type other than `support`.

---

For questions, suggestions, or security reports (see [SECURITY.md](SECURITY.md)), contact **Antonio Di Nuzzo** at iamantoniodinuzzo@gmail.com.
