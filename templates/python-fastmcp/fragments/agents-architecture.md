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
