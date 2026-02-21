# New Project Setup Checklist

## All Projects

- [ ] `git init` + initial `.gitignore`
- [ ] `README.md` with project purpose and setup instructions
- [ ] `CLAUDE.md` — Claude Code agent context (from template)
- [ ] `AGENTS.md` — Shared agent context (from template)
- [ ] `GEMINI.md` — Gemini review standards (from template)
- [ ] `.github/workflows/ci.yml` — CI pipeline (from template)
- [ ] `.github/workflows/gemini-code-review.yml` — PR review (from template)
- [ ] `GEMINI_API_KEY` added to GitHub repo secrets
- [ ] Verify `tmux-dev.sh` detects project correctly
- [ ] Initial commit with all scaffolding

## Node.js / TypeScript

- [ ] `package.json` with project metadata
- [ ] `tsconfig.json` with strict mode enabled
- [ ] ESLint configured (`.eslintrc.*` or `eslint.config.*`)
- [ ] Jest configured (`jest.config.ts` or in `package.json`)
- [ ] `npm run dev` script working
- [ ] `npm run test` script working
- [ ] `npm run lint` script working
- [ ] `npm run type-check` script (`tsc --noEmit`)
- [ ] `npm run build` script working
- [ ] `src/` directory with Clean Architecture structure
- [ ] First test file created and passing
- [ ] `Dockerfile` (if deploying to Cloud Run)
- [ ] `.env.example` with required variables documented

### Next.js Specific
- [ ] `app/` directory with App Router structure
- [ ] `app/api/health/ping/route.ts` — health check endpoint
- [ ] Tailwind CSS configured
- [ ] `next.config.js` with appropriate settings

## Python

- [ ] `pyproject.toml` with project metadata
- [ ] `uv` as package manager (`uv init` or `uv sync`)
- [ ] `ruff` configured for linting + formatting
- [ ] `mypy` configured for type checking
- [ ] `pytest` configured
- [ ] Virtual environment created (`.venv/`)
- [ ] `src/` directory structure
- [ ] First test file created and passing
- [ ] `Dockerfile` (if deploying)
- [ ] `.env.example` with required variables

### FastMCP Server Specific
- [ ] `server.py` or `__main__.py` entry point
- [ ] MCP tool definitions with proper typing
- [ ] Health check tool
- [ ] `Makefile` with `dev-serve`, `test`, `lint` targets

## Go

- [ ] `go.mod` initialized
- [ ] `Makefile` with standard targets (`build`, `test`, `lint`, `dev`)
- [ ] `Dockerfile` (multi-stage build)
- [ ] `cmd/` for entry points
- [ ] `internal/` for private packages
- [ ] First test file created and passing (`*_test.go`)
- [ ] `golangci-lint` configured (`.golangci.yml`)
- [ ] Race detection in tests (`-race` flag)

### Docker-Only Development (Go)
- [ ] `docker-compose.yml` for local dev
- [ ] `make up` starts dev container
- [ ] `make test` runs tests in container
- [ ] `make shell` gives interactive access

## GCP Cloud Run Deployment

- [ ] `Dockerfile` with appropriate base image
- [ ] `cloudbuild.yaml` (if using Cloud Build)
- [ ] Service account created with minimal permissions
- [ ] `--no-allow-unauthenticated` for private services
- [ ] `gcloud run deploy` command documented in README
- [ ] Health check endpoint for Cloud Scheduler (if applicable)
- [ ] Secrets in GCP Secret Manager (not env vars in Cloud Run config)

## Security Baseline

- [ ] No secrets in code (use env vars or secret manager)
- [ ] `.env` in `.gitignore`
- [ ] Auth middleware configured (if applicable)
- [ ] CORS configured (if web API)
- [ ] Rate limiting considered
- [ ] Input validation on all endpoints
