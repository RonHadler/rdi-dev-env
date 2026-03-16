"""Smoke tests for the <!-- CUSTOMIZE: Project Name --> coordinator."""

from <!-- CUSTOMIZE: package_name -->.coordinator import mcp
from <!-- CUSTOMIZE: package_name -->.server import main


class TestCoordinator:
    def test_mcp_instance_exists(self) -> None:
        assert mcp is not None

    def test_server_name(self) -> None:
        assert mcp.name == "<!-- CUSTOMIZE: Project Name -->"

    def test_main_is_callable(self) -> None:
        assert callable(main)
