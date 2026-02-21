# rdi-dev-env

Single source of truth for RDI's development environment configuration, AI agent context templates, and Claude Code extensions.

## What's Included

| Directory | Purpose |
|-----------|---------|
| `tmux/` | tmux config + one-command 3-pane dev launcher |
| `scripts/` | Generic quality gate (auto-detects Node.js, Python, Go) |
| `templates/` | AI agent context templates (CLAUDE.md, GEMINI.md, CODEX.md, AGENTS.md) + GitHub Actions workflows |
| `commands/` | Claude Code custom slash commands (`/review-pr`, `/quality`, `/deploy`) |
| `skills/` | Claude Code Agent Skills (TDD, Clean Architecture, Security, PR, Project Setup) |
| `install.sh` | Symlinks configs, commands, and skills to the right locations |

## Quick Start

```bash
# Clone the repo
cd /mnt/c/Dev  # or /c/Dev in Git Bash
git clone <repo-url> rdi-dev-env

# Install symlinks (tmux config, commands, skills)
cd rdi-dev-env
bash install.sh

# Launch a 3-pane dev environment for any project
bash tmux/tmux-dev.sh /mnt/c/Dev/rdi-novusiq elevateai
```

## Commands vs Skills

| | Custom Commands | Agent Skills |
|---|---|---|
| **Location** | `~/.claude/commands/*.md` | `~/.claude/skills/skill-name/SKILL.md` |
| **Triggered by** | User types `/command-name` | Claude auto-detects relevance |
| **Best for** | Explicit workflows (deploy, review) | Domain expertise (TDD, architecture) |

## tmux Layout

```
+------------------------------+----------------------+
|                              |                      |
|   Pane 1: Claude Code        |  Pane 2: Quality     |
|   (main development)         |  Gate (watch)        |
|                              |                      |
|                              +----------------------+
|                              |                      |
|                              |  Pane 3: Dev Server  |
|                              |                      |
+------------------------------+----------------------+
```

## Templates

Copy templates to a new project and customize the `<!-- CUSTOMIZE -->` sections:

```bash
cp templates/CLAUDE.md  /path/to/new-project/CLAUDE.md
cp templates/AGENTS.md  /path/to/new-project/AGENTS.md
cp templates/GEMINI.md  /path/to/new-project/GEMINI.md
cp -r templates/github-workflows/ /path/to/new-project/.github/workflows/
```

See `templates/github-workflows/README.md` for GitHub Actions setup.

## Updating

After pulling changes, re-run `install.sh` to update symlinks:

```bash
cd /mnt/c/Dev/rdi-dev-env
git pull
bash install.sh
```

---

*Maintained by Ron Hadler / RDI*
