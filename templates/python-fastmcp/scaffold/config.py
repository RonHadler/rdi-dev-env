from typing import Literal

from pydantic_settings import BaseSettings

TransportType = Literal["stdio", "sse", "streamable-http"]


class Settings(BaseSettings):
    """<!-- CUSTOMIZE: Project Name --> server configuration loaded from environment variables."""

    # Server
    port: int = 8000
    <!-- CUSTOMIZE: package_name -->_env: str = "development"
    <!-- CUSTOMIZE: package_name -->_transport: TransportType = "streamable-http"

    # <!-- CUSTOMIZE: Add project-specific settings here -->

    model_config = {
        "env_file": (".env.development", ".env.local"),
        "env_file_encoding": "utf-8",
        "extra": "ignore",
    }


def get_settings() -> Settings:
    """Return the module-level Settings singleton."""
    return settings


# Module-level singleton — reads .env once at import time
settings = Settings()
