# ── Stage 1: Build ──
FROM golang:1.23-alpine AS builder

WORKDIR /src

# Install dependencies first (cached unless go.mod/go.sum change)
COPY go.mod go.sum* ./
RUN go mod download

# Copy full source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server ./cmd/server

# ── Stage 2: Runtime ──
FROM alpine:3.21

RUN apk --no-cache add ca-certificates \
    && adduser -D -g '' appuser

COPY --from=builder --chown=appuser:appuser /app/server /app/server

USER appuser

EXPOSE ${PORT:-8000}

ENTRYPOINT ["/app/server"]
