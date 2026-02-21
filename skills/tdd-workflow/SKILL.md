---
name: tdd-workflow
description: >
  Use when implementing features, fixing bugs, or writing tests.
  Triggered by "implement", "write tests", "TDD", "red green refactor",
  "add feature", "fix bug", "coverage".
---

# TDD Workflow

Every feature follows the Red-Green-Refactor cycle. No exceptions.

## The Cycle

```
1. RED    — Write a failing test that defines expected behavior
2. GREEN  — Write the minimum code to make the test pass
3. REFACTOR — Clean up while keeping tests green
```

## Before Writing Any Code

1. **Identify the behavior** — What should the code do? What are the inputs/outputs?
2. **Create the test file** — Co-locate with implementation: `MyThing.test.ts` next to `MyThing.ts`
3. **Write test cases** covering:
   - Happy path (normal operation)
   - Edge cases (empty input, boundaries)
   - Error cases (invalid input, failures)
4. **Run the tests** — They MUST fail (red phase). If they pass, the test is wrong.

## After Tests Fail (Red)

1. **Write only enough code** to make failing tests pass
2. **Don't anticipate** — No extra features, no "while I'm here" additions
3. **Run tests again** — They MUST pass (green phase)

## After Tests Pass (Green)

1. **Refactor** — Improve code quality, extract patterns, reduce duplication
2. **Run tests after each refactor step** — They must stay green
3. **No new behavior** without a new failing test first

## Coverage Gate

- New code must not drop coverage below **80%**
- Check with: `npx jest --coverage --coverageReporters=text-summary`

## What Needs TDD

- New use cases, entities, services, repositories
- New API routes with business logic
- New hooks with state logic
- Bug fixes (reproduce the bug with a test first)

## What Can Skip Tests

- Documentation-only changes
- Config/environment changes
- Pure UI styling (Tailwind classes, layout tweaks)
- One-line fixes where existing tests already cover the behavior

## Red Flags — STOP

- Writing implementation code before any test file exists
- "I'll add tests later" — NO. Tests come first.
- A PR with new code but zero new tests
- Skipping from discussion to coding without a test plan

For common test patterns and mocking examples, see [references/test-patterns.md](references/test-patterns.md).
