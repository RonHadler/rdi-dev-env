---
name: pr-workflow
description: >
  Use when creating pull requests, branches, or commits.
  Triggered by "create PR", "branch", "commit", "merge",
  "pull request", "feature branch", "push".
---

# PR Workflow

All code changes go through feature branches and pull requests. PRs trigger automated AI code review.

## Branch Naming

Format: `feat/description-MMDD`

```
feat/auth-refactor-0221      # Feature, Feb 21
fix/login-bug-0221           # Bug fix, Feb 21
test/coverage-improvement    # Test-only (no date needed)
docs/update-readme           # Documentation (no date needed)
```

Always append the date to avoid conflicts with stale remote branches from previous sessions.

## Workflow

```
1. Create feature branch from master
2. Implement changes (TDD: tests first)
3. Commit with conventional messages
4. Push to remote
5. Create PR with structured description
6. Automated Gemini review runs
7. Address review feedback
8. Merge to master
```

## Conventional Commits

Format: `type: description`

| Type | When |
|------|------|
| `feat:` | New feature or capability |
| `fix:` | Bug fix |
| `test:` | Adding or updating tests |
| `docs:` | Documentation only |
| `refactor:` | Code restructuring (no behavior change) |
| `chore:` | Build, config, dependency updates |
| `perf:` | Performance improvement |

Examples:
```
feat: add user authentication with JWT
fix: resolve race condition in session loading
test: add coverage for ProcessQueryUseCase edge cases
refactor: extract auth middleware from API routes
```

Always include co-author attribution:
```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## PR Description Template

```markdown
## Summary
- Brief description of what changed and why
- Link to related issue/user story if applicable

## Changes
- Bullet points of specific changes made

## Test Plan
- [ ] New tests written (TDD)
- [ ] All existing tests pass
- [ ] Manual testing steps

## Checklist
- [ ] Follows Clean Architecture
- [ ] No hardcoded secrets
- [ ] Tests cover new code
- [ ] Documentation updated (if needed)
```

## What Goes Through PR

- New features (multi-file changes)
- Bug fixes
- Architectural changes
- Security fixes
- Any code change

## What Can Skip PR

- Documentation-only changes
- Config tweaks with no code impact
- Typo fixes in comments

For commit conventions details, see [references/commit-conventions.md](references/commit-conventions.md).
