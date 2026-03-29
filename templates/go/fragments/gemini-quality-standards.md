| Metric | Target |
|--------|--------|
| File length | < 200 lines |
| Function length | < 50 lines |
| Cyclomatic complexity | < 10 |
| Test coverage | > 80% |
| Exported docs | All exported functions documented |
| golangci-lint | Zero errors |

### Go-Specific Standards

- **All exported functions must have doc comments** (enforced by golangci-lint)
- **golangci-lint clean** — code must pass `golangci-lint run ./...` with zero errors
- **go vet clean** — code must pass `go vet ./...` with zero errors
- **No global variables** without explicit justification in a comment
- **Error handling** — all errors must be checked, no `_ = fn()` for error returns
- **Interface compliance** — use small, focused interfaces; prefer standard library interfaces
