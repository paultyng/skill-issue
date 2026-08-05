---
name: review-plan
description: Use when the user asks to review the plan, sanity-check the plan, vet the plan, evaluate the plan, "is this plan ready", feasibility check on a plan, "review-plan PATH", or when another skill (like implement-plan) requests pre-flight plan evaluation before execution. Do NOT use when no plan file is in scope (the user is likely asking for a summary — use Read instead), nor when the user is asking about source code (use review-code), nor when the user wants documentation review (use review-documentation).
---

# Plan Review

Pre-flight review of an implementation plan markdown file. Produces a verdict (`READY` / `NEEDS_REVISION` / `BLOCKED`) and a prioritized findings table. Used standalone and as a pre-execution gate by `implement-plan`.

This is a **document** review, not a code review. No static analyzers. No diff scoping. The plan is treated as the artifact under test; the codebase is read-only context for feasibility checks.

## Workflow

### 1. Resolve the plan file

Priority order:
1. Explicit path from the invocation (e.g. `/review-plan .plans/auth-rewrite.md`).
2. `./.plans/PLAN.md` in the current working directory.
3. Latest by mtime in `./.plans/*.md` (typically `YYYY-MM-DD-<feature>.md` per convention).
4. **Legacy fallback** (one-release transition): `./PLAN.md`, then latest by mtime in `./docs/plans/*.md`. If either resolves, warn once: `Plan resolved from legacy path <X>; consider moving under .plans/`.

If none resolve, stop and ask the user for a path. Do not guess.

**CLAUDE.md override**: if the project `CLAUDE.md` (or `CLAUDE.local.md`) contains a `Plans live in <path>` directive, use `<path>` as the primary discovery dir instead of `.plans/`.

### 2. Load context

- Read the resolved plan file fully.
- Read any docs the plan references inline (`./REVIEW.md`, `./CLAUDE.md`, design docs cited).
- For each file path mentioned in the plan, confirm the file exists (or is named as new in the plan). Missing files referenced as "edit" targets are a feasibility issue.
- If the plan references prior work in commits or PRs, capture branch + base ref for the run metadata header.

Do **not** read the entire codebase. Read only what the plan references plus enough to verify the named files exist.

### 3. Apply the plan-shape contract

The plan must satisfy these structural rules. Any violation contributes to `NEEDS_REVISION` or `BLOCKED` per the verdict rules.

Where a task states a requirement level, it SHOULD use RFC 2119 key words (`MUST` / `SHOULD` / `MAY`) so mandatory and optional steps are unambiguous (see the `normative-language` rule).

| Rule | Severity if violated |
|---|---|
| Tasks are `- [ ]` checkboxes | BLOCKED — no machine-readable progress |
| Each task names the files it touches | NEEDS_REVISION — implementer guesses scope |
| Each task includes a **probable** verification step (greppable string, command with expected output, or file-content assertion — NOT "section X present" / "file exists") | NEEDS_REVISION — completion is unverifiable |
| Tasks are sized 2-5 min (small) to ~30 min (max) | NEEDS_REVISION — too coarse to track or recover from failure |
| Plan has a stated end-state (one paragraph or "Definition of Done") | NEEDS_REVISION — no exit criterion |
| Plan has a "Constraints" or "Out of scope" section (or equivalent) | LOW — preferred but not required |
| Plan has a **Behavior delta** section (see [reference.md](reference.md#behavior-delta)) when it crosses an API / user-visible boundary | NEEDS_REVISION on a boundary-crossing plan; LOW on a small internal-only plan |
| Each behavior-delta entry is tagged `ADDED` / `MODIFIED` / `REMOVED` | NEEDS_REVISION — untagged deltas aren't reviewable as compat signals |
| Each `ADDED` / `MODIFIED` entry carries ≥1 observable `Acceptance:` criterion | NEEDS_REVISION — behavior change is unverifiable |

### 4. Apply the content checklist

Review the plan against the checklist in [reference.md](reference.md):
- Feasibility
- Completeness / gap
- Behavior delta
- Open questions
- Ordering
- Verification
- Scope creep
- Risk / blast radius
- Improvements

When a Behavior delta is present, treat `MODIFIED` / `REMOVED` entries as compatibility signals: fold them into the Scope-creep and Risk / blast-radius checks, and recommend a `review-api-compat` pass when they touch a contract boundary (proto, public API, wire format).

For each finding, cite the plan line (e.g. `PLAN.md:42`). When `pr_url` is provided (a plan being reviewed inside a PR), wrap line references via `~/.claude/scripts/pr-deeplink.sh "$pr_url" <plan-path> <line>` — same convention as siblings.

### 5. Compute the verdict

Apply in order; first match wins:

1. **BLOCKED** if any of:
   - Plan does not resolve / is empty.
   - Plan-shape contract: missing checkboxes (no `- [ ]` lines).
   - A task references a file that doesn't exist and isn't created earlier in the plan.
   - A task requires a decision the user has not made and the plan does not record (architecture choice, library choice, naming convention). The plan can't be executed without inventing.
   - A task is destructive and lacks explicit user-confirmation gating (e.g. "drop table", "delete prod data", "force push").
2. **NEEDS_REVISION** if any of:
   - Two or more plan-shape contract NEEDS_REVISION rules violated.
   - High-priority open questions that are answerable but not yet answered.
   - Ordering bug: Task B depends on Task A but listed before A.
   - Verification missing on more than ~30% of tasks.
3. **READY** otherwise. Minor improvements may still be present; they are non-blocking.

### 6. Present results

Resolve the review output directory (same pattern as sibling reviews). `.reviews/` is gitignored on first use; review outputs are working artifacts, not source:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header)) and prepend to `${REVIEW_DIR}/PLAN-REVIEW.md`.

