# <!-- CUSTOMIZE: Project Name --> - Shared Agent Context

> This file contains project context shared across all AI coding agents (Claude, Gemini, Cursor, etc.).
> Agent-specific instructions are in their respective files: [CLAUDE.md](CLAUDE.md), [GEMINI.md](GEMINI.md)

---

## Project Overview

<!-- CUSTOMIZE: Describe your project in 2-3 sentences -->
<!-- Example: rdi-example-mcp is a FastMCP server that provides AI-powered analysis tools via the Model Context Protocol. It exposes MCP tools for data processing, analysis, and reporting. -->

**Current Phase:** <!-- CUSTOMIZE: Current sprint/phase -->
**Test Coverage:** <!-- CUSTOMIZE: e.g., 10 tests passing (90%+ statements) -->

---

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Framework** | Python 3.12+, FastMCP 3.x, Pydantic v2 |
| **Config** | pydantic-settings, python-dotenv |
| **HTTP** | httpx (async HTTP client) |
| **Testing** | pytest, pytest-asyncio, pytest-mock, pytest-cov |
| **Linting** | ruff (linting + formatting), mypy (strict type checking) |
| **Infrastructure** | Docker, GCP Cloud Run, uv (package manager) |

---

## Architecture Overview

This project uses the **MCP Coordinator Pattern** — a flat module layout with a singleton FastMCP instance.

```
+-----------------------------------------------------------+
|                    Entry Point (server.py)                  |
|         dotenv -> config -> import tools -> mcp.run()      |
+-----------------------------------------------------------+
|                    Tools Layer (tools/)                     |
|        @mcp.tool() decorated async functions               |
|        One file per domain (e.g., analyze.py, health.py)   |
+-----------------------------------------------------------+
|                    Models Layer (models/)                   |
|         Pydantic BaseModel schemas for I/O                 |
+-----------------------------------------------------------+
|                    Config (config.py)                       |
|         Pydantic BaseSettings singleton                    |
+-----------------------------------------------------------+
|                    Coordinator (coordinator.py)             |
|         FastMCP("Name") singleton instance                 |
+-----------------------------------------------------------+
```

### Key Patterns

- **Coordinator Singleton:** `mcp = FastMCP("Name")` in `coordinator.py`, imported by all tool modules
- **Tool Registration:** `@mcp.tool()` decorators in `tools/*.py`, imported in `server.py` to trigger registration
- **Config Singleton:** `settings = Settings()` in `config.py`, typed env var loading via pydantic-settings
- **Entry Point:** `server.py` loads dotenv, imports tools (side-effect registration), calls `mcp.run()`
- **TDD:** Write failing tests first, then implementation code

### Import Rules

| Module | Can Import From | Cannot Import From |
|--------|-----------------|-------------------|
| `coordinator.py` | `fastmcp` only | tools, models, config |
| `config.py` | `pydantic_settings` | tools, coordinator |
| `tools/*.py` | coordinator, config, models | other tools (directly) |
| `models/*.py` | `pydantic` only | tools, config, coordinator |
| `server.py` | Everything (entry point) | N/A |

---

## File Structure

```
<!-- CUSTOMIZE: package_name -->/
  __init__.py
  __main__.py             # python -m support
  coordinator.py          # FastMCP singleton
  config.py               # Pydantic BaseSettings
  server.py               # Entry point
  models/
    __init__.py
    schemas.py            # Pydantic I/O models
  tools/
    __init__.py
    health.py             # Health check tool
    # Add domain-specific tools here

tests/
  __init__.py
  conftest.py             # Shared fixtures
  test_coordinator.py     # Coordinator smoke tests
  test_config.py          # Settings tests
  tools/
    __init__.py
    test_health.py        # Health tool tests

docs/
  current-tasks.md        # Track progress (read first!)
  adr/                    # Architecture decisions
  stories/                # User stories
  requirements/           # Requirements docs
```

---

## Security Standards

- **NO Hardcoded Secrets:** Never commit API keys, tokens, or credentials to git
- **Input Validation:** Validate all tool inputs via Pydantic models
- **Environment Variables:** All secrets via `.env.local` (git-ignored) or GCP Secret Manager
- **Type Safety:** mypy strict mode enforced — no `Any` types without justification

<!-- CUSTOMIZE: Add project-specific security requirements -->

---

## Environment Variables

### Required

<!-- CUSTOMIZE: List your required env vars -->
```
PORT=8000                  # Server port (default 8000)
```

### Optional

<!-- CUSTOMIZE: List optional env vars with defaults -->
```
<!-- CUSTOMIZE: package_name -->_TRANSPORT=streamable-http  # Transport: streamable-http | stdio | sse
<!-- CUSTOMIZE: package_name -->_ENV=development            # Environment: development | staging | production
LOG_LEVEL=info                                              # Log verbosity
```

---

## Quick Commands

```bash
# Development
make dev-serve              # Start server (Streamable HTTP)
make dev-stdio              # Start server (stdio transport)

# Testing
make test                   # pytest with coverage
make test-quick             # pytest without coverage

# Code Quality
make lint                   # ruff check
make format                 # ruff format
make type-check             # mypy strict

# Building
make build                  # Docker build
make clean                  # Remove caches
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
|                              |  make dev-serve      |
+------------------------------+----------------------+
```

### Starting the Environment

```bash
# One-command launch (from rdi-dev-env):
bash /path/to/rdi-dev-env/tmux/tmux-dev.sh /path/to/project session-name

# Or manually:
# Pane 1: claude
# Pane 2: bash scripts/quality-gate.sh
# Pane 3: make dev-serve
```

---

<!-- CUSTOMIZE: Update date and version -->
*Last Updated: <!-- CUSTOMIZE: date -->*
*Version: 1.0*
