---
description: Run inline quality checks (security, types, lint, tests)
allowed-tools: Bash(npx:*, npm:*, tsc:*, jest:*, pytest:*, go:*, mypy:*, grep:*, ruff:*), Read, Glob, Grep
---

# Run Quality Checks

Run a comprehensive quality check on the current project, inline within Claude Code.

## Steps

1. **Detect project type** by checking for `package.json`, `pyproject.toml`, `go.mod`

2. **Tier 1: Security Scan** — Search for:
   - Hardcoded API keys (patterns: `sk-`, `AIza`, `AKIA`, `ghp_`)
   - `eval()` or `exec()` usage in non-test files
   - `dangerouslySetInnerHTML` (Node.js)
   - `subprocess` with `shell=True` (Python)
   - Secrets in committed files (`.env` files tracked by git)

3. **Tier 2: Type/Lint Check**
   - **Node.js:** `npx tsc --noEmit` + `npx next lint` (or `npx eslint .`)
   - **Python:** `mypy .` + `ruff check .` (or `flake8`)
   - **Go:** `go vet ./...`

4. **Tier 3: Tests**
   - **Node.js:** `npx jest --no-coverage` (or `npm test`)
   - **Python:** `pytest --tb=short -q`
   - **Go:** `go test ./... -count=1 -short`

5. **Report results** with clear pass/fail indicators:

   ```
   ## Quality Check Results

   | Check    | Status | Details |
   |----------|--------|---------|
   | Security | PASS   | No issues |
   | Types    | PASS   | 0 errors |
   | Lint     | WARN   | 2 warnings |
   | Tests    | PASS   | 156 passed |
   ```

6. If any check fails, show the specific errors and suggest fixes.