Output structure:
1. Run metadata header
2. **Verdict line** (first line after the H1): `**Verdict:** READY | NEEDS_REVISION | BLOCKED`
3. One-sentence rationale for the verdict
4. Findings table
5. Recommended action: if `NEEDS_REVISION`, the minimal set of edits to the plan that would flip it to `READY`; if `BLOCKED`, the decision(s) the user must make before re-review.

Present the report. When invoked by `implement-plan`, return the verdict as the first machine-parseable line and stop.

---

## Invocation by other skills

When `implement-plan` (or any other skill) invokes `review-plan` as a gate:

- The plan path is supplied as an explicit argument.
- The caller treats the returned verdict as authoritative:
  - `READY` → proceed.
  - `NEEDS_REVISION` → surface findings to the user, ask whether to revise or proceed anyway.
  - `BLOCKED` → halt; surface findings; do not proceed even with user override (the plan literally cannot run).
- The caller must not implementation-edit the plan to flip the verdict; revisions are a separate human step.

---

## Run metadata header

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "—")
GIT_COMMIT_FULL=$(git rev-parse HEAD 2>/dev/null || echo "—")
GIT_SUBJECT=$(git log -1 --pretty=%s 2>/dev/null || echo "—")
PLAN_PATH=<resolved plan file path>
```

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Plan:** {PLAN_PATH}
```

Note: this skill runs fine outside a git repo. Fall back gracefully when git commands fail.

---

## Output Templates

### Verdict block (always first, after H1)

```markdown
**Verdict:** READY

Plan is structurally sound, all tasks have verification, no open questions. Minor improvements noted below.
```

```markdown
**Verdict:** NEEDS_REVISION

Two tasks missing verification; one ordering bug (Task 4 references a file Task 6 creates). Plan recoverable with ~5 edits.
```

```markdown
**Verdict:** BLOCKED

Task 2 requires choosing between Redis and Memcached; the plan does not record this decision. Cannot proceed without user input.
```

### Findings table

```markdown
| Priority | Category | Finding | Recommendation | Plan line |
|----------|----------|---------|----------------|-----------|
| P0 | feasibility | Task 3 edits `internal/auth/jwt.go` but file does not exist and is not created earlier | Create the file in a preceding task or confirm path | PLAN.md:42 |
| P1 | open-question | Task 5 says "use the standard cache" — repo has both `bigcache` and `ristretto` in use | Specify which; or escalate to user | PLAN.md:58 |
| P2 | verification | Task 7 has no verification step | Add `task test ./internal/queue/...` with expected pass | PLAN.md:71 |
| P3 | improvement | Tasks 2-4 are independent of Tasks 5-8; could split into two PRs | nit: only worth doing if PRs are getting large | PLAN.md:30-72 |
```

**Priority column values:** `P0` (blocker), `P1` (high), `P2` (medium), `P3` (low / nit).

**Category column values:** `feasibility`, `gap`, `open-question`, `ordering`, `verification`, `scope`, `shape`, `risk`, `improvement`.

**Plan line column:** Line reference into the reviewed plan file. When `pr_url` is set, wrap the reference via `~/.claude/scripts/pr-deeplink.sh "$pr_url" <plan-path> <line>`.

### Recommended action

```markdown
## To move to READY

1. Add a "depends on Task 3" annotation to Task 5 OR reorder so Task 5 precedes Task 3.
2. Add verification step to Task 7: `task test ./internal/queue/... → PASS`.
3. Pick a cache library in Task 5 (recommend `ristretto` per existing usage in `internal/...`).
```

```markdown
## To unblock

The plan needs the following decisions before re-review:
1. **Cache library**: Redis or Memcached for Task 2?
2. **API versioning**: bump to `v2` or add additive field in `v1`?

Once decided, edit the plan to record the choice and request `review-plan` again.
```

---

## Guidelines

- The verdict is a gate, not a vote. Apply the rules; don't hedge to be polite.
- A `READY` plan is not a *good* plan, only an *executable* one. Improvements stay as P3 findings and don't block.
- Do not edit the plan during review. Surface findings; let the user (or plan-author) revise.
- When `implement-plan` invokes this skill, return the verdict first so the caller can branch without parsing the whole report.
- For detailed checklist categories, see [reference.md](reference.md).
- This skill is **not** included in `review-all`. Plan review is plan-time; code review is code-time. Different lifecycle, different invocation.
- Verification steps in tasks must be probable (run/grep/output), not presence-checks ("section X present" passes for anything). Per `~/.claude/rules/probe-not-assume.md`.
