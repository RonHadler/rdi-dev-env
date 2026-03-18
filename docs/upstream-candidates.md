# Upstream Candidates

Patterns discovered in projects during compliance audits that should be considered for inclusion in rdi-dev-env templates. These flow back in Phase 4 of the [standards compliance plan](standards-compliance-plan.md).

## How to use

- `rdi-audit <path>` shows upstream candidates at the bottom of each report
- `rdi-audit <path> --json` includes them in the `upstream` array
- `rdi-audit status` shows the UP column count per project

When starting template improvement work, check this file first.

---

## Candidates

### Dockerfile: HEALTHCHECK instruction
- **Source:** rdi-datagov-mcp
- **Found:** 2026-03-18
- **Description:** `HEALTHCHECK CMD curl -f http://localhost:8000/health || exit 1` — enables Docker and Cloud Run to detect unhealthy containers without external probes
- **Template action:** Add HEALTHCHECK to `templates/python-fastmcp/Dockerfile`

### Testing: Rich conftest fixtures
- **Source:** rdi-datagov-mcp (4 fixtures), rdi-documents-mcp
- **Found:** 2026-03-18
- **Description:** Domain-specific test fixtures beyond the basic env reset pattern (e.g. mock clients, sample data factories)
- **Template action:** Extend `templates/python-fastmcp/scaffold/tests/conftest.py` with examples

### Dockerfile: Multi-stage build
- **Source:** rdi-documents-mcp (3 stages: base, dev, production)
- **Found:** 2026-03-18 (from plan)
- **Description:** Separate dev and production stages with different dependency sets
- **Template action:** Add `Dockerfile.multistage` option or document pattern

### Dockerfile: Custom ENTRYPOINT script
- **Source:** rdi-poe-mcp
- **Found:** 2026-03-18 (from plan)
- **Description:** `entrypoint.sh` for pre-start initialization (e.g. Alembic migrations)
- **Template action:** Document pattern in template README

### Testing: Dedicated config test file
- **Source:** rdi-poe-mcp
- **Found:** 2026-03-18 (from plan)
- **Description:** `tests/test_config.py` that validates Settings defaults, overrides, and validation
- **Template action:** Add to template test suite

---

*Updated: 2026-03-18*
