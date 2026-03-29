**CRITICAL: Every feature follows this exact pipeline. No exceptions.**

```
1. CHAT        — Discuss the feature with the user
   |
2. PLAN        — Enter plan mode, explore codebase, propose approach
   |
3. APPROVE     — User reviews and approves the plan
   |
4. USER STORIES — Write US-XXX (docs/stories/)
   |
5. REQUIREMENTS — Write FR-XX / NFR-XX (docs/requirements/)
   |
6. ADR          — Write ADR-XXX if architectural (docs/adr/)
   |
7. IMPLEMENT (TDD) — Tests FIRST, then code to make them pass
   |
8. PR + REVIEW  — Feature branch -> PR -> Gemini review -> merge
```

### TDD Rules (Step 7)

1. **Write failing tests first** — Before writing ANY implementation code, write the test file with tests that capture the expected behavior. Run the tests — they MUST fail (red).
2. **Write minimum code to pass** — Implement only enough production code to make the failing tests pass (green).
3. **Refactor** — Clean up the code while keeping tests green. No new behavior without a new test.
4. **Coverage gate** — New code must have tests. Do not merge code that drops coverage below 80%.

### What counts as "needing TDD"
- New functions, services, or modules with business logic
- New API routes or endpoints
- Bug fixes (write a test that reproduces the bug first)

### What can skip writing tests first
- Documentation-only changes
- Config/environment changes
- One-line fixes where existing tests already cover the behavior

### Red Flags — STOP if you see:
- Writing implementation code before any test file exists
- "I'll add tests later" — NO. Tests come first.
- A PR with new code but zero new tests
- Skipping straight from chat to coding without user stories/requirements
