| Metric | Target |
|--------|--------|
| File length | < 200 lines |
| Function length | < 50 lines |
| Cyclomatic complexity | < 10 |
| Test coverage | > 80% |
| Type hints | All public functions |
| Docstrings | All public APIs |

### Python-Specific Standards

- **Type hints required** on all function signatures (enforced by mypy strict)
- **Ruff compliance** — code must pass `ruff check .` with zero errors
- **No `Any` types** without explicit justification in a comment
- **Async consistency** — async functions should use `async with` / `await`, never blocking calls
- **Pydantic models** for all structured I/O (not raw dicts)
