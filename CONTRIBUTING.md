# Contributing to git-ai-flow

Thank you for considering a contribution! This project uses its own workflow, so please follow the guidelines below.

---

## Getting started

1. **Fork** this repository
2. **Clone** your fork locally
3. Follow the [installation steps](README.md#installation) so you can test your changes with the actual scripts

---

## Branching convention

Use the same naming convention this project documents:

```
feature/<issue_number>_<short_description>
bugfix/<issue_number>_<short_description>
```

Always branch from `develop`:

```bash
git checkout develop
git pull origin develop
git checkout -b feature/42_improve_prompt
```

---

## Commit messages

Please use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(commit): improve Gemini prompt for scoped messages
fix(finish): correct merge target for support branches
docs(readme): add troubleshooting section
chore: update gitconfig alias formatting
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`

> Of course, feel free to use `git c` from this very project to generate your commit messages.

---

## Pull requests

- Target branch: **`develop`** (never `main` directly)
- Keep PRs focused — one feature or fix per PR
- Update `docs/DOCUMENTATION.md` if you change script behavior
- Update `README.md` if you add or remove a command

### PR title format

Follow Conventional Commits for the PR title as well:

```
feat(finish): add GPT fallback when Gemini is unavailable
fix(commit): handle empty diff edge case
```

---

## Suggesting changes to prompts

The Gemini prompts inside the scripts are the core of this project. If you have an improvement:

1. Open an issue describing the current output vs. the expected output with a real example
2. Propose the new prompt wording in the issue before opening a PR

This avoids back-and-forth on subjective prompt phrasing.

---

## Reporting bugs

Open an issue with:

- Your OS and Git Bash version
- The command you ran
- The full terminal output
- Expected vs. actual behavior

---

## Code style

- Scripts are **bash** — keep them POSIX-compatible where possible
- Prefer clarity over cleverness
- Add a comment for any non-obvious logic
- Emoji in `echo` output is encouraged 🙂
