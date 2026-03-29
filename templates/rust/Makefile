.PHONY: dev test lint check build clean

## dev: Run the project in development mode
dev:
	cargo run

## test: Run all tests
test:
	cargo test

## lint: Run clippy with strict warnings
lint:
	cargo clippy -- -D warnings

## check: Type-check without producing binaries
check:
	cargo check

## build: Build optimized release binary
build:
	cargo build --release

## clean: Remove build artifacts
clean:
	cargo clean
