# git-ai-flow 🤖

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/tonydetony/git-ai-flow/actions/workflows/ci.yml/badge.svg)](https://github.com/tonydetony/git-ai-flow/actions)

A lightweight GitFlow toolkit integrated with **Gemini CLI** for AI-assisted commit and merge messages.

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)

## Features
- **Smart Commits:** Generates Conventional Commits messages based on your staged diff.
- **Automated Merges:** Creates detailed merge summaries with issue references (e.g., `Close #123`).
- **Clean GitFlow:** Ready-to-use aliases for starting and finishing features, bugfixes, releases, and hotfixes.
- **Issue Integration:** Automatically extracts issue numbers from branch names.

## Requirements
- **Git** (tested on 2.40+)
- **Bash** (v4.0+)
- **[Gemini CLI](https://github.com/google/gemini-cli)** (logged in and working)

## Installation

### 1. Clone the repository
```bash
git clone https://github.com/tonydetony/git-ai-flow.git
cd git-ai-flow
```

### 2. Prepare the scripts directory

#### 🍎 macOS / 🐧 Linux
```bash
mkdir -p ~/.git-scripts
cp scripts/git-commit-script.sh ~/.git-scripts/git-commit.sh
cp scripts/git-finish-script.sh ~/.git-scripts/git-finish.sh
chmod +x ~/.git-scripts/*.sh
```

#### 🪟 Windows (PowerShell)
```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.git-scripts"
Copy-Item "scripts\git-commit-script.sh" -Destination "$HOME\.git-scripts\git-commit.sh"
Copy-Item "scripts\git-finish-script.sh" -Destination "$HOME\.git-scripts\git-finish.sh"
# chmod is not required on Windows
```

### 3. Configure your Git aliases
Open your `~/.gitconfig` (usually at `%USERPROFILE%\.gitconfig` on Windows) and append the contents of `gitconfig-aliases.ini`.

> ⚠️ **Warning:** The `gitconfig-aliases.ini` file starts with a `[user]` block. Before appending, check if you already have one:
> ```bash
> # In Bash/Git Bash:
> grep "\[user\]" ~/.gitconfig
> ```
> If you do, skip the first few lines of the `.ini` file and only append the `[alias]` section.

## Usage

### 1. Initialize Flow
If your project only has a `main` branch:
```bash
git init-flow
```

### 2. Start a Task
```bash
git start feature 123_dark_mode
# Creates branch feature/123_dark_mode from develop
```

### 3. Commit with AI
```bash
git add .
git c
# Gemini generates a message, you confirm/edit, commit is made
```

### 4. Finish and Merge
```bash
git finish
# Generates merge message, merges to develop (and main if needed), deletes branch
```

### 5. Release & Hotfix Workflow
For standard releases and urgent fixes:

1. **Prepare the Changelog:**
   Update `CHANGELOG.md` with the new version header (e.g., `## [1.0.0]`). Do not add a date yet.

2. **Start a release/hotfix:**
   ```bash
   # Automatically detects version from CHANGELOG.md
   git start release
   
   # Or specify manually
   git start hotfix v1.0.1
   ```

3. **Work and commit:**
   ```bash
   git add .
   git c
   ```

4. **Finish the branch:**
   ```bash
   git finish
   ```
   **What happens automatically:**
   - **Changelog Update:** If a matching version is found in `CHANGELOG.md` without a date, it automatically appends the current date (e.g., `## [1.0.0] - 2026-04-11`).
   - **Merge targets:** Merges into **both** `main` and `develop`.
   - **AI Summary:** Generates a detailed merge message from all branch commits.
   - **Tagging:** Automatically creates a Git tag with the version name (e.g., `v1.0.0`).
   - **Cleanup:** Deletes the local release/hotfix branch.

## Troubleshooting
- **Gemini not found:** Ensure `gemini` is in your PATH and you have run `gemini login`.
- **Permission denied (macOS/Linux):** Ensure you ran `chmod +x` on the scripts in `~/.git-scripts/`.
- **Bash not found (Windows):** Ensure Git Bash is installed (it comes with Git for Windows). The scripts are executed using the `bash` command defined in the aliases.
- **Alias conflict:** Check `~/.gitconfig` for existing aliases that might conflict with `c`, `finish`, or `start`.
