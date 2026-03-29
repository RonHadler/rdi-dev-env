When reviewing code changes, prioritize:

### 1. Critical Issues (Block Merge)
- Security vulnerabilities (injection, auth bypass, hardcoded secrets)
- Data loss risks
- Breaking changes without migration
- Missing type annotations on public functions

### 2. High Priority (Strong Warning)
- Architectural pattern violations
- Untestable code (hard dependencies, no DI)
- Missing error handling in public functions
- Performance issues (blocking calls in async functions, memory leaks)

### 3. Medium Priority (Suggestions)
- Code style violations (file/function length)
- Missing tests for new code
- Loose typing (untyped parameters, generic containers)
- Missing docstrings on public APIs
- Readability improvements

### 4. Low Priority (Informational)
- Code formatting (leave to linter)
- Minor optimizations
- Documentation improvements
