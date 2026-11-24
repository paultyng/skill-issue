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
- **Resolve the base once.** For diff scope, record `BASE_REF` and `BASE_COMMIT=$(git rev-parse "$BASE_REF")` here and pass both to every subagent. A subagent MUST NOT recompute the base; two reviewers on different bases review different diffs.
- **Empty diff stops the run.** If diff scope resolves to no changed files, report "No changes to review" and stop.
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
  - `has_manifest`: any dependency manifest (`go.mod`, `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, `Gemfile`, `mix.exs`, `composer.json`)
  - `has_authoring`: any agent-authoring file: `SKILL.md`, `.claude/agents/**`, `agents/*.md`, `.claude/rules/**`, `rules/*.md`, `.claude/commands/**`, `commands/*.md`, `.claude/settings*.json`, `hooks.json`, `.mcp.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `AGENTS.md`, `CLAUDE.md` (any depth)
  - `has_ui`: any `.tsx`, `.jsx`, `.vue`, `.svelte`, `.astro`, `.html`, `.hbs`, `.ejs`, `.pug`, `.erb`, `.njk`, `.css`, `.scss`, `.sass`, `.less`
  - `has_changes`: true when scope is "changed files (PR or branch)", or when scope is "explicit paths" and those paths have a diff against the base ref (run `git diff --name-only --diff-filter=d <base>...HEAD -- <paths>` to check; default base is `main`). False for full-codebase reviews with no diff baseline.
- **Detect opt-in flags** from the user's request phrasing:
  - `include_performance`: true when the user explicitly asks for performance, perf, benchmark, profiling, pprof, hot-path, or latency review alongside the comprehensive request. Default false. Never auto-enable from file types.
  - `include_deep_security`: true when the user explicitly asks for a deep / thorough security review, "CodeQL", "capability audit", "supply-chain audit", or otherwise signals willingness to pay the multi-minute cost of CodeQL database builds and capslock VTA. Default false. Standard `review-security` still runs without this flag; the flag only enables the deep static-analysis tier. Never auto-enable from file types.
- **Determine which review types are applicable** using the flags above:
  - **review-security**: applicable if `has_code` or `has_infra`
  - **review-reliability**: applicable if `has_code` or `has_iac`
  - **review-code**: applicable if `has_code` or `has_proto`
  - **review-database**: applicable if `has_sql`, or database-interacting code exists (check imports for DB drivers like `pgx`, `pq`, `database/sql`, `sqlx`, `diesel`, `sqlalchemy`, etc.)
  - **review-coverage**: applicable if `has_go` and `has_changes`
  - **review-documentation**: always applicable
  - **review-infrastructure**: applicable if `has_iac`
  - **review-ci**: applicable if `has_ci`
  - **review-observability**: applicable if `has_code` (observability gaps are code-level; configs alone aren't enough)
  - **invariant-adversary**: applicable if `has_code`. Not a separate skill — an in-line reviewer defined in [reference-invariant-adversary.md](reference-invariant-adversary.md).
  - **review-api-compat**: applicable if `has_api_specs` AND `has_changes` (it's a diff-aware review; no diff baseline = nothing to compare)
  - **review-authoring**: applicable if `has_authoring`
  - **review-accessibility**: applicable if `has_ui`
  - **Repo lenses**: one per REVIEW.md `## Lens:` whose globs match a changed file (step 1b)
  - **review-performance**: applicable ONLY if `include_performance` is true. Never auto-launched.
  - **evaluate-dependency**: applicable if `has_manifest` AND `has_changes`. Diff the manifest to find added or version-bumped dependencies (`git diff <base>...HEAD -- <manifest>`); run it in **review mode** once per added/bumped dependency. Skip when the only manifest change is a removal or a checksum-only lockfile churn.

### 1a. Detect conformance mode

If the user's request includes phrases like "full conformance", "pattern discovery", "check patterns", or "discover patterns", set `conformance_mode` to `full`. Otherwise default to `lightweight`. This flag is passed to review-code in step 3.

### 1b. Load REVIEW.md (if present)

Check for a `REVIEW.md` file at the repository root. If it exists, read it and extract:
- **Always check** rules: these become mandatory check items passed to all subagents (flagged at HIGH severity)
- **Skip** rules: filter these paths/patterns out of scope before passing to subagents (apply alongside the file-type classification above)
- **Domain-specific sections** (Security, Reliability, Database, Protobuf & API, Go conventions, Documentation): route each section to the corresponding review subagent as additional context
- **Lens sections** (`## Lens: <id>` with `Paths:` globs and criteria): parse and validate per [reference-lenses.md](reference-lenses.md). Reject an id that names a built-in domain, and report a glob that matches no tracked file, both under **Not checked**.

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

Resolve related open PRs, issues, and tickets per [reference-open-work.md](reference-open-work.md). It defines the keyword filter, the lookups, and the rendered `Open work context` block.

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

**Print the dispatch table first**: one row per domain, marked `flag` (selected by a step 1 flag) or `model-added` (no flag selected it, and you add it with a stated reason, e.g. a deleted auth file whose content no flag can scan), with the files that triggered it. You MAY add domains; you MUST NOT drop a flag-selected one.

Launch every applicable light review in one message using the Task tool; the harness limits overall concurrency. **Heavy reviews** build or run the project: `review-coverage` (test suite with coverage), `review-performance` (benchmarks, pprof), and `review-security` when `include_deep_security` is set (CodeQL database build, capslock). Run at most 2 heavy reviews at a time and queue the rest, logging `heavy: start <name>` and `heavy: done <name>`. Each subagent is `subagent_type="generalPurpose"`, `model: sonnet` (per `subagent-model-routing` — structured analysis with code-level findings).

For each subagent, include in its prompt:
- The finding contract from [reference-tracking.md § Finding header](reference-tracking.md#finding-header): one `FINDING |` header per finding, and one `COVERAGE | file=<path> | status=<read-fully|skimmed|not-read>` row per in-scope file after the findings. Read each cited line before raising a finding; drop what you cannot verify. Paste the fixed `rule_id` list.
- `BASE_REF` and `BASE_COMMIT` from step 1, with the instruction that the subagent MUST NOT recompute the base
- The system overview and flow mapping from step 2
- The resolved file list and package paths from step 1 (the subagent should use this scope directly and skip its own scope confirmation)
- The `has_changes` flag, base ref, and changed file list from step 1 (so change-aware subagents like review-code's Regression History can use them)
- The `pr_url` from step 1 (used to wrap `path:line` finding references via `~/.claude/scripts/pr-deeplink.sh`; empty string disables wrapping)
- The `conformance_mode` flag from step 1a (for review-code only)
- The `include_deep_security` flag from step 1 (for review-security only)
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

**Exception — the `Invariant adversary` subagent.** It receives only the resolved file list, the base ref, and the diff. Withhold the system overview, the PR title and body, `REVIEW.md` sections, the `Open work context` block, and every other subagent's findings. Those are narratives of what the change is meant to do; a reviewer handed one checks the code against it and inherits its blind spots. Launch it with `model: fable` per `subagent-model-routing` (adversarial enumeration where a miss is costly; a model different from the parent also weakens self-agreement). Its full prompt body and output template are in [reference-invariant-adversary.md](reference-invariant-adversary.md).

**Exception — the `Trajectory` subagent.** Launch it with `model: fable` per `subagent-model-routing` (a tipping-point call with no rubric). Its findings concern the whole repository, not the resolved file list. Pass the base ref and the diff, and state that it reads members the diff never touches. A third entrypoint is invisible to a reviewer scoped to changed files. Its output is advisory and MUST NOT request a change to the diff.

**Review subagents to launch:**

| Subagent | Skill | Condition |
|----------|-------|-----------|
| Security | review-security | `has_code` or `has_infra` (pass `include_deep_security` to enable CodeQL + capslock VTA) |
| Reliability | review-reliability | `has_code` or `has_iac` |
| Code | review-code | `has_code` or `has_proto` |
| Database | review-database | `has_sql` or DB code in scope |
| Coverage | review-coverage | `has_go` and `has_changes` |
| Documentation | review-documentation | Always |
| Infrastructure | review-infrastructure | `has_iac` |
| CI | review-ci | `has_ci` |
| Observability | review-observability | `has_code` |
| Invariant adversary | [reference-invariant-adversary.md](reference-invariant-adversary.md) | `has_code` — `model: fable`, starved inputs (see above) |
| Trajectory | review-trajectory | `has_code` and `has_changes` — `model: fable`, anti-scoped (see above) |
| API compatibility | review-api-compat | `has_api_specs` and `has_changes` |
| Authoring | review-authoring | `has_authoring` |
| Accessibility | review-accessibility | `has_ui` |
| Lens `<id>` | [reference-lenses.md](reference-lenses.md) | a REVIEW.md lens whose globs match a changed file — one generic subagent per lens, scoped to the matched files |
| Performance | review-performance | `include_performance` is true (opt-in only) |
| Dependency eval | evaluate-dependency | `has_manifest` and `has_changes` — one review-mode run per added/bumped dependency |

Each subagent should NOT write its own output file; it returns findings to this orchestrator. (`evaluate-dependency` is launched once per added/bumped dependency; each returns a GO/CAUTION/NO-GO row.)

### 4. Merge, then summarize

**Pre-merge (orchestrator, before the summarizer):**

1. Parse every `FINDING` and `COVERAGE` line. A reviewer that returned none goes under **Not checked** with its name.
2. **Merge by `dkey`.** Findings with the same `dkey`, or the same path and `rule_id` within ±3 lines, are one finding: keep the highest `sev`, OR the `blocking` flags, union the domains.
3. **Demote** each `conf=low` finding with `blocking=y` to `blocking=n`, tagged "(low-confidence)".
4. **Coverage gaps** = in-scope files no reviewer marked `read-fully`.

Hand the merged set, the coverage gaps, and the raw reviewer output to the summarizer. Its semantic dedupe below still runs as a fallback for findings whose `rule_id` differs.

After all review subagents complete, launch a single summarization subagent (`subagent_type="generalPurpose"`, `model: opus` per `subagent-model-routing` — cross-cutting dedup and prioritization across all review domains) with the full findings from each review subagent. Pass `pr_url` so it can preserve and apply the [Finding link wrapping](#finding-link-wrapping) convention when rewriting tables.

Prompt it to:
1. **Deduplicate** overlapping findings across all reviews. Common overlaps to watch for:
   - security ↔ reliability (e.g. unbounded result sets)
   - security ↔ infrastructure (e.g. inline secrets in TF / k8s)
   - security ↔ ci (e.g. PR-target script injection)
   - security ↔ dependency-eval (e.g. a new dep's vuln history overlaps `govulncheck` output)
   - reliability ↔ observability (e.g. missing error spans on hot paths)
   - reliability ↔ infrastructure (e.g. k8s probes vs. shutdown contract — `review-infrastructure` covers probe presence, `review-reliability` covers shutdown semantics)
   - code ↔ api-compat (e.g. a proto change flagged for design AND for wire compat)
   - invariant-adversary ↔ code / reliability / database (it reaches the same defect from the invariant side; keep its evidence, which cites dependency source, and drop the weaker duplicate)
2. **Cross-reference** each deduplicated finding to its source review and IDs.
3. **Compute unified tracking** for each deduplicated finding. Populate `tracking: {status, sources, possibly_overlaps}` per [reference-tracking.md](reference-tracking.md). Combines in-repo signals (TODO / FIXME etc., always evaluated) with open-work signals (tier-1 path mention / tier-2 symbol mention / tier-3 keyword match against the step-1d set). Tier-1 and tier-2 promote to `tracked`; tier-3 stays `untracked` with a `possibly_overlaps` annotation. Terminal-state items (closed / merged PRs, closed issues, `statusCategory = Done` Jira) never produce a source entry.
4. **Prioritize and lay out** per [reference-tracking.md § Findings layout in SUMMARY.md](reference-tracking.md#findings-layout-in-summarymd): two flat tables (untracked above the fold; tracked collapsed in a `<details>` block), severity desc then category alpha, `tracking` rendered inline per [reference-tracking.md § Badge rendering](reference-tracking.md#badge-rendering).
5. **Recommend fix order**, considering dependencies between findings and effort estimates. Tracked findings (tier-1 or tier-2 source) may be deprioritized when the source indicates an active plan. A `possibly_overlaps` annotation (tier-3 only) does not affect ordering.
6. **Tool Availability summary**. Consolidate from all reviews into a summary listing which automated tools ran successfully, which were skipped, and why.
7. **Not checked**: every failed tool, missing input, skipped or failed domain, and reviewer that returned no coverage rows. Never present these as a pass.
8. **Headline**, verbatim shape: `**<B> blocking · <N> non-blocking · <G> coverage gaps** — If you change only one thing: <finding and one-line fix>`.

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
2. Headline (step 4 item 8), including "If you change only one thing"
3. Tool availability summary
4. `## Coverage gaps`: in-scope files no reviewer read fully, or "None"
5. `## Not checked` (step 4 item 7), or "None"
6. System overview (from step 2)
7. Open work context (from step 1d; omit this section entirely if the block was empty)
8. **Findings — untracked** (one flat table; see [reference-tracking.md § Findings layout in SUMMARY.md](reference-tracking.md#findings-layout-in-summarymd))
9. **Findings — tracked** (collapsed `<details>` block, one flat table; omit when empty)
10. Recommended fix order (untracked first; tracked items only if they're high-severity blockers despite an owner)
11. **Trajectory** (advisory; from the Trajectory subagent. Omit when no axis tips. Never merged into the findings tables — it reports no defects.)

Render both findings sections per [reference-tracking.md § Findings layout in SUMMARY.md](reference-tracking.md#findings-layout-in-summarymd) — flat tables (categories are a column, not a header), severity desc then category alpha, empty-group rules defined there. Per-domain templates in [reference-output.md](reference-output.md) describe what each subagent emits; the summarization subagent compresses them into the unified shape. Present the report to the user.

---

## Run metadata header

The metadata-capture snippet and header template live in [reference-metadata.md](reference-metadata.md). Capture once near `REVIEW_DIR` resolution and prepend to every output document this skill writes (subagents that write their own files do the same).

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

The `Tracked` column in those tables renders the badge defined in [reference-tracking.md § Badge rendering](reference-tracking.md#badge-rendering).

---

## Output Templates

Per-domain templates each review subagent emits: [reference-output.md](reference-output.md).

---

## Guidelines

- Search the organization's codebase (Sourcegraph, GitHub) for existing patterns before recommending new dependencies or approaches.
- Cross-reference findings between reviews to avoid duplicate entries in the consolidated tables.
- Include effort estimates to help prioritize implementation.
- When the user asks for a follow-up review, find the most recent review directory containing `SUMMARY.md`. Primary lookup: `ls -d .reviews/*/ 2>/dev/null | sort | tail -1`. Legacy fallback if empty: `ls -d reviews/*/ 2>/dev/null | sort | tail -1`. Re-evaluate all prior findings against the current code state, and update with the [re-evaluation table](reference-output.md#re-evaluation-table-for-follow-up-reviews) appended.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
