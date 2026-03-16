import logging
import os

import dotenv
from starlette.requests import Request
from starlette.responses import JSONResponse

logger = logging.getLogger(__name__)

# Load .env files BEFORE importing config
dotenv.load_dotenv()

# fmt: off
# isort: off
# Import after dotenv so env vars are available at module load time
from <!-- CUSTOMIZE: package_name -->.config import settings  # noqa: E402
from <!-- CUSTOMIZE: package_name -->.coordinator import mcp  # noqa: E402
# Import tool modules to trigger @mcp.tool() registration
# <!-- CUSTOMIZE: Add tool imports here, e.g.:
# from <!-- CUSTOMIZE: package_name -->.tools import health  # noqa: E402, F401
# isort: on
# fmt: on


# Register health endpoint on FastMCP server
@mcp.custom_route("/health", methods=["GET"])
async def health_endpoint(request: Request) -> JSONResponse:
    """Health check for Cloud Run liveness/readiness probes."""
    return JSONResponse({"status": "ok"})


def main() -> None:
    """Start the MCP server with configured transport."""
    port = int(os.environ.get("PORT", settings.port))
    transport = settings.<!-- CUSTOMIZE: package_name -->_transport

    print(f"<!-- CUSTOMIZE: Project Name --> starting on port {port} ({transport})")
    mcp.run(transport=transport, port=port, host="0.0.0.0")


if __name__ == "__main__":
    main()
