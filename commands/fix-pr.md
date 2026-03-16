---
description: Auto-fix PR review comments (mechanical fixes + architectural triage)
argument-hint: "[PR number]"
allowed-tools: Bash(git:*, gh:*), Read, Glob, Grep, Edit, Write
---

# Fix PR Review Comments

Automatically fix mechanical PR review comments and triage architectural ones for human decision.

## Steps

1. **Identify the PR:**
   - If a PR number is given as `$ARGUMENTS`, use `gh pr view $ARGUMENTS`
   - If no argument, use `gh pr view` for the current branch's PR
   - Extract PR number, title, and base branch

2. **Fetch review comments:**
   ```bash
   # Get all review comments
   gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate
   # Also get review-level comments (top-level reviews)
   gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate
   ```

3. **Read project context:**
   - Read `CLAUDE.md` for development workflow
   - Read `AGENTS.md` for architecture and patterns
   - Read `GEMINI.md` for code review standards

4. **Classify each comment into two categories:**

   ### Mechanical (Auto-fixable)
   Comments about:
   - Missing or incorrect type hints
   - Unused imports or variables
   - Missing error handling (try/except, null checks)
   - Style violations (naming, formatting, line length)
   - Missing docstrings or documentation
   - Missing tests for new code
   - Simple refactoring (extract function, rename variable)
   - Missing input validation

   ### Architectural (Needs Human Decision)
   Comments containing signals like:
   - "consider", "alternative", "should we", "trade-off", "design" + question mark
   - Suggestions to change patterns, add new dependencies, or restructure
   - API design changes (new endpoints, changed contracts)
   - Performance architecture (caching strategy, async patterns)
   - Security model changes

5. **Present classification to user:**

   ```
   ## PR #<number> Review Comment Analysis

   ### Mechanical Fixes (will auto-fix)
   | # | File | Comment | Planned Fix |
   |---|------|---------|-------------|
   | 1 | path/file.py:42 | "Missing type hint on return" | Add return type annotation |

   ### Architectural (needs your decision)
   | # | File | Comment | Why It's Architectural |
   |---|------|---------|----------------------|
   | 1 | path/file.py:15 | "Consider using Strategy pattern" | Design pattern choice |

   Proceed with mechanical fixes? (The architectural items will be listed in the commit message for follow-up)
   ```

6. **Implement mechanical fixes:**
   - Fix each mechanical comment one at a time
   - Read the relevant file before making changes
   - Make minimal, targeted changes (don't refactor surrounding code)
   - If a "mechanical" fix turns out to be complex, skip it and note why

7. **Run the test suite:**
   - Auto-detect project type and run appropriate tests
   - Python: `uv run pytest tests/ -v`
   - Node.js: `npm test`
   - Go: `go test ./...`
   - If tests fail, fix the issue before proceeding

8. **Commit and push:**
   ```bash
   git add -A
   git commit -m "fix: address PR review findings (#<PR-number>)

   Mechanical fixes applied:
   - <list each fix>

   Architectural items deferred:
   - <list each deferred item>

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

   git push
   ```

9. **Report summary:**
   ```
   ## Fix PR Summary

   | Category | Count |
   |----------|-------|
   | Mechanical fixes applied | N |
   | Mechanical fixes skipped | N (with reasons) |
   | Architectural deferred | N |

   Pushed to branch: <branch-name>
   ```
