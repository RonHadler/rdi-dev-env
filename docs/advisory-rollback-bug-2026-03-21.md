# Advisory: Rollback Bug in Deploy Workflows

**Date:** 2026-03-21
**Severity:** Medium — affects rollback on first-ever deployment only
**Status:** Fixed in rdi-dev-env templates, needs propagation to existing projects

## Problem

The Cloud Run rollback logic in deploy workflows uses `tail -1` to get the previous revision. If there's only one revision (first deploy), `tail -1` returns that same broken revision, so the "rollback" redeploys the failing code.

## Fix

In each deploy workflow file under `.github/workflows/`, find the rollback step and change:

```bash
# Before (buggy)
--limit=2 | tail -1)
# or
--limit=2 | tail -n 1)

# After (fixed)
--limit=2 | sed -n '2p')
```

`sed -n '2p'` returns nothing if only one revision exists, which correctly triggers the "no previous revision found" warning instead of a false rollback.

## Affected Projects

- rdi-argus-mcp (`deploy-staging.yml`, `deploy-production.yml`)
- rdi-elevateai (`deploy-shared.yml`)
- rdi-google-ads-mcp (`deploy-staging.yml`, `deploy-production.yml`)
- rdi-google-ga4-mcp (`deploy-staging.yml`, `deploy-production.yml`)
- rdi-marketmirror-mcp (`deploy-cloudrun.yml`)
- rdi-poe-mcp (`deploy-staging.yml`, `deploy-production.yml`)

## Commit message

```
fix: prevent rollback to same broken revision on first deploy
```

---

# Advisory: gcloud Health Check Format Bug

**Date:** 2026-03-21
**Severity:** Medium — health check may always report "Unknown", triggering false rollbacks
**Status:** Fixed in rdi-dev-env templates, needs propagation to existing projects

## Problem

Deploy workflows using `gcloud run services describe` with `--format='value(status.conditions[0].status)'` are fragile — the `[0]` index isn't guaranteed to be the "Ready" condition. The older `filter("type","Ready")` syntax also broke in newer gcloud versions.

## Fix

Replace the gcloud format line in health check steps:

```bash
# Before (fragile — index not guaranteed)
--format='value(status.conditions[0].status)' 2>/dev/null || echo "Unknown")

# After (portable across all gcloud versions)
--format='json(status.conditions)' 2>/dev/null \
| python3 -c "import sys,json; d=json.load(sys.stdin); print(next((c['status'] for c in d.get('status',{}).get('conditions',[]) if c.get('type')=='Ready'),'Unknown'))" 2>/dev/null || echo "Unknown")
```

## Affected Projects

Same list as rollback bug above — any project with deploy workflows using `status.conditions[0].status` or `status.conditions.filter`.

## Commit message

```
fix: use portable JSON parsing for Cloud Run health check status
```
