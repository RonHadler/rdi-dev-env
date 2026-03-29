```bash
# Development
make dev-serve              # Start server (Streamable HTTP)
make dev-stdio              # Start server (stdio transport)

# Testing
make test                   # pytest with coverage
make test-quick             # pytest without coverage
make smoke                  # Smoke tests against deployed server

# Code Quality
make lint                   # ruff check
make format                 # ruff format
make type-check             # mypy strict

# Building
make build                  # Docker build
make clean                  # Remove caches
```
