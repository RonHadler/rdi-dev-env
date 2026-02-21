# <!-- CUSTOMIZE: Project Name --> - OpenAI Codex / ChatGPT Context

> **Shared Context:** See [AGENTS.md](AGENTS.md) for project overview, architecture, security, and file structure.

This file provides context for OpenAI Codex and ChatGPT-based coding agents.

---

## Development Process — TDD is MANDATORY

Every feature follows this pipeline:

1. **Discuss** — Understand the requirement
2. **Plan** — Propose an approach for user approval
3. **Document** — User Stories -> Requirements -> ADR (if architectural)
4. **Implement (TDD)** — Tests FIRST, then code to make them pass
5. **Review** — Feature branch -> PR -> Automated review -> Merge

### TDD Rules

1. **Write failing tests first** — Before ANY implementation, create tests that define expected behavior. They MUST fail.
2. **Write minimum code to pass** — Only enough to make failing tests green.
3. **Refactor** — Clean up while keeping tests green.
4. **Coverage gate** — Do not merge code that drops coverage below 80%.

---

## Architecture

<!-- CUSTOMIZE: Adjust for your project -->

This project uses **Clean Architecture**:

```
Presentation  ->  Application  ->  Infrastructure  ->  Domain (innermost)
```

### Rules
- **Domain layer** has ZERO external dependencies (pure language types only)
- **Application layer** contains use cases, imports only from Domain
- **Infrastructure layer** implements Domain interfaces with external packages
- **Presentation layer** is thin wrappers (API routes, UI components)
- Use **dependency injection** for all external dependencies

### File Placement

| What | Where |
|------|-------|
| Entity / Interface | `src/domain/` |
| Use Case / DTO | `src/application/` |
| Repository / Service impl | `src/infrastructure/` |
| API Route / UI Component | `app/` |

---

## Code Standards

- **No hardcoded secrets** — Use environment variables
- **No `any` types** — Use proper TypeScript types
- **No eval()** — Security risk
- **API routes < 70 lines** — Delegate to use cases
- **Functions < 50 lines** — Extract helpers if longer
- **Files < 200 lines** — Split into focused modules

---

## Git Workflow

- **Branch naming:** `feat/description-MMDD` (append date)
- **Commits:** Conventional format (`feat:`, `fix:`, `test:`, `docs:`)
- **PRs:** All code changes through pull requests
- **Co-author:** Include `Co-Authored-By:` in commit messages

---

## Testing

<!-- CUSTOMIZE: Update test commands for your project -->

```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage

# Type check
npm run type-check

# Lint
npm run lint
```

### Test Patterns
- Co-locate test files with implementations (`MyThing.test.ts`)
- Mock all external dependencies via interfaces
- Cover happy path, edge cases, and error cases
- TDD: write tests BEFORE implementation

---

## Quick Commands

<!-- CUSTOMIZE: Update for your project -->

```bash
npm run dev           # Development server
npm test              # Run tests
npm run build         # Production build
npm run lint          # Lint check
npm run type-check    # TypeScript check
```

---

## Important Notes

- Read existing code before proposing changes
- Follow existing patterns in the codebase
- Don't over-engineer — make only the requested changes
- Ask for clarification rather than assuming

---

<!-- CUSTOMIZE: Update date and version -->
*Last Updated: YYYY-MM-DD*
*Version: 1.0*
