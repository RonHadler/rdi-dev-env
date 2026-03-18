# Roadmap

## Phase 2: High-Risk Production (Next)
Remediate rdi-google-ads-mcp and rdi-google-ga4-mcp. Separate security and quality PRs per project. Stagger Dockerfile merges by 24h since these are deployed to Cloud Run.

See [standards-compliance-plan.md](standards-compliance-plan.md) for details.

## Phase 3: Mature Projects
Remediate rdi-marketmirror-mcp, rdi-documents-mcp, rdi-poe-mcp. These are 70-80% compliant already — smaller changes, lower risk.

## Phase 4: Upstream Innovations
Feed project innovations back into templates. See [upstream-candidates.md](upstream-candidates.md) for the running list.

## Phase 5: Maintenance Mode
- `/audit` slash command for Claude Code
- CI-based audit (GitHub Action posts compliance score on push)
- Quarterly review across all projects

## Template Improvements (Ongoing)
- Add `docs/current-tasks.md` and `docs/roadmap.md` to scaffold
- Add smoke test files to scaffold option
- Consider Copier or similar for template updates beyond `rdi-refresh`

---

*Updated: 2026-03-18*
