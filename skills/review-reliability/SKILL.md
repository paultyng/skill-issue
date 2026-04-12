---
name: review-reliability
description: Perform a reliability review covering graceful shutdown, gRPC production patterns, stability patterns (timeouts, circuit breakers, bulkheads), and stability anti-patterns. Use when the user asks for a reliability review, production readiness assessment, stability analysis, or graceful shutdown audit.
---

# Reliability Review

Structured reliability review producing actionable, prioritized findings with code-level references.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific packages/directories, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file/package list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD` to get changed files (default `<base>` is `main`). If the user references a PR number, use `gh pr diff <number> --name-only` instead. Filter to relevant file types (`.go`, config files, Kubernetes manifests). Derive affected Go packages from the file paths (unique parent directories containing `.go` files).
  - **Explicit paths/packages:** The user may specify directories (e.g. `internal/auth/`), Go package patterns (e.g. `./internal/auth/...`), or individual files. When given a directory or package pattern, include all files under it.
  - **Full codebase:** No filtering — explore everything (default).
- **Pass the resolved scope** (file list) to all exploration and investigation subagents so they only read and analyze scoped files.
- Explore the scoped code using parallel subagents (`subagent_type="explore"`). Read all relevant source files, configs, Kubernetes manifests, and deployment definitions.

### 2. System overview

Produce a brief architecture summary covering:
- Services, ports, and transport (gRPC, HTTP, etc.)
- Data stores and external dependencies
- Deployment model (if discernible)

Map the critical hot paths:

```
Client → Transport
  → step 1 (local / I/O annotation)
  → step 2 (DB round-trip #1)
  → step 3 (external call, round-trip #2)
  → response
```

Annotate each step: local vs. I/O, serial vs. parallel, cached vs. uncached.

### 3. Launch investigation subagent

Launch a single investigation subagent (`subagent_type="generalPurpose"`) with the system overview, flow mapping, and in-scope file list.

Prompt it to:
- Read all in-scope source files.
- Analyze against all reliability categories: graceful shutdown contract, gRPC production patterns, stability patterns, and stability anti-patterns (see [reference.md](reference.md)).
- **Goroutine leak test coverage**: search test files for `goleak.VerifyNone` or `goleak.VerifyTestMain` usage. Search source files for goroutine-spawning patterns (`go func`, `go ` keyword launching goroutines). Flag packages that spawn goroutines but have no goleak checks in their tests (see Steady State in [reference.md](reference.md)).
- For each finding, search nearby code and project documentation (README, doc comments, TODO/FIXME/HACK/XXX comments, issue references) for existing tracking.
- Return findings using the **reliability findings** template.
- Every finding must include specific file paths, line numbers or function names, priority (P0–Pn), impact, effort estimate, and tracking status.

### 4. Present results

Create the output directory (`mkdir -p reviews`) and write the output to `reviews/RELIABILITY-REVIEW.md`, structured as:
1. System overview and flow mapping
2. Reliability findings table
3. Recommended fix order

Present the report to the user. Overwrite if `reviews/RELIABILITY-REVIEW.md` already exists.

---

## Output Templates

### Reliability findings

```markdown
| Priority | Finding | Impact | Effort | Tracked |
|----------|---------|--------|--------|---------|
| P0 | Description with code references | Impact on availability/latency | trivial / small / moderate / large | — |
| P1 | Description with code references | Impact description | Effort estimate | FIXME in file:line |
```

**Tracked column values:** Use `—` for new findings. For already-captured findings: `TODO in file:line`, `FIXME in file:line`, `README`, `#123` (issue reference), etc.

### Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Brief explanation of the fix |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- Search the organization's codebase (Sourcegraph, GitHub) for existing patterns before recommending new approaches.
- Include effort estimates to help prioritize implementation.
- When the user asks for a follow-up review, read the existing `reviews/RELIABILITY-REVIEW.md`, re-evaluate all prior findings, and update with the re-evaluation table appended.
- For detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (Reliability section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
