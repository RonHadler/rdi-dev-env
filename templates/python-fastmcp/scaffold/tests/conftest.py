"""Shared test fixtures for <!-- CUSTOMIZE: project-name -->."""

from __future__ import annotations

import os

import pytest


@pytest.fixture(autouse=True)
def _set_test_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set minimal env vars for tests and re-instantiate Settings singleton."""
    monkeypatch.setenv("<!-- CUSTOMIZE: PACKAGE_NAME -->_ENV", "test")

    # Re-instantiate Settings so it picks up the monkeypatched env vars
    # (the module-level singleton is created at import time, before fixtures run)
    from <!-- CUSTOMIZE: package_name --> import config
    from <!-- CUSTOMIZE: package_name -->.config import Settings

    config.settings = Settings()
