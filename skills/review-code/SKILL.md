---
name: review-code
description: Review code architecture (SOLID, design patterns, package design, coupling, testability), Go best practices, and protobuf/API design using manual analysis and static analysis tools (gocyclo, staticcheck, buf). Use when the user asks for a code review, architecture review, Go review, protobuf review, SOLID review, or design pattern review.
---

# Code Review

Structured code review covering architecture, Go best practices, and protobuf/API design. Produces actionable, prioritized findings with code-level references.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific packages/directories, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file/package list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD` to get changed files (default `<base>` is `main`). If the user references a PR number, use `gh pr diff <number> --name-only` instead. Filter to relevant file types (`.go`, `.proto`). Derive affected Go packages from the file paths (unique parent directories containing `.go` files).
  - **Explicit paths/packages:** The user may specify directories (e.g. `internal/auth/`), Go package patterns (e.g. `./internal/auth/...`), or individual files. When given a directory or package pattern, include all files under it. Derive Go package paths for static analysis tool invocations.
  - **Full codebase:** No filtering. Explore everything (default).
- **Pass the resolved scope** (file list and derived package paths) to all exploration and investigation subagents so they only read and analyze scoped files. Static analysis tools receive package paths; manual review subagents receive the file list.
- Explore the scoped code using parallel subagents (`subagent_type="explore"`). Read all relevant source files, paying attention to package structure, type definitions, interfaces, import graphs, `.go` files, `.proto` files, and test files.
- **Classify the scope** for change-aware subagents:
  - `has_changes`: true when scope is "changed files (PR or branch)", **or** when scope is "explicit paths" and those paths have a diff against the base ref (run `git diff --name-only --diff-filter=d <base>...HEAD -- <paths>` to check; default base is `main`). False for full-codebase reviews with no diff baseline. When true, derive the **changed file list** (intersection of scoped files and files with diffs) and carry the **base ref** forward for subagents that need them.
- Determine which subagents are applicable:
  - **Architecture and Design**: applicable if code files (`.go`, `.rs`, `.ts`, `.tsx`, `.js`, `.jsx`, `.swift`, `.kt`, `.kts`, `.py`, `.rb`) exist in scope
  - **Go Best Practices**: applicable if `.go` files exist in scope
  - **Protobuf and API Design**: applicable if `.proto` files exist in scope
  - **Go Static Analysis**: applicable if `.go` files exist in scope
  - **Protobuf Linting**: applicable if `.proto` files exist in scope
  - **Regression History**: applicable if code files exist in scope and `has_changes` is true
  - **Conformance Check**: applicable if code files exist in scope (lightweight mode by default; full mode when `conformance_mode` is `full`)

### 2. Launch investigation subagents in parallel

Launch applicable subagents concurrently using the Task tool (max 4 at a time; if more than 4 are applicable, launch 4 first and the remaining after one completes). Each subagent is `subagent_type="generalPurpose"`, `model: sonnet` by default (per `subagent-model-routing`), except Subagent A which uses `model: opus` (see below).

Every investigation subagent must check each finding against existing documentation: TODO comments, README notes, FIXME/HACK/XXX comments, and issue tracker references. Report tracked findings but mark them accordingly.

**Subagent A. Architecture and Design Principles** (`subagent_type="generalPurpose"`, `model: opus` per `subagent-model-routing` — always on; SOLID/DIP analysis requires architecture-level reasoning, requires code files)

Prompt the subagent to:
- Read all in-scope source files.
- Analyze against all 5 SOLID principles, GoF design pattern usage, package cohesion/coupling, minimal-changes alignment, and testability indicators (see [reference-architecture.md](reference-architecture.md)).
- Check design pattern usage: verify canonical naming, flag pattern anti-patterns (singletons via globals, forced patterns, pattern names without the pattern). Flag code that implements a recognizable pattern but doesn't use the canonical name.
- Apply the minimal-changes lens: flag speculative abstractions, premature generalization, and over-engineering.
- Analyze dependency graphs, import structure, and circular dependencies.
- Check interface placement: interfaces should be defined in the consumer package, not the implementor.
- Apply the testing-philosophy lens: flag concrete dependencies that should use interfaces for DI, mock-heavy test setups indicating tight coupling, and tests making real calls to external services.
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with `ARCH-` prefixed IDs for design/SOLID findings and `DEP-` prefixed IDs for dependency/testability findings.
- Every finding must include specific file paths, line numbers or function names, a severity rating (CRITICAL / HIGH / MEDIUM / LOW), and tracking status.

**Subagent B. Go Best Practices** (`subagent_type="generalPurpose"`, requires `.go` files)

Prompt the subagent to:
- Read all in-scope `.go` source files.
- Analyze against Go code review comments, Go proverbs, and Go best practices (see [reference-go.md](reference-go.md)).
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with `GO-` prefixed IDs.
- Every finding must include specific file paths, line numbers or function names, a severity rating (CRITICAL / HIGH / MEDIUM / LOW), and tracking status.

**Subagent C. Protobuf and API Design** (`subagent_type="generalPurpose"`, requires `.proto` files)

Prompt the subagent to:
- Read all in-scope `.proto` files and any generated code or API-related source.
- Analyze against protobuf best practices and AEP rules (see [reference-protobuf.md](reference-protobuf.md)).
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with `PB-` prefixed IDs.
- Every finding must include specific file paths, line numbers or function names, a severity rating (CRITICAL / HIGH / MEDIUM / LOW), and tracking status.

**Subagent D. Go Static Analysis** (`subagent_type="generalPurpose"`, requires `.go` files)

Prompt the subagent to run all 6 automated Go analysis tools via **parallel Shell calls** (launch all concurrently, then collect results) and report findings with `SA-` prefixed IDs. In each command below, replace `./...` with the resolved package paths when scope is narrowed (e.g. `./internal/auth/...`). Use `./...` only for full-codebase scope.
- **gocyclo**: `go run github.com/fzipp/gocyclo/cmd/gocyclo@latest -over 12 -ignore "_test|vendor" ./...`. Cyclomatic complexity scan. Include each flagged function with its complexity score and refactoring guidance.
- **staticcheck**: `go run honnef.co/go/tools/cmd/staticcheck@latest ./...`. Bugs (SA*), simplifications (S*), dead code, deprecated API usage.
- **errcheck**: `go run github.com/kisielk/errcheck@latest ./...`. Unchecked error return values.
- **nilaway**: `go run go.uber.org/nilaway/cmd/nilaway@latest ./...`. Nil pointer dereference detection via type-flow inference.
- **exhaustive**: `go run github.com/nishanths/exhaustive/cmd/exhaustive@latest ./...`. Non-exhaustive enum switch statements and map literal keys.
- **deadcode**: `go run golang.org/x/tools/cmd/deadcode@latest -filter=$(go list -m) ./...`. Unreachable functions via call graph analysis.
- **revive**: if a `.golangci.yml` enables revive, run `go run github.com/mgechev/revive@latest ./...` with the project's revive config. If no revive config is found, skip and note in Tool Availability.
- If a tool fails, skip it but note why in a **Tool Availability** section.
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with `SA-` prefixed IDs.

**Subagent E. Protobuf Linting** (`subagent_type="generalPurpose"`, requires `.proto` files)

Prompt the subagent to run automated protobuf analysis tools via Shell and report findings with `PBL-` prefixed IDs:
- Check if `buf` is on PATH (`which buf`). If available, run `buf lint` and `buf breaking --against .git#branch=main` via **parallel Shell calls**. When scope is narrowed, pass `--path <dir>` for each directory containing in-scope `.proto` files. Include diagnostics as findings. If `buf` is not available or the repo has no git history for the breaking check, note in Tool Availability and continue.
- Include a **Tool Availability** section listing each tool's status (ran / skipped + reason).
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with `PBL-` prefixed IDs.

