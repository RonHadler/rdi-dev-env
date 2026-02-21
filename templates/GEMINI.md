# <!-- CUSTOMIZE: Project Name --> - Gemini Code Review Context

> **Shared Context:** See [AGENTS.md](AGENTS.md) for project overview, architecture, security, and file structure.

This file contains Gemini-specific code review standards and guidelines.

---

## Review Focus Areas

When reviewing code changes, prioritize:

### 1. Critical Issues (Block Merge)
- Security vulnerabilities (XSS, injection, auth bypass)
- Data loss risks
- Breaking changes without migration
- Domain layer importing external packages

### 2. High Priority (Strong Warning)
- Clean Architecture violations (domain layer dependencies)
- Untestable code (hard dependencies, no DI)
- Performance issues (N+1 queries, memory leaks)
- Missing error handling
- API routes with business logic (should be in use cases)

### 3. Medium Priority (Suggestions)
- Code style violations (file/function length)
- Missing tests for new code
- TypeScript `any` types (or equivalent loose typing)
- Readability improvements

### 4. Low Priority (Informational)
- Code formatting (leave to linter)
- Minor optimizations
- Documentation improvements

---

## Code Quality Standards

| Metric | Target |
|--------|--------|
| File length | < 200 lines |
| Function length | < 50 lines |
| Cyclomatic complexity | < 10 |
| Test coverage | > 80% |

<!-- CUSTOMIZE: Add language-specific quality standards -->

---

## Architectural Constraints

<!-- CUSTOMIZE: Adjust layer paths and rules for your project -->

### Domain Layer (`src/domain/`)
- **ONLY** pure language types, interfaces, and entities
- **ZERO** imports from npm/pip/external packages
- No business logic implementation (only interfaces)
- No imports from infrastructure, application, or presentation layers

### Application Layer (`src/application/`)
- Use cases orchestrate business logic
- Use dependency injection for all external dependencies
- Return DTOs, not entities directly
- No direct instantiation of infrastructure classes

### Infrastructure Layer (`src/infrastructure/`)
- Implements domain interfaces
- All external dependencies go here
- No business logic (only integration logic)

### Presentation Layer (`app/`)
- API routes are thin wrappers (50-70 lines max)
- Resolve use cases from DI container
- Handle HTTP concerns only
- No business logic

---

## Common Violations to Flag

### 1. Importing external packages in domain layer
```
BAD:  import SomeSDK from 'some-package';  // in domain/
GOOD: export interface ISomeService { ... } // interface in domain/
```

### 2. Hard-coded dependencies
```
BAD:  const provider = new ConcreteProvider();
GOOD: constructor(private provider: IProvider) {}
```

### 3. Business logic in API routes
```
BAD:  300 lines of logic in route handler
GOOD: Route calls use case, returns result
```

---

## Review Guidelines

- **Be specific:** Reference line numbers and exact issues
- **Be actionable:** Suggest how to fix, don't just point out problems
- **Be concise:** Focus on critical issues first
- **Be constructive:** Explain *why* something is an issue
- **Approve if good:** Don't nitpick - if code is solid, say so!

---

## Testing Standards

- All use cases must have unit tests with mocked dependencies
- All API routes should have integration tests
- Edge cases must be covered
- Test coverage should be > 80%
- TDD is mandatory - tests written before implementation

<!-- CUSTOMIZE: Add project-specific testing patterns and notes -->

---

<!-- CUSTOMIZE: Update date and version -->
*Last Updated: YYYY-MM-DD*
*Version: 1.0*
