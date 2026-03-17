"""Smoke tests for <!-- CUSTOMIZE: Project Name --> MCP server.

Copy this file to tests/smoke/test_smoke_<name>.py and customize.
Run with: SMOKE_TEST_URL=http://localhost:8000/mcp make smoke
"""

from __future__ import annotations

import json

import pytest
from fastmcp.client import Client

pytestmark = pytest.mark.smoke


# ── Tool Discovery ───────────────────────────────────────────


class TestToolDiscovery:
    """Verify the server exposes the expected set of tools."""

    # <!-- CUSTOMIZE: set of tool names your server registers -->
    EXPECTED_TOOLS = {"health_check", "tool_a", "tool_b"}

    async def test_expected_tools_registered(self, mcp_client: Client) -> None:
        tools = await mcp_client.list_tools()
        tool_names = {t.name for t in tools}

        missing = self.EXPECTED_TOOLS - tool_names
        assert not missing, f"Missing tools: {missing}"


# ── Tool Execution ───────────────────────────────────────────


class TestToolExecution:
    """Call each tool with the cheapest valid input and validate the response."""

    async def test_health_check_smoke(self, mcp_client: Client) -> None:
        result = await mcp_client.call_tool("health_check", {})
        data = json.loads(result.content[0].text)

        assert data["status"] == "ok"
        # <!-- CUSTOMIZE: add server-specific health assertions -->

    # <!-- CUSTOMIZE: add one test per tool with minimal input -->
    # async def test_tool_a_smoke(self, mcp_client: Client) -> None:
    #     result = await mcp_client.call_tool("tool_a", {"param": "value"})
    #     data = json.loads(result.content[0].text)
    #     assert "expected_field" in data
