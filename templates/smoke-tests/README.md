# Smoke Test Framework for Python/FastMCP MCP Servers

Functional validation after deployment using FastMCP's built-in `Client`.

## Quick Start

### 1. Copy the template files

```bash
mkdir -p tests/smoke
cp templates/smoke-tests/conftest.py tests/smoke/conftest.py
cp templates/smoke-tests/test_smoke_example.py tests/smoke/test_smoke_<your_server>.py
touch tests/smoke/__init__.py
```

### 2. Add the pytest marker to `pyproject.toml`

```toml
[tool.pytest.ini_options]
markers = [
    "smoke: tests against a deployed server (skipped when SMOKE_TEST_URL unset)",
]
```

### 3. Add the Makefile target

```makefile
smoke:  ## Run smoke tests against deployed server
	uv run pytest tests/smoke/ -v -m smoke --tb=short
```

### 4. Customize the test file

- Set `EXPECTED_TOOLS` to your server's tool names
- Add one `test_<tool>_smoke` per tool with the cheapest valid input
- Gate expensive operations behind env vars (e.g. `SMOKE_TEST_LLM=true`)

### 5. Run locally

```bash
# Start your server
make dev-serve

# In another terminal
SMOKE_TEST_URL=http://localhost:8000/mcp make smoke
```

### 6. Add to CI (optional)

See `workflow-snippet.yml` for GitHub Actions integration with Cloud Run deployments.

## Guidelines

- **Use the cheapest valid input** — smallest file, simplest query, fewest tokens
- **Gate expensive operations** — LLM calls, large file processing behind env vars
- **Validate shape, not content** — check field presence and types, not exact values
- **Keep total runtime < 30 seconds** — smoke tests run on every deployment
- **Don't test error paths** — unit tests handle that; smoke tests confirm "it works"

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SMOKE_TEST_URL` | Yes | Server URL (e.g. `http://localhost:8000/mcp`) |
| `SMOKE_TEST_AUTH_TOKEN` | No | Bearer token for authenticated servers |

## How It Works

1. `conftest.py` reads `SMOKE_TEST_URL` — if unset, all smoke tests skip gracefully
2. `mcp_client` fixture connects via FastMCP `Client` (function-scoped for pytest-asyncio compatibility)
3. Tests call `list_tools()` and `call_tool()` against the live server
4. In CI, failures after deployment trigger automatic rollback
