---
name: review-observability
description: Use when the user asks for an observability review, telemetry review, logging review, metrics review, tracing review, OpenTelemetry review, OTel review, Prometheus review, "are we observable", logging audit, structured logging audit, trace coverage check, span coverage check, metrics cardinality review, or production observability assessment.
---

# Observability Review

Structured review of logging, metrics, and tracing sufficiency. Producing actionable, prioritized findings with code-level references.

**Out of scope** (defer to siblings):
- Health/readiness probes, gRPC health, retry/timeout semantics → `review-reliability`
- Log injection, PII leakage, log-as-attack-channel → `review-security` (but flag obvious secret-in-log here as well)
- Dashboard / alert authoring (where to set thresholds) → typically out of scope; observability review covers signal *availability*, not alert tuning

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific packages/directories, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file/package list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD`. If the user references a PR number, use `gh pr diff <number> --name-only`. Filter to source files (`.go`, `.ts`, `.tsx`, `.js`, `.py`, etc.) and configs (`prometheus.yml`, `otel-collector-config.yaml`).
  - **Explicit paths/packages:** Include all files under given directories.
  - **Full codebase:** No filtering.
- **If invoked from review-all**: receive `file_list`, `package_paths`, `has_changes`, `base_ref`, `REVIEW_DIR`, and `pr_url` from the orchestrator. Skip your own scope confirmation.
- **Pass the resolved scope** to all exploration and investigation subagents.

### 2. System overview

Produce a brief telemetry summary covering:
- **Logging library/sink**: structured (`slog`, `zap`, `zerolog`, `logrus`) vs. unstructured (`fmt.Println`, `log.Printf`). Output sink (stdout, file, syslog, log aggregator).
- **Metrics library/exporter**: Prometheus client, OTel metrics, statsd. Where scraping happens.
- **Tracing library/exporter**: OTel tracer, vendor-specific (Datadog, Honeycomb, Jaeger). Sampling strategy.
- **Correlation**: are trace IDs threaded through logs (e.g. `slog.With("trace_id", ...)`)? Are span context propagated across RPC boundaries (`otelgrpc`, `otelhttp`)?
- **Collector / pipeline**: is there an OTel Collector in the path? What processors and exporters?

### 3. Launch investigation subagent

Launch a single investigation subagent (`subagent_type="generalPurpose"`, `model: sonnet` per `subagent-model-routing`) with the system overview and in-scope file list.

Prompt it to:
- Read all in-scope source files and any observability config files (Prometheus, OTel Collector, dashboard JSON).
- Apply the checklists in [reference.md](reference.md):
  - Logging sufficiency and structure
  - Metrics sufficiency and cardinality
  - Tracing sufficiency and propagation
  - Correlation across signals
- Identify gaps: RPC handlers without spans, error paths without log entries, hot loops emitting per-iteration metrics, unbounded label values.
- For each finding, search nearby code for existing tracking (TODO/FIXME/HACK).
- Return findings using the **observability findings** template.

### 4. Run static analyzers (when applicable)

Most observability gaps are not lint-discoverable; the work is semantic. A few mechanical checks:

```sh
# Go: find packages spawning goroutines/RPC handlers without otel instrumentation
# (these are heuristics for the subagent to triage, not gates)
grep -rl "http.HandleFunc\|grpc.NewServer" --include='*.go' <paths>
grep -rL "otelhttp\|otelgrpc\|otel\.Tracer" --include='*.go' <paths>

# Cardinality smell: dynamic strings in metric labels
grep -rn "\.With(prometheus\.Labels{" --include='*.go' <paths>
grep -rn "labels\.NewBuilder\|labels.FromMap" --include='*.go' <paths>
```

These are inputs for the subagent. False positives are expected.

### 5. Present results

Resolve the review output directory (same pattern as siblings):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR="reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR="reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header)) and prepend to `${REVIEW_DIR}/OBSERVABILITY-REVIEW.md`.

Output structure:
1. Run metadata header
2. Telemetry overview (from step 2)
3. Findings table (grouped by signal: logging / metrics / tracing / correlation)
4. Recommended fix order

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

The display text stays `path:line`. Pass `L` as the fourth argument for findings about removed code. Findings follow `terse-comments`: concrete fix, optional `bug:`/`risk:`/`nit:`/`unsure:` prefix.

---

## Output Templates

### Observability findings

```markdown
| Priority | Signal | Finding | Impact | Effort | Tracked |
|----------|--------|---------|--------|--------|---------|
| P0 | tracing | Description with code references | Impact on debuggability / MTTR | trivial / small / moderate / large | — |
| P1 | metrics | Description with code references | Cardinality / cost impact | Effort estimate | TODO in file:line |
```

**Signal column values:** `logging`, `metrics`, `tracing`, `correlation`.

### Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Brief explanation of the fix |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- Observability is about debuggability under failure. The bar is "could oncall figure out what broke at 3am from these signals alone?"
- Cardinality is cost. Flag high-cardinality labels (user IDs, request IDs, raw URLs) on Prometheus metrics; they're fine as log fields and span attributes.
- Search the organization's codebase for existing logger / tracer / metric patterns before recommending new ones.
- Include effort estimates.
- When the user asks for a follow-up review, find the most recent review directory and append a re-evaluation table.
- For detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (Observability section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
