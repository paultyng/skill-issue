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
  - **Full codebase:** No filtering — explore everything (default).
- **Pass the resolved scope** (file list and derived package paths) to all exploration and investigation subagents so they only read and analyze scoped files.
- Detect which documentation surfaces exist within the resolved scope:
  - `.go` files → `go doc` analysis, `doc.go` files, `Example*` tests
  - `.proto` files → service/method/message/field comments
  - `openapi.yml` / `openapi.yaml` / `swagger.*` → API descriptions
  - `*.md` files → README, guides, changelogs

### 2. Launch investigation subagents in parallel

Launch up to 3 investigation subagents concurrently using the Task tool. Each receives the list of in-scope files as context. Only launch subagents whose preconditions are met.

Every investigation subagent must check each finding against existing documentation — TODO comments, README notes, FIXME/HACK/XXX comments, and issue tracker references. Report tracked findings but mark them accordingly.

**Subagent A — Go documentation** (`subagent_type="generalPurpose"`, requires `.go` files)

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

**Subagent B — Proto and OpenAPI documentation** (`subagent_type="generalPurpose"`, requires `.proto` files)

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

**Subagent C — Markdown and general docs** (`subagent_type="generalPurpose"`)

Prompt the subagent to:
- Glob for `*.md` files across the repo.
- Check README.md exists at the repo root. Flag if missing.
- Scan markdown files for:
  - Links to files that no longer exist (spot-check relative links against the file tree).
  - References to CLI flags, env vars, or config keys — spot-check a sample against actual code.
  - Code examples — spot-check function/type names against actual exports.
- Flag large documentation gaps: no README, no CONTRIBUTING guide (for OSS projects), no architectural overview for multi-service repos.
- Return findings with `DOC-` prefixed IDs.

### 3. Summarize

After all subagents complete, deduplicate overlapping findings, produce a consolidated table ordered by severity, and recommend fix order.

### 4. Present results

Create the output directory (`mkdir -p reviews`) and write the output to `reviews/DOCUMENTATION-REVIEW.md`, structured as:
1. Tool availability summary
2. Consolidated findings table (with tracking status inline)
3. Recommended fix order

Present the report to the user. Overwrite if `reviews/DOCUMENTATION-REVIEW.md` already exists.

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
- When the user asks for a follow-up review, read the existing `reviews/DOCUMENTATION-REVIEW.md`, re-evaluate all prior findings, and update with the re-evaluation table appended.
- For detailed documentation quality dimensions, see [reference.md](reference.md).
