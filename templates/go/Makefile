.PHONY: dev test test-race lint vet build clean

## dev: Run the server locally
dev:
	go run ./cmd/server

## test: Run tests with coverage
test:
	go test ./... -coverprofile=coverage.out -covermode=atomic -v

## test-race: Run tests with race detector
test-race:
	go test -race ./... -v

## lint: Run golangci-lint
lint:
	golangci-lint run ./...

## vet: Run go vet (type/correctness checks)
vet:
	go vet ./...

## build: Build the server binary
build:
	go build -o bin/server ./cmd/server

## clean: Remove build artifacts
clean:
	rm -rf bin/ coverage.out
