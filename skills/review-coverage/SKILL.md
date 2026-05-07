---
name: review-coverage
description: Use when the user asks for a coverage review, test coverage analysis, coverage gap analysis, uncovered code review, or wants to know what new/changed Go code is missing tests. Runs `go test -coverprofile` against the resolved scope and reports uncovered functions in changed Go files, grouped by package, with severity grading. Go projects only.
---

# Coverage Review

Structured Go test-coverage review producing actionable findings: which new or modified functions in the scope are not exercised by the test suite. Reports per-package coverage and (when a baseline exists) per-package coverage delta.

## Workflow

### 1. Scope and resolve

- Confirm scope with the user: full codebase, specific packages/directories, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file/package list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD` to get changed files (default `<base>` is `main`). If the user references a PR number, use `gh pr diff <number> --name-only` instead. Filter to `.go` files. Derive affected Go packages from the file paths (unique parent directories containing `.go` files).
  - **Explicit paths/packages:** The user may specify directories (e.g. `internal/auth/`), Go package patterns (e.g. `./internal/auth/...`), or individual files. When given a directory or package pattern, include all `.go` files under it.
  - **Full codebase:** No filtering — coverage analysis applies to every package (default).
- **Filter the resolved file list:**
  - `.go` files only
  - Exclude `_test.go`
  - Exclude generated code: anything under `gen/`, `internal/store/db/`, or files whose first 100 lines contain `// Code generated` or `DO NOT EDIT`
- Derive affected Go packages (unique parent dirs with surviving `.go` files).
- **If invoked from review-all**: receive `file_list`, `package_paths`, `has_changes`, `base_ref`, and `REVIEW_DIR` from the orchestrator. Skip your own scope confirmation and use the provided values directly.
- Set `has_changes` true when scope is "changed files" or when explicit paths have a diff against the base ref. False for full-codebase reviews with no diff baseline. When false, the skill still reports per-package coverage but cannot compute a "changed functions" delta.

### 2. Run baseline coverage

Run from the repo root:

```sh
go test -short -count=1 -covermode=atomic -coverprofile=coverage.out -coverpkg=./... ./...
```

`-coverpkg=./...` ensures cross-package coverage so e2e and integration tests count toward unit packages.

If the test suite fails, surface the failure and stop — do not attempt partial analysis or report misleading 0% coverage.

If a `Taskfile.yaml` defines a `test:cover` (or similar) target that runs equivalent coverage, prefer it over the raw command and capture its `coverage.out` output. If unsure, run the raw command above.

### 3. Parse the coverage profile

```sh
go tool cover -func=coverage.out
```

Parse output rows of the form `<file>:<line>:	<funcName>	<percent>%`. Filter rows to functions defined in the scoped/changed files (match by file path prefix). Compute per-package coverage by aggregating function-level results within each package directory.

### 4. Identify changed/new functions (when `has_changes` is true)

For each changed file, run `git diff <base>...HEAD -- <file>` and parse:
- Hunk headers (`@@ ... @@ func Name(...)` or `@@ ... @@ method (...) Name(...)`) for surrounding function names
- Added lines (`+` prefix) to determine which functions were added or modified

Cross-reference the resulting set against the parsed coverage profile to find changed/new functions with 0% or low coverage.

### 5. Coverage delta (optional)

Locate the most recent prior review's coverage profile:

```sh
prev=$(ls -t reviews/*/coverage.out 2>/dev/null | head -1)
```

If found, compute per-package coverage delta (current % − prior %) for affected packages. If not found, omit the delta column.

Either way, persist the current profile to `${REVIEW_DIR}/coverage.out` so the next run has a baseline.

### 6. Severity grading

Apply heuristics to each uncovered function:

- **HIGH** — function name or body involves error returns, security-sensitive operations (auth, decode, validate, sign, verify, decrypt, sanitize, escape), or panics/`os.Exit` calls
- **MEDIUM** — uncovered business logic in non-helper packages with non-trivial branching
- **LOW** — getters, setters, formatters, `String()` / `Error()` methods, trivial constructors, stringer-generated functions

Severity is applied by the investigation subagent's judgment based on reading the function body — no automated complexity check in v1.

### 7. Launch investigation subagent

Launch a single investigation subagent (`subagent_type="generalPurpose"`) with the system context, scope, and parsed coverage data.

Prompt it to:
- Read the in-scope `.go` files and any directly relevant test files in the same package.
- Use the per-function coverage data and changed-function set to identify uncovered or under-covered functions.
- Apply the severity heuristics from step 6 by reading function bodies.
- For each finding, search nearby code and project documentation (TODO/FIXME/HACK/XXX comments, README, issue references) for existing tracking.
- Return findings using the **uncovered functions** template with `COV-` prefixed IDs.
- Every finding must include: package, function name, file:line, severity, and tracking status.

