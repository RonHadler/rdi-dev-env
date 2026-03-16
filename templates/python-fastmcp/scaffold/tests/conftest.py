"""Shared test fixtures for <!-- CUSTOMIZE: project-name -->."""

from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def _set_test_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set minimal env vars for tests (runs for every test)."""
    monkeypatch.setenv("<!-- CUSTOMIZE: PACKAGE_NAME -->_ENV", "test")
