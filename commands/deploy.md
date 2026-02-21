---
description: Build, test, and deploy to staging or production
argument-hint: "[staging|prod]"
allowed-tools: Bash(git:*, npm:*, docker:*, gcloud:*, gh:*, npx:*), Read, Glob, Grep
---

# Deploy Workflow

Build, test, and deploy the current project. Defaults to staging if no environment is specified.

## Steps

1. **Determine target environment:**
   - If `$ARGUMENTS` contains "prod" or "production", target is **production**
   - Otherwise, target is **staging**
   - **For production:** Ask the user for explicit confirmation before proceeding

2. **Pre-deploy checks:**
   - Verify you're on the correct branch (usually `master` for production, feature branch for staging)
   - Check for uncommitted changes: `git status`
   - Check all tests pass: run the project's test command
   - Check types pass: run the project's type check command
   - Verify no critical security issues (quick grep for hardcoded keys)

3. **Build:**
   - **Node.js:** `npm run build`
   - **Python:** Verify dependencies are locked (`uv lock --check` or `pip freeze`)
   - **Go:** `go build ./...`
   - **Docker:** `docker build -t <image> .`

4. **Deploy based on project type:**

   ### Cloud Run (most RDI projects)
   ```bash
   # Build and push
   gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME

   # Deploy
   gcloud run deploy $SERVICE_NAME \
     --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
     --region us-central1 \
     --no-allow-unauthenticated
   ```

   ### Next.js (Cloud Run)
   ```bash
   npm run build
   gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME
   gcloud run deploy $SERVICE_NAME --image gcr.io/$PROJECT_ID/$SERVICE_NAME
   ```

5. **Post-deploy verification:**
   - Check the deployment URL is responding
   - If a health endpoint exists (`/api/health/ping`), verify it returns 200
   - Report the deployed URL to the user

6. **Output summary:**
   ```
   ## Deployment Summary

   | Item        | Value |
   |-------------|-------|
   | Environment | staging |
   | Branch      | feat/my-feature |
   | Commit      | abc1234 |
   | Service URL | https://... |
   | Health      | OK |
   ```

**IMPORTANT:** Never deploy to production without explicit user confirmation.
