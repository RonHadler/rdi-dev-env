## File Structure

```
Cargo.toml          # Package manifest and dependencies
Cargo.lock          # Locked dependency versions
src/
  main.rs           # Application entry point
  lib.rs            # Library root (public API)
tests/              # Integration tests
Dockerfile          # Multi-stage production build
Makefile            # Standard dev/build/test targets
```
