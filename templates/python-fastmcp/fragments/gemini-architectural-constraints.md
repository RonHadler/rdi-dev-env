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
