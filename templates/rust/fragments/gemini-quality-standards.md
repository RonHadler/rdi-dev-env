## Quality Standards

- **Clippy:** All code must pass `cargo clippy -- -D warnings` with zero warnings
- **Type check:** `cargo check` must complete cleanly with no errors
- **Function length:** Functions should not exceed 50 lines; extract helpers for complex logic
- **Test coverage:** Minimum 80% line coverage enforced via cargo-tarpaulin
- **Documentation:** All `pub` items must have doc comments (`///`)
- **Unsafe:** No `unsafe` blocks without a `// SAFETY:` comment justifying the invariants
