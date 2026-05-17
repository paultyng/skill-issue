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
  - **Full codebase:** No filtering; explore everything (default).
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

Launch a single investigation subagent (`subagent_type="generalPurpose"`, `model: sonnet` per `subagent-model-routing`) with the system overview, flow mapping, and in-scope file list.

Prompt it to:
- Read all in-scope source files.
- Analyze against all reliability categories: graceful shutdown contract, gRPC production patterns, stability patterns, and stability anti-patterns (see [reference.md](reference.md)).
- **Goroutine leak test coverage**: search test files for `goleak.VerifyNone` or `goleak.VerifyTestMain` usage. Search source files for goroutine-spawning patterns (`go func`, `go ` keyword launching goroutines). Flag packages that spawn goroutines but have no goleak checks in their tests (see Steady State in [reference.md](reference.md)).
- For each finding, search nearby code and project documentation (README, doc comments, TODO/FIXME/HACK/XXX comments, issue references) for existing tracking.
- Return findings using the **reliability findings** template.
- Every finding must include specific file paths, line numbers or function names, priority (P0–Pn), impact, effort estimate, and tracking status.

### 4. Present results

Resolve the review output directory:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR="reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR="reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header) below) and prepend the rendered block to `${REVIEW_DIR}/RELIABILITY-REVIEW.md`.

Write the output to `${REVIEW_DIR}/RELIABILITY-REVIEW.md`, structured as:
1. Run metadata header
2. System overview and flow mapping
3. Reliability findings table
4. Recommended fix order

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
- When the user asks for a follow-up review, find the most recent review directory (`ls -d reviews/*/ 2>/dev/null | sort | tail -1`) containing `RELIABILITY-REVIEW.md`, re-evaluate all prior findings, and update with the re-evaluation table appended.
- For detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (Reliability section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
