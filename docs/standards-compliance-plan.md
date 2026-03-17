# RDI Standards Compliance System — Implementation Plan

## Context

RDI has ~6 Python/FastMCP MCP servers that were built before or independently of rdi-dev-env's template system. Recent template improvements (non-root Docker, layer caching, security workflows, hardened Gemini review, pydantic-settings patterns) need to be propagated to existing projects. Drift goes both ways — some projects have innovations (multi-stage Docker, HEALTHCHECK, entrypoint scripts) that should flow back to the templates.

This plan builds reusable audit tooling first, then remediates projects in risk order, with a pilot project to validate the approach before touching production services.

---

## Phase 0: Audit Tooling (rdi-dev-env only) — COMPLETE

**Goal:** Make compliance measurable and repeatable. Zero project changes.

### Deliverables

1. **`standards.json`** — Declarative manifest of 21 checks grouped by severity
   - `critical/security`: Non-root Docker, no hardcoded secrets, frozen deps
   - `high/ci`: CI lint+test workflow, security scan, Gemini review, uv from official image
   - `medium/quality`: `[build-system]`, pydantic-settings, conftest env reset, Makefile, no python-dotenv
   - `low/consistency`: CLAUDE.md, AGENTS.md, GEMINI.md, dependabot, stale, .rdi-baseline

2. **`scripts/audit-project.sh`** — Reads standards.json, checks any project
   - Modes: `status` (dashboard), `<path>` (single project), `--json` (machine-readable), `--generate-tasks` (Ralph Loop tasks.json)
   - Check types: `file_exists`, `file_contains`, `file_not_contains`
   - Exit codes: 0 = pass, 1 = high failures, 2 = critical failures
   - Reverse audit: `--reverse` flags project patterns not in template

3. **`.rdi-baseline` spec** — JSON marker file for projects tracking adoption version and suppressed checks

4. **`install.sh` updated** — Symlinks `rdi-audit` to `~/.local/bin/`

### Files changed
- `standards.json` (new)
- `scripts/audit-project.sh` (new)
- `docs/standards-compliance-plan.md` (new — this file)
- `install.sh` (add symlink)

---

## Phase 1: Pilot — rdi-datagov-mcp

**Why first:** Closest to compliant already (good Dockerfile, pydantic-settings, conftest, CLAUDE.md). NOT deployed to Cloud Run. Safe to validate the full remediation workflow.

**Branch:** `fix/rdi-standards-baseline` off default branch

### Fixes (priority order)

| # | Fix | Severity | Ralph-automatable |
|---|-----|----------|-------------------|
| 1 | Non-root Docker user | Critical | No (human review) |
| 2 | Add CI lint/test workflow (ci-python.yml) | High | Yes |
| 3 | Add security scan workflow | High | Yes |
| 4 | Add Gemini code review workflow | High | Yes |
| 5 | Add `[build-system]` to pyproject.toml | Medium | Yes |
| 6 | Add `get_settings()` accessor to config.py | Medium | No (verify singleton pattern) |
| 7 | Add conftest.py env reset + Settings re-instantiation | Medium | No (must not break existing fixtures) |
| 8 | Add Makefile | Medium | Yes |
| 9 | Add AGENTS.md | Low | Yes |
| 10 | Drop `python-dotenv` if present | Low | No (verify env loading) |
| 11 | Add `.rdi-baseline` marker | Low | Yes |

### Verification
```bash
uv sync && uv run pytest tests/ -v && docker build .
```

### Risk: Low — project not in production. All existing tests must pass after changes.

---

## Phase 2: High-Risk Production — rdi-google-ads-mcp & rdi-google-ga4-mcp

**Why next:** Deployed to Cloud Run, most gaps, highest security risk (root Docker, no CI, no security scanning).

**Critical constraint:** Dockerfile changes affect live services. Must test locally, deploy to staging revision first (`gcloud run deploy --no-traffic`), then promote. Stagger merges by 24+ hours between projects.

### Per-project: Two PRs each

**PR A — Security (human review required):**
1. Dockerfile overhaul: non-root user, layer caching, `--frozen`/`--no-dev`
2. CI lint/test workflow
3. Security scan workflow

**PR B — Quality (Ralph-automatable):**
4. `[build-system]` in pyproject.toml
5. conftest.py with env reset
6. CLAUDE.md, AGENTS.md, Makefile
7. Gemini review, dependabot, stale workflows
8. `.rdi-baseline`

