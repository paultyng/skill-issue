---
name: review-performance
description: Use when the user explicitly asks for a performance review, benchmark review, profiling review, perf audit, pprof analysis, allocation review, latency regression check, hot-path review, throughput review, "is this fast enough", or "review perf". This skill is opt-in only — never run automatically as part of review-all unless the user explicitly requests it.
---

# Performance Review

Structured review of hot-path performance, allocation patterns, and benchmark coverage. **Opt-in only** — performance is rarely the bottleneck for new code, and a perf review on every PR is noise. Run when the user explicitly asks, or when a feature is performance-sensitive by nature (hot path, fanout, large-data).

**Out of scope** (defer to siblings):
- Concurrency safety (race, deadlock, leak) → `review-reliability`
- Cardinality / metric cost → `review-observability`
- Database query plans / index design → `review-database`

`review-performance` looks at code-level allocation and CPU hotspots, benchmark sufficiency, and obvious algorithmic complexity issues.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific packages/directories, changed files only (PR or branch diff), or a specific hot path.
- **Resolve scope.** Same conventions as siblings:
  - **Changed files (PR or branch):** `git diff --name-only --diff-filter=d <base>...HEAD`; filter to source files.
  - **Explicit paths/packages:** include all relevant source files.
  - **Full codebase:** walk source files.
- **If invoked from review-all** (only when the user opted in): receive `file_list`, `package_paths`, `has_changes`, `base_ref`, `REVIEW_DIR`, and `pr_url`.

This skill is **primarily Go-focused** because the existing review-* corpus targets Go; it has cross-language sections in [reference.md](reference.md) but the deepest checklist is for Go.

### 2. System overview

Produce a brief summary covering:
- Languages and runtimes in scope
- Identifiable hot paths (RPC handlers, queue consumers, batch jobs)
- Existing benchmark coverage (Go: `Benchmark*` functions; presence of `testing.B`)
- Observed SLOs / latency targets if documented in `REVIEW.md`, `README.md`, or runbooks

### 3. Launch investigation subagent

Launch a single investigation subagent (`subagent_type="generalPurpose"`, `model: sonnet` per `subagent-model-routing`) with the system overview and in-scope file list.

Prompt it to:
- Read all in-scope source files.
- Apply the checklists in [reference.md](reference.md):
  - Allocation hotspots (Go-specific patterns)
  - Algorithmic complexity (N+1, nested loops over unbounded inputs, O(n²) on hot paths)
  - Concurrency efficiency (goroutine-per-request anti-patterns, oversharing of locks, mutex contention)
  - Benchmark sufficiency
  - I/O batching and connection reuse
- Identify which findings are real concerns vs. premature optimization. Bias toward "show me the profile" over "I think this allocates". Findings without evidence are P2/nit.
- For each finding, search nearby code for existing benchmarks, comments, or TODOs.
- Return findings using the **performance findings** template.

### 4. Run static analyzers and benchmarks

```sh
# Go static analysis with perf-relevant linters
command -v staticcheck >/dev/null && staticcheck -checks "U1000,SA1019,SA6005" <package_paths>
command -v gocyclo     >/dev/null && gocyclo -over 15 <source_dirs>

# Go: identify benchmark files in scope (used to detect coverage gaps)
grep -rl 'func Benchmark' --include='*_test.go' <package_paths>

# Go: existing benchmark output (do NOT run benchmarks; this is a static review)
# If the user explicitly asks to run benchmarks, ask for an isolated machine first; do not run on a dev workstation by default.

# Go: build with -gcflags="-m=1" can reveal escape analysis when the user wants it; do not run by default.
```

Static analyzers feed the subagent. **Do not run benchmarks** as part of the review unless the user explicitly asks — benchmarks need isolated, repeatable hardware to produce useful numbers.

### 5. Present results

Resolve the review output directory (skip if `REVIEW_DIR` was provided by the review-all orchestrator):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header)) and prepend to `${REVIEW_DIR}/PERFORMANCE-REVIEW.md`.

Output structure:
1. Run metadata header
2. System overview (from step 2)
3. Findings table (grouped by category: allocation / complexity / concurrency / benchmarks / I/O)
4. Recommended fix order, **with explicit "needs profiling evidence" markers** on findings that should not be acted on without a profile

Present the report to the user.

---

## Run metadata header

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
GIT_SUBJECT=$(git log -1 --pretty=%s)
# When scope is diff-based: BASE_REF=<base>; BASE_COMMIT=$(git rev-parse --short "$BASE_REF")
```

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Base:** {BASE_REF} @ {BASE_COMMIT}   <!-- omit when scope is not diff-based -->
> **Scope:** {scope description}
```

---

## Finding link wrapping (PR mode)

When `pr_url` is provided (or `gh pr view --json url -q .url 2>/dev/null` returns one for standalone runs), wrap every `path:line` reference inside the finding tables as a Markdown link:

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>
```

The display text stays `path:line`. Pass `L` for findings about removed code. Findings follow `terse-comments`: concrete fix, optional `bug:`/`risk:`/`nit:`/`unsure:` prefix.

---

## Output Templates

### Performance findings

```markdown
| Priority | Category | Finding | Impact | Effort | Evidence | Tracked |
|----------|----------|---------|--------|--------|----------|---------|
| P0 | allocation | Description with code references | Allocations on every request | small | profile needed | — |
| P1 | complexity | O(n²) loop in hot path at file:line | Linear-in-N regression for N > 1k | moderate | bench needed | TODO in file:line |
```

**Category column values:** `allocation`, `complexity`, `concurrency`, `benchmarks`, `io`.

**Evidence column values:** `profile shown`, `bench shown`, `profile needed`, `bench needed`, `static-only`. Use this to flag findings that need empirical confirmation before action.

### Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Benchmark shows X% improvement |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- **Bias toward measurement.** If a finding can't be backed by a profile or benchmark, mark it `static-only` and downgrade priority unless the issue is glaring (e.g. O(n²) over user-controlled input).
- **Don't run benchmarks on shared hardware** unless the user explicitly requests it. Benchmark noise is high; bad numbers are worse than no numbers.
- Premature optimization is a real concern; explicitly say "needs profile" when a finding is intuition-based.
- Include effort estimates.
- When the user asks for a follow-up review, find the most recent review directory and append the re-evaluation table.
- For detailed framework categories, see [reference.md](reference.md).
- **Opt-in opt-out**: this skill should never run as part of `review-all` unless the user explicitly requests it. The orchestrator must check `include_performance` before fanning out to this skill.
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (Performance section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
