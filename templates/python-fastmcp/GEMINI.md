# <!-- CUSTOMIZE: Project Name --> - Gemini Code Review Context

> **Shared Context:** See [AGENTS.md](AGENTS.md) for project overview, architecture, security, and file structure.

This file contains Gemini-specific code review standards and guidelines for Python/FastMCP projects.

---

## Review Focus Areas

When reviewing code changes, prioritize:

### 1. Critical Issues (Block Merge)
- Security vulnerabilities (injection, auth bypass, hardcoded secrets)
- Data loss risks
- Breaking changes without migration
- Missing type hints on public functions

### 2. High Priority (Strong Warning)
- MCP coordinator pattern violations (tools importing other tools directly)
- Untestable code (hard dependencies, no DI)
- Missing error handling in tool functions
- Performance issues (blocking calls in async functions, memory leaks)
- Business logic outside of tool functions (in server.py or coordinator.py)

### 3. Medium Priority (Suggestions)
- Code style violations (file/function length)
- Missing tests for new code
- Loose typing (`Any`, `dict` instead of Pydantic models)
- Missing docstrings on MCP tools
- Readability improvements

### 4. Low Priority (Informational)
- Code formatting (leave to ruff)
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
| Type hints | All public functions |
| Docstrings | All MCP tools |

### Python-Specific Standards

- **Type hints required** on all function signatures (enforced by mypy strict)
- **Docstrings required** on all MCP tool functions (shown to LLM clients)
- **Ruff compliance** — code must pass `ruff check .` with zero errors
- **No `Any` types** without explicit justification in a comment
- **Async consistency** — tool functions should be `async def` unless purely synchronous
- **Pydantic models** for all structured I/O (not raw dicts)

---

## Architectural Constraints

### Coordinator (`coordinator.py`)
- **ONLY** creates the FastMCP singleton instance
- No tool definitions, no config access, no business logic
- Should be 2-5 lines of code

### Config (`config.py`)
- **ONLY** Pydantic BaseSettings class and module-level singleton
- All environment variables typed with defaults
- No imports from tools or coordinator

### Tools (`tools/*.py`)
- Each file covers one domain (health, analysis, etc.)
- Functions decorated with `@mcp.tool()`
- Import coordinator for `mcp` reference, config for `settings`
- Input validation at function boundary
- Return Pydantic models, not raw dicts

### Server (`server.py`)
- Entry point only — loads dotenv, imports tool modules, runs server
- Custom routes (e.g., `/health`) registered here
- No business logic

### Models (`models/*.py`)
- Pydantic BaseModel classes for tool I/O
- No external dependencies beyond pydantic
- Strict validation (`model_config = {"extra": "forbid"}` where appropriate)

---

## Common Violations to Flag

### 1. Tools importing other tools
```python
# BAD: tools/analyze.py importing tools/health.py
from tools.health import check_service

# GOOD: shared logic in a service module, or call via coordinator
```

### 2. Raw dicts instead of Pydantic models
```python
# BAD
@mcp.tool()
async def analyze(data: dict) -> dict:
    return {"result": "..."}

# GOOD
@mcp.tool()
async def analyze(data: AnalyzeInput) -> AnalyzeOutput:
    return AnalyzeOutput(result="...")
```

### 3. Blocking calls in async functions
```python
# BAD
@mcp.tool()
async def fetch_data(url: str) -> str:
    import requests
    return requests.get(url).text

# GOOD
@mcp.tool()
async def fetch_data(url: str) -> str:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.text
```

### 4. Missing error handling in tools
```python
# BAD
@mcp.tool()
async def call_api(endpoint: str) -> ApiResponse:
    response = await client.get(endpoint)
    return ApiResponse.model_validate(response.json())

# GOOD
@mcp.tool()
async def call_api(endpoint: str) -> ApiResponse:
    try:
        response = await client.get(endpoint)
        response.raise_for_status()
        return ApiResponse.model_validate(response.json())
    except httpx.HTTPError as exc:
        raise ValueError(f"API call failed: {exc}") from exc
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

- All MCP tools must have unit tests with mocked external dependencies
- Async tests use `pytest-asyncio` with `asyncio_mode = "auto"`
- Config tests verify env var loading and defaults
- Edge cases must be covered (empty input, invalid input, timeout)
- Test coverage should be > 80%
- TDD is mandatory — tests written before implementation

<!-- CUSTOMIZE: Add project-specific testing patterns and notes -->

---

<!-- CUSTOMIZE: Update date and version -->
*Last Updated: <!-- CUSTOMIZE: date -->*
*Version: 1.0*
