# rdi-dev-env — Claude Code Context

Development environment, templates, and tooling for RDI's Python/FastMCP MCP servers.

## Session Startup

1. **Check current tasks** — `docs/current-tasks.md` for what's in progress and up next
2. **Check roadmap** — `docs/roadmap.md` for the big picture
3. **Check upstream candidates** — `docs/upstream-candidates.md` for patterns to bring into templates
4. **Run fleet audit** — `bash scripts/audit-project.sh status` to see current compliance

## Key Tools

| Command | Purpose |
|---------|---------|
| `rdi-audit <path>` | Check a project against standards |
| `rdi-audit status` | Fleet compliance dashboard |
| `rdi-refresh <path> --apply --tasks` | Deploy managed files + generate tasks |
| `rdi-new-project` | Scaffold a new project from templates |

## Conventions

- **Conventional commits:** `feat:`, `fix:`, `test:`, `docs:`, `deps:`, `ci:`
- **Feature branches → PR** — Gemini AI review runs on all PRs
- Templates use `<!-- CUSTOMIZE: marker_name -->` for substitution points
- `standards.json` is the source of truth for compliance checks
