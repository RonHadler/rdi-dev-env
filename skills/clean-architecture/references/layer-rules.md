# Layer Dependency Rules

## Import Constraints Matrix

```
FROM \ TO        Domain    Application    Infrastructure    Presentation
Domain              -        NEVER            NEVER            NEVER
Application        OK          -              NEVER            NEVER
Infrastructure     OK         OK                -              NEVER
Presentation       OK         OK         Only via DI            -
```

## Domain Layer Constraints

The domain layer is the innermost layer. It has ZERO dependencies on anything external.

**Allowed:**
- Pure language types (string, number, boolean, Date, Map, Set, etc.)
- Interfaces (contracts for what other layers must implement)
- Entities (business objects with behavior)
- Value objects (immutable, equality by value)
- Enums and type aliases
- Pure functions (no side effects)

**Forbidden:**
- `import` from any npm package
- `import` from `@anthropic-ai/*`, `firebase-admin/*`, `openai`, etc.
- `process.env` access
- File system access
- Network calls
- Any side effects

## Application Layer Constraints

The application layer orchestrates business logic via use cases.

**Allowed:**
- Import from Domain layer
- Use case classes
- DTOs (Data Transfer Objects)
- Application-level interfaces (e.g., `IAuthService`)
- React context definitions (types + hooks, NOT providers)

**Forbidden:**
- Import from Infrastructure layer
- Import from Presentation layer
- Direct instantiation of infrastructure classes
- Direct HTTP/database/file operations

## Infrastructure Layer Constraints

The infrastructure layer implements domain interfaces using external libraries.

**Allowed:**
- Import from Domain layer
- Import from Application layer
- npm packages (SDKs, ORMs, etc.)
- Environment variable access
- File system, network, database operations
- `@injectable()` and `@inject()` decorators

**Forbidden:**
- Import from Presentation layer
- Business logic (only integration/mapping logic)

## Presentation Layer Constraints

The presentation layer handles user interaction (HTTP, UI, CLI).

**Allowed:**
- Import from all layers (but prefer via DI container)
- API route handlers (thin wrappers)
- React components
- React hooks

**Forbidden:**
- Direct instantiation of infrastructure classes (use DI container)
- Business logic (delegate to use cases)
- Long route handlers (>70 lines is a smell)

## How to Check for Violations

Quick grep to find potential violations:

```bash
# Domain layer importing npm packages
grep -rn "from ['\"]" src/domain/ | grep -v "from ['\"]\./" | grep -v "from ['\"]@/" | grep -v ".test."

# Application layer importing infrastructure
grep -rn "from.*infrastructure" src/application/ | grep -v ".test."

# Business logic in API routes (long files)
wc -l app/api/**/route.ts | sort -n | tail -20
```
