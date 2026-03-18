# rdi-dev-env — Claude Code Context

Development environment, templates, and tooling for RDI's Python/FastMCP MCP servers.

## Session Startup

1. **Check upstream candidates** — `docs/upstream-candidates.md` for patterns to bring into templates
2. **Check compliance plan** — `docs/standards-compliance-plan.md` for current phase and next steps
3. **Run fleet audit** — `bash scripts/audit-project.sh status` to see current compliance across all projects

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
