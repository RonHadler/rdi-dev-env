FROM python:3.12-slim

# Install uv from official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app
ENV PYTHONUNBUFFERED=1

# Install dependencies first (cached unless pyproject.toml/uv.lock change)
COPY pyproject.toml uv.lock* /app/
RUN uv sync --frozen --no-dev --no-install-project

# Copy full source and install project
COPY . /app
RUN uv sync --frozen --no-dev

# Run as non-root user
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE ${PORT:-8000}

CMD ["uv", "run", "--no-sync", "python", "-m", "<!-- CUSTOMIZE: package_name -->"]
