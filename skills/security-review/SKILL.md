---
name: security-review
description: >
  Use when reviewing code for security, handling user input,
  or working with authentication. Triggered by "security", "auth",
  "input validation", "XSS", "injection", "credentials", "secret",
  "vulnerability", "OWASP".
---

# Security Review

Check all code changes against these security standards.

## Quick Checklist

Before merging any code, verify:

- [ ] No hardcoded secrets (API keys, tokens, passwords)
- [ ] User input is validated and sanitized
- [ ] Authentication is enforced on all protected routes
- [ ] Authorization checks exist (role-based access)
- [ ] No eval() or dynamic code execution with user data
- [ ] No SQL injection vectors (use parameterized queries)
- [ ] No XSS vectors (no `dangerouslySetInnerHTML` with user content)
- [ ] Error messages don't leak internal details
- [ ] Sensitive data isn't logged

## Secret Detection Patterns

Flag these immediately:

```
sk-[a-zA-Z0-9]{20,}          # OpenAI/Anthropic keys
AIza[a-zA-Z0-9_-]{35}        # Google API keys
AKIA[A-Z0-9]{16}             # AWS access keys
ghp_[a-zA-Z0-9]{36}          # GitHub tokens
-----BEGIN.*PRIVATE KEY-----  # Private keys
password\s*=\s*['"][^'"]+     # Hardcoded passwords
```

If a secret is committed to git history, it is **compromised**. Rotate immediately.

## Authentication Patterns

### API Routes
Every API route that handles user data MUST:
1. Verify authentication (check token/session)
2. Check authorization (role-based access)
3. Return 401 for unauthenticated, 403 for unauthorized

### Client-Side
- Store tokens securely (httpOnly cookies preferred)
- Include auth headers on all API requests
- Handle token expiration gracefully

## Input Validation

### Server-Side (Always)
- Validate all request body fields (type, length, format)
- Sanitize strings that will be rendered as HTML
- Reject unexpected fields
- Use allowlists, not blocklists

### Client-Side (UX only)
- Client validation is for UX, NOT security
- Never trust client-side validation alone

For the full OWASP checklist, see [references/owasp-checklist.md](references/owasp-checklist.md).
