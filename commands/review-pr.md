---
description: Review a pull request for code quality, architecture, and security
argument-hint: "[PR number or branch name]"
allowed-tools: Bash(git:*, gh:*), Read, Glob, Grep
---

# Review Pull Request

Review a pull request thoroughly, checking for code quality, architecture compliance, and security issues.

## Steps

1. **Identify the PR:**
   - If a PR number is given as `$ARGUMENTS`, use `gh pr view $ARGUMENTS`
   - If a branch name is given, use `gh pr list --head $ARGUMENTS`
   - If no argument, use `gh pr view` for the current branch's PR

2. **Fetch the diff:**
   ```bash
   gh pr diff $PR_NUMBER
   ```

3. **Read project context:**
   - Read `GEMINI.md` or `CLAUDE.md` for project standards
   - Read `AGENTS.md` for architecture rules

4. **Analyze the changes across these dimensions:**

   ### Critical (Block Merge)
   - Security vulnerabilities (XSS, injection, auth bypass, hardcoded secrets)
   - Data loss risks
   - Breaking changes without migration

   ### High Priority (Strong Warning)
   - Architecture violations (wrong layer, missing DI, business logic in routes)
   - Untestable code (hard dependencies)
   - Performance issues (N+1, memory leaks)
   - Missing error handling

   ### Medium Priority (Suggestions)
   - Missing tests for new code
   - TypeScript `any` types
   - File/function too long (>200 / >50 lines)

   ### Low Priority (Informational)
   - Minor readability improvements
   - Documentation suggestions

5. **Output your review** in this format:

   ```
   ## PR Review: #<number> — <title>

   ### Critical Issues
   [List or "None"]

   ### High Priority
   [List or "None"]

   ### Medium Priority
   [List or "None"]

   ### Low Priority
   [List or "None"]

   ### Overall Assessment
   [Summary and merge recommendation]
   ```

6. **If everything looks good**, say so clearly. Don't nitpick.
