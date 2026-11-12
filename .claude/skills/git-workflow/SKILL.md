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
| `start` | `git start <type> <name> [--json] [--no-issue] [--worktree [<path>]]` | `~/.git-scripts/git-start.sh` |
| `c` | `git c [-m <subject>] [--body <text>] [--json]` | `~/.git-scripts/git-commit.sh` — interactive Conventional Commit |
| `finish` | `git finish [--yes\|-y] [--json] [--keep-worktree]` | `~/.git-scripts/git-finish.sh` — merge, tag, CHANGELOG |
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

**Naming convention — format: `<issue#>_<snake_case_name>`**

```bash
git start feature 42_auth_login   # ✅ → feature/42_auth_login from develop
git start feature issue-42-login  # ❌ wrong — no "issue-" prefix, use number only
git start hotfix 1.0.2            # → hotfix/1.0.2 from main
```

Required for auto issue-ref detection (`git c`, `git finish`) on `feature`/`bugfix`
branches. `git start` warns (non-fatal, stderr only) if the prefix is missing on
those types; pass `--no-issue` to silence it. `release`/`hotfix`/`support` use
version-style names and are never checked.

Multiple issues on one branch:
```bash
git start bugfix 44-45_fix_login  # → close both #44 and #45 on finish
```

---

## `git c` — commit

Runs `~/.git-scripts/git-commit.sh`. Two modes:

**Interactive (default, no `-m`):**

1. Validates staged files exist (aborts if nothing staged)
2. Auto-detects issue number(s) from branch name (`feature/42_name` → `#42`)
3. Opens `$GIT_EDITOR` with a Conventional Commits template pre-filled with branch context and staged file stats
4. Strips `#` comment lines, validates non-empty, warns if not CC format
5. Shows preview, prompts: accept (`Y`) / re-edit (`e`) / cancel (`n`)
6. On accept: appends `(ref #<issue>)` to subject, runs `git commit`

**Non-interactive (`-m`) — for AI agents / CI:**

```bash
git c -m "<subject>" [--body "<text>"] [--json]
```

