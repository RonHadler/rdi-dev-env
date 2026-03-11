# GitHub Actions Workflow Templates

## Quick Setup

```bash
# From your project root:
mkdir -p .github/workflows

# Workflows (copy to .github/workflows/)
cp /path/to/rdi-dev-env/templates/github-workflows/ci.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/security.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/gemini-code-review.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/gemini-on-demand.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/deploy-cloudrun.yml .github/workflows/
# For Next.js projects, use the Next.js variant instead:
# cp /path/to/rdi-dev-env/templates/github-workflows/deploy-cloudrun-nextjs.yml .github/workflows/deploy-qa.yml
# For projects with Firestore:
# cp /path/to/rdi-dev-env/templates/github-workflows/deploy-firestore.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/stale.yml .github/workflows/

# Dependabot config (NOTE: goes in .github/, NOT .github/workflows/)
cp /path/to/rdi-dev-env/templates/github-workflows/dependabot.yml .github/dependabot.yml
```

Search for `<!-- CUSTOMIZE` in each file and replace placeholders with your project's values.

---

## Secrets & Variables

Configure these in GitHub repo > Settings > Secrets and variables > Actions:

### Secrets

| Secret | Used By | Description |
|--------|---------|-------------|
| `GEMINI_API_KEY` | gemini-code-review, gemini-on-demand | Google AI Studio API key ([get one](https://aistudio.google.com/apikey)) |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | deploy-cloudrun | WIF provider resource name (from Pulumi output) |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | deploy-cloudrun | Deploy service account email |
| `GCP_PROJECT_ID` | deploy-cloudrun | GCP project ID for the target environment |

### Variables

| Variable | Used By | Description | Default |
|----------|---------|-------------|---------|
| `GEMINI_MODEL` | gemini-code-review, gemini-on-demand | Gemini model ID | `gemini-2.5-pro` |

### GitHub Environments (for deploy-cloudrun)

Create two environments in Settings > Environments:

1. **staging** — No protection rules (auto-deploys on push to master)
2. **production** — Add "Required reviewers" protection rule with team leads

---

## Workflow Reference

### 1. CI Pipeline (`ci.yml`)

**Triggers:** Push to master, all PRs (skips docs-only changes)

**Architecture:**
```
Jobs (parallel):        Jobs (gated):
  lint ─────────────┐
  typecheck ────────┤
  test ─────────────┼──→ build
  security-audit ───┘
```

**Key features:**
- 4 parallel jobs for faster feedback (~2-3 min vs ~5-7 sequential)
- `concurrency` with `cancel-in-progress` saves runner minutes on rapid pushes
- Coverage threshold enforcement (default 80%, configurable)
- `npm audit --audit-level=high` for dependency vulnerabilities
- Hardcoded secret pattern detection
- `paths-ignore` skips CI on docs-only changes

**Customization:**
- Set `COVERAGE_THRESHOLD` env var (0 to disable)
- Uncomment Python/Go job blocks at the bottom for non-Node projects

---

### 2. Security Scan (`security.yml`)

**Triggers:** PR opened/updated

**Three scan tiers:**

| Tier | Check | What it detects |
|------|-------|-----------------|
| 1 | Dependency audit | High/critical npm vulnerabilities |
| 2 | Secret detection | Hardcoded API keys (OpenAI, Google, AWS, GitHub tokens) |
| 3 | SAST patterns | `eval()`, `dangerouslySetInnerHTML`, `subprocess shell=True` |

**Output:** Posts a structured PR comment with summary table and per-tier details.

**Customization:**
- Set `BLOCK_ON_CRITICAL: 'true'` to fail the workflow on secrets or high/critical dep vulnerabilities

---

### 3. Gemini Code Review (`gemini-code-review.yml`)

**Triggers:** PR opened/updated (skip with `[skip-review]` in PR title)

**Improvements over basic review:**
- Extracts PR title, description, and commit messages for context
- Filters binary/generated files from diff (lock files, images, coverage, build output)
- Truncates diffs over 50KB to stay within token limits
- Requests structured JSON severity counts from Gemini
- Graceful fallback if Gemini API fails (posts fallback comment instead of failing)

**Customization:**
- Set `BLOCK_ON_CRITICAL: 'true'` to fail the workflow when Gemini flags critical issues
- Set `MAX_DIFF_BYTES` to adjust truncation threshold
- Create `GEMINI.md` in your repo root with project-specific review standards

---

### 4. Gemini On-Demand (`gemini-on-demand.yml`)

**Triggers:** Comment containing `@gemini-cli` on any issue or PR

**Usage examples:**
```
@gemini-cli How does authentication work in this project?
@gemini-cli /code-review
@gemini-cli What's the best way to add a new API endpoint?
```

**Key features:**
- Dynamic default branch detection (works with `main` or `master`)
- Graceful error handling when used on issues (no diff available)
- Diff truncation for large PRs
- Generic prompt text (no hardcoded project names)

---

### 5. Cloud Run Deployment (`deploy-cloudrun.yml`)

**Triggers:**
- Auto: Push to master → deploy to staging
- Manual: `workflow_dispatch` with environment choice

**Flow:**
```
Authenticate (WIF) → Build Docker → Push to Artifact Registry →
Deploy to Cloud Run → Health check (5 retries) → Rollback if failed
```

**Prerequisites:**
1. Dockerfile in repo root
2. GCP Workload Identity Federation configured (Pulumi `shared/workload-identity.ts`)
3. Deploy service account created (Pulumi `shared/deploy-service-account.ts`)
4. Artifact Registry repository created
5. GitHub Environments with secrets: `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_DEPLOY_SERVICE_ACCOUNT`, `GCP_PROJECT_ID`

**Customization:** Replace all `<!-- CUSTOMIZE -->` values:
- `GCP_REGION`, `SERVICE_NAME`, `HEALTH_CHECK_PATH`

**GitHub Environment Secrets (per environment):**

| Secret | Description |
|--------|-------------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Full WIF provider resource name from Pulumi output |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | Deploy SA email (e.g., `github-actions-deploy@project.iam.gserviceaccount.com`) |
| `GCP_PROJECT_ID` | GCP project ID for this environment |

---

### 5b. Cloud Run Deployment — Next.js (`deploy-cloudrun-nextjs.yml`)

Extends the base template with Next.js-specific features:
- Fetches `NEXT_PUBLIC_*` secrets from GCP Secret Manager at build time
- Passes secrets as `--build-arg` to Docker for static compilation
- Targets the `production` Docker stage with `--platform linux/amd64`

**Additional prerequisites:**
- `NEXT_PUBLIC_*` secrets populated in GCP Secret Manager
- Multi-stage Dockerfile with `production` target

**Customization:** Same as base, plus add/remove `NEXT_PUBLIC_*` secrets in the "Fetch build secrets" step

---

### 6. Firestore Deploy (`deploy-firestore.yml`)

**Triggers:**
- Auto: Push to default branch when `firestore.rules` or `firestore.indexes.json` change
- Manual: `workflow_dispatch` to force sync

**Flow:**
```
Authenticate (WIF) → Deploy rules & indexes to all environments (parallel matrix)
```

**Key features:**
- Deploys to all environments simultaneously via matrix strategy
- `fail-fast: false` ensures one env failure doesn't block others
- Manual trigger for initial setup or drift recovery
- Uses `npx firebase-tools` (no global install needed)

**Prerequisites:**
1. `firebase.json` in repo root with `firestore` config
2. `firestore.rules` and `firestore.indexes.json` in repo root
3. GitHub Environments with GCP secrets (same as deploy-cloudrun)
4. Deploy service account needs `roles/firebase.admin` or `roles/datastore.owner`

**Customization:** Replace `<!-- CUSTOMIZE -->` values:
- Default branch (if not `develop`)
- Environment names and count in matrix

---

### 7. Dependabot (`dependabot.yml`)

**Note:** This is NOT a workflow. Copy to `.github/dependabot.yml` (not `.github/workflows/`).

**What it does:**
- Groups npm minor/patch updates into a single PR (reduces noise)
- Bumps GitHub Actions versions weekly
- Conventional commit prefixes (`deps:`, `ci:`)

**Customization:** Uncomment Python (`pip`) or Go (`gomod`) sections as needed.

---

### 8. Stale Cleanup (`stale.yml`)

**Triggers:** Weekly (Monday 9am UTC) + manual

**Timelines:**
| Type | Stale After | Close After |
|------|-------------|-------------|
| PRs | 14 days | 7 more days |
| Issues | 30 days | 14 more days |

**Exempt labels:** `pinned`, `work-in-progress`, `roadmap`

---

## Troubleshooting

### Gemini review not posting
1. Verify `GEMINI_API_KEY` secret is set in repo settings
2. Check Actions tab for workflow run errors
3. Confirm the workflow has `pull-requests: write` permission
4. Check if PR title contains `[skip-review]` (intentionally skips)

### CI failing on PRs
1. Check the specific job that failed (lint, typecheck, test, security-audit, build)
2. Run the failing command locally to reproduce
3. Common issues: missing dependencies, type errors, test failures

### Coverage threshold failing
1. Ensure `npm run test:coverage` generates `coverage/coverage-summary.json`
2. Your jest config needs `coverageReporters: ['json-summary']`
3. Set `COVERAGE_THRESHOLD: 0` to disable temporarily

### Security scan false positives
1. Secret detection excludes test files and known workflow files
2. If a pattern is a false positive, add a grep exclusion to the scan step
3. SAST patterns (eval, dangerouslySetInnerHTML) may be intentional — review and suppress if needed

### Deploy health check failing
1. Verify `HEALTH_CHECK_PATH` returns HTTP 200
2. The health endpoint must respond within 10 seconds
3. Check Cloud Run logs for startup errors
4. Auto-rollback will revert to the previous working revision

### On-demand not responding
1. Ensure comment includes `@gemini-cli` (case-insensitive)
2. The workflow file must exist in the repo's default branch
3. The workflow needs `issues: write` permission
4. If used on an issue (not PR), `/code-review` will note "no diff available"

### Dependabot PRs not appearing
1. Verify `.github/dependabot.yml` exists (not in `workflows/`)
2. Check Settings > Code security > Dependabot is enabled
3. PRs may be grouped — look for a single PR with multiple dependency updates

### Stale not marking items
1. The workflow only runs on schedule (Mondays) or manual trigger
2. Items with exempt labels (`pinned`, `work-in-progress`, `roadmap`) are skipped
3. Check if the workflow has `issues: write` and `pull-requests: write` permissions
