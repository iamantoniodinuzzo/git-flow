# git-flow

A lightweight GitFlow toolkit with Conventional Commits automation and interactive commit workflows, implemented as Bash scripts and Git aliases.

## Project Overview

**git-flow** simplifies the GitFlow workflow by providing automated tools for branch creation, committing, and merging. It ensures consistency by enforcing Conventional Commits and automatically linking issue numbers from branch names.

- **Main Technologies:** Bash (4.0+), Git (2.20+), ShellCheck.
- **Key Features:** Interactive commit templates, automated merge messages, automatic CHANGELOG updates for releases, and streamlined branch lifecycle management.

## Architecture

The project is structured as a set of Bash scripts that are invoked via Git aliases.

- `scripts/git-commit-script.sh`: Logic for `git c`. Opens an editor with a Conventional Commits template, validates the message, and commits.
- `scripts/git-finish-script.sh`: Logic for `git finish`. Generates merge messages, handles multi-target merges (e.g., release to `main`/`master` and `develop`), creates tags, and cleans up branches.
- `gitconfig-aliases.ini`: Defines the Git aliases that integrate these scripts into the user's `git` command.
- `install.sh` / `install.bat`: Installation scripts that copy scripts to `~/.git-scripts/` and configure Git to include the aliases.

## Building and Running

Since this is a collection of shell scripts, there is no "build" step in the traditional sense.

### Installation
To install the toolkit locally:
- **Windows:** `.\install.bat`
- **macOS/Linux:** `bash install.sh`

### Testing & Linting
- **Linting:** Use ShellCheck to lint the scripts.
  ```bash
  shellcheck scripts/*.sh
  ```
- **Manual Testing:** Follow the workflow described in the README (init-flow -> start -> c -> finish).

## Development Conventions

### Coding Style (Bash)
- **Version:** Target Bash 4.0+.
- **Indentation:** Use 2 spaces.
- **Variables:** Always quote variables (`"$VAR"`) to prevent word splitting and globbing.
- **Conditionals:** Prefer `[[ ... ]]` over `[ ... ]`.
- **Output:** Use `printf` instead of `echo` for user-facing messages.
- **Safety:** Scripts should use `set -euo pipefail`.

### Git & Commits
- **Conventional Commits:** All commits in this repository must follow the Conventional Commits specification.
- **Branch Naming:**
  - `feature/<issue>_<description>`
  - `bugfix/<issue>_<description>`
  - `release/<version>`
  - `hotfix/<version>`
  - `support/<description>`

### Workflow
- New features or bugfixes should be developed on branches created from `develop`.
- Hotfixes and releases are merged into both `main`/`master` and `develop`.
- Releases require a version header (e.g., `## [1.2.0]`) to be present in `CHANGELOG.md` before running `git finish`.
