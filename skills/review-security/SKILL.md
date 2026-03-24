---
name: review-security
description: Perform a security review using STRIDE threat modeling, OWASP Top 10 analysis, and automated scanning (gosec, govulncheck). Use when the user asks for a security review, threat model, OWASP analysis, or security audit.
---

# Security Review

Structured security review producing actionable, prioritized findings with code-level references.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific packages/directories, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file/package list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD` to get changed files (default `<base>` is `main`). If the user references a PR number, use `gh pr diff <number> --name-only` instead. Filter to relevant file types (`.go`, config files). Derive affected Go packages from the file paths (unique parent directories containing `.go` files).
  - **Explicit paths/packages:** The user may specify directories (e.g. `internal/auth/`), Go package patterns (e.g. `./internal/auth/...`), or individual files. When given a directory or package pattern, include all files under it. Derive Go package paths for static analysis tool invocations.
  - **Full codebase:** No filtering — explore everything (default).
- **Pass the resolved scope** (file list and derived package paths) to all exploration and investigation subagents so they only read and analyze scoped files. Static analysis tools receive package paths; manual review subagents receive the file list.
- Explore the scoped code using parallel subagents (`subagent_type="explore"`). Read all relevant source files, configs, and dependency manifests.

### 2. System overview

Produce a brief architecture summary covering:
- Services, ports, and transport (gRPC, HTTP, etc.)
- Authentication and authorization mechanisms
- Data stores and external dependencies
- Deployment model (if discernible)

### 3. Launch investigation subagents in parallel

Determine which subagents are applicable based on the scoped files:
- **STRIDE Threat Model**: applicable if code files (`.go`, `.rs`, `.ts`, `.tsx`, `.js`, `.jsx`, `.swift`, `.kt`, `.kts`, `.py`, `.rb`) or infrastructure files (Dockerfiles, k8s manifests, Terraform, CI configs) exist in scope
- **OWASP Top 10 Analysis**: applicable if code files or infrastructure files exist in scope
- **Security Static Analysis**: applicable if `.go` files exist in scope

If only non-code files (e.g. `.md`, images) are in scope, skip all subagents and report that no security-relevant code was found.

Launch applicable investigation subagents concurrently using the Task tool. Each receives the system overview and list of in-scope files as context.

Every investigation subagent must check each finding against existing documentation — TODO comments, README notes, FIXME/HACK/XXX comments, and issue tracker references. Report tracked findings but mark them accordingly.

**Subagent A — STRIDE Threat Model** (`subagent_type="generalPurpose"`, requires code or infra files)

Prompt the subagent to:
- Read all in-scope source files.
- Analyze against all 6 STRIDE categories (see [reference.md](reference.md)).
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with S/T/R/I/D/E prefixes.
- Every finding must include specific file paths, line numbers or function names, a severity rating (CRITICAL / HIGH / MEDIUM / LOW), and tracking status.

**Subagent B — OWASP Top 10 Analysis** (`subagent_type="generalPurpose"`, requires code or infra files)

Prompt the subagent to:
- Read all in-scope source files.
- Analyze against all 10 OWASP categories A01–A10 (see [reference.md](reference.md)).
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with A01–A10 prefixes.
- Every finding must include specific file paths, line numbers or function names, a severity rating, and tracking status.

**Subagent C — Security Static Analysis** (`subagent_type="generalPurpose"`, requires `.go` files)

Prompt the subagent to run automated security scanning tools via Shell and report findings with `SEC-` prefixed IDs. In each command below, replace `./...` with the resolved package paths when scope is narrowed (e.g. `./internal/auth/...`). Use `./...` only for full-codebase scope.
- **gosec**: `go run github.com/securego/gosec/v2/cmd/gosec@latest -fmt json -quiet ./...` — parse JSON output for security findings. Map each gosec rule to the relevant STRIDE/OWASP category.
- **govulncheck**: `go run golang.org/x/vuln/cmd/govulncheck@latest ./...` — report known CVEs in dependencies, filtered to actually-called functions.
- If a tool fails, skip it but note why in a **Tool Availability** section.
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with `SEC-` prefixed IDs.

### 4. Summarize and deduplicate

After all subagents complete, launch a summarization subagent (`subagent_type="generalPurpose"`) with the full findings from each investigation subagent.

Prompt it to:
1. **Deduplicate** overlapping findings across STRIDE, OWASP, and static analysis.
2. **Cross-reference** each deduplicated finding to its source IDs.
3. **Preserve tracking status** — a finding is tracked if any source subagent marked it as tracked.
4. **Prioritize** — produce a consolidated findings table ordered by severity.
5. **Recommend fix order** — considering dependencies between findings and effort estimates.
6. **Tool Availability summary** — consolidate from all subagents.

### 5. Present results

Create the output directory (`mkdir -p reviews`) and write the summarization output to `reviews/SECURITY-REVIEW.md`, structured as:
1. Tool availability summary
2. System overview (from step 2)
3. Consolidated findings table (with tracking status inline)
4. Recommended fix order

Present the report to the user. Overwrite if `reviews/SECURITY-REVIEW.md` already exists.

---

## Output Templates

### Per-category findings

```markdown
### S — Spoofing Identity

| # | Finding | Severity | Tracked |
|---|---------|----------|---------|
| S1 | **Description.** Specific code reference (file:line). Explanation of risk. | CRITICAL | — |
| S2 | Description with code reference. | MEDIUM | TODO in file:line |
```

### Consolidated security findings (deduplicated)

```markdown
| Severity | ID | Finding | STRIDE | OWASP | Tracked |
|----------|----|---------|--------|-------|---------|
| CRITICAL | 1 | Description with code references | S1, E1 | A01, A07 | — |
| HIGH | 2 | Description with code references | T2 | A04 | TODO in file:line |
```

Severity levels: **CRITICAL**, **HIGH**, **MEDIUM**, **LOW**.

**Tracked column values:** Use `—` for new findings. For already-captured findings, indicate the type and location: `TODO in file:line`, `FIXME in file:line`, `README`, `#123` (issue reference), etc.

### Re-evaluation table (for follow-up reviews)

When the user requests a follow-up review after fixes:

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Brief explanation of the fix |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- Search the organization's codebase (Sourcegraph, GitHub) for existing patterns before recommending new approaches.
- Cross-reference findings between STRIDE and OWASP to avoid duplicate entries in the consolidated table.
- Include effort estimates to help prioritize implementation.
- When the user asks for a follow-up review, read the existing `reviews/SECURITY-REVIEW.md`, re-evaluate all prior findings, and update with the re-evaluation table appended.
- For detailed framework categories, see [reference.md](reference.md).