**Subagent F. Regression History Analysis** (`subagent_type="generalPurpose"`, requires code files and `has_changes`)

Prompt the subagent to:
- Receive the list of changed files and the base ref.
- For each changed file, run `git log -n 200 --oneline --all -- <file>` to get recent commit history. Filter commits whose messages match regression/bug-fix signals: keywords like `fix`, `bug`, `revert`, `regression`, `hotfix`, `patch`, `CVE`, `workaround`; conventional-commit prefixes like `fix:`, `fix(...):`; revert commits (`Revert "..."`).
- For each matching historical commit, run `git show <commit> -- <file>` to retrieve the diff of that fix.
- Retrieve the current diff for the file (`git diff <base>...HEAD -- <file>`).
- Analyze whether the current changes overlap with or undo the historical fix, specifically whether modified/deleted lines or logic reversals touch the same code regions as a prior fix.
- **Test removal and modification detection**: examine the current diff for deleted, gutted, or weakened test functions, test cases, or test files. Flag removal of test coverage and changes that relax assertions (e.g. removing checks, loosening expected values, commenting out assertions, reducing test case coverage). Pay extra attention to tests that were added as part of a historical bug fix (cross-reference with the historical commit diffs). Legitimate test refactors (e.g. moving tests to a new file, renaming, updating assertions to match intentional behavior changes) should not be flagged; look for the test logic reappearing elsewhere before reporting.
- For each potential regression reintroduction or test coverage reduction, search nearby code for TODO/FIXME/HACK/XXX comments or issue references.
- Return findings using the **per-category findings** template with `REG-` prefixed IDs.
- Every finding must include the historical fix commit hash and message (for regression reintroductions), the file and line region affected, why the current change appears to unwind the fix or reduce test coverage, a severity rating (CRITICAL / HIGH / MEDIUM / LOW), and tracking status.

