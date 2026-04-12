---
name: review-database
description: Review database usage for migration safety, query performance, connection/transaction management, and schema design. Covers PostgreSQL and MySQL. Runs squawk for PostgreSQL migration linting if available. Use when the user asks for a database review, SQL review, migration review, or schema review.
---

# Database & SQL Review

Structured database review producing actionable, prioritized findings with code-level references.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific packages/directories, specific migrations, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file/package list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD` to get changed files (default `<base>` is `main`). If the user references a PR number, use `gh pr diff <number> --name-only` instead. Filter to relevant file types (`.go`, `.sql`). Derive affected Go packages from the file paths (unique parent directories containing `.go` files).
  - **Explicit paths/packages:** The user may specify directories (e.g. `internal/store/`), Go package patterns (e.g. `./internal/store/...`), individual files, or specific migration files. When given a directory or package pattern, include all files under it.
  - **Full codebase:** No filtering — explore everything (default).
- **Pass the resolved scope** (file list) to all exploration and investigation subagents so they only read and analyze scoped files.
- Explore the scoped code using parallel subagents (`subagent_type="explore"`). Read all in-scope `.sql` files, schema definitions, and source files that interact with the database (queries, connection setup, transaction handling).

### 2. Launch investigation subagent

Launch a single investigation subagent (`subagent_type="generalPurpose"`) with the list of in-scope files.

Prompt it to:
- Read all in-scope `.sql` files, schema definitions, and source files that interact with the database.
- Detect which database engine is in use by checking imports (`pgx`, `pq`, `lib/pq` for PostgreSQL; `go-sql-driver/mysql` for MySQL), migration tool configs, and connection strings. Apply the appropriate engine-specific checklist from [reference.md](reference.md).
- Analyze against all database categories: migration safety, query performance, connection & transaction management, and schema design (see [reference.md](reference.md)).
- Detect if horizontal sharding is in use (VSchema files, Citus distribution config, Spanner interleaved tables, shard-routing middleware, or multi-column partition keys). If detected, analyze hot-path queries against the checklist in [reference-sharding.md](reference-sharding.md) — flag scatter queries, missing sharding keys in WHERE clauses, cross-shard JOINs, and cross-shard transactions.
- For PostgreSQL projects: check if `npx` is on PATH (`which npx`). If available, run `npx squawk-cli <migration_files>` against in-scope `.sql` migration files only (when scope is narrowed, limit to `.sql` files in the resolved file list). If `npx` is not available, check for `squawk` directly on PATH. If neither is available, note in Tool Availability and continue with manual review only.
- Include a **Tool Availability** section listing each tool's status (ran / skipped + reason).
- For each finding, search nearby code and project documentation for existing TODOs or notes.
- Return findings using the **per-category findings** template with `DB-` prefixed IDs (e.g. `DB1`, `DB2`).
- Every finding must include specific file paths, line numbers or function names, a severity rating (CRITICAL / HIGH / MEDIUM / LOW), and tracking status.

### 3. Present results

Create the output directory (`mkdir -p reviews`) and write the output to `reviews/DATABASE-REVIEW.md`, structured as:
1. Tool availability summary
2. Findings table (with tracking status inline)
3. Recommended fix order

Present the report to the user. Overwrite if `reviews/DATABASE-REVIEW.md` already exists.

---

## Output Templates

### Per-category findings

```markdown
| # | Finding | Severity | Tracked |
|---|---------|----------|---------|
| DB1 | **Description.** Specific code reference (file:line). Explanation. | HIGH | — |
| DB2 | Description with code reference. | MEDIUM | TODO in file:line |
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
- When the user asks for a follow-up review, read the existing `reviews/DATABASE-REVIEW.md`, re-evaluate all prior findings, and update with the re-evaluation table appended.
- For detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (Database section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
