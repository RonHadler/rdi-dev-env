# ── Smoke Tests ───────────────────────────────────────────────
# Paste this target into your project Makefile.
# Requires SMOKE_TEST_URL env var (skips gracefully if unset).

smoke:  ## Run smoke tests against deployed server
	uv run pytest tests/smoke/ -v -m smoke --tb=short
