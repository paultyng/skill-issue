---
name: review-all
description: Use when the user asks for a deep review, full review, comprehensive review, production readiness assessment, full audit, multi-domain audit, "security and reliability and code review", or "review everything". Also use when the user explicitly requests performance review alongside the comprehensive request (e.g. "include perf", "review including performance", "deep review with perf"); without that explicit phrasing, performance is excluded. Do NOT use for narrow single-domain reviews (use the matching review-* skill directly).
---

# Full Review

Orchestrate all domain-specific review skills as parallel subagents, then consolidate into a unified report.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific packages/directories, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file/package list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD` to get changed files (default `<base>` is `main`). If the user references a PR number, use `gh pr diff <number> --name-only` instead. Derive affected Go packages from the file paths (unique parent directories containing `.go` files).
  - **Explicit paths/packages:** The user may specify directories (e.g. `internal/auth/`), Go package patterns (e.g. `./internal/auth/...`), or individual files. When given a directory or package pattern, include all files under it. Derive Go package paths for static analysis tool invocations.
  - **Full codebase:** No filtering. Explore everything (default).
- **Pass the resolved scope** (file list, derived package paths, and file-type flags below) to each review subagent in step 3 so they skip their own scope confirmation and use the provided scope directly.
- **Resolve `pr_url` for deep-linking** (display-only, used in the final consolidated report). Run `gh pr view --json url -q .url 2>/dev/null` to capture the PR URL for the current branch (or for the PR number the user supplied via `gh pr view <num> --json url -q .url`). Empty string if no PR exists. Pass `pr_url` to each subagent in step 3 and to the summarization subagent in step 4. Subagents wrap finding `path:line` references using `~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>`. See [Finding link wrapping](#finding-link-wrapping) below.
- **Classify the resolved files** to determine which reviews to launch:
  - `has_code`: any source files (`.go`, `.rs`, `.ts`, `.tsx`, `.js`, `.jsx`, `.swift`, `.kt`, `.kts`, `.py`, `.rb`)
  - `has_go`: any `.go` files
  - `has_proto`: any `.proto` files
  - `has_sql`: any `.sql` files
  - `has_iac`: any Dockerfiles/Containerfiles, k8s manifests, Terraform (`.tf`/`.tofu`), Helm charts (`Chart.yaml`), service mesh / gateway CRDs (Linkerd/Istio/Gateway API/Ingress/Envoy bootstrap)
  - `has_ci`: any GitHub Actions workflows (`.github/workflows/*.yml`), composite actions (`action.yml`), Dependabot/Renovate configs, or CI configs (`.circleci/config.yml`, `.buildkite/pipeline.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, `azure-pipelines.yml`, `cloudbuild.yaml`, `bitbucket-pipelines.yml`)
  - `has_infra`: shorthand for `has_iac || has_ci` (kept for backwards compatibility with existing review-* subagents)
  - `has_api_specs`: any `.proto`, OpenAPI/Swagger specs (`openapi.{yml,yaml,json}`, `swagger.{yml,yaml,json}`), or GraphQL schemas (`*.graphql`, `*.gql`)
  - `has_docs`: any `.md` files or OpenAPI/Swagger specs
  - `has_changes`: true when scope is "changed files (PR or branch)", or when scope is "explicit paths" and those paths have a diff against the base ref (run `git diff --name-only --diff-filter=d <base>...HEAD -- <paths>` to check; default base is `main`). False for full-codebase reviews with no diff baseline.
- **Detect opt-in flags** from the user's request phrasing:
  - `include_performance`: true when the user explicitly asks for performance, perf, benchmark, profiling, pprof, hot-path, or latency review alongside the comprehensive request. Default false. Never auto-enable from file types.
### 1a. Detect conformance mode

If the user's request includes phrases like "full conformance", "pattern discovery", "check patterns", or "discover patterns", set `conformance_mode` to `full`. Otherwise default to `lightweight`. This flag is passed to review-code in step 3.

### 1b. Load REVIEW.md (if present)

Check for a `REVIEW.md` file at the repository root. If it exists, read it and extract:
- **Always check** rules: these become mandatory check items passed to all subagents (flagged at HIGH severity)
- **Skip** rules: filter these paths/patterns out of scope before passing to subagents (apply alongside the file-type classification above)
- **Domain-specific sections** (Security, Reliability, Database, Protobuf & API, Go conventions, Documentation): route each section to the corresponding review subagent as additional context

If no `REVIEW.md` exists, proceed without it. All review skills have their own reference checklists.

**`REVIEW.md` schema extensions used by this skill** (all subsections optional):

```markdown
## Open context

- Skip: true                    # disable open-work-context lookup entirely
- Include PRs: false            # disable GH PR source
- Include issues: false         # disable GH issue source
- Jira project: AUTH            # enable Jira source with this project key
- Recency days: 60              # override the 30-day window

## Policy gate

- Skip: true                    # suppress the gate prompt; always proceed with original scope
- Policy files: [glob, ...]     # additional globs appended to the default policy-file list
```

`Open context` controls step 1d (below). `Policy gate` controls step 1c (above).

- Determine which review types are applicable using these flags:
  - **review-security**: applicable if `has_code` or `has_infra`
  - **review-reliability**: applicable if `has_code` or `has_iac`
  - **review-code**: applicable if `has_code` or `has_proto`
  - **review-database**: applicable if `has_sql`, or database-interacting code exists (check imports for DB drivers like `pgx`, `pq`, `database/sql`, `sqlx`, `diesel`, `sqlalchemy`, etc.)
  - **review-coverage**: applicable if `has_go` and `has_changes`
  - **review-documentation**: always applicable
  - **review-infrastructure**: applicable if `has_iac`
  - **review-ci**: applicable if `has_ci`
  - **review-observability**: applicable if `has_code` (observability gaps are code-level; configs alone aren't enough)
  - **review-api-compat**: applicable if `has_api_specs` AND `has_changes` (it's a diff-aware review; no diff baseline = nothing to compare)
  - **review-performance**: applicable ONLY if `include_performance` is true. Never auto-launched.

### 1c. Policy-change detection (gate)

If diff scope is in use, check whether any changed file is a **policy file** — a rule/config artifact that affects review of the whole repo, not just itself:

- `REVIEW.md`, `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md` (at any path depth; typically repo root)
- Any file under `.claude/rules/` or `.cursor/rules/` (recursive)
- Any glob declared in `REVIEW.md` under `Policy gate: Policy files: [glob, ...]` — appended to (not replacing) the default list

Detection:

```sh
POLICY_HITS=$(printf '%s\n' "$CHANGED_FILES" \
  | grep -E '(^|/)(REVIEW|CLAUDE|CLAUDE\.local|AGENTS)\.md$|^\.claude/rules/|^\.cursor/rules/' \
  || true)
# Append matches for any REVIEW.md-declared globs to POLICY_HITS.
```

When `POLICY_HITS` is empty, skip the rest of step 1c and continue to 1d. When non-empty, apply the gate below.

**Opt-out**: if `REVIEW.md` declares `Policy gate: Skip: true`, suppress the prompt and continue with the original diff scope silently. Record `Scope: diff (kept; policy gate skipped via REVIEW.md)` in the run metadata.

**Gate behavior** when `POLICY_HITS` is non-empty and not opted out:

1. Surface to the user a brief block listing the policy files in `POLICY_HITS`, plus the one-line explanation: *"Policy/rule changes affect the whole codebase; diff review only audits the policy itself."*
2. Ask: **"Switch to full-repo review against this policy? [y/N]"**
3. **`y`** → rescope: clear `pr_url`, set scope to full codebase (run the file-type classification on the entire tree the way a no-PR / no-base-ref invocation would), set `conformance_mode=full`. Append to run metadata: `Scope: full-repo (escalated from diff due to policy change in <files>)`.
4. **`N`** → keep diff scope unchanged. Append to run metadata: `Scope: diff (kept despite policy change in <files>)`.

Continue to 1d once the gate decision is recorded.

### 1d. Resolve open-work context

Surface in-flight work that may overlap with the (post-gate) scope so subagents can flag conflicts and duplicates. Skip the entire step if `REVIEW.md` declares `Open context: Skip: true`.

**Keyword extraction** from the changed file list (output of step 1):

1. Unique top-level dirs from changed paths.
2. Unique immediate parent dir names.
3. For `.go` files: `filepath.Base(pkg_dir)`.
4. For `.proto` files: the declared `package` line.

De-dup, lowercase, drop the stop-list `(internal|pkg|cmd|test|tests|vendor|gen|api|proto|src|lib)`. If the resulting keyword set is empty (e.g. all changed files sit inside stop-listed dirs), skip step 1d entirely — no useful filter is possible.

The keyword set drives the three source queries below (PRs, issues, Jira).

**Source: open GitHub PRs**

Skip if `REVIEW.md` declares `Open context: Skip: true` or `Open context: Include PRs: false`.

```sh
gh pr list --state open --limit 50 \
  --search "updated:>$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)" \
  --json number,title,headRefName,labels,updatedAt,url 2>/dev/null
```

Post-filter the JSON result: keep entries where `title || headRefName || labels[*].name` contains ≥1 keyword (case-insensitive substring). Sort by `updatedAt` desc, cap at 10.

**Fail-soft**: if `gh` errors (no auth, no remote, command not found), record one line `PR lookup unavailable: <reason>` in the run metadata and continue with the remaining sources.

**Source: open GitHub issues**

Skip if `REVIEW.md` declares `Open context: Skip: true` or `Open context: Include issues: false`.

```sh
gh issue list --state open --limit 100 \
  --search "updated:>$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)" \
  --json number,title,labels,updatedAt,url 2>/dev/null
```

Post-filter: keep entries where `title || labels[*].name` contains ≥1 keyword. Sort by `updatedAt` desc, cap at 10.

**Label boost**: when a hit carries any of `bug`, `regression`, `flaky`, `security`, prefix the rendered row with `★` (visual emphasis only — ordering is unchanged).

**Fail-soft**: same as the PR source — record `Issue lookup unavailable: <reason>` and continue.

**Source: open Jira tickets (opt-in)**

Run this substep **only** when `REVIEW.md` declares `Open context: Jira project: <KEY>`. No default; absence means no Jira lookup.

Use the MCP tool `claude_ai_Atlassian_Rovo:searchJiraIssuesUsingJql` with this JQL template (substitute `<KEY>` and `<RECENCY>`; `<RECENCY>` defaults to 30, override via `Open context: Recency days:`):

```
project = <KEY> AND statusCategory != Done AND updated >= -<RECENCY>d
```

Post-filter: keep entries where `summary || description` contains ≥1 keyword (case-insensitive substring). Sort by `updated` desc, cap at 10. Render each as `<KEY>-<NUM>: <summary>` with status.

**Fail-soft**: if the MCP is unavailable or returns an auth error, record `Jira lookup unavailable: <reason>` and continue.

**Rendered block** — `Open work context`:

```markdown
## Open work context

Filter: changed-path keywords `<keyword-list>`; updated within last 30 days.

**Open PRs (n)**
| # | Title | Branch | Updated |
| --- | --- | --- | --- |
| [#412](url) | <title> | <branch> | YYYY-MM-DD |

**Open issues (n)**
| # | Title | Labels | Updated |
| --- | --- | --- | --- |
| ★[#523](url) | <title> | bug | YYYY-MM-DD |

**Open Jira (n)**
| Key | Summary | Status | Updated |
| --- | --- | --- | --- |
| [AUTH-2583](url) | <summary> | In Progress | YYYY-MM-DD |
```

Omit each sub-block when count is 0. Omit the whole section when all three counts are 0 (do not render an empty `## Open work context` heading).

### 2. System overview

Produce a brief architecture summary covering:
- Services, ports, and transport (gRPC, HTTP, etc.)
- Data stores and external dependencies
- Authentication and authorization mechanisms
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

This system overview is shared context for all review subagents.

### 2b. Run pattern discovery (if full conformance mode)

If `conformance_mode` is `full`, resolve the review output directory first. `.reviews/` is gitignored on first use; review outputs are working artifacts, not source:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Then launch a `/discover-patterns` subagent (`subagent_type="generalPurpose"`, `model: opus` per `subagent-model-routing` — architecture-level pattern discovery) with the resolved scope and `REVIEW_DIR`, instructing it to write to `${REVIEW_DIR}/PATTERNS.md`. Pass `REVIEW_DIR` to review-code's prompt so its Conformance Check subagent reads `${REVIEW_DIR}/PATTERNS.md`. Other review subagents (security, reliability, database, documentation) can launch in parallel with this step since they don't depend on it; only review-code must wait for it to complete.

### 3. Launch review subagents in parallel

Launch applicable review skills concurrently using the Task tool (max 4 at a time; if more than 4, launch the first 4 and the remaining after one completes). Each subagent is `subagent_type="generalPurpose"`, `model: sonnet` (per `subagent-model-routing` — structured analysis with code-level findings).

For each subagent, include in its prompt:
- The system overview and flow mapping from step 2
- The resolved file list and package paths from step 1 (the subagent should use this scope directly and skip its own scope confirmation)
- The `has_changes` flag, base ref, and changed file list from step 1 (so change-aware subagents like review-code's Regression History can use them)
- The `pr_url` from step 1 (used to wrap `path:line` finding references via `~/.claude/scripts/pr-deeplink.sh`; empty string disables wrapping)
- The `conformance_mode` flag from step 1a (for review-code only)
- If `REVIEW.md` was loaded in step 1b: the "Always check" rules (for all subagents) and the relevant domain-specific section for that subagent (e.g. Security section → review-security, Database section → review-database). Instruct the subagent to treat "Always check" rules as HIGH severity and domain-specific rules as MEDIUM severity, in addition to its own reference checklist.
- Instructions to follow the corresponding skill's workflow (read the SKILL.md for reference on what each skill does)
- Request that it return the full findings output (including tracking annotations and tool availability sections)
- **If the `Open work context` block from step 1d is non-empty**, include it in the subagent prompt under a dedicated heading:
  ```
  # Open work context that may overlap
  <paste the rendered block from step 1d here>

  Flag in your findings if any item below conflicts with, duplicates, or would be invalidated by your recommendations. Do not treat the existence of an open PR as license to skip a finding.
  ```
  This is the **sole injection point** for the open-context block. The system overview from step 2 is **not** modified to carry it — keep step 2 focused on architecture, step 3's per-subagent prompt focused on reviewer-facing context.

**Review subagents to launch:**

| Subagent | Skill | Condition |
|----------|-------|-----------|
| Security | review-security | `has_code` or `has_infra` |
| Reliability | review-reliability | `has_code` or `has_iac` |
| Code | review-code | `has_code` or `has_proto` |
| Database | review-database | `has_sql` or DB code in scope |
| Coverage | review-coverage | `has_go` and `has_changes` |
| Documentation | review-documentation | Always |
| Infrastructure | review-infrastructure | `has_iac` |
| CI | review-ci | `has_ci` |
| Observability | review-observability | `has_code` |
| API compatibility | review-api-compat | `has_api_specs` and `has_changes` |
| Performance | review-performance | `include_performance` is true (opt-in only) |

Each subagent should NOT write its own output file; it returns findings to this orchestrator.

**Concurrency cap.** Launch up to 4 subagents at a time. With all skills enabled the dispatch can exceed 4; queue the rest and launch them as earlier ones complete.

### 4. Launch summarization subagent

After all review subagents complete, launch a single summarization subagent (`subagent_type="generalPurpose"`, `model: opus` per `subagent-model-routing` — cross-cutting dedup and prioritization across all review domains) with the full findings from each review subagent. Pass `pr_url` so it can preserve and apply the [Finding link wrapping](#finding-link-wrapping) convention when rewriting tables.

Prompt it to:
1. **Deduplicate** overlapping findings across all reviews. Common overlaps to watch for:
   - security ↔ reliability (e.g. unbounded result sets)
   - security ↔ infrastructure (e.g. inline secrets in TF / k8s)
   - security ↔ ci (e.g. PR-target script injection)
   - reliability ↔ observability (e.g. missing error spans on hot paths)
   - reliability ↔ infrastructure (e.g. k8s probes vs. shutdown contract — `review-infrastructure` covers probe presence, `review-reliability` covers shutdown semantics)
   - code ↔ api-compat (e.g. a proto change flagged for design AND for wire compat)
2. **Cross-reference** each deduplicated finding to its source review and IDs.
3. **Preserve tracking status**. A finding is tracked if any source review marked it as tracked.
4. **Prioritize**. Produce consolidated findings tables ordered by severity/priority, grouped by category (security, reliability, code, infrastructure, ci, observability, api-compatibility, performance, database, coverage, documentation).
5. **Recommend fix order**, considering dependencies between findings and effort estimates. Already-tracked findings may be deprioritized if the existing TODO indicates a plan.
6. **Tool Availability summary**. Consolidate from all reviews into a summary listing which automated tools ran successfully, which were skipped, and why.

### 5. Present results

If `REVIEW_DIR` was resolved in step 2b, reuse it. Otherwise, resolve it now:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Capture run metadata for the output header (see [Run metadata header](#run-metadata-header) below). When scope is diff-based, also capture `BASE_REF` and `BASE_COMMIT=$(git rev-parse "$BASE_REF")`.

Write the summarization output to `${REVIEW_DIR}/SUMMARY.md`, structured as:
1. Run metadata header
2. Tool availability summary
3. System overview (from step 2)
4. Consolidated findings tables (with tracking status inline), grouped by category
5. Recommended fix order

Present the report to the user.

---

## Run metadata header

Capture once near `REVIEW_DIR` resolution and prepend to every output document this skill writes (and require subagents that write their own files to do the same):

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
GIT_SUBJECT=$(git log -1 --pretty=%s)
# When scope is diff-based, also capture:
# BASE_REF=<base, e.g. main>; BASE_COMMIT=$(git rev-parse --short "$BASE_REF")
```

Header template (place at the very top of the output `.md`, before the H1 title):

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Base:** {BASE_REF} @ {BASE_COMMIT}   <!-- omit when scope is not diff-based -->
> **Scope:** {scope description, e.g. "changed files (PR #42)" or "full codebase" or "./internal/auth/..."}
```

---

## Finding link wrapping

When `pr_url` is non-empty (resolved in step 1), every `path:line` reference inside finding cells in the consolidated tables below is wrapped as a Markdown link to the PR's "Files changed" tab, anchored at the line. The display text stays `path:line`; only the link target carries the URL, so table widths don't blow up.

Use the helper to build each link:

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>
# → [path:line](https://github.com/owner/repo/pull/N/files#diff-<hash>R<line>)

~/.claude/scripts/pr-deeplink.sh "$pr_url" <path>
# → [path](https://github.com/owner/repo/pull/N/files#diff-<hash>)   (file-level)

~/.claude/scripts/pr-deeplink.sh "" <path> <line>
# → path:line   (no PR scope; plain text)
```

Notes:
- Right-side anchor (`R<line>`) is the default and almost always correct; findings call out added/modified code.
- Use `L` as the fourth argument only when a finding is specifically about removed code on the left side of the diff.
- The diff anchor format (`#diff-<sha256(path).first32>`) is GitHub's stable but undocumented convention. If GitHub ever changes it, only `pr-deeplink.sh` needs updating.
- For file-level findings (no specific line), call the helper without `<line>` to emit a file-anchor link.
- `Tracked` column entries that include `path:line` (e.g. `TODO in foo.go:42`) follow the same wrapping rule.
- Findings themselves follow `terse-comments`: concrete fix, optional `bug:`/`risk:`/`nit:`/`unsure:` prefix, no praise or restating the diff.

This applies to the consolidated tables below **and** to per-category finding tables emitted by each subagent (reproduced into the consolidated report).

---

## Output Templates

### Consolidated security findings

```markdown
| Severity | ID | Finding | STRIDE | OWASP | Tracked |
|----------|----|---------|--------|-------|---------|
| CRITICAL | 1 | Description with code references | S1, E1 | A01, A07 | — |
| HIGH | 2 | Description with code references | T2 | A04 | TODO in file:line |
```

### Consolidated reliability findings

```markdown
| Priority | Finding | Impact | Effort | Tracked |
|----------|---------|--------|--------|---------|
| P0 | Description with code references | Impact on availability/latency | trivial / small / moderate / large | — |
```

### Consolidated code findings

```markdown
| Severity | ID | Finding | Source | Tracked |
|----------|----|---------|--------|---------|
| HIGH | 1 | Description with code references | ARCH1, DEP2 | — |
| MEDIUM | 2 | Description with code references | GO1, SA3 | TODO in file:line |
| MEDIUM | 3 | Description with code references | PB2, PBL1 | — |
| HIGH | 4 | Description with code references | REG1 | — |
| MEDIUM | 5 | Description with code references | CONF1, CONF2 | — |
```

### Consolidated documentation findings

```markdown
| Severity | ID | Finding | Source | Tracked |
|----------|----|---------|--------|---------|
| HIGH | 1 | Description with code references | DOC1, DOC4 | — |
| MEDIUM | 2 | Description with code references | DOC2 | TODO in file:line |
```

### Consolidated infrastructure findings

```markdown
| Priority | Surface | Finding | Impact | Effort | Tracked |
|----------|---------|---------|--------|--------|---------|
| P0 | k8s | Description with code references | Impact | trivial / small / moderate / large | — |
| P1 | terraform | Description with code references | Impact | Effort | FIXME in file:line |
```

### Consolidated CI findings

```markdown
| Priority | Workflow | Finding | Impact | Effort | Tracked |
|----------|----------|---------|--------|--------|---------|
| P0 | release.yml | Description with code references | Supply chain / security | trivial / small / moderate / large | — |
```

### Consolidated observability findings

```markdown
| Priority | Signal | Finding | Impact | Effort | Tracked |
|----------|--------|---------|--------|--------|---------|
| P0 | tracing | Description with code references | MTTR / debuggability | trivial / small / moderate / large | — |
```

### Consolidated API compatibility findings

```markdown
| Priority | Surface | Change | Class | Recommendation | Tracked |
|----------|---------|--------|-------|----------------|---------|
| P0 | proto | `pkg.Service.Method` removed at file:line | wire-breaking | Deprecate first; remove in next major version | — |
```

### Consolidated performance findings

Only emitted when `include_performance` is true.

```markdown
| Priority | Category | Finding | Impact | Effort | Evidence | Tracked |
|----------|----------|---------|--------|--------|----------|---------|
| P1 | allocation | Description with code references | Allocations on hot path | small | profile needed | — |
```

### Consolidated coverage findings

Per-package coverage (omit Delta column when no prior baseline exists):

```markdown
| Package | Coverage | Delta | Affected Functions |
|---------|----------|-------|--------------------|
| internal/auth | 78.4% | +2.1% | 3 changed, 1 uncovered |
| internal/store | 64.2% | — | 5 changed, 4 uncovered |
```

Uncovered functions (grouped by package, sorted by severity):

```markdown
| Severity | ID | Package | Function | File:Line | Tracked |
|----------|----|---------|----------|-----------|---------|
| HIGH | COV1 | internal/auth | `verifyToken` | auth/verify.go:42 | — |
| MEDIUM | COV2 | internal/render | `(*Page).Render` | render/page.go:104 | — |
| LOW | COV3 | internal/store | `formatRowKey` | store/key.go:18 | TODO in store/key.go:15 |
```

### Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Brief explanation of the fix |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- Search the organization's codebase (Sourcegraph, GitHub) for existing patterns before recommending new dependencies or approaches.
- Cross-reference findings between reviews to avoid duplicate entries in the consolidated tables.
- Include effort estimates to help prioritize implementation.
- When the user asks for a follow-up review, find the most recent review directory containing `SUMMARY.md`. Primary lookup: `ls -d .reviews/*/ 2>/dev/null | sort | tail -1`. Legacy fallback if empty: `ls -d reviews/*/ 2>/dev/null | sort | tail -1`. Re-evaluate all prior findings against the current code state, and update with the re-evaluation table appended.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
