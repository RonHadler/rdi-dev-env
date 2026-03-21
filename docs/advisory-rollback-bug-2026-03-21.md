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
