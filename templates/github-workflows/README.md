# GitHub Actions Workflow Templates

## Setup

### 1. Copy Workflows

```bash
# From your project root:
mkdir -p .github/workflows

cp /path/to/rdi-dev-env/templates/github-workflows/ci.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/gemini-code-review.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/gemini-on-demand.yml .github/workflows/
```

### 2. Add Secrets

Go to your GitHub repo > Settings > Secrets and variables > Actions:

| Secret | Required | Description |
|--------|----------|-------------|
| `GEMINI_API_KEY` | Yes (for Gemini workflows) | Google AI Studio API key |

| Variable | Required | Description |
|----------|----------|-------------|
| `GEMINI_MODEL` | No | Gemini model ID (default: `gemini-2.5-pro`) |

Get a Gemini API key at: https://aistudio.google.com/apikey

### 3. Customize Workflows

#### ci.yml
- Update the setup step for your language (Node.js, Python, Go)
- Adjust the lint, type-check, test, and build commands
- Uncomment the relevant sections for your project type

#### gemini-code-review.yml
- Create a `GEMINI.md` file in your repo root (use the template from `rdi-dev-env/templates/`)
- The review will automatically use your project's standards from GEMINI.md

#### gemini-on-demand.yml
- Works out of the box once `GEMINI_API_KEY` secret is added
- Usage: Comment `@gemini-cli <question>` on any issue or PR
- For code review: `@gemini-cli /code-review`

## Workflow Descriptions

### CI Pipeline (`ci.yml`)
- **Triggers:** Push to master, all PRs to master
- **Steps:** Lint -> Type check -> Tests with coverage -> Build verification
- **Artifacts:** Coverage report uploaded

### Gemini Code Review (`gemini-code-review.yml`)
- **Triggers:** PR opened, synchronized, or reopened
- **What it does:** Reads the PR diff and GEMINI.md, generates an AI code review
- **Output:** Comment on the PR with structured feedback (Critical/High/Medium/Low)
- **Non-blocking:** Won't fail the build, but flags issues for review

### Gemini On-Demand (`gemini-on-demand.yml`)
- **Triggers:** Comment containing `@gemini-cli` on any issue or PR
- **What it does:** Answers questions about the codebase or performs targeted code reviews
- **Usage examples:**
  - `@gemini-cli How does authentication work in this project?`
  - `@gemini-cli /code-review`
  - `@gemini-cli What's the best way to add a new API endpoint?`

## Troubleshooting

### Gemini review not posting
1. Check that `GEMINI_API_KEY` secret is set
2. Check Actions tab for workflow run errors
3. Verify the workflow has `pull-requests: write` permission

### CI failing on PRs
1. Check the specific step that failed in the Actions tab
2. Run the failing command locally to reproduce
3. Common issues: missing dependencies, type errors, test failures

### On-demand not responding
1. Make sure your comment includes `@gemini-cli` (case-insensitive)
2. Check that the workflow file exists in the default branch
3. The workflow needs `issues: write` permission
