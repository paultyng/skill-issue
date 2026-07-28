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
  - **Full codebase:** No filtering. Explore everything (default).
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
- **Dependency Evaluation**: applicable if a dependency manifest (`go.mod`, `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, `Gemfile`, `mix.exs`, `composer.json`) changed in scope. Diff the manifest for added/bumped dependencies and invoke `evaluate-dependency` in **review mode** per dependency — this covers license, maintenance, tenure, and capability surface that `govulncheck` (a CVE scan of called functions) does not. Dedupe the vuln portion against `govulncheck` output in step 4.

If only non-code files (e.g. `.md`, images) are in scope, skip all subagents and report that no security-relevant code was found.

Launch applicable investigation subagents concurrently using the Task tool. Each receives the system overview and list of in-scope files as context.

Every investigation subagent must check each finding against existing documentation: TODO comments, README notes, FIXME/HACK/XXX comments, and issue tracker references. Report tracked findings but mark them accordingly.

**Subagent A — STRIDE Threat Model** (`subagent_type="generalPurpose"`, `model: opus` per `subagent-model-routing` — always on; threat modeling requires design-level reasoning, requires code or infra files)

Prompt the subagent to:
- Read all in-scope source files.
- Analyze against all 6 STRIDE categories (see [reference.md](reference.md)).
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with S/T/R/I/D/E prefixes.
- Every finding must include specific file paths, line numbers or function names, a severity rating (CRITICAL / HIGH / MEDIUM / LOW), and tracking status.

**Subagent B — OWASP Top 10 Analysis** (`subagent_type="generalPurpose"`, `model: opus` per `subagent-model-routing` — always on; threat modeling requires design-level reasoning, requires code or infra files)

Prompt the subagent to:
- Read all in-scope source files.
- Analyze against all 10 OWASP categories A01–A10 (see [reference.md](reference.md)).
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with A01–A10 prefixes.
- Every finding must include specific file paths, line numbers or function names, a severity rating, and tracking status.

**Subagent C — Security Static Analysis** (`subagent_type="generalPurpose"`, `model: sonnet` per `subagent-model-routing` — tool wrangling and output parsing, not threat modeling, requires `.go` files)

Prompt the subagent to run automated security scanning tools via Shell and report findings with `SEC-` prefixed IDs. In each command below, replace `./...` with the resolved package paths when scope is narrowed (e.g. `./internal/auth/...`). Use `./...` only for full-codebase scope.
- **gosec**: `go run github.com/securego/gosec/v2/cmd/gosec@latest -fmt json -quiet ./...`. Parse JSON output for security findings. Map each gosec rule to the relevant STRIDE/OWASP category.
- **govulncheck**: `go run golang.org/x/vuln/cmd/govulncheck@latest ./...`. Report known CVEs in dependencies, filtered to actually-called functions via the call graph.
- **bearer** (dataflow SAST): if `bearer` is on PATH, run `bearer scan --quiet --format json --output bearer.json .`. Parses dataflow for injection sinks and sensitive-data tracking. If not installed, skip and note in Tool Availability. Treat as the dataflow-flavored complement to gosec's pattern matching.
- **capslock** (capability snapshot): if `capslock` is on PATH, run `capslock -output=json ./...`. Surface the top high-signal capabilities only — do **not** dump the full report inline. Specifically flag:
  - `CAPABILITY_ARBITRARY_EXECUTION` (any presence)
  - `CAPABILITY_REFLECT` combined with `CAPABILITY_EXEC` (dynamic-code gadget)
  - `CAPABILITY_EXEC` reaching from request-handling code (filter `path[]` to chains ending at `(*os/exec.Cmd).Run`)
  - `CAPABILITY_CGO` / `CAPABILITY_UNSAFE_POINTER` (calibrate the report's confidence — see SSA blind spots)
  - Note any `CAPABILITY_UNANALYZED` count so reviewers know how much of the program escaped analysis.
- If a tool fails, skip it but note why in a **Tool Availability** section.
- **SSA / callgraph blind spots**: `govulncheck`, `bearer`, and `capslock` rely on SSA + call-graph analysis. They miss code reached via reflection (`reflect.Value.Call`), the `cgo` boundary, `unsafe.Pointer` arithmetic, and build-tag-gated paths for inactive tags. Surface this caveat alongside any SSA-derived finding so reviewers don't over-trust it.
- **Deep tier** (gated on `include_deep_security` from `review-all`, or explicit user opt-in like "deep security review" when running this skill directly). Adds minutes per run, so default-off. Skip cleanly if the flag is not set; otherwise run alongside the standard tools:
  - **CodeQL**: if `codeql` is on PATH, build a database (`codeql database create db --language=go --source-root=. --overwrite`) and run the Go security-and-quality query pack (`codeql database analyze db codeql/go-queries:codeql-suites/go-security-and-quality.qls --format=sarif-latest --output=codeql.sarif`). Parse the SARIF `runs[].results[]` for findings; map `ruleId` to STRIDE/OWASP. DB build is the cost — measure in minutes on large repos. If `codeql` is not installed, skip and note in Tool Availability.
  - **capslock VTA**: `capslock -output=json -algo=vta ./...`. The VTA call-graph algorithm is more precise than the default CHA but heavier and **experimental** (API may change). Use the VTA report's `path[]` to cite concrete reachability of high-risk sinks (e.g. user request → `(*os/exec.Cmd).Run`) rather than just capability presence.
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with `SEC-` prefixed IDs.

### 4. Summarize and deduplicate

After all subagents complete, launch a summarization subagent (`subagent_type="generalPurpose"`) with the full findings from each investigation subagent.

Prompt it to:
1. **Deduplicate** overlapping findings across STRIDE, OWASP, and static analysis.
2. **Cross-reference** each deduplicated finding to its source IDs.
3. **Preserve tracking status**. A finding is tracked if any source subagent marked it as tracked.
4. **Prioritize**. Produce a consolidated findings table ordered by severity.
5. **Recommend fix order**, considering dependencies between findings and effort estimates.
6. **Tool Availability summary**. Consolidate from all subagents.

### 5. Present results

Resolve the review output directory (skip if `REVIEW_DIR` was provided by the review-all orchestrator):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header) below) and prepend the rendered block to `${REVIEW_DIR}/SECURITY-REVIEW.md`.

Write the summarization output to `${REVIEW_DIR}/SECURITY-REVIEW.md`, structured as:
1. Run metadata header
2. Tool availability summary
3. System overview (from step 2)
4. Consolidated findings table (with tracking status inline)
5. Recommended fix order

Present the report to the user.

---

## Run metadata header

Capture once near `REVIEW_DIR` resolution and prepend the rendered block to the output document:

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
GIT_SUBJECT=$(git log -1 --pretty=%s)
# When scope is diff-based, also: BASE_REF=<base>; BASE_COMMIT=$(git rev-parse --short "$BASE_REF")
```

Header template (placed at the top of the output `.md`, before the H1 title):

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Base:** {BASE_REF} @ {BASE_COMMIT}   <!-- omit when scope is not diff-based -->
> **Scope:** {scope description}
```

---

## Finding link wrapping (PR mode)

When the review is scoped to a GitHub PR (`pr_url` is provided by the caller, or, when run standalone, `gh pr view --json url -q .url 2>/dev/null` returns one), wrap every `path:line` reference inside the finding tables below as a Markdown link:

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>
# pr_url set   → [path:line](https://github.com/.../pull/N/files#diff-<hash>R<line>)
# pr_url empty → path:line   (plain text, unchanged)
```

The display text stays `path:line` so plain and linked tables look identical; only the URL goes in the link target. Pass `L` as the fourth argument for findings about removed code (default is `R`). Omit `<line>` for file-level findings to get a file-anchor link. Apply the same wrapping to `path:line` references inside the Tracked column (e.g. `TODO in foo.go:42`). Findings themselves follow `terse-comments`: concrete fix, optional `bug:`/`risk:`/`nit:`/`unsure:` prefix, no praise or restating the diff.

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
- When the user asks for a follow-up review, find the most recent review directory (`ls -d reviews/*/ 2>/dev/null | sort | tail -1`) containing `SECURITY-REVIEW.md`, re-evaluate all prior findings, and update with the re-evaluation table appended.
- For detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (Security section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
