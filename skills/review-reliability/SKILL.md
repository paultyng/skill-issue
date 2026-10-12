---
name: review-reliability
description: Perform a reliability review covering graceful shutdown, gRPC production patterns, stability patterns (timeouts, circuit breakers, bulkheads), and stability anti-patterns. Use when the user asks for a reliability review, production readiness assessment, stability analysis, or graceful shutdown audit.
---

# Reliability Review

A reliability review that produces prioritized findings with code-level references.

## Workflow

### 1. Scope and explore

- Confirm the scope with the user: full codebase, named packages or directories, changed files only (PR or branch diff), or one named concern.
- **Resolve the scope to a file and package list:**
  - **Changed files (PR or branch):** run `git diff --name-only --diff-filter=d <base>...HEAD`. The default `<base>` is `main`. If the user names a PR number, run `gh pr diff <number> --name-only` instead. Keep `.go` files, config files, and Kubernetes manifests. Derive the affected Go packages from the file paths, which are the unique parent directories that contain `.go` files.
  - **Explicit paths or packages:** the user can name directories (`internal/auth/`), Go package patterns (`./internal/auth/...`), or single files. For a directory or a package pattern, include every file under it.
  - **Full codebase:** no filter. Explore everything. This is the default.
- **Pass the resolved scope** (the file list) to every exploration and investigation subagent, so that findings stay scoped to those files. Reading is **not** scoped. Follow callees, callers, and third-party source wherever a finding depends on their behavior. Report a bug in code the scope touches or calls even when the bug predates the diff, and prefix it `pre-existing:`.
- Explore the scoped code with parallel subagents (`subagent_type="explore"`). Read the source files, configs, Kubernetes manifests, and deployment definitions.

### 2. System overview

Produce a short architecture summary of:
- Services, ports, and transport (gRPC, HTTP)
- Data stores and external dependencies
- Deployment model, if you can determine it

Map the critical hot paths:

```
Client → Transport
  → step 1 (local / I/O annotation)
  → step 2 (DB round-trip #1)
  → step 3 (external call, round-trip #2)
  → response
```

Annotate each step: local or I/O, serial or parallel, cached or uncached.

### 3. Launch investigation subagent

Launch one investigation subagent (`subagent_type="generalPurpose"`, `model: sonnet` per `subagent-model-routing`) with the system overview, the flow mapping, and the in-scope file list.

Prompt it to:
- Check the code against every reliability category: graceful shutdown contract, gRPC production patterns, stability patterns, resource and context ownership, and stability anti-patterns. See [reference.md](reference.md).
- **Timeout budget**: for each route in scope, tabulate the outer deadline, every nested timeout, and the retry counts. Check that the sum fits. Report the table even when the budget balances. See Timeouts in [reference.md](reference.md).
- **Resource ownership**: for each resource acquired on a request path, name the owner of its lifetime after the caller's context is cancelled. Read the dependency's source to answer this, and cite `path:line`. Do not infer the answer from the library's public signature. See Resource and Context Ownership in [reference.md](reference.md).
- **Goroutine leak test coverage**: search the test files for `goleak.VerifyNone` and `goleak.VerifyTestMain`. Search the source files for `go func` and for the `go ` keyword. Report a package that spawns goroutines and has no goleak check in its tests. See Steady State in [reference.md](reference.md).
- For each finding, search nearby code and project documentation for existing tracking. Look in the README, doc comments, TODO/FIXME/HACK/XXX comments, and issue references.
- Return the findings in the **reliability findings** template.
- Give every finding a file path, a line number or function name, a priority (P0–Pn), an impact, an effort estimate, and a tracking status.

### 4. Present results

If the review-all orchestrator supplied `REVIEW_DIR`, skip this snippet. Otherwise resolve the review output directory:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Capture the run metadata. See [Run metadata header](#run-metadata-header) below.

Write `${REVIEW_DIR}/RELIABILITY-REVIEW.md` in this order:
1. Run metadata header
2. System overview and flow mapping
3. Reliability findings table
4. Recommended fix order

Present the report to the user.

---

## Run metadata header

Capture this once, near the point where you resolve `REVIEW_DIR`. Prepend the rendered block to the output document.

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
GIT_SUBJECT=$(git log -1 --pretty=%s)
# When scope is diff-based, also: BASE_REF=<base>; BASE_COMMIT=$(git rev-parse --short "$BASE_REF")
```

Header template. It goes at the top of the output `.md`, before the H1 title.

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Base:** {BASE_REF} @ {BASE_COMMIT}   <!-- omit when scope is not diff-based -->
> **Scope:** {scope description}
```

---

## Finding link wrapping (PR mode)

If the review is scoped to a GitHub PR, wrap every `path:line` reference in the finding tables as a Markdown link. The caller supplies `pr_url`. In a standalone run, read it with `gh pr view --json url -q .url 2>/dev/null`.

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>
# pr_url set   → [path:line](https://github.com/.../pull/N/files#diff-<hash>R<line>)
# pr_url empty → path:line   (plain text, unchanged)
```

The display text stays `path:line`, so a plain table and a linked table look identical. Only the URL goes in the link target.

- For a finding about removed code, pass `L` as the fourth argument. The default is `R`.
- For a file-level finding, omit `<line>` to get a file-anchor link.
- Wrap `path:line` references inside the Tracked column the same way, for example `TODO in foo.go:42`.
- Findings follow `terse-comments`: a concrete fix, an optional `bug:`/`risk:`/`nit:`/`unsure:` prefix, no praise, no restating of the diff.

---

## Output Templates

### Reliability findings

```markdown
| Priority | Finding | Impact | Effort | Tracked |
|----------|---------|--------|--------|---------|
| P0 | Description with code references | Impact on availability/latency | trivial / small / moderate / large | — |
| P1 | Description with code references | Impact description | Effort estimate | FIXME in file:line |
```

**Tracked column values:** use `—` for a new finding. For a finding that is already captured, use `TODO in file:line`, `FIXME in file:line`, `README`, or an issue reference such as `#123`.

### Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Brief explanation of the fix |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- Search the organization's codebase (Sourcegraph, GitHub) for existing patterns before you recommend a new approach.
- Give every finding an effort estimate, so the user can prioritize the work.
- For a follow-up review, find the most recent review directory that contains `RELIABILITY-REVIEW.md` with `ls -d reviews/*/ 2>/dev/null | sort | tail -1`. Check every prior finding against the current code. Append the re-evaluation table.
- For the detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: treat the rules in `REVIEW.md` as extra review criteria. The review-all orchestrator supplies this section. In a standalone run, read `REVIEW.md` from the repository root. "Always check" items are HIGH severity. Items in the Reliability section are MEDIUM severity. "Skip" patterns exclude matching files from the review scope.
- Every finding must cite probed evidence: `path:line`, grep output, or a command result. Pattern-matched suspicion is not evidence. Per `~/.claude/rules/probe-not-assume.md`.
