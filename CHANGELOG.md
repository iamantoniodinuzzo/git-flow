# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
