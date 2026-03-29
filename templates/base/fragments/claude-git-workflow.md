**IMPORTANT: All code changes should go through a Feature Branch + PR.**
PRs trigger an automated Gemini AI code review (via GitHub Actions) that catches
architecture violations, security issues, and code quality problems.

**Branch Naming:** `feat/description-MMDD` (e.g. `feat/health-endpoint-0301`).
Always append the date to avoid conflicts with stale remote branches.

**Use Feature Branch + PR for:**
- New features (multi-file changes)
- Architectural changes
- Bug fixes and security fixes

**Direct Commit to default branch (exception, not the rule):**
- Documentation-only changes
- Config tweaks with no code impact
