# Deploy Pipeline Upgrade Guide

> How to upgrade existing MCP server projects to the robust 3-tier deploy verification pipeline.

**Reference implementation:** `rdi-google-ads-mcp` (proven working 2026-03-22)

---

## What This Pipeline Does

```
CI (lint + typecheck + tests) → Deploy image → Route traffic (--to-latest)
  → Tier 1 (revision ready) → Tier 2 (100% traffic verified) → Tier 3 (HTTP /health probe)
  → Success or Rollback
```

---

## Prerequisites

Before upgrading deploy workflows, the project needs:

### 1. `/health` endpoint on the FastMCP server

Add to `coordinator.py` (where the FastMCP singleton lives):

```python
from starlette.requests import Request
from starlette.responses import JSONResponse

@mcp_server.custom_route("/health", methods=["GET"], include_in_schema=False)
async def health(request: Request) -> JSONResponse:
    """Health check for deploy verification and uptime monitoring."""
    return JSONResponse({"status": "ok"})
```

If the project has a database, add a connectivity check (see `rdi-poe-mcp` for pattern).

### 2. CI workflow with `workflow_call` trigger

`ci.yml` must support being called by deploy workflows:

```yaml
on:
  pull_request:
    branches: ["develop"]
    paths-ignore: ['**.md', 'docs/**', 'LICENSE', '.gitignore']
  workflow_call:  # Deploy workflows reuse CI as a gate
```

**Important:** Remove the `push` trigger — deploy workflows handle CI on push. Also fix the concurrency group:

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}  # NOT ci-${{ github.ref }}
  cancel-in-progress: true
```

### 3. GitHub repo variables

Set via GitHub UI (Settings → Variables → Actions) or CLI:

```bash
gh variable set CLOUD_RUN_SERVICE_ACCOUNT --body "your-sa@project.iam.gserviceaccount.com"
```

### 4. GitHub repo secrets

These should already exist if you have deploy workflows:
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_DEPLOY_SERVICE_ACCOUNT`
- `GCP_PROJECT_ID`

### 5. Branch protection (requires GitHub Pro)

```bash
# Protect develop
gh api repos/OWNER/REPO/branches/develop/protection -X PUT \
  --input - <<'EOF'
{
  "required_status_checks": {"strict": true, "contexts": []},
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 0},
  "restrictions": null
}
EOF

# Protect production
gh api repos/OWNER/REPO/branches/production/protection -X PUT \
  --input - <<'EOF'
{
  "required_status_checks": {"strict": true, "contexts": []},
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 0},
  "restrictions": null
}
EOF
```

---

## Upgrade Steps

### Option A: Copy from templates (recommended for new or simple projects)

1. Copy `templates/github-workflows/deploy-staging.yml` to `.github/workflows/deploy-staging.yml`
2. Copy `templates/github-workflows/deploy-production.yml` to `.github/workflows/deploy-production.yml`
3. Search for `<!-- CUSTOMIZE` and replace all placeholders
4. Set `HEALTH_CHECK_PATH: '/health'` in the `env:` block
5. Move any hardcoded service account emails to `${{ vars.CLOUD_RUN_SERVICE_ACCOUNT }}`

### Option B: Patch existing workflows (recommended for projects with custom deploy flags)

For each deploy workflow, add/update these steps after the Deploy step:

**Step 1:** Add traffic routing after deploy:
```yaml
      - name: Route traffic to new revision
        run: |
          gcloud run services update-traffic "${{ env.SERVICE_NAME }}" \
            --region="${{ env.GCP_REGION }}" \
            --project="${{ secrets.GCP_PROJECT_ID }}" \
            --to-latest
```

**Step 2:** Add ID token generation after Get service URL:
```yaml
      - name: Generate ID token for health probe
        id: id-token
        uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_DEPLOY_SERVICE_ACCOUNT }}
          token_format: 'id_token'
          id_token_audience: ${{ steps.deploy.outputs.url }}
          id_token_include_email: true
```

**Step 3:** Replace the health check step with the 3-tier verification from the template.

**Step 4:** Fix the rollback step — change `tail -1` to `sed -n '2p'`.

**Step 5:** Ensure `HEALTH_CHECK_PATH: '/health'` is in the `env:` block.

---

## Verification Checklist

After upgrading, push a change to `develop` and verify:

- [ ] CI runs inside the deploy workflow (not separately)
- [ ] Deploy succeeds
- [ ] "Route traffic to new revision" step completes
- [ ] Tier 1: "Revision X is ready"
- [ ] Tier 2: "Latest revision has 100% traffic"
- [ ] Tier 3: "Health probe passed (HTTP 200)" and "All 3 verification tiers passed"
- [ ] No duplicate CI runs on push to develop

---

## Repos to Upgrade

| Repo | Status | Notes |
|------|--------|-------|
| `rdi-google-ads-mcp` | Done | Reference implementation |
| `rdi-google-ga4-mcp` | Pending | Needs `/health` (has `/healthz`), deploy workflows |
| `rdi-poe-mcp` | Pending | Already has `/health`, needs deploy workflow update + CI workflow |
| `rdi-domo-mcp` | Pending | Needs assessment |
| `rdi-argus-mcp` | Pending | Go project — different patterns |

---

*Last Updated: 2026-03-22*
