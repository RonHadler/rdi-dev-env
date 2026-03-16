# rdi-dev-env

Single source of truth for RDI's development environment configuration, AI agent context templates, and Claude Code extensions.

**Repo:** https://github.com/RonHadler/rdi-dev-env

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [What's Included](#whats-included)
- [Ralph Loop (Autonomous SDLC)](#ralph-loop-autonomous-sdlc)
- [Project Scaffolder](#project-scaffolder)
- [tmux Development Environment](#tmux-development-environment)
- [Quality Gate](#quality-gate)
- [Usage Monitor](#usage-monitor)
- [Compaction Resilience](#compaction-resilience)
- [Claude Code Commands](#claude-code-commands)
- [Claude Code Skills](#claude-code-skills)
- [Templates](#templates)
- [Setting Up a New Project](#setting-up-a-new-project)
- [CI/CD Strategy](#cicd-strategy)
- [Updating](#updating)
- [Changelog](#changelog)
- [Roadmap](#roadmap)
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
| **jq** | `sudo apt install jq` (for Ralph Loop task parsing) |
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
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-elevateai elevateai
```

That's it. You now have tmux configured, 5 Claude Code slash commands, 5 Agent Skills, 6 CLI tools (`rdi-ralph-loop`, `rdi-new-project`, `rdi-quality-gate`, `rdi-usage-monitor`, `rdi-conversation-archiver`, `rdi-context-reseeder`), and Claude Code hooks for compaction resilience — all active globally.

---

## What's Included

| Directory | Files | Purpose |
|-----------|-------|---------|
| `tmux/` | `tmux.conf`, `tmux-dev.sh` | tmux config + one-command 3-pane launcher |
| `scripts/` | `ralph-loop.sh`, `new-project.sh`, `quality-gate.sh`, `usage-monitor.sh`, `conversation-archiver.sh`, `context-reseeder.sh` | Autonomous SDLC loop, scaffolder, quality watch, usage budget, compaction hooks |
| `commands/` | `review-pr.md`, `quality.md`, `deploy.md`, `fix-pr.md`, `usage.md` | Claude Code `/slash-commands` |
| `skills/` | 5 skills with references | Claude Code Agent Skills (auto-triggered) |
| `templates/` | Generic + Python/FastMCP templates, 5 workflow templates | Copy to new projects, or use scaffolder |
| `install.sh` | Symlink installer | Wires everything into the right locations |

---

## Ralph Loop (Autonomous SDLC)

The Ralph Loop is an autonomous task execution system that lets fresh Claude instances pick up tasks, implement them via TDD, run tests, commit on pass, and create PRs — eliminating manual copy-paste and context rot.

### Usage

```bash
# Run the full loop (picks tasks from tasks.json)
rdi-ralph-loop

# Or run directly:
bash scripts/ralph-loop.sh [options] [tasks.json]
```

### Options

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would happen without executing |
| `--once` | Execute one task and exit |
| `--max-iterations N` | Maximum loop iterations (default: 10) |
| `--no-pr` | Skip PR creation at the end |
| `--usage-check` | Enable pre-flight usage budget check (default) |
| `--no-usage-check` | Disable usage budget check |
| `--branch NAME` | Use specific branch name (default: `ralph/MMDD`) |

### How It Works

```
1. Pick next pending task (respects dependencies and max_attempts)
2. Build prompt with project context (CLAUDE.md + AGENTS.md + task description)
3. Send to Claude CLI (claude -p)
4. Run test command from task verification
5. PASS → git commit with conventional message → mark completed
6. FAIL → store error, revert changes, retry or mark failed
7. Repeat until all tasks done or max iterations reached
8. Create PR with completed tasks summary
```

### tasks.json Format

```json
{
  "version": "1.0",
  "project": "rdi-example-mcp",
  "tasks": [
    {
      "id": "TASK-001",
      "status": "pending",
      "priority": 1,
      "title": "Short imperative description",
      "description": "Detailed instructions for Claude",
      "blocked_by": [],
      "verification": {
        "test_command": "uv run pytest tests/ -v"
      },
      "commit_type": "feat",
      "attempts": 0,
      "max_attempts": 3,
      "last_error": ""
    }
  ]
}
```

### Safety Measures

- **Stop file:** `touch /tmp/.ralph-stop-<project>` pauses at next iteration
- **Max attempts:** Default 3 per task — prevents infinite loops
- **Clean revert:** Failed tasks revert all uncommitted changes
- **Dry run:** Full simulation with zero side effects
- **Ctrl+C:** Writes clean summary before exiting
- **Usage budget:** Pre-flight check before each task — pauses when LOW, stops when CRITICAL

---

## Project Scaffolder

Interactive script to create new projects from templates with all the RDI conventions pre-configured.

### Usage

```bash
# Interactive mode
rdi-new-project

# Or run directly:
bash scripts/new-project.sh
```

### What It Asks

| # | Question | Effect |
|---|----------|--------|
| 1 | Project name | Sets names (kebab, snake, display) |
| 2 | Stack type | Python/FastMCP (Next.js and Go coming soon) |
| 3 | Description | Project metadata |
| 4 | GitHub remote? | Creates repo via `gh repo create` |
| 5 | GitHub Actions | Selects workflows (default: ci, security, gemini-review) |
| 6 | GCP project ID | Cloud Run deployment config |
| 7 | Create tasks.json? | Ralph Loop integration |

### What It Creates (Python/FastMCP)

A complete, working MCP server project with:
- FastMCP 3.x coordinator pattern (coordinator + config + server + tools/)
- Pydantic v2 settings with env file stacking
- pytest test suite with first passing test
- Makefile with standard targets (test, lint, type-check, dev-serve)
- Dockerfile (python:3.13-slim + uv)
- CLAUDE.md, AGENTS.md, GEMINI.md (customized from templates)
- GitHub Actions workflows
- Git initialized with develop/staging/main branches
- Optional tasks.json for Ralph Loop

### After Scaffolding

1. `uv sync` installs dependencies
2. `uv run pytest` verifies initial test passes
3. Initial git commit on `develop` branch
4. `staging` and `main` branches created
5. GitHub remote created (if opted in)

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
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-elevateai elevateai

# Argus MCP (Go/Docker)
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-argus-mcp argus

# Current directory, auto-named
bash tmux/tmux-dev.sh .

# Re-attach to existing session
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-elevateai elevateai  # auto-attaches if exists
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

## Usage Monitor

Tracks Claude Max subscription message usage within the 5-hour rolling window. The limit is **account-level** — all Claude Code instances (same project or different projects) count toward the same budget.

### Usage

```bash
# Dashboard with progress bar
rdi-usage-monitor status

# Machine-readable check (exit 0=ok, 1=low, 2=critical)
rdi-usage-monitor check

# Can we afford N more messages?
rdi-usage-monitor can-afford 12

# JSON output (for scripting)
rdi-usage-monitor json
```

### Example Output

```
Claude Max Usage Monitor (max_5x)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5-hour window:   ████████████░░░░░░░░  142/225 messages (63%)
Effective limit: 180 (20% reserved for interactive use)
Remaining:       38 messages
Status:          OK
```

### Configuration

| Env Var | Default | Description |
|---------|---------|-------------|
| `USAGE_PLAN` | `max_5x` | Subscription tier (`max_5x` = 225 msgs, `max_20x` = 900 msgs) |
| `USAGE_5H_LIMIT` | Auto from plan | Override message limit per 5-hour window |
| `USAGE_SAFETY_PCT` | `20` | % reserved for interactive use (not consumed by automation) |
| `CLAUDE_DIR` | `~/.claude` | Claude config directory |

### How It Works

Counts assistant messages (`"role":"assistant"`) across all `~/.claude/projects/*/*.jsonl` files with timestamps within the last 5 hours. No external dependencies — uses `grep` + `awk` only.

**Multiple instances:** All sessions write to the same `~/.claude/projects/` directory, so every instance is counted regardless of which project it's in.

### Slash Command

Run `/usage` in any Claude Code session to see the dashboard interactively.

### Ralph Loop Integration

The loop runs `usage-monitor.sh can-afford 12` before each task. If budget is LOW, it pauses for 5 minutes and rechecks (up to 1 hour). If CRITICAL, it stops the loop. Disable with `--no-usage-check`.

---

## Compaction Resilience

When Claude Code auto-compacts a conversation, details not captured in plan files are lost. Two hooks preserve and restore context automatically.

### Conversation Archiver (PreCompact Hook)

Before compaction, copies the full conversation JSONL to a project-local `.sdlc/conversations/` directory.

**Archive naming:** `YYYYMMDD-HHMMSS-<session-id-prefix>.jsonl`

**Location:** `<project>/.sdlc/conversations/` — travels with the project, gitignored by default.

### Context Reseeder (SessionStart Hook)

After compaction, the reseeder finds the most recent archive and injects a summary as `additionalContext` that Claude sees automatically. The summary includes:
- Recent user requests
- Files modified in the session
- Task references (TASK-NNN)
- Path to the full archive

### Git Safety

`.sdlc/conversations/` is excluded from git at three layers:
1. **Template `.gitignore`** — `templates/python-fastmcp/.gitignore` includes `.sdlc/`
2. **Scaffolder** — `new-project.sh` ensures `.sdlc/` is in `.gitignore` for all stacks
3. **Global gitignore** — `install.sh` adds `.sdlc/conversations/` to `~/.gitignore_global`

### Hook Configuration

Hooks are installed to `~/.claude/settings.json` (user-level) by `install.sh`. They apply to all projects automatically.

```json
{
  "hooks": {
    "PreCompact": [{ "matcher": "", "hooks": [{ "type": "command", "command": "rdi-conversation-archiver", "timeout": 10 }] }],
    "SessionStart": [{ "matcher": "compact", "hooks": [{ "type": "command", "command": "rdi-context-reseeder", "timeout": 10 }] }]
  }
}
```

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

### `/usage`

Show Claude Max subscription usage budget and status.

```
/usage
```

**What it does:** Runs the usage monitor and displays the budget dashboard with message count, progress bar, effective limit, and status (OK/LOW/CRITICAL).

### `/fix-pr`

Auto-fix PR review comments — mechanical fixes applied automatically, architectural items triaged for human decision.

```
/fix-pr 42             # Fix comments on PR #42
/fix-pr                # Fix comments on current branch's PR
```

**What it does:** Fetches PR review comments, classifies each as mechanical (auto-fixable: missing types, unused imports, style violations, missing tests) or architectural (needs human: design alternatives, pattern changes, API changes). Applies mechanical fixes, runs tests, commits, and pushes. Reports a summary table of applied/deferred/failed fixes.

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

### Automated (Recommended)

Use the interactive scaffolder for Python/FastMCP projects:

```bash
rdi-new-project
# Or: bash /mnt/c/Dev/rdi-dev-env/scripts/new-project.sh
```

This creates a complete project with all templates customized, dependencies installed, tests passing, and git initialized. See [Project Scaffolder](#project-scaffolder) for details.

### Manual Step-by-step

For project types not yet supported by the scaffolder:

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

## Changelog

### v2.1 — Usage Monitor + Compaction Resilience (2026-03-04)

#### New: Usage Monitor (`scripts/usage-monitor.sh`)
Tracks Claude Max subscription message usage within the 5-hour rolling window. Counts assistant messages across all project JSONLs. Four modes: `status` (dashboard), `check` (exit codes), `can-afford N`, `json`. Integrated into Ralph Loop as pre-flight budget check.

#### New: Compaction Resilience (hooks)
Two Claude Code hooks that preserve context across auto-compaction:
- **Conversation Archiver** (`scripts/conversation-archiver.sh`) — PreCompact hook that copies conversation JSONL to `.sdlc/conversations/`
- **Context Reseeder** (`scripts/context-reseeder.sh`) — SessionStart hook that injects archived context summary after compaction

#### New: `/usage` Command (`commands/usage.md`)
Slash command for interactive budget dashboard. Runs usage monitor and displays results.

#### Updated: `scripts/ralph-loop.sh`
- Pre-flight usage budget check before each task (pauses on LOW, stops on CRITICAL)
- New flags: `--usage-check` (default), `--no-usage-check`

#### Updated: `install.sh`
- Sections 5-6: Claude Code hook configuration in `~/.claude/settings.json`, global gitignore setup
- 3 new CLI symlinks: `rdi-usage-monitor`, `rdi-conversation-archiver`, `rdi-context-reseeder`

#### Updated: `scripts/new-project.sh`
- Ensures `.sdlc/` in `.gitignore` for all stacks (future-proof for Next.js, Go)

#### Updated: `templates/python-fastmcp/.gitignore`
- Added `.sdlc/` to ignored paths

### v2.0 — Autonomous SDLC System (2026-03-04)

The "Ralph Loop" release — transforming rdi-dev-env from a configuration repo into a full autonomous development platform.

#### New: Ralph Loop (`scripts/ralph-loop.sh`)
Autonomous task execution loop that lets fresh Claude instances pick up tasks from `tasks.json`, implement them via TDD, run tests, commit on pass, and create PRs. Eliminates manual copy-paste and context rot across sessions.
- Task dependency graph with `blocked_by` support
- Retry logic with `max_attempts` and `last_error` propagation between attempts
- Stop file escape hatch (`touch /tmp/.ralph-stop-<project>`)
- `--dry-run`, `--once`, `--max-iterations`, `--no-pr`, `--branch` flags
- Auto-generated PR with completed/failed/pending task summary
- Clean revert on test failure (no broken commits)

#### New: Project Scaffolder (`scripts/new-project.sh`)
Interactive script that creates complete, working projects from templates in under a minute.
- Python/FastMCP stack fully supported (Next.js and Go planned)
- 7-question interactive setup (name, stack, description, GitHub, workflows, GCP, tasks)
- `<!-- CUSTOMIZE: marker -->` pattern for template substitution via `sed`
- Post-scaffold: `uv sync` + `uv run pytest` + git init with develop/staging/main branches
- Optional GitHub remote creation via `gh repo create`
- Optional `tasks.json` for immediate Ralph Loop integration

#### New: Python/FastMCP Template Suite (`templates/python-fastmcp/`)
15 template files based on the production `rdi-poe-mcp` patterns:
- **CLAUDE.md** — Python/FastMCP-specific workflow with Ralph Loop awareness
- **AGENTS.md** — MCP coordinator pattern architecture, flat module layout, import rules
- **GEMINI.md** — Python-specific review standards (type hints, ruff, mypy strict, async)
- **pyproject.toml** — FastMCP 3.x, Pydantic v2, ruff, mypy strict, pytest-asyncio
- **Makefile** — dev-serve, dev-stdio, test, lint, format, type-check, build, clean
- **Dockerfile** — python:3.13-slim + uv, streamable-http transport
- **tasks.json** — 4 starter tasks (scaffold pre-completed, health check, config, lint)
- **scaffold/** — coordinator.py (FastMCP singleton), config.py (Pydantic BaseSettings), server.py (entry point with /health route), __main__.py, conftest.py, test_coordinator.py

#### New: `/fix-pr` Command (`commands/fix-pr.md`)
Claude Code slash command that auto-fixes PR review comments:
- Fetches review comments via `gh api`
- Classifies each as **mechanical** (auto-fixable) or **architectural** (needs human decision)
- Applies mechanical fixes, runs tests, commits with summary
- Reports applied/deferred/failed counts

#### Updated: `install.sh`
- New section 4: symlinks scripts to `~/.local/bin/` as `rdi-ralph-loop`, `rdi-new-project`, `rdi-quality-gate`
- PATH check with suggested fix if `~/.local/bin` not on PATH

#### Updated: `README.md`
- Added Ralph Loop, Project Scaffolder, and `/fix-pr` documentation
- Updated What's Included table, Repository Structure tree, prerequisites

### v1.0 — Foundation (2026-02-21)

Initial release with tmux environment, quality gate, 3 slash commands, 5 skills, and generic templates.

---

## Roadmap

### Near-term (proving ground)

- [ ] **End-to-end validation** — Run `new-project.sh` to scaffold a test MCP server, then `ralph-loop.sh` to implement all 4 starter tasks autonomously
- [ ] **Harden ralph-loop.sh** — Test on Windows Git Bash (path handling, `jq` on MINGW), test SIGINT trap, test edge cases (empty tasks.json, all tasks blocked, circular dependencies)
- [ ] **Template refinement** — Run scaffolder against real projects, fix any `<!-- CUSTOMIZE` markers that survive substitution, validate Dockerfile builds

### Scaffolder stack expansion

- [ ] **Next.js/TypeScript template** — `templates/nextjs/` with App Router, MUI, Firebase, Clean Architecture layers, Jest, ESLint, Prettier
- [ ] **Go/Docker template** — `templates/go/` with Makefile-driven Docker dev, table-driven tests, race detection

### Ralph Loop enhancements

- [x] **Usage budget tracking** — Pre-flight message budget check prevents hitting limits mid-task
- [x] **Compaction resilience** — Hooks archive conversations and reseed context after auto-compaction
- [ ] **Parallel task execution** — Run independent tasks (no shared `blocked_by`) in parallel Claude instances
- [ ] **Task file watching** — Auto-reload `tasks.json` when modified externally (live task injection)
- [ ] **Rich progress UI** — Replace plain log output with a TUI dashboard showing task status, current iteration, elapsed time
- [ ] **Verification patterns** — `expected_files` and `check_patterns` validation (currently defined in schema but not enforced)
- [ ] **Error learning** — Aggregate `last_error` patterns across projects to improve prompts

### Platform integration

- [ ] **n8n webhook trigger** — Ralph Loop reports completion to n8n for downstream automation
- [ ] **Slack notifications** — Post Ralph Loop summaries to a channel on PR creation
- [ ] **Reusable GitHub Actions** — Extract common CI steps into shared workflows (eliminate copy-paste across projects)
- [ ] **Template versioning** — Track which template version a project was scaffolded from, offer upgrade diffs

### Commands & skills

- [ ] **`/fix-pr` refinement** — Test against real Gemini review comments, tune mechanical vs architectural classification heuristics
- [ ] **`/scaffold-tool` command** — Add a new MCP tool to an existing project (creates tool file, test file, registers import in server.py)
- [ ] **`/add-task` command** — Append a task to tasks.json interactively from within Claude Code

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
|   |-- ralph-loop.sh                      # Autonomous task execution loop
|   |-- new-project.sh                     # Interactive project scaffolder
|   |-- quality-gate.sh                    # Generic quality gate (Node/Python/Go)
|   |-- usage-monitor.sh                   # Claude Max message budget tracker
|   |-- conversation-archiver.sh           # PreCompact hook (archive JSONL)
|   +-- context-reseeder.sh               # SessionStart hook (inject context)
|
|-- commands/                              # -> symlinked to ~/.claude/commands/
|   |-- review-pr.md                       # /review-pr
|   |-- fix-pr.md                          # /fix-pr (auto-fix review comments)
|   |-- quality.md                         # /quality
|   |-- deploy.md                          # /deploy
|   +-- usage.md                           # /usage (budget dashboard)
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
+-- templates/
    |-- CLAUDE.md                          # Generic Claude Code context
    |-- AGENTS.md                          # Generic shared agent context
    |-- GEMINI.md                          # Generic Gemini review standards
    |-- CODEX.md                           # Generic OpenAI Codex context
    |-- python-fastmcp/                    # Python/FastMCP project template
    |   |-- CLAUDE.md                      # Python-specific Claude context
    |   |-- AGENTS.md                      # Python-specific agent context
    |   |-- GEMINI.md                      # Python-specific review standards
    |   |-- tasks.json                     # Ralph Loop starter tasks
    |   |-- pyproject.toml                 # Python project config
    |   |-- Makefile                       # Standard make targets
    |   |-- Dockerfile                     # python:3.13-slim + uv
    |   |-- .gitignore                     # Python-specific ignores
    |   |-- .env.example                   # Environment variable template
    |   +-- scaffold/                      # Source files copied into package
    |       |-- coordinator.py             # FastMCP singleton
    |       |-- config.py                  # Pydantic BaseSettings
    |       |-- server.py                  # Entry point
    |       |-- __main__.py                # python -m support
    |       +-- tests/
    |           |-- conftest.py            # Pytest fixtures
    |           +-- test_coordinator.py    # First passing test
    +-- github-workflows/
        |-- ci.yml                         # CI pipeline (parallel jobs + coverage gate)
        |-- security.yml                   # Security scanning (deps, secrets, SAST)
        |-- gemini-code-review.yml         # Automated PR review (structured output)
        |-- gemini-on-demand.yml           # @gemini-cli interactive
        |-- deploy-cloudrun.yml            # Cloud Run deploy + health check + rollback
        |-- dependabot.yml                 # Dependency update config (-> .github/)
        |-- stale.yml                      # Stale PR/issue cleanup
        +-- README.md                      # Setup guide for all templates
```

---

*Maintained by Ron Hadler / RDI*
