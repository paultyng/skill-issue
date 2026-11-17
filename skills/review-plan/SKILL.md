---
name: review-plan
description: Use when the user asks to review the plan, sanity-check the plan, vet the plan, evaluate the plan, "is this plan ready", feasibility check on a plan, "review-plan PATH", or when another skill (like implement-plan) requests pre-flight plan evaluation before execution. Do NOT use when no plan file is in scope (the user is likely asking for a summary — use Read instead), nor when the user is asking about source code (use review-code), nor when the user wants documentation review (use review-documentation).
---

# Plan Review

Decide whether a competent implementer could execute this plan to the intended behavior without inventing architecture, and whether the plan's verification would catch it if they failed. Produce a verdict (`READY` / `NEEDS_REVISION` / `BLOCKED`) with findings that cite plan lines. Used standalone and as the pre-execution gate in `implement-plan`.

The plan is the artifact under review. The codebase is read-only context for checking the plan's claims. Do not edit the plan; surface findings and let the author revise.

## The two questions

**Executable without invention.** Every decision the implementer needs is either made in the plan, resolvable from a cited project convention, or explicitly delegated ("implementer's choice between A and B"). Words like "appropriate", "reasonable", "standard", "the existing pattern" with no referent are decisions in disguise. Files and symbols the plan edits exist, or an earlier task creates them. Dependencies and infrastructure the plan uses are present, or an earlier task adds them. Assumptions about the code ("the handler is stateless") hold when you check.

**Verification that can fail.** A task's verification is a probe with an expected result: a test command and its pass, a command and its output, a grep and its match, a manual check with what you see. "Section present", "file exists", "review the code", and "run the program" pass for broken work and count as missing. Verification cannot rely on something a later task builds. A task that adds a test is self-verifying.

Everything else (ordering, scope, blast radius, sizing, improvements) serves those two questions. The categories in [reference.md](reference.md) say what a defect looks like in each.

## What a finding is

A finding names a specific defect at a specific plan line, says what goes wrong for the implementer if it stands, and gives the smallest edit that fixes it. "Task 5 is vague" is an opinion. "Task 5 says `use the standard cache`; the repo imports both `bigcache` and `ristretto` (`go.mod:14,22`); name one" is a finding.

Evidence is what you checked, not what you read. When a finding depends on a claim about the codebase (a file is missing, a symbol has a different signature, two conventions compete), you MUST have confirmed it with a read or grep and cite the location. Per `probe-not-assume`.

Priorities: `P0` blocks execution, `P1` will mislead the implementer, `P2` makes completion unverifiable or scope unclear, `P3` is an improvement. Categories: `feasibility`, `gap`, `open-question`, `ordering`, `verification`, `scope`, `shape`, `risk`, `improvement`.

## Verdict

The verdict is a gate, not a vote. `READY` means executable, not good; improvements stay `P3` and never block.

- **`BLOCKED`**: the plan cannot be executed as written. The file does not resolve or is empty; tasks are not `- [ ]` checkboxes (the executor cannot track progress); a task edits something that does not exist and nothing earlier creates it; a task needs a decision the user has not made (architecture, library, naming, API shape); a destructive step (drop, force-push, delete data, prod touch) has no explicit user-confirmation gate. The caller halts even if the user wants to proceed.
- **`NEEDS_REVISION`**: executable, but the implementer would guess or could not prove completion. Open questions that are answerable but unanswered; a task listed before one it depends on; verification missing or unfalsifiable on a meaningful share of tasks (roughly a third); tasks that do not name their files; no stated end-state; a boundary-crossing plan with no Behavior delta, or delta entries without observable `Acceptance:` criteria; tasks too coarse to recover from (over about 30 minutes of work).
- **`READY`**: otherwise.

Severity follows consequence, not count. One decision the plan leaves to the implementer is `BLOCKED`; five nits are `READY`.

### Sections the executor relies on

`implement-plan` reads two optional plan sections verbatim. When present, they MUST be well-formed:

