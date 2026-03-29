# Stage 1: Build
FROM rust:1.85-slim AS builder

WORKDIR /app

# Copy manifests first for dependency caching
COPY Cargo.toml Cargo.lock* ./

# Create dummy src to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Copy real source and rebuild
COPY src/ src/
RUN touch src/main.rs && cargo build --release

# Stage 2: Runtime
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder --chown=appuser:appuser /app/target/release/<!-- CUSTOMIZE: project-name --> /usr/local/bin/server

# Non-root user
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

EXPOSE ${PORT:-8000}

ENTRYPOINT ["/usr/local/bin/server"]
