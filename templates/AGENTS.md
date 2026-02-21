# <!-- CUSTOMIZE: Project Name --> - Shared Agent Context

> This file contains project context shared across all AI coding agents (Claude, Gemini, Cursor, etc.).
> Agent-specific instructions are in their respective files: [CLAUDE.md](CLAUDE.md), [GEMINI.md](GEMINI.md)

---

## Project Overview

<!-- CUSTOMIZE: Describe your project in 2-3 sentences -->
<!-- Example: MyApp is a Next.js analytics platform integrating GA4 and Google Ads with AI. It provides a chat interface for querying real analytics data using natural language. -->

**Current Phase:** <!-- CUSTOMIZE: Current sprint/phase -->
**Test Coverage:** <!-- CUSTOMIZE: e.g., 500 tests passing (85%+ statements) -->

---

## Technology Stack

<!-- CUSTOMIZE: Update this table for your project -->

| Layer | Technologies |
|-------|-------------|
| **Frontend** | <!-- e.g., Next.js 15, React 19, TypeScript, Tailwind CSS --> |
| **Backend** | <!-- e.g., Next.js API routes, Clean Architecture --> |
| **Database** | <!-- e.g., Firebase/Firestore, PostgreSQL --> |
| **Testing** | <!-- e.g., Jest 30, React Testing Library --> |
| **Infrastructure** | <!-- e.g., Docker, GCP Cloud Run --> |

---

## Architecture Overview

<!-- CUSTOMIZE: Adjust if not using Clean Architecture -->

This project uses **Clean Architecture** with four layers:

```
+-----------------------------------------------------------+
|                    Presentation Layer                       |
|              (API routes, UI components, CLI)               |
+-----------------------------------------------------------+
|                    Application Layer                        |
|           (Use cases, DTOs, orchestration)                  |
+-----------------------------------------------------------+
|                   Infrastructure Layer                      |
|    (External SDKs, databases, file systems, APIs)           |
+-----------------------------------------------------------+
|                      Domain Layer                           |
|      (Entities, interfaces, value objects, types)           |
|              *** ZERO external dependencies ***             |
+-----------------------------------------------------------+
```

### Layer Rules

| Layer | Can Import From | Cannot Import From |
|-------|-----------------|-------------------|
| Domain | Nothing (pure language types) | Any packages, other layers |
| Application | Domain | Infrastructure, Presentation |
| Infrastructure | Domain, Application | Presentation |
| Presentation | All layers via DI container | Direct instantiation |

### Key Patterns

- **TDD (Test-Driven Development):** Write failing tests first, then code to pass, then refactor
- **Dependency Injection:** All external dependencies injected via interfaces
- **Use Cases:** Business logic lives in use case classes, not API routes

---

## File Structure

<!-- CUSTOMIZE: Update to match your project structure -->

```
app/                          # Presentation layer
  api/                        # API routes (thin wrappers)
  components/                 # UI components
  hooks/                      # React hooks
  page.tsx                    # Main page

src/                          # Clean Architecture layers
  domain/
    entities/                 # Business objects
    interfaces/               # Contracts (IRepository, IService)
    types/                    # Shared types
  application/
    use-cases/                # Business logic
    dto/                      # Data transfer objects
  infrastructure/
    repositories/             # Database implementations
    services/                 # External service integrations

docs/
  current-tasks.md            # Track progress (read first!)
  adr/                        # Architecture decisions
```

---

## Security Standards

- **NO Hardcoded Secrets:** Never commit API keys, tokens, or credentials to git
- **Input Validation:** Validate all user inputs, sanitize for XSS
- **Authentication:** All protected routes must verify auth
- **Authorization:** Role-based access control enforced

<!-- CUSTOMIZE: Add project-specific security requirements -->

---

## Environment Variables

### Required

<!-- CUSTOMIZE: List your required env vars -->
```
DATABASE_URL=           # Database connection string
API_KEY=                # External API key
```

### Optional

<!-- CUSTOMIZE: List optional env vars with defaults -->
```
DEBUG_MODE=false        # Enable debug logging
LOG_LEVEL=info          # Log verbosity
```

---

## Quick Commands

<!-- CUSTOMIZE: Update commands for your project -->

```bash
# Development
npm run dev                    # Start dev server

# Testing
npm test                       # Run unit tests
npm run test:coverage          # Generate coverage report
npm run type-check             # TypeScript type checking
npm run lint                   # Lint checks

# Building
npm run build                  # Production build
```

---

## Development Environment (tmux)

### Layout

The recommended development setup uses tmux with 3 panes:

```
+------------------------------+----------------------+
|                              |                      |
|   Pane 1: Claude Code        |  Pane 2: Quality     |
|   (main development)         |  Gate (watch)        |
|                              |                      |
|                              +----------------------+
|                              |                      |
|                              |  Pane 3: Dev Server  |
|                              |                      |
+------------------------------+----------------------+
```

### Starting the Environment

```bash
# One-command launch (from rdi-dev-env):
bash /path/to/rdi-dev-env/tmux/tmux-dev.sh /path/to/project session-name

# Or manually:
# Pane 1: claude
# Pane 2: bash scripts/quality-gate.sh
# Pane 3: npm run dev
```

### Inter-Pane Commands (from Claude Code)

```bash
# Restart dev server (Pane 3)
tmux send-keys -t 3 C-c && tmux send-keys -t 3 'npm run dev' Enter

# Re-run quality gate (Pane 2)
tmux send-keys -t 2 C-c && tmux send-keys -t 2 'bash scripts/quality-gate.sh' Enter
```

<!-- CUSTOMIZE: Add project-specific WSL2 or environment notes -->

---

<!-- CUSTOMIZE: Update date and version -->
*Last Updated: YYYY-MM-DD*
*Version: 1.0*