- `## Behavior delta`: entries tagged `ADDED` / `MODIFIED` / `REMOVED`; every `ADDED` and `MODIFIED` entry has at least one observable `Acceptance:` criterion. Acceptance proves the behavior; task verification proves the mechanism ran. `MODIFIED` / `REMOVED` entries are compatibility signals: trace who depends on the old behavior, and recommend `review-api-compat` when a contract boundary (proto, public API, wire format) moves. Format and example in [reference.md](reference.md#behavior-delta).
- `## Branch policy`: `Base:` / `Chain:` / `Branch:` refs that resolve. A chain base that does not exist is `P0 / feasibility`.

A boundary-crossing plan (public API or user-visible behavior) with no Behavior delta is `NEEDS_REVISION`; an internal-only plan without one is `P3`.

## Known misses

Plans that looked fine and were not. One line each; check for these explicitly.

- The decision is hidden in an adjective: "appropriate error handling", "a reasonable timeout", "a good name".
- "Follow the existing pattern" where two patterns coexist; the plan must cite which.
- Verification that asserts presence, not behavior. It passes for any content.
- A task's verification depends on a later task's output.
- Schema and the code that reads it change in one task on a shared database; the plan needs expand, backfill, switch, contract.
- Temporary scaffolding (flags, shims) added with no removal task or tracking reference.
- The narrative mentions work no task does ("we'll also update the dashboard"), or a task does work the narrative never mentions.
- A task changes behavior that no Behavior delta entry declares.
- A migration with no rollback note.
- Destructive or shared-resource steps (prod data, org-wide modules, CI others depend on, secrets) buried mid-plan with no pause. Flag `P0 / risk` even on a `READY` plan so the executor pauses at the right moment.

## Inputs

Resolve the plan in this order: the path given in the invocation; `./.plans/PLAN.md`; the newest `./.plans/*.md`; legacy `./PLAN.md`, then the newest `./docs/plans/*.md` (warn once: `Plan resolved from legacy path <X>; consider moving under .plans/`). A `Plans live in <path>` directive in the project `CLAUDE.md` or `CLAUDE.local.md` replaces `.plans/` as the discovery directory. If nothing resolves, ask for a path. Do not guess.

Read the plan fully and any document it cites (`REVIEW.md`, `CLAUDE.md`, design docs). Read code only to check what the plan claims: that named files and symbols exist, that stated assumptions hold, that a cited convention is the only one. Do not survey the codebase.

## Output

Write the report to `${REVIEW_DIR}/PLAN-REVIEW.md` and present it. Resolve the directory as sibling reviews do (`.reviews/` is a working artifact, gitignored on first use):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

The report MUST satisfy these invariants, in order:

1. Run metadata header (below).
2. First line after the H1: `**Verdict:** READY | NEEDS_REVISION | BLOCKED`, exactly one of those three tokens.
3. One sentence of rationale naming the finding(s) that set the verdict.
4. Findings table with columns `Priority | Category | Finding | Recommendation | Plan line`. Every row cites a plan line (`PLAN.md:42`). When a `pr_url` is supplied, wrap the reference with `~/.claude/scripts/pr-deeplink.sh "$pr_url" <plan-path> <line>`.
5. Recommended action: for `NEEDS_REVISION`, the minimal edits that flip it to `READY`; for `BLOCKED`, the decisions the user must record before re-review; for `READY`, nothing or the `P3` list.

When another skill invokes this one, the verdict line is the first line of the reply so the caller can branch without parsing the body. The caller treats it as authoritative: `READY` proceeds, `NEEDS_REVISION` asks the user whether to revise or proceed, `BLOCKED` halts. The caller MUST NOT edit the plan to change the verdict; revision is a human step, after which the plan is re-reviewed.

### Run metadata header

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "-")
GIT_COMMIT_FULL=$(git rev-parse HEAD 2>/dev/null || echo "-")
GIT_SUBJECT=$(git log -1 --pretty=%s 2>/dev/null || echo "-")
PLAN_PATH=<resolved plan file path>
```

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Plan:** {PLAN_PATH}
```

The skill runs outside a git repo; the fallbacks above cover it.

### Example

```markdown
**Verdict:** NEEDS_REVISION

Two tasks have no falsifiable verification and Task 4 reads a file Task 6 creates.

| Priority | Category | Finding | Recommendation | Plan line |
|---|---|---|---|---|
| P1 | ordering | Task 4 edits `internal/auth/jwt.go`; Task 6 creates it | Move Task 6 before Task 4 | PLAN.md:42 |
| P1 | open-question | Task 5 says "use the standard cache"; repo imports `bigcache` and `ristretto` (`go.mod:14,22`) | Name one, or mark implementer's choice | PLAN.md:58 |
| P2 | verification | Task 7 verifies by "checking the handler reads correctly" | `task test ./internal/queue/... → PASS` | PLAN.md:71 |

## To move to READY

1. Reorder Tasks 4 and 6.
2. Pick a cache in Task 5 (`ristretto` matches `internal/session/`).
3. Replace Task 7 verification with the test command above.
```

## Boundaries

- Not part of `review-all`. Plan review happens at plan time; code review at code time.
- Not a style review. Structure is judged only where it affects executability or verifiability.
- Requirement levels inside a plan SHOULD use RFC 2119 key words so mandatory and optional steps read differently (`normative-language`); their absence is `P3`, not a defect.
