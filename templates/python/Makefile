.PHONY: dev test test-quick lint format type-check build clean

# ── Development ──────────────────────────────────────────────

dev:  ## Start development server
	uv run python -m <!-- CUSTOMIZE: package_name -->

# ── Testing ──────────────────────────────────────────────────

test:  ## Run tests with coverage
	uv run pytest --cov=<!-- CUSTOMIZE: package_name --> --cov-report=term-missing -v

test-quick:  ## Run tests without coverage
	uv run pytest -v

# ── Code Quality ─────────────────────────────────────────────

lint:  ## Run ruff linter
	uv run ruff check .

format:  ## Auto-format with ruff
	uv run ruff format .

type-check:  ## Run mypy strict type checking
	uv run mypy <!-- CUSTOMIZE: package_name -->/

# ── Build ────────────────────────────────────────────────────

build:  ## Build Docker image
	docker build -t <!-- CUSTOMIZE: project-name --> .

clean:  ## Remove cache directories
	rm -rf __pycache__ .pytest_cache .mypy_cache .ruff_cache .coverage htmlcov
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
