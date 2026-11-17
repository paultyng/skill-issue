# Security Review — Framework Reference

Prompt bodies for each security analysis framework. The SKILL.md workflow references this file.

## Contents
- [STRIDE Threat Model](#stride-threat-model)
- [OWASP Top 10](#owasp-top-10)
- [Automated Security Scanning](#automated-security-scanning)

## STRIDE Threat Model

The prompt body for Subagent A in [SKILL.md § 3](SKILL.md). This is a threat model, not a checklist: the reviewer decides where to look, and STRIDE supplies the vocabulary for what it found.

### Goal

Find realistic ways an attacker crosses a trust boundary that the in-scope code defines or touches. Start from the boundaries, not the categories. Where does data or control move between principals, services, tenants, processes, or privilege levels? For each boundary, name what it protects and who is on the hostile side, then trace how the code enforces it, following callees and third-party source wherever enforcement depends on them.

A boundary the code relies on but does not define (middleware it sits behind, a token another service minted) is in scope. State the assumption and whether the code checks it.

### What a good finding is

- **Attacker**: who they are and what they already hold (anonymous caller, authenticated user of another tenant, operator with log access).
- **Entry point**: the request, message, file, or config value they control, at `path:line`.
- **Asset**: what they reach: data, identity, capability, or availability.
- **Impact**: what they can do that the boundary was meant to prevent.
- **Path**: the code path from entry to impact, cited `path:line` at each hop that matters, including the check that is missing or bypassed.

A finding with no attacker who can reach the entry point is a code-quality note, not a threat. A finding with no traced path is a hypothesis: prefix it `unsure:` and say what would settle it.

### Evidence

- A traced path through the actual code is the minimum. Probe where possible: craft the input, run the handler, grep for the check that should exist. Command output beats reading (`probe-not-assume`).
- When no probe is possible, mark the finding `unverified` and name the gap.
- Report bugs in code the scope touches or calls even when they predate the diff, prefixed `pre-existing:`.
- Check each finding against TODO/FIXME/HACK/XXX comments, README notes, and issue references. Fill the Tracked column from what you find.

### Classification

Label each finding with the one STRIDE letter naming the property it violates: **S** authentication (the caller is not who the code believes), **T** integrity, **R** accountability (no reliable record of who did what), **I** confidentiality, **D** availability, **E** authorization (the caller acts as a more privileged principal). Classify after finding, not before.

A **D** finding needs an attacker who triggers the exhaustion. Operational stability (circuit breakers, bulkheads, graceful shutdown) belongs to **review-reliability**.

### Known misses

Boundaries past reviews skipped. Check each one is covered before returning.

- Token validation that verifies the signature but not issuer, audience, or expiry; identity trusted from a header another service was supposed to set.
- Authorization on the route but not on the object: a caller past the auth gate reads or mutates a resource another tenant or user owns.
- Default-allow: a new route, role, or resource is open until someone adds a rule.
- Fail-open when an auth backend, policy service, or cache is unavailable.
- Secrets or tokens in logs, error responses, URLs, or crash output; errors that reveal internal structure or let a caller enumerate resources.
- Security-relevant actions with no record of actor, action, and target, or a record the actor can alter.

### Output invariants

- Return the **per-category findings** template (SKILL.md § Output Templates) with `S`/`T`/`R`/`I`/`D`/`E` prefixes numbered per letter (`S1`, `S2`, `T1`). The summarizer parses these.
- Every finding MUST carry `path:line` or a function name, a severity (CRITICAL / HIGH / MEDIUM / LOW), and a Tracked value (`—` or the tracking reference).
- Severity follows impact and reachability by the stated attacker, not code smell.
- A letter with nothing found gets its heading and "No findings". An empty category and a skipped category are different results.
- MUST NOT report a finding whose entry point the stated attacker cannot reach, and MUST NOT pad a category to look thorough.

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
