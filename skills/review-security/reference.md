# Security Review — Framework Reference

Detailed checklists for each security analysis framework. The SKILL.md workflow references this file.

## STRIDE Threat Model

### S — Spoofing Identity

- Authentication mechanisms: are all endpoints that require auth properly gated?
- Token/credential validation: issuer, audience, expiration, signature verification
- Identity propagation: is identity passed securely between services?
- Credential storage: secrets in env vars vs. hardcoded, rotation capability

### T — Tampering with Data

- Input validation: are all external inputs validated and sanitized?
- Data integrity: are stored values signed or integrity-checked where needed?
- API mutation endpoints: can unauthenticated or unauthorized callers modify data?
- Transport security: TLS enforcement, certificate validation

### R — Repudiation

- Audit logging: are security-relevant actions logged with actor, action, and target?
- Structured logging: request tracing, correlation IDs
- Log integrity: are logs protected from tampering?
- Non-repudiation controls: signed receipts, immutable audit trails

### I — Information Disclosure

- Error messages: do error responses leak implementation details (stack traces, DB errors, internal paths)?
- Enumeration: can external callers enumerate internal IDs or resources?
- Token/credential exposure: are secrets logged, returned in responses, or exposed in URLs?
- Data classification: is sensitive data encrypted at rest and in transit?

### D — Denial of Service

- Rate limiting: are public or expensive endpoints rate-limited?
- Resource limits: connection pool sizes, request body size limits, timeouts

For operational stability patterns (circuit breakers, bulkheads, graceful shutdown), see **review-reliability**.

### E — Elevation of Privilege

- Authorization checks: are admin/privileged operations gated by authorization?
- Tenant isolation: can one tenant access another's data?
- Ownership verification: do mutation operations verify the caller owns the resource?
- Default-deny: is the authorization model default-deny or default-allow?

---

## OWASP Top 10

### A01 — Broken Access Control

- Path/resource authorization: are all API paths checked?
- Tenant isolation and data segregation
- CORS and origin policies
- Direct object reference protection

### A02 — Security Misconfiguration

- Default credentials, debug endpoints, unnecessary features enabled
- Secret handling: environment variables, config files, rotation
- TLS configuration and certificate management
- HTTP security headers (if applicable)

### A03 — Software Supply Chain Failures

- Dependency pinning: are versions pinned in go.mod, package.json, etc.?
- CI action versions: are GitHub Actions / CI steps pinned to SHA or tag?
- Container image tags: are base images pinned to digest?
- Vulnerability scanning: is dependency scanning configured?

### A04 — Cryptographic Failures

- Algorithm choices: key derivation, hashing, encryption algorithms
- Key management: entropy, rotation, storage
- Token construction: sufficient entropy, secure random generation
- Certificate validation and TLS version requirements

### A05 — Injection

- SQL parameterization: are all queries parameterized (no string concatenation)?
- Policy/expression evaluation: are user-controlled inputs compiled/evaluated safely?
- Template rendering: is user input escaped in templates?
- Command execution: no shell injection vectors

### A06 — Insecure Design

- Replay prevention: JTI tracking, nonce enforcement, idempotency keys
- TTL and expiration: are tokens/sessions time-bounded?
- Single points of failure: is a single URL, key, or config a hard dependency?
- Fail-open vs. fail-closed: what happens when a dependency is unavailable?

### A07 — Authentication Failures

- Unauthenticated endpoints: are any endpoints unintentionally open?
- Failed authentication tracking: lockout, logging, alerting
- Token validation: issuer, audience, expiration, algorithm pinning
- Session management: secure cookie flags, session fixation

### A08 — Software or Data Integrity Failures

- Unsigned data: are trust policies, configs, or artifacts integrity-verified?
- Origin verification: is the source of data/configs validated?
- CI/CD integrity: are build artifacts signed or checksummed?
- Update mechanisms: are updates verified before applying?

### A09 — Security Logging & Alerting Failures

- Audit events: are key security events captured?
- Request logging: are requests logged with sufficient context?
- Alerting: are anomalous patterns (failed auth spikes, privilege escalation) alertable?
- Log retention and accessibility

### A10 — Mishandling of Exceptional Conditions

- Panic/crash paths: can unhandled errors crash the service?
- Silent error swallowing: are errors ignored without logging?
- Shutdown behavior: bounded context, in-flight request draining
- Fallback behavior: what happens when parsing, validation, or external calls fail?

---

## Automated Security Scanning

The following tools provide automated signal to complement manual STRIDE/OWASP review. They are run opportunistically; if unavailable, manual review proceeds without them.

- **[gosec](https://github.com/securego/gosec)**: AST+SSA security scanner with taint analysis. Run via `go run github.com/securego/gosec/v2/cmd/gosec@latest -fmt json -quiet ./...`. Detects hardcoded credentials, weak crypto, SQL injection, command injection, path traversal, SSRF, and XSS.
- **[govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck)**: Dependency vulnerability scanner backed by the Go vulnerability database (vuln.go.dev). Run via `go run golang.org/x/vuln/cmd/govulncheck@latest ./...`. Uses static analysis to report only vulnerabilities in functions the code actually calls.