- Skips the editor entirely; validates staged files exist first.
- Auto-appends `(ref #N)` to the subject, same as interactive mode.
- Warns (non-fatal) if the subject doesn't look like Conventional Commits.
- `--body` adds a blank-line-separated body to the commit message.
- `--json` requires `-m` (there's no editor to fall back to) and emits:
  ```bash
  git c -m "feat(auth): add login retry" --json
  # {"status":"ok","branch":"feature/42_auth_login","sha":"abc123","message":"feat(auth): add login retry (ref #42)"}
  ```

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
| `--keep-worktree` | Run from a linked worktree: merge, but keep the worktree (and therefore the branch) instead of removing it |

**Requires clean working directory.** Stash or commit everything first.

**Refuses to run on `main`/`master`/`develop`.** These aren't flow branches; if a
manual merge left you checked out on one, resolve it manually
(finish the merge commit, then `git tag` + `git push` yourself) instead of
re-running `git finish` there — it exits with `on_protected_branch` and never
merges, tags, or deletes that branch.

---

## `--json` flag — AI agent / CI mode

All four script-backed commands (`git start`, `git c`, `git publish`, `git finish`) support `--json`.

- Human-readable output is suppressed; only one JSON line goes to stdout.
- `--json` implies `--yes` for `git finish` (interactive prompts would corrupt the JSON stream).
- `--json` requires `-m` for `git c` (no editor in JSON mode).
- Exit codes are always meaningful: `0` success, non-zero error — regardless of `--json`.

**Success payloads:**

```bash
git start feature 42_foo --json
# {"status":"ok","branch":"feature/42_foo","base":"develop"}

git c -m "feat(auth): add login retry" --json
# {"status":"ok","branch":"feature/42_foo","sha":"abc123","message":"feat(auth): add login retry (ref #42)"}

git publish --json
# {"status":"ok","branch":"feature/42_foo","remote":"origin"}

git start feature 42_foo --worktree --json
# {"status":"ok","branch":"feature/42_foo","base":"develop","worktree":"/abs/path/repo_wt_42_foo"}

git finish --json
# {"status":"ok","branch":"feature/42_foo","merged_into":["develop"],"tag":null,"pushed":true,"deleted":true,"worktree_removed":false}

# release/hotfix (tag included):
# {"status":"ok","branch":"release/1.2.0","merged_into":["main","develop"],"tag":"1.2.0","pushed":true,"deleted":true,"worktree_removed":false}
```

**Error payload (any command):**

```bash
# {"status":"error","code":"dirty_working_tree","message":"Clean your working directory before merging. Commit or stash changes."}
```

**Use `--json` whenever running these commands programmatically** (AI agent flows, CI pipelines, non-TTY contexts).

---

## Typical feature lifecycle

```bash
git start feature 42_auth_login --json      # branch from develop
# [write code]
git add <files>                              # stage changes
git c -m "feat(auth): add login retry" --json  # Conventional Commit (auto issue ref), non-interactive
git finish --json                            # merge into develop, push, delete — JSON out
gh issue close 42                            # only needed when the default branch is not the merge target (see Gotchas)
```

---

## Parallel work with worktrees

To work on two issues at once (one agent or terminal each), give every issue its own linked worktree. One branch per issue, one worktree per branch — never share a worktree between issues.

```bash
# From the main checkout, once per issue:
git start feature 42_auth_login --worktree --json   # → worktree at ../<repo>_wt_42_auth_login
git start feature 43_dark_mode  --worktree --json   # → worktree at ../<repo>_wt_43_dark_mode
# JSON payload carries "worktree":"<absolute path>" — cd there and work.

# Inside each worktree, nothing special:
git add <files>
git c -m "feat(auth): add login retry" --json
git publish --json                                  # optional

# Still inside the worktree, when done:
git finish --json   # merges into develop, pushes, removes the worktree, deletes the branch
                    # → "worktree_removed":true
```

- The main checkout is never moved by `git start --worktree`: the branch is cut from `origin/develop` (local `develop` if there is no remote, or if local is ahead of origin).
- Custom location: `git start feature 42_foo --worktree <path>` (or `--worktree=<path>`).
- `git finish` merges in whichever worktree has the target checked out (usually the main checkout, which must then be clean → else `target_worktree_dirty`). If no worktree has it, it checks the target out in the current one. Finish worktrees one after the other: the second merge sees the first.
- `git finish` from a linked worktree refuses on untracked files too (`dirty_working_tree`), since they would block removing the worktree. `--keep-worktree` merges but keeps the worktree and branch.
- `git start` without `--worktree` inside a linked worktree fails with `in_linked_worktree` — add `--worktree` or run it from the main checkout.
- `git c` and `git publish` work unchanged in any worktree. `git sync` is for the main checkout.
- Per-worktree tooling state (dependency install, build output) is the project's job, not this toolchain's.
- Epics/parent issues get no branch: create worktrees for their sub-issues, one each.

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

- **Issue auto-close depends on the repo's default branch.** `git finish` appends `Close #N` to the merge message; GitHub closes the issue a few seconds after that merge lands on the **default branch**. Check it with `gh repo view --json defaultBranchRef`. Default `develop`: nothing to do, confirm with `gh issue view <n>`. Default `main`: feature and bugfix issues stay open until the release or hotfix merge, so run `gh issue close <n>` after `git finish`.
- **`git finish` requires clean working directory** — commit or stash everything first.
- **`git finish` refuses to run on `main`/`master`/`develop`** — never merges, tags, or deletes those branches; recover manually if you end up there. A `merge_conflict` error means the merge was aborted and the target is unchanged: merge the target into your branch, resolve, commit, and rerun `git finish`.
- **`git start` requires `develop` to exist** (except `hotfix`/`support`) — run `git init-flow` first on a fresh repo.
- **`git start feature`/`bugfix` warns (stderr, non-fatal) if `<issue#>_` prefix is missing** — branch is still created, but auto issue-ref in `git c`/`git finish` won't fire. Use `--no-issue` to silence.
- **Worktree error codes:** `in_linked_worktree` (`git start` without `--worktree` inside a linked worktree), `worktree_path_exists`, `worktree_add_failed`, `fetch_failed` (`git start --worktree`), `target_worktree_dirty` (`git finish`, merge target's worktree has uncommitted changes).
- **File exists on disk ≠ tracked by git** — verify with `git ls-files <path>`, not a filesystem check.
- **CHANGELOG header must exist without a date** before `git finish` on release/hotfix — the script adds the date automatically; if already dated, it skips the update.
