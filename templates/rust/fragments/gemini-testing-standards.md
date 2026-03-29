## Testing Standards

- **Unit tests:** Place in `#[cfg(test)] mod tests` at the bottom of each module
- **Integration tests:** Place in the `tests/` directory at the crate root
- **Doc tests:** Include runnable examples in doc comments for public API items
- **Coverage:** Minimum 80% line coverage measured by cargo-tarpaulin
- **Naming:** Use descriptive test names: `test_<function>_<scenario>_<expected>`
- **Assertions:** Prefer `assert_eq!` / `assert_ne!` over bare `assert!` for better error messages
