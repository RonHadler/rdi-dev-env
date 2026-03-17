"""Shared fixtures for MCP smoke tests.

Provides connection to a deployed MCP server via FastMCP Client.
All smoke tests are skipped when SMOKE_TEST_URL is not set.
"""

from __future__ import annotations

import os

import pytest
from fastmcp.client import Client


@pytest.fixture(scope="module")
def smoke_url() -> str:
    """Read the deployed server URL from environment.

    Skips the entire test module when SMOKE_TEST_URL is not set,
    so smoke tests never fail in local `make test` runs.
    """
    url = os.environ.get("SMOKE_TEST_URL", "")
    if not url:
        pytest.skip("SMOKE_TEST_URL not set — skipping smoke tests")
    return url


@pytest.fixture(scope="module")
def auth_token() -> str | None:
    """Optional bearer token for authenticated servers."""
    return os.environ.get("SMOKE_TEST_AUTH_TOKEN")


@pytest.fixture(scope="module")
async def mcp_client(smoke_url: str, auth_token: str | None) -> Client:
    """Connect to the deployed MCP server and yield a ready client.

    Module-scoped so the connection is reused across all tests in a file.
    """
    auth = auth_token if auth_token else None
    client = Client(smoke_url, auth=auth)

    async with client:
        yield client
