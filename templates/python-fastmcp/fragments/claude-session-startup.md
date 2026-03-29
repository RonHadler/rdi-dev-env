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

### Step 2: Check for Pending Tasks
```bash
Read: tasks.json
```

If `tasks.json` exists, it contains prioritized tasks (from `rdi-audit`, Ralph Loop, or manual creation). Work through them in priority order (1 = highest). After completing each task, run its `verification.test_command` to confirm the fix, then update the task status to `completed`.

### Step 3: Read Implementation Plan (If Active)
```bash
# If current-tasks.md references an active plan
Read: docs/current-tasks.md
```

### Step 4: Understand Current Architecture
```bash
Read: docs/adr/   # Architecture decisions
```

<!-- CUSTOMIZE: Add project-specific startup steps -->

### Step 5: Execute Task Using TDD
- **Write tests FIRST** — Create test file before implementation. Tests must fail (red).
- **Write code to pass** — Implement minimum code to make tests green.
- **Refactor** — Clean up while tests stay green.
- Follow the MCP coordinator pattern (coordinator + tools/ + config)
- Use dependency injection for all external dependencies

### Step 6: Update Current Tasks as Work Progresses
```bash
Edit: docs/current-tasks.md
```
