"""Shared fixtures for MCP smoke tests.

Provides connection to a deployed MCP server via FastMCP Client.
All smoke tests are skipped when SMOKE_TEST_URL is not set.
"""

from __future__ import annotations

import os
from collections.abc import AsyncIterator

import pytest
from fastmcp.client import Client


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Skip all smoke-marked tests when SMOKE_TEST_URL is not set."""
    if os.environ.get("SMOKE_TEST_URL"):
        return
    skip_smoke = pytest.mark.skip(reason="SMOKE_TEST_URL not set")
    for item in items:
        if "smoke" in item.keywords:
            item.add_marker(skip_smoke)


@pytest.fixture(scope="function")
def smoke_url() -> str:
    """Read the deployed server URL from environment."""
    url = os.environ.get("SMOKE_TEST_URL", "")
    if not url:
        pytest.skip("SMOKE_TEST_URL not set")
    return url


@pytest.fixture(scope="function")
def auth_token() -> str | None:
    """Optional bearer token for authenticated servers."""
    return os.environ.get("SMOKE_TEST_AUTH_TOKEN")


@pytest.fixture(scope="function")
async def mcp_client(smoke_url: str, auth_token: str | None) -> AsyncIterator[Client]:
    """Connect to the deployed MCP server and yield a ready client."""
    auth = auth_token if auth_token else None
    client = Client(smoke_url, auth=auth)

    async with client:
        yield client
