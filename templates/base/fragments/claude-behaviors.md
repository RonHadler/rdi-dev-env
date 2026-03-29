### Tool Usage
- Prefer specialized tools over bash commands (Read over cat, Edit over sed)
- Use Agent tool for open-ended exploration
- Parallelize independent tool calls

### Code Changes
- NEVER propose changes to code you haven't read
- Avoid over-engineering - only make requested changes
- Don't add features, refactoring, or "improvements" beyond what was asked

### Commits
- Only commit when explicitly requested
- Use conventional commit messages: `feat:`, `fix:`, `test:`, `docs:`, `refactor:`
- Always include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