**Subagent G. Conformance Check** (`subagent_type="generalPurpose"`, requires code files)

Prompt the subagent to:
- Load explicit conformance rules from: REVIEW.md (if provided by review-all or present at repo root), CLAUDE.md (if present at repo root), AGENTS.md (if present at repo root), and all files in `.claude/rules/` (if directory exists). These are the **explicit rules**.
- Determine conformance mode:
  - **Lightweight** (default, or when `conformance_mode` is `lightweight`): For each in-scope file, read sibling files in the same package to infer local patterns. Require at least 3 sibling files showing the same pattern before flagging a deviation. Check whether the in-scope file conforms to both explicit rules and inferred local patterns.
  - **Full** (when `conformance_mode` is `full`): If `REVIEW_DIR` was provided by the review-all orchestrator, read `${REVIEW_DIR}/PATTERNS.md`. Otherwise, find the most recent patterns file (`ls -t .reviews/*/PATTERNS.md reviews/*/PATTERNS.md 2>/dev/null | head -1`; the legacy `reviews/` path is honored for one transition release); if none exists, run `/discover-patterns` first. Check all in-scope files against both explicit rules and the discovered patterns.
- When `has_changes` is true (diff mode): focus findings on changed/added lines only. For each deviation, reference the established pattern with an exemplar.
- When `has_changes` is false (full mode): identify outlier files/packages that deviate from the majority pattern.
- For each finding, search nearby code for TODOs or notes.
- Return findings using the **per-category findings** template with `CONF-` prefixed IDs.
- Every finding must include: the pattern being violated, an exemplar of the correct pattern (file:line), the violating code (file:line), and tracking status.
- Severity mapping:
  - CRITICAL: explicit rule violation (from REVIEW.md, CLAUDE.md, AGENTS.md, or `.claude/rules/`)
  - HIGH: deviation from ESTABLISHED pattern (>80% conformance)
  - MEDIUM: deviation from EMERGING pattern (50-80% conformance)

### 3. Summarize

After all subagents complete, deduplicate overlapping findings, produce a consolidated table ordered by severity, and recommend fix order.

### 4. Present results

Resolve the review output directory (skip if `REVIEW_DIR` was provided by the review-all orchestrator):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header) below) and prepend the rendered block to `${REVIEW_DIR}/CODE-REVIEW.md`.

Write the output to `${REVIEW_DIR}/CODE-REVIEW.md`, structured as:
1. Run metadata header
2. Tool availability summary
3. Consolidated findings table (with tracking status inline)
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

### Per-category findings

```markdown
| # | Finding | Severity | Tracked |
|---|---------|----------|---------|
| ARCH1 | **Description.** Specific code reference (file:line). Explanation. | HIGH | — |
| DEP1 | Description with code reference. | MEDIUM | TODO in file:line |
| GO1 | Description with code reference. | HIGH | — |
| PB1 | Description with code reference. | MEDIUM | — |
| SA1 | Description with code reference. | LOW | — |
| PBL1 | Description with code reference. | LOW | — |
| REG1 | Description with code reference and historical commit. | HIGH | — |
| CONF1 | Description with pattern exemplar and violating code. | MEDIUM | — |
```

### Consolidated findings

```markdown
| Severity | ID | Finding | Source | Tracked |
|----------|----|---------|--------|---------|
| HIGH | 1 | Description with code references | ARCH1, DEP3 | — |
| HIGH | 2 | Description with code references | REG1 | — |
| MEDIUM | 3 | Description with code references | GO5, SA2 | TODO in file:line |
| MEDIUM | 4 | Description with code references | CONF1, CONF2 | — |
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

- Search the organization's codebase (Sourcegraph, GitHub) for existing patterns before recommending changes.
- Include effort estimates to help prioritize implementation.
- When the user asks for a follow-up review, find the most recent review directory (`ls -d reviews/*/ 2>/dev/null | sort | tail -1`) containing `CODE-REVIEW.md`, re-evaluate all prior findings, and update with the re-evaluation table appended.
- For detailed checklists, see [reference-architecture.md](reference-architecture.md), [reference-go.md](reference-go.md), and [reference-protobuf.md](reference-protobuf.md).
- For documentation quality (doc comments, examples, README), see **review-documentation**.
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (Go conventions, Protobuf & API) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
