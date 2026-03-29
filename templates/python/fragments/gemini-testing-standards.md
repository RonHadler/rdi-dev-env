- All public functions must have unit tests with mocked external dependencies
- Async tests use `pytest-asyncio` with `asyncio_mode = "auto"`
- Config tests verify env var loading and defaults
- Edge cases must be covered (empty input, invalid input, timeout)
- Test coverage should be > 80%
- TDD is mandatory — tests written before implementation

<!-- CUSTOMIZE: Add project-specific testing patterns and notes -->
