---
name: git-workflow
description: >
  Operate git using the project's custom aliases (git start, git c, git finish,
  git publish, git sync, git st-flow, git init-flow). Use when the user asks to
  create a branch, commit, merge, push, or manage the git flow lifecycle.
user-invocable: true
---

## Alias quick reference

| Alias | Syntax | Backed by |
|---|---|---|
| `init-flow` | `git init-flow` | Inline alias — create `develop` from `main`/`master`, push to origin |
| `start` | `git start <type> <name> [--json]` | `~/.git-scripts/git-start.sh` |
| `c` | `git c` | `~/.git-scripts/git-commit.sh` — interactive Conventional Commit |
| `finish` | `git finish [--yes\|-y] [--json]` | `~/.git-scripts/git-finish.sh` — merge, tag, CHANGELOG |
| `publish` | `git publish [--json]` | `~/.git-scripts/git-publish.sh` — push current branch |
| `st-flow` | `git st-flow` | Inline alias — list active flow branches |
| `sync` | `git sync` | Inline alias — checkout develop + pull |

---

## Branch types and base routing

`git start <type> <name>` picks the base automatically:

| Type | Base branch |
|---|---|
| `feature` | `develop` |
| `bugfix` | `develop` |
| `release` | `develop` |
| `hotfix` | `main` / `master` |
| `support` | `main` / `master` |

**Naming convention — REQUIRED format: `<issue#>_<snake_case_name>`**

```bash
git start feature 42_auth_login   # ✅ → feature/42_auth_login from develop
git start feature issue-42-login  # ❌ wrong — no "issue-" prefix, use number only
git start hotfix 1.0.2            # → hotfix/1.0.2 from main
```

Multiple issues on one branch:
```bash
git start bugfix 44-45_fix_login  # → close both #44 and #45 on finish
```

---

## `git c` — interactive commit

Runs `~/.git-scripts/git-commit.sh`. Behavior:

1. Validates staged files exist (aborts if nothing staged)
2. Auto-detects issue number(s) from branch name (`feature/42_name` → `#42`)
3. Opens `$GIT_EDITOR` with a Conventional Commits template pre-filled with branch context and staged file stats
4. Strips `#` comment lines, validates non-empty, warns if not CC format
5. Shows preview, prompts: accept (`Y`) / re-edit (`e`) / cancel (`n`)
6. On accept: appends `(ref #<issue>)` to subject, runs `git commit`

**Always stage files before running `git c`.**

---

## `git finish` — merge and close branch

Runs `~/.git-scripts/git-finish.sh`. Merge targets by branch type:

| Branch type | Merges into | Tag created |
|---|---|---|
| `feature/*`, `bugfix/*` | `develop` | No |
| `release/*` | `main`/`master` + `develop` | Yes |
| `hotfix/*` | `main`/`master` + `develop` | Yes |
| `support/*` | `main`/`master` | No |

For `release/*` and `hotfix/*`: also updates `CHANGELOG.md` with current date and creates an annotated git tag.

**Flags:**

| Flag | Effect |
|---|---|
| _(none)_ | Interactive: prompts for merge message, push, branch deletion |
| `--yes` / `-y` | Non-interactive: auto-accepts all prompts |
| `--json` | Machine-readable JSON output; implies `--yes`; suppresses all human text |

**Requires clean working directory.** Stash or commit everything first.

**Refuses to run on `main`/`master`/`develop`.** These aren't flow branches; if a
release/hotfix merge conflict left you checked out on one, resolve it manually
(finish the merge commit, then `git tag` + `git push` yourself) instead of
re-running `git finish` there — it exits with `on_protected_branch` and never
merges, tags, or deletes that branch.

---

## `--json` flag — AI agent / CI mode

All three script-backed commands (`git start`, `git publish`, `git finish`) support `--json`.

- Human-readable output is suppressed; only one JSON line goes to stdout.
- `--json` implies `--yes` for `git finish` (interactive prompts would corrupt the JSON stream).
- Exit codes are always meaningful: `0` success, non-zero error — regardless of `--json`.

**Success payloads:**

```bash
git start feature 42_foo --json
# {"status":"ok","branch":"feature/42_foo","base":"develop"}

git publish --json
# {"status":"ok","branch":"feature/42_foo","remote":"origin"}

git finish --json
# {"status":"ok","branch":"feature/42_foo","merged_into":["develop"],"tag":null,"pushed":true,"deleted":true}

# release/hotfix (tag included):
# {"status":"ok","branch":"release/1.2.0","merged_into":["main","develop"],"tag":"1.2.0","pushed":true,"deleted":true}
```

**Error payload (any command):**

```bash
# {"status":"error","code":"dirty_working_tree","message":"Clean your working directory before merging. Commit or stash changes."}
```

**Use `--json` whenever running these commands programmatically** (AI agent flows, CI pipelines, non-TTY contexts).

---

## Typical feature lifecycle

```bash
git start feature 42_auth_login   # branch from develop
# [write code]
git add <files>                    # stage changes
git c                              # Conventional Commit (auto issue ref)
git finish --json                  # merge into develop, push, delete — JSON out
gh issue close 42                  # GitHub does NOT auto-close on merge
```

---

## Release / hotfix lifecycle

```bash
# 1. Pre-condition: add version header to CHANGELOG.md WITHOUT a date
#    ## [1.2.0]
#    ### Added
#    - Dark mode support

git start release 1.2.0            # branch from develop
# [bump version, update docs]
git add .
git c
git finish --json                   # CHANGELOG dated, merged → main+develop, tagged 1.2.0, pushed
```

Hotfix is the same but branches from `main`/`master`:

```bash
git start hotfix 1.2.1_urgent_fix
git c
git finish --json
```

---

## Gotchas

- **GitHub does NOT auto-close issues on merge** — always run `gh issue close <n>` after merging.
- **`git finish` requires clean working directory** — commit or stash everything first.
- **`git finish` refuses to run on `main`/`master`/`develop`** — never merges, tags, or deletes those branches; recover manually if a merge conflict left you there.
- **`git start` requires `develop` to exist** (except `hotfix`/`support`) — run `git init-flow` first on a fresh repo.
- **File exists on disk ≠ tracked by git** — verify with `git ls-files <path>`, not a filesystem check.
- **CHANGELOG header must exist without a date** before `git finish` on release/hotfix — the script adds the date automatically; if already dated, it skips the update.
