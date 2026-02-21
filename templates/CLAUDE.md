# <!-- CUSTOMIZE: Project Name --> - Claude Code Context

> **Shared Context:** See [AGENTS.md](AGENTS.md) for project overview, architecture, security, and file structure.

This file contains Claude Code-specific workflows and behaviors.

---

## Development Process — TDD is MANDATORY

**CRITICAL: Every feature follows this exact pipeline. No exceptions.**

```
1. CHAT        — Discuss the feature with the user
   |
2. PLAN        — Enter plan mode, explore codebase, propose approach
   |
3. APPROVE     — User reviews and approves the plan
   |
4. USER STORIES — Write US-XXX (docs/user-stories.md)
   |
5. REQUIREMENTS — Write FR-XX / NFR-XX (docs/requirements.md)
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
- New use cases, entities, services, repositories
- New API routes with business logic
- New React hooks with state logic
- Bug fixes (write a test that reproduces the bug first)

### What can skip writing tests first
- Documentation-only changes
- Config/environment changes
- Pure UI styling (Tailwind classes, layout tweaks)
- One-line fixes where existing tests already cover the behavior

### Red Flags — STOP if you see:
- Writing implementation code before any test file exists
- "I'll add tests later" — NO. Tests come first.
- A PR with new code but zero new tests
- Skipping straight from chat to coding without user stories/requirements

---

## Session Startup Checklist

**CRITICAL:** At the start of EVERY session, follow these steps:

### Step 1: Check Current Tasks (ALWAYS DO FIRST)
```bash
Read: docs/current-tasks.md
```

**Look for:**
- **Current Sprint Goal** - What phase are we in?
- **In Progress** - What task is currently being worked on?
- **Up Next** - What's the next task to start?
- **Blocked** - Are there any blockers?

### Step 2: Read Implementation Plan (If Active)
```bash
# If current-tasks.md references an active plan
Read: docs/REFACTORING_PLAN.md  # or relevant plan doc
```

### Step 3: Understand Current Architecture
```bash
Read: docs/architecture-decisions.md  # ADR index
```

<!-- CUSTOMIZE: Add project-specific startup steps -->

### Step 4: Execute Task Using TDD
- **Write tests FIRST** — Create test file before implementation. Tests must fail (red).
- **Write code to pass** — Implement minimum code to make tests green.
- **Refactor** — Clean up while tests stay green.
- Follow Clean Architecture (Domain -> Application -> Infrastructure -> Presentation)
- Use dependency injection for all external dependencies

### Step 5: Update Current Tasks as Work Progresses
```bash
Edit: docs/current-tasks.md
```

---

## Documentation Workflow

**ALWAYS follow this order for new features (steps 1-5 before writing any code):**

```
1. USER STORIES FIRST (docs/user-stories.md)
   |
2. REQUIREMENTS SECOND (docs/requirements.md)
   |
3. ARCHITECTURE DECISIONS THIRD (docs/adr/adr-XXX-name.md)
   |
4. IMPLEMENTATION PLAN LAST (docs/product-roadmap.md)
   |
5. UPDATE TRACEABILITY MATRIX (docs/user-stories.md)
   |
6. TDD IMPLEMENTATION — Write tests first, then code
```

**Red Flags - STOP if you see:**
- "We need [technology X]" without user story justification
- Writing ADR-XXX before US-XXX exists
- Creating ADR before requirements are defined
- Writing implementation code before tests exist

---

## Git Workflow

**IMPORTANT: All code changes should go through a Feature Branch + PR.**
PRs trigger an automated Gemini AI code review (via GitHub Actions) that catches
architecture violations, security issues, and code quality problems.

**Branch Naming:** `feat/description-MMDD` (e.g. `feat/auth-refactor-0221`).
Always append the date to avoid conflicts with stale remote branches.

**Use Feature Branch + PR for:**
- New features (multi-file changes)
- Architectural changes
- Bug fixes and security fixes
- Any multi-file code change

**Direct Commit to Master (exception, not the rule):**
- Documentation-only changes
- Config tweaks with no code impact

---

## Claude Code-Specific Behaviors

### Tool Usage
- Prefer specialized tools over bash commands (Read over cat, Edit over sed)
- Use Task tool for open-ended exploration
- Parallelize independent tool calls

### Code Changes
- NEVER propose changes to code you haven't read
- Avoid over-engineering - only make requested changes
- Don't add features, refactoring, or "improvements" beyond what was asked

### Todo List
- Use TodoWrite for multi-step tasks
- Mark todos complete immediately after finishing
- Only one task should be in_progress at a time

### Commits
- Only commit when explicitly requested
- Use conventional commit messages
- Always include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

---

## Contact & Resources

<!-- CUSTOMIZE: Add project-specific resources -->
- **MCP Documentation**: https://modelcontextprotocol.io
- **Claude API**: https://docs.anthropic.com

---

<!-- CUSTOMIZE: Update date and version -->
*Last Updated: YYYY-MM-DD*
*Version: 1.0*
