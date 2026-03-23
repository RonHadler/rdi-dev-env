# RDI FastMCP Server Branching Strategy

> Standard branching strategy for all RDI MCP servers deployed to GCP Cloud Run.
> Copy this file to `rdi-dev-env/standards/` for use in scaffolding.

---

## Branch Model

| Branch | Purpose | Deploys To | Trigger |
|--------|---------|------------|---------|
| `develop` | Default branch. All PRs merge here. | **Staging** (auto) | Push to develop |
| `production` | Represents what's live in production. | **Production** (auto) | Push to production (via merge from develop) |

Feature branches are created from `develop` and merged back via PR.

---

## Flow

```
feature/my-feature-0321
        |
        v
    PR -> develop  ──auto──>  CI (lint, typecheck, test)  ──pass──>  Deploy to Staging
                                                                          |
                                                                     (verify staging)
                                                                          |
                                                              PR: develop -> production
                                                                          |
                                                                       merge
                                                                          |
                                                                     Deploy to Production
```

### Day-to-Day Development
1. Create feature branch from `develop`: `feat/description-MMDD`
2. Push commits, open PR targeting `develop`
3. CI runs (lint, typecheck, test), Gemini reviews, security scan
4. Merge PR → auto-deploys to staging
5. Verify on staging

### Promoting to Production
1. Create PR: `develop` → `production`
2. PR description serves as release notes / audit trail
3. Merge PR → auto-deploys to production
4. Health check runs, auto-rollback on failure

### Hotfixes
1. Create branch from `production`: `hotfix/description-MMDD`
2. PR to `production` (triggers prod deploy on merge)
3. Immediately cherry-pick or merge back to `develop`

---

## Workflow Configuration

### CI Pipeline (`ci.yml`)
```yaml
on:
  push:
    branches: ["develop"]
  pull_request:
    branches: ["develop"]
  workflow_call:  # Reusable by deploy workflows
```

### Deploy Staging (`deploy-staging.yml`)
```yaml
on:
  push:
    branches: ["develop"]
    paths-ignore: ['**.md', 'docs/**', 'LICENSE', '.gitignore']
  workflow_dispatch:  # Manual backup
```
- Calls CI as prerequisite (`needs: [ci]`)

### Deploy Production (`deploy-production.yml`)
```yaml
on:
  push:
    branches: ["production"]
    paths-ignore: ['**.md', 'docs/**', 'LICENSE', '.gitignore']
  workflow_dispatch:  # Manual backup with confirmation
```
- Calls CI as prerequisite
- `validate` job (confirmation) only runs on `workflow_dispatch`
- Health check + auto-rollback on failure

---

## GitHub Repository Settings

> **Requires GitHub Pro** (or GitHub Team/Enterprise) for branch protection rules on private repos.

### Branch Protection Rules

1. **Default branch:** `develop`
2. **Branch protection on `develop`:**
   - Require status checks to pass before merging (select "CI Pipeline")
   - Require branches to be up to date before merging
   - Allow squash merges
   - Do NOT require PR for docs/config direct pushes (protection still enforces CI)
3. **Branch protection on `production`:**
   - Require PR before merging (no direct pushes)
   - Require status checks (CI) to pass
   - Require review approval (1+ reviewer recommended)
   - Include administrators (no bypassing)
4. **Delete stale branches:** `main`, `master` (if they exist after migration)

### Why CI Doesn't Have a Push Trigger

The CI template (`ci.yml`) only triggers on `pull_request` and `workflow_call` — not `push`. This is intentional:

- **PRs:** CI runs via `pull_request` trigger → branch protection blocks merge if CI fails
- **Deploys:** CI runs via `workflow_call` gate → deploy won't proceed if CI fails
- **Direct pushes:** Branch protection requires status checks → GitHub blocks the push if CI hasn't passed

This avoids duplicate CI runs (push + PR would both trigger) and ensures CI is always enforced through branch protection, not workflow triggers.

---

## Migration Checklist (for existing repos)

See [branching-migration-plan.md](branching-migration-plan.md) for step-by-step instructions.

---

*Last Updated: 2026-03-21*
*Version: 1.0*
