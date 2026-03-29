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
