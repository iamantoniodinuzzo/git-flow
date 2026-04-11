# Contributing to git-ai-flow

Thank you for your interest in improving `git-ai-flow`! To maintain consistency and quality, please follow these guidelines.

## Development Environment Setup

1. **Prerequisites:**
   - Git 2.20+
   - Bash 4.0+ (macOS users: `brew install bash`)
   - Gemini CLI (properly logged in)
   - ShellCheck (`brew install shellcheck` or `sudo apt install shellcheck`)

2. **Local Testing:**
   - Make your changes to the scripts in the `scripts/` directory.
   - To test them locally, copy them to your `~/.git-scripts/` directory:
     ```bash
     cp scripts/git-commit-script.sh ~/.git-scripts/git-commit.sh
     cp scripts/git-finish-script.sh ~/.git-scripts/git-finish.sh
     ```
   - Use a separate test repository to verify the behavior.

## Linting and Code Style

Before submitting a PR, ensure your shell scripts pass ShellCheck:
```bash
shellcheck scripts/*.sh
```

**Code Style Rules:**
- Use 2-space indentation.
- Always quote variables (e.g., `"$VARIABLE"`) to prevent word splitting.
- Use `set -euo pipefail` for robustness.
- Prefer `printf` over `echo` for messages.
- Comments should explain *why*, not just *what*.

## Manual Testing Checklist

Before opening a PR, please verify:
- [ ] `git start feature 123_test` creates the branch from `develop`.
- [ ] `git start hotfix 1.2.1_fix` creates the branch from `main`.
- [ ] `git c` correctly generates a Conventional Commit message.
- [ ] `git finish` on a feature branch merges into `develop` and deletes the branch.
- [ ] `git finish` on a release/hotfix branch merges into BOTH `main` and `develop`.
- [ ] Error handling: try running `git c` without staged files.

## Branching & PRs

1. Fork the repo and create your branch from `develop`.
2. Name your branch: `feature/description` or `bugfix/description`.
3. Keep PRs focused on a single change.
4. If you modify the Gemini prompt, please provide at least 3 examples of the current output vs. the desired output in the PR description.

## AI Prompt Guidelines

When modifying prompts in `scripts/`:
- Keep the instructions concise.
- Ensure the output format is strictly defined (e.g., "Reply with ONLY...").
- Do not hardcode specific issue numbers in the prompt; use variables.
- Always prioritize English for the generated messages.
