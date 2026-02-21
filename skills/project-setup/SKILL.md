---
name: project-setup
description: >
  Use when setting up a new project, initializing a repo,
  or scaffolding a codebase. Triggered by "new project", "init",
  "scaffold", "setup", "create repo", "bootstrap".
---

# Project Setup

Guide for creating new RDI projects with proper structure, tooling, and AI agent context.

## New Project Checklist

### 1. Initialize Repository

```bash
mkdir rdi-project-name
cd rdi-project-name
git init
```

### 2. Create AI Agent Context Files

Copy templates from `rdi-dev-env/templates/` and customize:

```bash
cp /path/to/rdi-dev-env/templates/CLAUDE.md  ./CLAUDE.md
cp /path/to/rdi-dev-env/templates/AGENTS.md  ./AGENTS.md
cp /path/to/rdi-dev-env/templates/GEMINI.md  ./GEMINI.md
```

Edit each file and fill in the `<!-- CUSTOMIZE -->` sections.

### 3. Set Up GitHub Actions

```bash
mkdir -p .github/workflows
cp /path/to/rdi-dev-env/templates/github-workflows/ci.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/gemini-code-review.yml .github/workflows/
cp /path/to/rdi-dev-env/templates/github-workflows/gemini-on-demand.yml .github/workflows/
```

Add `GEMINI_API_KEY` to GitHub repo secrets.

### 4. Configure Development Environment

Verify `tmux-dev.sh` auto-detects this project type:
```bash
bash /path/to/rdi-dev-env/tmux/tmux-dev.sh . my-project
```

### 5. Set Up Testing

- **Node.js:** `npm install --save-dev jest @types/jest ts-jest`
- **Python:** `uv add --dev pytest pytest-asyncio`
- **Go:** Tests built-in, just create `*_test.go` files

### 6. Create Initial Structure

See [references/checklist.md](references/checklist.md) for a complete checklist by project type.

## Project Types

### Node.js / TypeScript

```
project/
  src/
    domain/          # Entities, interfaces
    application/     # Use cases, DTOs
    infrastructure/  # External integrations
  app/               # Next.js (if applicable)
  tests/             # Or co-located *.test.ts
  package.json
  tsconfig.json
  CLAUDE.md
  AGENTS.md
  GEMINI.md
```

### Python

```
project/
  src/project_name/
    domain/
    application/
    infrastructure/
  tests/
  pyproject.toml
  CLAUDE.md
  AGENTS.md
  GEMINI.md
```

### Go

```
project/
  cmd/               # Entry points
  internal/          # Private packages
  pkg/               # Public packages
  Makefile
  Dockerfile
  go.mod
  CLAUDE.md
  AGENTS.md
  GEMINI.md
```

## Common Setup Steps

1. Create `.gitignore` appropriate for the language
2. Set up linting (ESLint, ruff, golangci-lint)
3. Set up type checking (tsc, mypy, go vet)
4. Create initial test file (verify test runner works)
5. Create `README.md` with project purpose and dev setup
6. Make initial commit
7. Create GitHub repo and push

For the complete setup checklist, see [references/checklist.md](references/checklist.md).
