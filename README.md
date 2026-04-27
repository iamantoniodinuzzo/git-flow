# git-ai-flow

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
git clone https://github.com/iamantoniodinuzzo/git-ai-flow.git
cd git-ai-flow
```

### 2. Copy the scripts

#### macOS / Linux

```bash
mkdir -p ~/.git-scripts
cp scripts/git-commit-script.sh ~/.git-scripts/git-commit.sh
cp scripts/git-finish-script.sh ~/.git-scripts/git-finish.sh
chmod +x ~/.git-scripts/*.sh
```

#### Windows (PowerShell)

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.git-scripts"
Copy-Item "scripts\git-commit-script.sh" -Destination "$HOME\.git-scripts\git-commit.sh"
Copy-Item "scripts\git-finish-script.sh" -Destination "$HOME\.git-scripts\git-finish.sh"
# chmod is not needed on Windows
```

### 3. Configure Git aliases

Open `~/.gitconfig` (`%USERPROFILE%\.gitconfig` on Windows) and append the contents of `gitconfig-aliases.ini`.

> **Warning:** `gitconfig-aliases.ini` starts with a `[user]` block. If you already have one in your `~/.gitconfig`, skip those lines and only append the `[alias]` section.
>
> Check first:
> ```bash
> grep "\[user\]" ~/.gitconfig
> ```

### 4. Set your editor

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

---

## Usage

### Initialize Flow

If your project only has a `main` branch, create `develop`:

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
⚠️  No files in staging. Run first: git add <files>
```

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
| `git init-flow` | Creates `develop` from `main` and pushes to origin |
| `git start <type> <name>` | Creates `type/name` from the correct base branch |
| `git c` | Interactive commit with Conventional Commits template |
| `git finish` | Merges the current branch, tags if release/hotfix, cleans up |
| `git publish` | Pushes the current branch to origin |
| `git sync` | Checks out `develop` and pulls latest |
| `git st-flow` | Lists all active GitFlow branches |

**Merge targets by branch type:**

| Branch type | Merges into | Tag created |
|---|---|---|
| `feature/*` | `develop` | No |
| `bugfix/*` | `develop` | No |
| `release/*` | `main` + `develop` | Yes |
| `hotfix/*` | `main` + `develop` | Yes |
| `support/*` | `main` | No |

---

## Troubleshooting

**Editor does not open**
Ensure `core.editor` is set in your `~/.gitconfig`. VS Code users must use `code --wait`.

**Permission denied (macOS/Linux)**
Run `chmod +x ~/.git-scripts/*.sh`.

**`bash: command not found` or scripts don't run (Windows)**
Ensure Git for Windows is installed. The aliases call `bash`, which must be on your PATH. Open a new Git Bash terminal after installation.

**Alias conflict**
Check `~/.gitconfig` for existing aliases that might conflict with `c`, `finish`, or `start`. Rename the conflicting alias.

**`develop` branch does not exist**
Run `git init-flow` before using `git start` for any branch type other than `support`.

---

For questions, suggestions, or security reports (see [SECURITY.md](SECURITY.md)), contact **Antonio Di Nuzzo** at iamantoniodinuzzo@gmail.com.