### 8. Present results

Resolve the review output directory (skip if `REVIEW_DIR` was provided by the review-all orchestrator):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR="reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR="reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header) below) and prepend the rendered block to `${REVIEW_DIR}/COVERAGE-REVIEW.md`.

Write the output to `${REVIEW_DIR}/COVERAGE-REVIEW.md`, structured as:
1. Run metadata header
2. Tool availability summary (Go version, test outcome, whether `coverage.out` was produced, prior baseline location if any)
3. Per-package coverage table (with delta column when baseline existed)
4. Uncovered functions table (grouped by package, sorted by severity)
5. Recommended fix order

Save the current `coverage.out` to `${REVIEW_DIR}/coverage.out`.

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

When the review is scoped to a GitHub PR — `pr_url` is provided by the caller, or, when run standalone, `gh pr view --json url -q .url 2>/dev/null` returns one — wrap every `path:line` reference inside the finding tables below as a Markdown link:

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>
# pr_url set   → [path:line](https://github.com/.../pull/N/files#diff-<hash>R<line>)
# pr_url empty → path:line   (plain text, unchanged)
```

The display text stays `path:line` so plain and linked tables look identical; only the URL goes in the link target. Pass `L` as the fourth argument for findings about removed code (default is `R`). Omit `<line>` for file-level findings to get a file-anchor link. Apply the same wrapping to `path:line` references inside the Tracked column (e.g. `TODO in foo.go:42`).

---

## Output Templates

### Per-package coverage

```markdown
| Package | Coverage | Delta | Affected Functions |
|---------|----------|-------|--------------------|
| internal/auth | 78.4% | +2.1% | 3 changed, 1 uncovered |
| internal/store | 64.2% | — | 5 changed, 4 uncovered |
| internal/render | 91.0% | -3.5% | 2 changed, 0 uncovered |
```

When no baseline exists, omit the **Delta** column. When `has_changes` is false, replace **Affected Functions** with **Functions** and report total counts.

### Uncovered functions

```markdown
| # | Package | Function | File:Line | Severity | Tracked |
|---|---------|----------|-----------|----------|---------|
| COV1 | internal/auth | `verifyToken` | auth/verify.go:42 | HIGH | — |
| COV2 | internal/store | `formatRowKey` | store/key.go:18 | LOW | TODO in store/key.go:15 |
| COV3 | internal/render | `(*Page).Render` | render/page.go:104 | MEDIUM | — |
```

**Tracked column values:** Use `—` for new findings. For already-captured findings: `TODO in file:line`, `FIXME in file:line`, `README`, `#123` (issue reference).

### Tool availability

```markdown
| Tool | Status | Notes |
|------|--------|-------|
| `go test -coverprofile` | ran | produced coverage.out (1.2 MB) |
| `go tool cover -func` | ran | parsed 412 functions |
| Prior baseline | found | reviews/2026-04-18/coverage.out |
```

---

## Guidelines

- **Single subagent.** This skill uses one investigation subagent — coverage parsing is mechanical and the only judgment call is severity grading.
- **When called from review-all**, skip standalone `REVIEW_DIR` resolution (the orchestrator owns it) and skip scope confirmation. Use the provided file list, package paths, `has_changes` flag, base ref, and `REVIEW_DIR`.
- **No follow-up re-evaluation table.** Coverage findings are derivable from current state on every run, unlike static-analysis findings which can persist after a fix.
- **REVIEW.md integration**: If a `REVIEW.md` was provided by the review-all orchestrator (or exists at the repo root when running standalone), respect any **Skip** patterns by excluding matching files from scope, and treat any **Always check** rules touching coverage thresholds as HIGH-severity floors.
- **Test failures stop the analysis.** Do not generate a coverage report from a failed test run — the profile would be misleading or incomplete.

### Boundary with adjacent skills

This skill's exclusive concern is **new or modified Go code in this diff that the test suite does not exercise**. Two adjacent skills cover related but distinct concerns — do not duplicate their checks here:

- **review-reliability** checks **goroutine leak coverage** via `goleak.VerifyNone` / `goleak.VerifyTestMain` in tests. Different axis: leak detection in tests, not line/function coverage of source.
- **review-code** Subagent F (Regression History) flags **test removal or weakening** in the diff (regressions from gutting tests). Different axis: deleted-test detection on the diff side, not uncovered-new-code detection.

If a finding straddles these axes (e.g. a removed test reduced coverage of a security path), report only the coverage gap here; the adjacent skills will catch their own concerns when run together via `/review-all`.
