# Current Tasks

## Current Phase
Phase 1 complete. Phase 2 next (high-risk production: rdi-google-ads-mcp, rdi-google-ga4-mcp).

## In Progress
- None

## Up Next — Script Updates
- (all complete — see Completed section)

## Up Next — Phase 2 Rollout
- [ ] Run `rdi-refresh --apply --tasks` on rdi-google-ads-mcp
- [ ] Run `rdi-refresh --apply --tasks` on rdi-google-ga4-mcp
- [ ] Hand tasks.json to project agents for seeded-file remediation
- [ ] Stagger Dockerfile merges by 24h (production services)

## Completed
- [x] Phase 0: Audit tooling (`rdi-audit`, `standards.json`)
- [x] Phase 0: Refresh tooling (`rdi-refresh`, managed vs seeded file model)
- [x] Phase 0: Smoke test framework (`templates/smoke-tests/`)
- [x] Phase 0: GitHub Actions version bumps
- [x] Phase 1: Pilot on rdi-datagov-mcp (100% compliance)
- [x] Template gaps fixed (branch detection, CI placeholders, dev deps checks)
- [x] Upstream candidates documented
- [x] Layered multi-stack template architecture (base, python, go, rust, node, python-fastmcp)
- [x] Update `standards.json` to v2 (multi-stack scoping with compat_aliases)
- [x] Update `audit-project.sh`: auto-detect stack from manifest files, multi-stack check collection
- [x] Update `refresh-project.sh`: manifest-driven managed file lists, polymorphic metadata extraction
- [x] Update `new-project.sh`: resolve_chain(), assemble_file(), stack menu, lockfile generation
- [x] Standardize `.template` suffix on `pyproject.toml`
- [x] Configure Python dependabot for `uv` (no-op: `pip` ecosystem already handles `uv.lock`)
- [x] Replace Go SQL injection regex with `gosec` in security-go.yml
- [x] Align `collect_managed_files` / `collect_seeded_files` to same data structure convention

## Blocked
- None
