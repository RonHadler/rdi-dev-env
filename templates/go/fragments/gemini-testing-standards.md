- All exported functions must have unit tests with mocked dependencies (interfaces)
- **Table-driven tests** are the standard pattern for multiple input/output scenarios
- Tests must pass with `-race` flag enabled (race condition detection)
- Test coverage should be > 80%
- Test files live next to source files (`foo_test.go` alongside `foo.go`)
- Use `t.Helper()` in test helper functions for accurate line reporting
- Edge cases must be covered (empty input, nil values, error paths)
- TDD is mandatory — tests written before implementation

<!-- CUSTOMIZE: Add project-specific testing patterns and notes -->
