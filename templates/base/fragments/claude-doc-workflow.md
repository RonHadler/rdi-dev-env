**ALWAYS follow this order for new features (steps 1-5 before writing any code):**

```
1. USER STORIES FIRST (docs/stories/)
   |
2. REQUIREMENTS SECOND (docs/requirements/)
   |
3. ARCHITECTURE DECISIONS THIRD (docs/adr/)
   |
4. UPDATE CURRENT TASKS (docs/current-tasks.md)
   |
5. TDD IMPLEMENTATION — Write tests first, then code
```

**Red Flags - STOP if you see:**
- "We need [technology X]" without user story justification
- Writing ADR-XXX before US-XXX exists
- Creating ADR before requirements are defined
- Writing implementation code before tests exist
