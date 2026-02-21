# OWASP Top 10 Checklist for Web Applications

## A01: Broken Access Control

- [ ] Authentication required on all protected endpoints
- [ ] Authorization checks enforce role-based access
- [ ] Users cannot access other users' data by changing IDs
- [ ] CORS is configured to allow only trusted origins
- [ ] Directory listing is disabled
- [ ] JWT tokens are validated (signature, expiration, issuer)
- [ ] API rate limiting is in place

**What to grep for:**
```bash
# Missing auth checks in API routes
grep -rn "export async function" app/api/ | grep -v "_lib" | grep -v "health"
# Then verify each has auth check
```

## A02: Cryptographic Failures

- [ ] Secrets stored in environment variables or secret manager (never in code)
- [ ] HTTPS enforced (no HTTP endpoints)
- [ ] Sensitive data encrypted at rest
- [ ] No sensitive data in URLs (query params logged by default)
- [ ] Password hashing uses bcrypt/argon2 (not MD5/SHA1)

## A03: Injection

- [ ] SQL: Use parameterized queries or ORM (Firestore handles this)
- [ ] NoSQL: Validate types before querying
- [ ] OS command: Never use user input in shell commands
- [ ] LDAP/XPath: Escape special characters
- [ ] Template: Don't interpolate user input into templates

**What to grep for:**
```bash
# Dynamic query construction
grep -rn "eval\|exec\|subprocess.*shell.*True\|child_process" src/ app/
```

## A04: Insecure Design

- [ ] Business logic validates at the domain level (not just UI)
- [ ] Rate limiting on authentication endpoints
- [ ] Account lockout after failed attempts
- [ ] Sensitive operations require re-authentication

## A05: Security Misconfiguration

- [ ] Debug mode disabled in production
- [ ] Default credentials changed
- [ ] Error pages don't reveal stack traces
- [ ] Unnecessary features/endpoints disabled
- [ ] Security headers set (CSP, X-Frame-Options, etc.)

## A06: Vulnerable Components

- [ ] Dependencies are up to date
- [ ] No known vulnerabilities: `npm audit` / `pip audit` / `govulncheck`
- [ ] Unused dependencies removed

## A07: Identification and Authentication Failures

- [ ] Strong password requirements enforced
- [ ] Multi-factor authentication available for admin
- [ ] Session tokens invalidated on logout
- [ ] Session timeout is reasonable (not infinite)

## A08: Software and Data Integrity Failures

- [ ] CI/CD pipeline is secured (no unauthorized modifications)
- [ ] Dependencies pinned to specific versions
- [ ] Code review required before merge
- [ ] Subresource Integrity (SRI) for CDN resources

## A09: Security Logging and Monitoring Failures

- [ ] Authentication events logged (login, logout, failed attempts)
- [ ] Authorization failures logged
- [ ] Input validation failures logged
- [ ] Logs don't contain sensitive data (passwords, tokens)
- [ ] Alerting configured for suspicious activity

## A10: Server-Side Request Forgery (SSRF)

- [ ] User-supplied URLs are validated against allowlist
- [ ] Internal services not accessible from user input
- [ ] DNS rebinding protections in place
- [ ] Metadata endpoints blocked (169.254.169.254)
