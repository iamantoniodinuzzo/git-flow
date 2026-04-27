# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-04-27

### Added
- `install.sh` — cross-platform install/update script; copies scripts to `~/.git-scripts/` and links `gitconfig-aliases.ini` via `git config --global include.path` (idempotent, works on macOS and Windows Git Bash).
- `install.bat` — Windows wrapper that auto-detects Git Bash from the `git` installation path and delegates to `install.sh`; allows running the installer from PowerShell or CMD without WSL.

### Changed
- `README.md` Installation section simplified: manual copy steps and gitconfig editing replaced by a single `.\install.bat` (Windows) or `bash install.sh` (macOS/Linux) command.

## [0.3.0] - 2026-04-19

### Changed
- `git c` no longer requires Gemini CLI — opens the user's editor with a Conventional Commits template including branch context and staged file summary. Issue references (`ref #N`) are still injected automatically.
- `git finish` no longer requires Gemini CLI — auto-generates a merge message from branch type, name, and commit history. Interactive confirmation workflow is preserved.

### Removed
- Gemini CLI is no longer a mandatory dependency. AI-powered message generation may return as an optional, user-configurable feature in a future release (see issue tracker).
- Removed `GEMINI.md` (Gemini-specific system instructions no longer applicable).

## [0.2.2] - 2026-04-11

### Added
- Repository settings configuration in `.github/settings.yml` (SEO description, topics).
- Official contact email (`iamantoniodinuzzo@gmail.com`) across `README.md`, `SECURITY.md`, and `gitconfig-aliases.ini`.

### Changed
- Removed outdated CI badges and links from `README.md`.

## [0.2.1] - 2026-04-11

### Added
- Interactive push to origin after successful branch finish.
- Enhanced branch cleanup with confirmation and optional force delete.
- Improved issue number extraction logic to prevent false positives (e.g., from version numbers like 0.2.0).
- Automatic push of tags for release and hotfix branches.

### Fixed
- ShellCheck warnings in scripts for better reliability.
- MarkdownLint warnings in documentation.

## [0.2.0] - 2026-04-11

### Added
- `git init-flow` alias to initialize GitFlow from a `main`-only repo
- `git start <type> <name>` alias to create branches from the correct base
- `git finish` alias with AI-generated merge commit via Gemini CLI
- `git publish`, `git st-flow`, `git sync` utility aliases
- Automatic `Close #N` reference appended to merge commit messages
- Automatic tag creation on `release` and `hotfix` branch finish
- `CONTRIBUTING.md` with branching, commit, and PR conventions
- `docs/documentation.md` with full script behavior reference

### Changed
- User identity configuration moved to `gitconfig-aliases.ini` with clear placeholders

## [0.1.0] - 2026-04-01

### Added
- Initial `git c` alias with Gemini CLI-powered commit message generation
- Conventional Commits format enforcement in the AI prompt
- Automatic `ref #N` issue reference extracted from branch name
- Interactive confirmation prompt (accept / cancel / edit)
