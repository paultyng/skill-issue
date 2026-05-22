---
name: review-documentation
description: Review documentation quality and sync with implementation across Go doc comments, proto comments, OpenAPI specs, markdown files, and example tests. Use when the user asks for a documentation review, doc audit, or wants to check that docs are in sync with code.
---

# Documentation Review

Structured documentation review producing actionable, prioritized findings with code-level references. Checks that documentation exists, is accurate, and stays in sync with the implementation.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific packages/directories, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file/package list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD` to get changed files (default `<base>` is `main`). If the user references a PR number, use `gh pr diff <number> --name-only` instead. Filter to relevant file types (`.go`, `.proto`, `.md`, OpenAPI specs). Derive affected Go packages from the file paths (unique parent directories containing `.go` files).
  - **Explicit paths/packages:** The user may specify directories (e.g. `internal/auth/`), Go package patterns (e.g. `./internal/auth/...`), or individual files. When given a directory or package pattern, include all files under it. Derive Go package paths for `go doc` invocations.
  - **Full codebase:** No filtering; explore everything (default).
- **Pass the resolved scope** (file list and derived package paths) to all exploration and investigation subagents so they only read and analyze scoped files.
- Detect which documentation surfaces exist within the resolved scope:
  - `.go` files → `go doc` analysis, `doc.go` files, `Example*` tests
  - `.proto` files → service/method/message/field comments
  - `openapi.yml` / `openapi.yaml` / `swagger.*` → API descriptions
  - `*.md` files → README, guides, changelogs

### 2. Launch investigation subagents in parallel

Launch up to 3 investigation subagents concurrently using the Task tool (`model: sonnet` per `subagent-model-routing` — documentation analysis requires cross-referencing signatures and prose). Each receives the list of in-scope files as context. Only launch subagents whose preconditions are met.

> **Future fan-out note:** If per-symbol doc-comment presence checking is ever split into a dedicated fan-out subagent (e.g. one per package), use `model: haiku` per `subagent-model-routing` — presence checks are mechanical.

Every investigation subagent must check each finding against existing documentation: TODO comments, README notes, FIXME/HACK/XXX comments, and issue tracker references. Report tracked findings but mark them accordingly.

**Subagent A: Go documentation** (`subagent_type="generalPurpose"`, requires `.go` files)

Prompt the subagent to:
- Enumerate packages: run `go list ./...` for full-codebase scope, or `go list <package_paths>` for the resolved package paths when scope is narrowed.
- For each package (sample if >20), run `go doc -all <pkg>` and inspect the output for:
  - Missing package-level comment (no `doc.go` or empty package doc).
  - Exported symbols (types, funcs, consts, vars) with missing or trivial (single-word, restating the name) doc comments.
  - Doc comments that don't start with the symbol name or don't end with a period.
  - Doc comment content that contradicts the actual function signature or behavior (parameter names, return types, error conditions).
- Check for `Example*` test functions in `*_test.go` files. Flag key exported APIs that lack examples.
- If `go doc` fails (e.g. build errors), fall back to reading `doc.go` and source files directly.
- Include a **Tool Availability** section noting whether `go doc` ran successfully.
- Return findings with `DOC-` prefixed IDs.

**Subagent B: Proto and OpenAPI documentation** (`subagent_type="generalPurpose"`, requires `.proto` files)

Prompt the subagent to:
- Read all in-scope `.proto` files and check for:
  - Missing service-level comments.
  - Missing RPC method comments.
  - Missing or sparse message and field comments, especially fields with unclear names.
- Glob for `openapi.yml`, `openapi.yaml`, `swagger.yml`, `swagger.yaml`, or `swagger.json` files.
- If an OpenAPI spec exists, cross-reference against proto comments:
  - Proto comments should appear as `description` fields in the OpenAPI spec.
  - Flag drift: OpenAPI description empty despite proto comment existing, or content diverging.
  - Flag missing `description` on endpoints, request/response schemas, and parameters.
- Return findings with `DOC-` prefixed IDs.

**Subagent C: Markdown and general docs** (`subagent_type="generalPurpose"`)

Prompt the subagent to:
- Glob for `*.md` files across the repo.
- Check README.md exists at the repo root. Flag if missing.
- Scan markdown files for:
  - Links to files that no longer exist (spot-check relative links against the file tree).
  - References to CLI flags, env vars, or config keys; spot-check a sample against actual code.
  - Code examples; spot-check function/type names against actual exports.
- Flag large documentation gaps: no README, no CONTRIBUTING guide (for OSS projects), no architectural overview for multi-service repos.
- Return findings with `DOC-` prefixed IDs.

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

Capture run metadata (see [Run metadata header](#run-metadata-header) below) and prepend the rendered block to `${REVIEW_DIR}/DOCUMENTATION-REVIEW.md`.

Write the output to `${REVIEW_DIR}/DOCUMENTATION-REVIEW.md`, structured as:
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
| DOC1 | **Description.** Specific code reference (file:line or package). Explanation. | HIGH | — |
| DOC2 | Description with code reference. | MEDIUM | TODO in file:line |
```

### Consolidated findings

```markdown
| Severity | ID | Finding | Source | Tracked |
|----------|----|---------|--------|---------|
| HIGH | 1 | Description with code references | DOC1, DOC5 | — |
| MEDIUM | 2 | Description with code references | DOC3 | TODO in file:line |
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

- Search the organization's codebase (Sourcegraph, GitHub) for existing documentation conventions before recommending changes.
- Include effort estimates to help prioritize implementation.
- When the user asks for a follow-up review, find the most recent review directory (`ls -d reviews/*/ 2>/dev/null | sort | tail -1`) containing `DOCUMENTATION-REVIEW.md`, re-evaluate all prior findings, and update with the re-evaluation table appended.
- For detailed documentation quality dimensions, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; "Skip" patterns exclude matching files from review scope.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
