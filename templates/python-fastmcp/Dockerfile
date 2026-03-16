FROM python:3.13-slim

# Install uv from official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

COPY . /app
WORKDIR /app

ENV PYTHONUNBUFFERED=1

# Install production dependencies only
RUN uv sync --no-dev

# Run as non-root user
RUN useradd -m appuser
USER appuser

EXPOSE ${PORT:-8000}

CMD ["uv", "run", "python", "-m", "<!-- CUSTOMIZE: package_name -->.server"]