### Project-specific notes

**rdi-google-ads-mcp:**
- Uses `pyink` not `ruff` (Google-style formatting) — CI lint must be customized
- Currently uses `pip install uv` — switch to `COPY --from=ghcr.io/astral-sh/uv:latest`
- No pydantic-settings — larger migration needed (consider Phase 2 scope)

**rdi-google-ga4-mcp:**
- Has `noxfile.py` for tests — CI should respect this or migrate to standard pytest
- Missing most `[tool.*]` config sections in pyproject.toml — substantial expansion

### Verification
```bash
docker build -t test-local . && docker run --rm -p 8000:8000 test-local
# Then: curl http://localhost:8000/health
# Then: deploy to staging revision with --no-traffic
```

### Risk: HIGH — production services. Mitigation: separate security/quality PRs, local Docker testing, staged deployment, 24h stagger between projects.

---

## Phase 3: Mature Projects — rdi-marketmirror-mcp, rdi-documents-mcp, rdi-poe-mcp

**Why last:** Already 70-80% compliant with active CI. Smaller changes, lower risk. But in active development — coordinate with in-flight work.

### Per-project fixes

**rdi-marketmirror-mcp (5 gaps):**
1. Dockerfile: add layer caching + non-root user
2. `[build-system]` in pyproject.toml
3. Remove `dotenv.load_dotenv()` from server.py (pydantic-settings handles it)
4. Add `--frozen` to Dockerfile `uv sync`
5. `.rdi-baseline`

**rdi-documents-mcp (3 gaps):**
1. Non-root user in both Dockerfile stages (DO NOT restructure the multi-stage build — it's better than template)
2. `[build-system]` in pyproject.toml
3. Add dependabot, stale, `.rdi-baseline`

**rdi-poe-mcp (4 gaps):**
1. Dockerfile: layer caching + non-root user (preserve entrypoint.sh, ensure appuser can execute it)
2. `[build-system]` in pyproject.toml
3. Remove `dotenv.load_dotenv()` from server.py (keep it in `alembic/env.py` — Alembic runs standalone)
4. `.rdi-baseline`

### Verification
Same as Phase 2: `uv sync && pytest && docker build && docker run` per project.

### Risk: Medium — these have CI that will catch regressions. Check for open PRs/branches before creating remediation branches.

---

## Phase 4: Upstream Innovations (back to rdi-dev-env)

**Goal:** Feed project innovations back into templates so new projects get the best patterns.

| Innovation | Source project | Template change |
|------------|---------------|-----------------|
| Multi-stage Dockerfile | rdi-documents-mcp | Add `Dockerfile.multistage` option |
| HEALTHCHECK instruction | rdi-datagov-mcp | Add to template Dockerfile |
| Entrypoint script pattern | rdi-poe-mcp | Document in template README |
| Domain fixture patterns | rdi-marketmirror-mcp | Extend template conftest.py |
| `test_config.py` starter | rdi-poe-mcp | Add to template test suite |
| Bump `standards.json` version | all | Incorporate lessons learned |

### Risk: None — template-only changes

---

## Phase 5: Maintenance Mode

1. **`/audit` slash command** — Run audit from within Claude Code
2. **CI-based audit** (optional) — GitHub Action that posts compliance score on push
3. **Quarterly review** — Run audit across all projects, compare to `.rdi-baseline`, file issues for regressions

---

## Dependency Graph

```
Phase 0 (tooling) ─────────────────────────────────────┐
    │                                                   │
    v                                                   v
Phase 1 (pilot: datagov) ──────> Phase 4 (upstream) ──> Phase 5 (maintenance)
    │
    v
Phase 2 (high-risk: ads, ga4)
    │
    v
Phase 3 (mature: marketmirror, documents, poe)
```

- Phase 0 must complete before anything else
- Phase 1 must complete before Phase 2 (validates approach)
- Phase 2 and 3 are independent of each other (can overlap)
- Phase 4 can start after Phase 1

## Key Principles

- **Pilot first, not batch** — Validate on datagov before touching production
- **Security PRs separate from quality PRs** — Smaller blast radius, easier rollback
- **Never restructure what's already better** — documents-mcp's Dockerfile stays as-is
- **Stagger production deployments** — 24h between Dockerfile merges on deployed services
- **Check for active work** — Don't create remediation branches against repos with open feature PRs
