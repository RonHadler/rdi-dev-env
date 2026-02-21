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
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | deploy-cloudrun | Workload Identity Federation provider |
| `GCP_SERVICE_ACCOUNT` | deploy-cloudrun | GCP service account email |

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
2. GCP Workload Identity Federation configured ([setup guide](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines))
3. Artifact Registry repository created
4. GitHub Environments configured (staging + production with approval)

**Customization:** Replace all `<!-- CUSTOMIZE -->` values:
- `GCP_PROJECT_ID`, `GCP_REGION`, `SERVICE_NAME`
- `ARTIFACT_REGISTRY`, `ARTIFACT_REPO`
- `HEALTH_CHECK_PATH`

---

### 6. Dependabot (`dependabot.yml`)

**Note:** This is NOT a workflow. Copy to `.github/dependabot.yml` (not `.github/workflows/`).

**What it does:**
- Groups npm minor/patch updates into a single PR (reduces noise)
- Bumps GitHub Actions versions weekly
- Conventional commit prefixes (`deps:`, `ci:`)

**Customization:** Uncomment Python (`pip`) or Go (`gomod`) sections as needed.

---

### 7. Stale Cleanup (`stale.yml`)

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
