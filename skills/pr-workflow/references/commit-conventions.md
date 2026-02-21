# Conventional Commits Guide

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Types

| Type | SemVer | Description |
|------|--------|-------------|
| `feat` | MINOR | New feature |
| `fix` | PATCH | Bug fix |
| `docs` | - | Documentation only |
| `style` | - | Formatting (no code change) |
| `refactor` | - | Code restructuring |
| `perf` | PATCH | Performance improvement |
| `test` | - | Adding/updating tests |
| `build` | - | Build system changes |
| `ci` | - | CI configuration changes |
| `chore` | - | Maintenance tasks |
| `revert` | - | Reverting a previous commit |

## Scopes (Optional)

Scope narrows the type. Common scopes:

```
feat(auth): add JWT token refresh
fix(api): handle timeout in respond route
test(use-cases): add ProcessQuery edge cases
refactor(infra): extract Firestore connection pooling
```

## Breaking Changes

Add `!` after type/scope, or `BREAKING CHANGE:` in footer:

```
feat!: remove deprecated API endpoints

BREAKING CHANGE: The /api/v1/ endpoints have been removed.
Use /api/v2/ instead.
```

## Body

Use the body to explain **why**, not **what** (the diff shows what):

```
fix(auth): handle expired refresh tokens gracefully

Previously, expired refresh tokens caused a 500 error.
Now the user is redirected to login with a clear message.
Closes #42
```

## Footer

```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
Closes #42
Refs: #38, #39
BREAKING CHANGE: description
```

## Multi-Line Commit Messages

Use heredoc format in bash:

```bash
git commit -m "$(cat <<'EOF'
feat(reports): add export to PDF

Implements PDF export using the browser's print API.
Adds a download button to the report header.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

## Examples

```
feat: add user activity dashboard
fix: resolve hydration mismatch in sidebar
test: add coverage for auth middleware
docs: update API documentation for v2 endpoints
refactor: extract common validation into shared utility
chore: update dependencies to latest versions
perf: add Redis caching for session lookups
ci: add coverage threshold to PR checks
```
