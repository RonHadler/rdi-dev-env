# rdi-dev-env

Single source of truth for RDI's development environment configuration, AI agent context templates, and Claude Code extensions.

**Repo:** https://github.com/RonHadler/rdi-dev-env

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [What's Included](#whats-included)
- [tmux Development Environment](#tmux-development-environment)
- [Quality Gate](#quality-gate)
- [Claude Code Commands](#claude-code-commands)
- [Claude Code Skills](#claude-code-skills)
- [Templates](#templates)
- [Setting Up a New Project](#setting-up-a-new-project)
- [CI/CD Strategy](#cicd-strategy)
- [Updating](#updating)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

| Requirement | Install |
|-------------|---------|
| **WSL2** (Ubuntu) | Windows Settings > Features > WSL, then `wsl --install -d Ubuntu` |
| **tmux** | `sudo apt install tmux` |
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` |
| **Git** | Pre-installed in WSL2 Ubuntu |
| **GitHub CLI** | `sudo apt install gh` then `gh auth login` |
| **Node.js 20+** | `nvm install 20` (for Node.js projects) |
| **Python 3.11+** | `sudo apt install python3` + `pip install uv` (for Python projects) |
| **Go 1.22+** | [golang.org/dl](https://go.dev/dl/) or Docker (for Go projects) |

Only install language runtimes for the project types you work on.

---

## Quick Start

```bash
# 1. Clone the repo
cd /mnt/c/Dev          # WSL2
# cd /c/Dev            # Git Bash on Windows
git clone https://github.com/RonHadler/rdi-dev-env.git

# 2. Install symlinks (tmux config, Claude commands, Claude skills)
cd rdi-dev-env
bash install.sh

# 3. Launch a dev environment for any project
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-novusiq elevateai
```

That's it. You now have tmux configured, 3 Claude Code slash commands, and 5 Agent Skills active globally.

---

## What's Included

| Directory | Files | Purpose |
|-----------|-------|---------|
| `tmux/` | `tmux.conf`, `tmux-dev.sh` | tmux config + one-command 3-pane launcher |
| `scripts/` | `quality-gate.sh` | Continuous quality watch (security, types, tests) |
| `commands/` | `review-pr.md`, `quality.md`, `deploy.md` | Claude Code `/slash-commands` |
| `skills/` | 5 skills with references | Claude Code Agent Skills (auto-triggered) |
| `templates/` | 4 agent context + 5 workflow + 2 config templates | Copy to new projects, customize |
| `install.sh` | Symlink installer | Wires everything into the right locations |

---

## tmux Development Environment

### Layout

Every RDI project uses the same 3-pane layout:

```
+------------------------------+----------------------+
|                              |                      |
|   Pane 1: Claude Code        |  Pane 2: Quality     |
|   (main development)         |  Gate (watch)        |
|                              |                      |
|   $ claude                   |  Security + Types    |
|                              |  + Tests on save     |
|                              +----------------------+
|                              |                      |
|                              |  Pane 3: Dev Server  |
|                              |                      |
|                              |  $ npm run dev       |
|                              |                      |
+------------------------------+----------------------+
```

### tmux-dev.sh — One-Command Launcher

```bash
bash tmux/tmux-dev.sh [project-path] [session-name]
```

**Examples:**
```bash
# ElevateAI (Next.js)
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-novusiq elevateai

# Argus MCP (Go/Docker)
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-argus-mcp argus

# Current directory, auto-named
bash tmux/tmux-dev.sh .

# Re-attach to existing session
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-novusiq elevateai  # auto-attaches if exists
```

**What it does:**
1. Creates a named tmux session with 3 panes
2. Sets pane titles ("Claude Code", "Quality Gate", "Dev Server")
3. Auto-detects and starts the dev server in Pane 3
4. Auto-detects and starts the quality gate in Pane 2
5. Focuses Pane 1 for you to run `claude`

**Auto-detected dev commands:**

| Project Type | Detection | Dev Command |
|-------------|-----------|-------------|
| Node.js | `package.json` with `"dev"` script | `npm run dev` |
| Go (Makefile) | `Makefile` with `dev:` or `up:` target | `make dev` or `make up` |
| Python | `pyproject.toml` | Manual start (prints message) |
| Docker | `docker-compose.yml` | `docker compose up` |

**Quality gate detection:** Uses the project's own `scripts/quality-gate.sh` if it exists, otherwise falls back to the generic one from rdi-dev-env.

### tmux.conf — Key Bindings

| Key | Action |
|-----|--------|
| `Alt+Arrow` | Switch between panes (no prefix needed) |
| `Prefix + \|` | Split pane horizontally |
| `Prefix + -` | Split pane vertically |
| `Prefix + r` | Reload tmux config |
| `Prefix + [` | Enter copy mode (vi keys) |
| Mouse scroll | Scroll pane history |
| Mouse click | Select pane |
| Mouse drag | Resize pane borders |

Default prefix is `Ctrl+B`.

### Inter-Pane Commands (from Claude Code)

Claude Code can send commands to other panes:

```bash
# Restart dev server (Pane 3)
tmux send-keys -t 3 C-c && tmux send-keys -t 3 'npm run dev' Enter

# Re-run quality gate (Pane 2)
tmux send-keys -t 2 C-c && tmux send-keys -t 2 'bash scripts/quality-gate.sh' Enter

# One-shot quality check (Pane 2)
tmux send-keys -t 2 C-c && tmux send-keys -t 2 'bash scripts/quality-gate.sh --once' Enter
```

---

## Quality Gate

Continuous file watcher that runs tiered checks on every save.

### Usage

```bash
# Watch mode (default) — runs in Pane 2
bash scripts/quality-gate.sh

# Skip tests for faster feedback
bash scripts/quality-gate.sh --no-test

# Run once and exit (for CI or manual check)
bash scripts/quality-gate.sh --once
```

### What It Checks

| Tier | Check | Node.js | Python | Go |
|------|-------|---------|--------|----|
| 1 | **Security** | Hardcoded keys, `eval()`, `dangerouslySetInnerHTML` | Hardcoded keys, `eval()`/`exec()`, `shell=True` | Hardcoded keys |
| 2 | **Types** | `tsc --noEmit` | `mypy` | `go vet` |
| 3 | **Tests** | `jest --findRelatedTests` | `pytest` | `go test ./...` |

**Auto-detects project type** from `package.json`, `pyproject.toml`, or `go.mod`.

### Output Color Key

- **Red** = Critical issue (security vulnerability, type error, test failure)
- **Yellow** = Warning (investigate, may be intentional)
- **Green** = All clear

### Project-Specific vs Generic

If a project has its own `scripts/quality-gate.sh` (like ElevateAI), the tmux launcher uses that instead. The generic version is a fallback for projects without their own.

---

## Claude Code Commands

Commands are user-invoked with `/command-name` in Claude Code. Installed globally via `install.sh`.

### `/review-pr`

Review a pull request for code quality, architecture, and security.

```
/review-pr 42          # Review PR #42
/review-pr my-branch   # Review PR for branch
/review-pr             # Review current branch's PR
```

**What it does:** Fetches the PR diff, reads project standards (GEMINI.md/CLAUDE.md), analyzes changes across 4 severity levels (Critical, High, Medium, Low), and outputs a structured review.

### `/quality`

Run inline quality checks without leaving Claude Code.

```
/quality
```

**What it does:** Detects project type, runs security scan + type check + lint + tests, reports results in a table.

### `/deploy`

Build, test, and deploy to staging or production.

```
/deploy              # Deploy to staging (default)
/deploy staging      # Explicit staging
/deploy prod         # Deploy to production (requires confirmation)
```

**What it does:** Pre-deploy checks (tests, types, security) -> build -> deploy to Cloud Run -> post-deploy verification (health check).

---

## Claude Code Skills

Skills are auto-triggered by Claude when it detects relevant context. You don't invoke them — Claude activates them based on what you're doing.

| Skill | Triggers When You... | What It Provides |
|-------|---------------------|------------------|
| **tdd-workflow** | Implement features, fix bugs, write tests | Red-Green-Refactor cycle, coverage gates, test patterns |
| **clean-architecture** | Create new files, classes, modules | Layer rules, file placement guide, DI patterns |
| **security-review** | Handle auth, user input, review for security | OWASP top 10 checklist, secret detection, input validation |
| **pr-workflow** | Create PRs, branches, commits | Branch naming, conventional commits, PR templates |
| **project-setup** | Set up new projects, initialize repos | Full setup checklist by language, scaffolding guide |

### Skill Structure

Each skill has:
- `SKILL.md` — Main instructions with trigger keywords
- `references/` — Detailed guides loaded on demand (test patterns, code examples, checklists)

Skills are progressively loaded: Claude reads metadata first, then full instructions only when relevant.

---

## Templates

Templates provide a starting point for AI agent context files and GitHub Actions. Copy them to a new project and fill in the `<!-- CUSTOMIZE: description -->` markers.

### Agent Context Templates

| Template | Purpose | Used By |
|----------|---------|---------|
| `CLAUDE.md` | Claude Code workflows, TDD process, session checklist | Claude Code |
| `AGENTS.md` | Shared context: architecture, tech stack, file structure | All AI agents |
| `GEMINI.md` | Code review standards, architectural constraints | Gemini (GitHub Actions) |
| `CODEX.md` | Development standards for OpenAI agents | Codex / ChatGPT |

**AGENTS.md is the shared foundation.** CLAUDE.md, GEMINI.md, and CODEX.md all reference it for project details and add agent-specific instructions on top.

### GitHub Actions Templates

| Template | Triggers On | What It Does |
|----------|-------------|--------------|
| `ci.yml` | Push to master, all PRs | Parallel lint, typecheck, test, security → gated build |
| `security.yml` | PR opened/updated | Dependency audit, secret detection, SAST patterns |
| `gemini-code-review.yml` | PR opened/updated | AI code review with PR context, diff filtering, structured output |
| `gemini-on-demand.yml` | Comment with `@gemini-cli` | Answer questions or review code on demand |
| `deploy-cloudrun.yml` | Push to master / manual | Build, push, deploy to Cloud Run with health check + rollback |
| `stale.yml` | Weekly (Monday) | Mark and close inactive PRs/issues |
| `dependabot.yml` | Dependabot schedule | Grouped dependency updates (npm + GitHub Actions) |

**Setup required:** Add `GEMINI_API_KEY` to GitHub repo secrets. For deployments, configure GCP Workload Identity Federation. See `templates/github-workflows/README.md` for full instructions.

---

## Setting Up a New Project

### Step-by-step

```bash
# 1. Create project directory
mkdir /mnt/c/Dev/rdi-my-project
cd /mnt/c/Dev/rdi-my-project
git init

# 2. Copy agent context templates
cp /mnt/c/Dev/rdi-dev-env/templates/CLAUDE.md  .
cp /mnt/c/Dev/rdi-dev-env/templates/AGENTS.md  .
cp /mnt/c/Dev/rdi-dev-env/templates/GEMINI.md  .
# cp /mnt/c/Dev/rdi-dev-env/templates/CODEX.md .   # optional

# 3. Edit each file — search for "CUSTOMIZE" and fill in project details

# 4. Copy GitHub Actions workflows
mkdir -p .github/workflows
cp /mnt/c/Dev/rdi-dev-env/templates/github-workflows/ci.yml .github/workflows/
cp /mnt/c/Dev/rdi-dev-env/templates/github-workflows/security.yml .github/workflows/
cp /mnt/c/Dev/rdi-dev-env/templates/github-workflows/gemini-code-review.yml .github/workflows/
cp /mnt/c/Dev/rdi-dev-env/templates/github-workflows/gemini-on-demand.yml .github/workflows/
cp /mnt/c/Dev/rdi-dev-env/templates/github-workflows/deploy-cloudrun.yml .github/workflows/
cp /mnt/c/Dev/rdi-dev-env/templates/github-workflows/stale.yml .github/workflows/

# 5. Copy Dependabot config (note: .github/, NOT .github/workflows/)
cp /mnt/c/Dev/rdi-dev-env/templates/github-workflows/dependabot.yml .github/dependabot.yml

# 6. Customize ci.yml for your language (uncomment Python/Go sections if needed)

# 7. Create GitHub repo and add GEMINI_API_KEY secret
gh repo create RonHadler/rdi-my-project --private --source=. --push
# Then: GitHub repo > Settings > Secrets > Add GEMINI_API_KEY

# 8. Verify tmux-dev.sh detects your project
bash /mnt/c/Dev/rdi-dev-env/tmux/tmux-dev.sh . my-project
```

### Customization Checklist

After copying templates, search for `<!-- CUSTOMIZE` in each file:

- [ ] **AGENTS.md** — Project name, description, tech stack, file structure, env vars, commands
- [ ] **CLAUDE.md** — Project name, startup steps, resources
- [ ] **GEMINI.md** — Project name, language-specific quality standards, testing patterns
- [ ] **ci.yml** — Uncomment the right language setup, adjust lint/test/build commands, set coverage threshold
- [ ] **deploy-cloudrun.yml** — GCP project ID, region, service name, Artifact Registry paths
- [ ] **CODEX.md** (optional) — Project name, commands, architecture details

---

## CI/CD Strategy

### rdi-dev-env is the baseline

This repo is the **golden path** for all CI/CD and GitHub Actions. The flow:

```
rdi-dev-env/templates/        # Canonical templates (improve here)
        |
        | copy on project setup
        v
project/.github/workflows/   # Project copy (customize here)
```

### Where to make improvements

| Change | Where | Then |
|--------|-------|------|
| **New workflow feature** (e.g., add security scanning step) | `rdi-dev-env/templates/` | Propagate to existing projects |
| **Better review prompts** (improve Gemini review quality) | `rdi-dev-env/templates/gemini-code-review.yml` | Propagate to existing projects |
| **Project-specific CI** (e.g., Firestore emulator in tests) | The project's `.github/workflows/` | Stays project-local |
| **New reusable workflow** (e.g., Docker build + push) | `rdi-dev-env/templates/github-workflows/` | Available to all new projects |

### Propagating improvements to existing projects

When you improve a template, update existing projects by diffing:

```bash
# See what changed in the template vs project's copy
diff rdi-dev-env/templates/github-workflows/ci.yml my-project/.github/workflows/ci.yml

# Or use Claude Code to merge improvements:
# "Update this project's ci.yml with the latest improvements from the rdi-dev-env template"
```

### Future: Reusable GitHub Actions

As workflows mature, consider extracting common steps into [reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) in a shared repo. This eliminates copy-paste entirely — projects reference the workflow by URL.

---

## Updating

When rdi-dev-env gets new features or improvements:

```bash
cd /mnt/c/Dev/rdi-dev-env
git pull

# Re-run installer to update symlinks (commands, skills, tmux config)
bash install.sh
```

The installer is idempotent — it skips anything already linked and backs up files before overwriting.

**Note:** Updating rdi-dev-env does NOT auto-update project copies of templates or workflows. Those are project-owned files. Propagate improvements manually (see [CI/CD Strategy](#cicd-strategy)).

---

## Troubleshooting

### tmux-dev.sh says "tmux is not installed"

```bash
sudo apt install tmux
```

### install.sh reports "backed up" — where are my old files?

Backups are saved next to the original with a timestamp suffix:
```
~/.tmux.conf.backup.20260221-143022
~/.claude/commands/quality.md.backup.20260221-143022
```

### Claude Code doesn't show /review-pr, /quality, /deploy

1. Verify symlinks exist: `ls -la ~/.claude/commands/`
2. If empty, re-run: `bash install.sh`
3. Restart Claude Code after installing commands

### Quality gate says "Cannot detect project type"

The script needs one of: `package.json` (Node.js), `pyproject.toml` (Python), or `go.mod` (Go) in the current directory. Run it from the project root.

### Quality gate "mypy not installed" / "pytest not installed"

Install the missing tool in your Python project's virtualenv:
```bash
uv add --dev mypy pytest
```

### tmux-dev.sh creates session but dev server doesn't start

The auto-detection might not match your project. Check what it detected:
```bash
# The launcher prints the detected command on startup
# Look for: "Dev cmd: ..."
```

If wrong, start the dev server manually in Pane 3.

### WSL2 file watching is slow

This is expected. Windows filesystem accessed via `/mnt/c/` uses polling (not inotify). The quality gate polls every 2 seconds, which is a reasonable balance.

### Pane numbers don't match (0 vs 1)

The tmux config sets `pane-base-index 1`, so panes are numbered 1, 2, 3. If you're using a different tmux config, panes might start at 0.

---

## Repository Structure

```
rdi-dev-env/
|-- README.md                              # This file
|-- install.sh                             # Symlink installer
|-- .gitignore
|
|-- tmux/
|   |-- tmux.conf                          # Enhanced tmux config
|   +-- tmux-dev.sh                        # One-command 3-pane launcher
|
|-- scripts/
|   +-- quality-gate.sh                    # Generic quality gate (Node/Python/Go)
|
|-- commands/                              # -> symlinked to ~/.claude/commands/
|   |-- review-pr.md                       # /review-pr
|   |-- quality.md                         # /quality
|   +-- deploy.md                          # /deploy
|
|-- skills/                                # -> symlinked to ~/.claude/skills/
|   |-- tdd-workflow/
|   |   |-- SKILL.md
|   |   +-- references/test-patterns.md
|   |-- clean-architecture/
|   |   |-- SKILL.md
|   |   +-- references/layer-rules.md, examples.md
|   |-- security-review/
|   |   |-- SKILL.md
|   |   +-- references/owasp-checklist.md
|   |-- pr-workflow/
|   |   |-- SKILL.md
|   |   +-- references/commit-conventions.md
|   +-- project-setup/
|       |-- SKILL.md
|       +-- references/checklist.md
|
+-- templates/                             # Copy to new projects
    |-- CLAUDE.md                          # Claude Code context
    |-- AGENTS.md                          # Shared agent context
    |-- GEMINI.md                          # Gemini review standards
    |-- CODEX.md                           # OpenAI Codex context
    +-- github-workflows/
        |-- ci.yml                         # CI pipeline (parallel jobs + coverage gate)
        |-- security.yml                   # Security scanning (deps, secrets, SAST)
        |-- gemini-code-review.yml         # Automated PR review (structured output)
        |-- gemini-on-demand.yml           # @gemini-cli interactive
        |-- deploy-cloudrun.yml            # Cloud Run deploy + health check + rollback
        |-- dependabot.yml                 # Dependency update config (→ .github/)
        |-- stale.yml                      # Stale PR/issue cleanup
        +-- README.md                      # Setup guide for all templates
```

---

*Maintained by Ron Hadler / RDI*
