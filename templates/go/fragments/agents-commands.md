```bash
# Development
make dev                    # Run server locally (go run)

# Testing
make test                   # go test with coverage
make test-race              # go test with race detector

# Code Quality
make lint                   # golangci-lint run
make vet                    # go vet (type/correctness checks)

# Building
make build                  # Build binary to bin/server
make clean                  # Remove bin/ and coverage.out
```
