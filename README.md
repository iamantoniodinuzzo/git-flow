# git-ai-flow

> Git Flow aliases and AI-powered commit utilities using Gemini CLI.

Streamline your Git workflow with smart aliases and automatic commit message generation via **Gemini CLI**. Every commit follows [Conventional Commits](https://www.conventionalcommits.org/) and automatically references the related GitHub issue.

---

## Features

- `git init-flow` — initialize GitFlow on a repo that only has `main`
- `git start` — create a branch from the correct base (`main` or `develop`) based on type
- `git c` — stage-aware AI commit message generator with bullet-point context
- `git finish` — AI-generated merge commit, auto `Close #issue`, optional tag on release/hotfix
- `git publish` — push current branch to origin
- `git st-flow` — list all active flow branches
- `git sync` — pull latest develop

---

## Requirements

| Tool | Notes |
|---|---|
| [Git for Windows](https://git-scm.com/download/win) | Includes Git Bash |
| [Node.js](https://nodejs.org/) | Required by Gemini CLI |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `npm install -g @google/gemini-cli` |

> **macOS / Linux:** all tools work natively. Use your terminal instead of Git Bash.

---

## Installation

### 1. Install Gemini CLI and authenticate

```bash
npm install -g @google/gemini-cli
gemini  # first run → login with your Google account
```

### 2. Clone this repository

```bash
git clone https://github.com/YOUR_USERNAME/git-ai-flow.git
```

### 3. Copy the scripts

**Windows (Git Bash):**
```bash
mkdir -p ~/.git-scripts
cp git-ai-flow/scripts/git-commit.sh ~/.git-scripts/
cp git-ai-flow/scripts/git-finish.sh ~/.git-scripts/
```

**macOS / Linux:**
```bash
mkdir -p ~/.git-scripts
cp git-ai-flow/scripts/git-commit.sh ~/.git-scripts/
cp git-ai-flow/scripts/git-finish.sh ~/.git-scripts/
chmod +x ~/.git-scripts/git-commit.sh
chmod +x ~/.git-scripts/git-finish.sh
```

### 4. Add aliases to your `.gitconfig`

Open `~/.gitconfig` and add the content from `gitconfig-aliases.ini`, or run:

```bash
cat git-ai-flow/gitconfig-aliases.ini >> ~/.gitconfig
```

Then set your identity (if not already configured globally):

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

> **Note:** On Windows `~` resolves to `C:\Users\YourName\`.

---

## Branch naming convention

Scripts extract the GitHub issue number from the branch name. The expected format is:

```
<type>/<issue_number>_<description>
```

**Examples:**
```
feature/123_dark_mode
bugfix/456_crash_login
hotfix/789_payment_fix
release/2.1.0
```

| Type | Base branch | Merge target(s) |
|---|---|---|
| `feature` | `develop` | `develop` |
| `bugfix` | `develop` | `develop` |
| `release` | `develop` | `main` + `develop` |
| `hotfix` | `main` | `main` + `develop` |
| `support` | `main` | `main` |

---

## Usage

### Initialize GitFlow on a new repo

If your repository only has `main` (freshly created on GitHub), run this once before anything else:

```bash
git init-flow
# ✅ Branch develop creato e pushato su origin
```

All subsequent commands will work normally. The only exception is `git start hotfix` and `git start support`, which can run without `develop` — but `git finish` on a hotfix still needs it, so running `init-flow` first is always the safest choice.

### Start a branch

```bash
git start feature 123_dark_mode
git start bugfix 456_crash_login
git start hotfix 789_payment_fix
git start release 2.1.0
```

### Commit while working

```bash
git add lib/ui/dark_mode.dart
git c

# 🤖 Generating message with Gemini...
#
# 💬 Suggested message:
#    feat(ui): add dark mode screen (ref #123)
#
#    - Add DarkModeScreen widget in dark_mode.dart
#    - Introduce ThemeProvider with system theme detection
#    - Update AppColors with dark palette variants
#
#    Accept? [Y/n/e(dit)] →
```

### Finish and merge

```bash
git finish

# 🔍 Branch: feature/123_dark_mode → merge into: develop
# 🤖 Generating message with Gemini...
#
# 💬 Suggested message:
#    feat: dark mode with system theme support
#    Close #123
#
#    Accept? [Y/n/e(dit)] →
```

### Other aliases

```bash
git publish        # push current branch to origin
git st-flow        # list active flow branches
git sync           # checkout develop + pull
```

---

## `develop` branch requirement

GitFlow requires `develop` to exist for almost every operation. The only exception is `support`, which interacts exclusively with `main`.

| Type | Needs `develop` for `start` | Needs `develop` for `finish` |
|---|---|---|
| `feature` | ✅ | ✅ |
| `bugfix` | ✅ | ✅ |
| `release` | ✅ | ✅ |
| `hotfix` | ❌ (starts from `main`) | ✅ (merges back) |
| `support` | ❌ | ❌ |

Both `git start` and `git finish` will show a clear error if `develop` is missing, with instructions to run `git init-flow`.

---

## Prompt interaction

Both `git c` and `git finish` show a confirmation prompt before acting:

| Input | Action |
|---|---|
| `Y` or Enter | Accept AI message |
| `n` | Cancel operation |
| `e` | Manually type a custom message |

When editing manually, the `ref #N` / `Close #N` issue reference is still appended automatically.

---

## Troubleshooting

**Gemini returns empty output**
```bash
gemini  # re-authenticate
```

**`git start` fails on pull**
Make sure `origin` is set and you have network access:
```bash
git remote -v
```

**Issue number not detected**
Ensure your branch name starts with digits: `123_feature_name`, not `feature_name_123`.
