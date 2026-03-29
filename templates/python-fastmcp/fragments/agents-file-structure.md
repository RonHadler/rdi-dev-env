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
