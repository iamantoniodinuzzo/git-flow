# GEMINI.md - git-ai-flow

## Project Overview
**git-ai-flow** is a collection of Git aliases and Bash scripts designed to streamline Git workflows using AI-powered automation via the **Gemini CLI**. It implements a modified GitFlow process with automatic commit and merge message generation following the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Key Features
- **AI Commits (`git c`):** Generates detailed, multi-line commit messages based on staged changes.
- **AI Merge (`git finish`):** Automates branch merging and generates descriptive merge messages with issue closing references.
- **GitFlow Automation (`git start`):** Standardizes branch creation from correct base branches (`main` or `develop`).
- **Issue Tracking:** Automatically extracts issue numbers from branch names (e.g., `feature/123_description`) to link commits and close issues.

### Architecture & Technologies
- **Shell Scripts:** Core logic resides in Bash scripts (`scripts/`).
- **Git Aliases:** Defined in `gitconfig-aliases.ini` to provide a seamless CLI experience.
- **Gemini CLI:** Used for generating commit and merge messages.
- **Node.js:** Runtime requirement for Gemini CLI.

---

## Installation & Setup
The project is intended to be installed globally on a developer's machine.

### Prerequisites
- [Git for Windows](https://git-scm.com/download/win) (for Git Bash) or any Unix-like terminal.
- [Node.js](https://nodejs.org/).
- [Gemini CLI](https://github.com/google-gemini/gemini-cli): `npm install -g @google/gemini-cli` followed by `gemini` to authenticate.

### Configuration
1. **Scripts:** Copy files from `scripts/` to `~/.git-scripts/`.
2. **Aliases:** Append content from `gitconfig-aliases.ini` to your `~/.gitconfig`.
3. **Permissions:** Ensure scripts are executable (macOS/Linux): `chmod +x ~/.git-scripts/*.sh`. (Not required on Windows).

---

## Development Conventions

### Branch Naming
Branches MUST follow the pattern: `<type>/<issue_number>_<description>`
- **Example:** `feature/42_add-auth-layer`
- **Types:** `feature`, `bugfix`, `release`, `hotfix`, `support`.

### Commit Style
- **Conventional Commits:** All generated messages use types like `feat`, `fix`, `chore`, `docs`, `test`, `style`, `refactor`, `perf`.
- **Issue References:**
  - `git c` appends `(ref #N)` to the first line.
  - `git finish` appends `Close #N` to the footer.

### Workflow Commands
- `git init-flow`: Set up `develop` branch.
- `git start <type> <name>`: Create a new flow branch.
- `git c`: Stage changes first, then run for AI-generated commit.
- `git finish`: Merge back to targets and delete the branch.
- `git publish`: Push current branch to origin.
- `git sync`: Pull latest `develop`.

---

## Project Structure
- `scripts/`: Implementation of the AI logic (Bash).
- `gitconfig-aliases.ini`: Git configuration template.
- `docs/`: Additional documentation.
- `CONTRIBUTING.md`: Guidelines for project contributions.
