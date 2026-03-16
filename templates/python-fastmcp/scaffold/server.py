import logging

from starlette.requests import Request
from starlette.responses import JSONResponse

from <!-- CUSTOMIZE: package_name -->.config import get_settings
from <!-- CUSTOMIZE: package_name -->.coordinator import mcp

logger = logging.getLogger(__name__)
# Import tool modules to trigger @mcp.tool() registration
# <!-- CUSTOMIZE: Add tool imports here, e.g.:
# from <!-- CUSTOMIZE: package_name -->.tools import health  # noqa: F401


# Register health endpoint on FastMCP server
@mcp.custom_route("/health", methods=["GET"])
async def health_endpoint(request: Request) -> JSONResponse:
    """Health check for Cloud Run liveness/readiness probes."""
    return JSONResponse({"status": "ok"})


def main() -> None:
    """Start the MCP server with configured transport."""
    settings = get_settings()
    port = settings.port
    transport = settings.<!-- CUSTOMIZE: package_name -->_transport

    print(f"<!-- CUSTOMIZE: Project Name --> starting on port {port} ({transport})")
    mcp.run(transport=transport, port=port, host="0.0.0.0")


if __name__ == "__main__":
    main()
