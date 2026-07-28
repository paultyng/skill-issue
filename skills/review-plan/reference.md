# Plan Review: Framework Reference

Detailed checklists for plan evaluation. SKILL.md references this file.

Reference sources:
- [Karpathy: Software 3.0 / specs as scaffold](https://karpathy.bearblog.dev/sequoia-ascent-2026/) — "the unit of programming changed from typing lines of code to delegating larger macro actions"
- [Osmani: How to write a good spec for AI agents](https://addyo.substack.com/p/how-to-write-a-good-spec-for-ai-agents) — "a vague spec multiplies errors across the entire fleet"
- [obra/superpowers: writing-plans](https://github.com/obra/superpowers/blob/main/skills/writing-plans/SKILL.md) — plan-shape contract (used under MIT, copyright Jesse Vincent)

## Table of contents

- [Feasibility](#feasibility)
- [Completeness and gap](#completeness-and-gap)
- [Behavior delta](#behavior-delta)
- [Open questions](#open-questions)
- [Ordering](#ordering)
- [Verification](#verification)
- [Scope](#scope)
- [Risk and blast radius](#risk-and-blast-radius)
- [Improvements](#improvements)

## Feasibility

- **Named files exist** or are created in a preceding task. A task that edits `foo.go` requires `foo.go` to exist when the task runs. Missing-file references are `P0 / feasibility`.
- **Named symbols exist** when the task says "modify function X". If X doesn't exist (and the plan doesn't say "add X first"), it's a feasibility issue. Quick check: `grep` for the symbol.
- **Required dependencies are in scope**. If a task says "use library Y", Y must already be a project dependency or the plan must include an "add Y to go.mod" task earlier.
- **Required infrastructure exists or is being set up**. A task that "writes to the events queue" requires the queue to exist. If it doesn't, flag as gap.
- **Tasks don't cross unstated boundaries**: editing prod config, modifying shared org-wide modules, touching files outside the repo. These need explicit user confirmation, not silent inclusion.
- **The codebase actually supports the approach**. If the plan assumes "the existing handler is stateless" but it's not, the plan won't survive contact. Spot-check the assumption against the code.

## Completeness and gap

- **End-state is defined**. The plan answers "how do we know we're done?" in concrete terms, not "the feature works". Acceptable forms: "test X passes", "endpoint Y returns Z", "user can do W".
- **Task-to-task gaps are bridged**. If Task 3 produces output A and Task 4 consumes input B, the plan should make it explicit how A becomes B.
- **State transitions are explicit**. "Now the cache is populated" between two tasks is fine; "now everything works" is not.
- **Cleanup is planned**. Temporary feature flags, scaffolding, deprecation steps — if the plan adds something temporary, it should plan its removal or cite where the removal is tracked.
- **Migrations are paired with rollbacks**. A schema change task should have an explicit "rollback strategy" note (even if "drop new column").

## Behavior delta

An optional but recommended plan section stating *what changes about system behavior* before the *how* (tasks). Borrowed from spec-driven tools (OpenSpec); the format is ours — no `openspec/` tree, no CLI. It makes intent reviewable and gives the completeness/gap, scope, and risk checks something concrete to test against.

Format:

```markdown
## Behavior delta
- ADDED: <one-line requirement — a behavior the system did not have>
  - Acceptance: <observable criterion that proves it>
- MODIFIED: <one-line requirement — a behavior that changes>
  - Acceptance: <criterion for the new behavior>
- REMOVED: <one-line requirement — a behavior that goes away>
```

Rules:
- Each entry is tagged `ADDED` / `MODIFIED` / `REMOVED`.
- Each `ADDED` / `MODIFIED` entry carries ≥1 `Acceptance:` criterion — an *observable* behavioral outcome, not a task-level "grep for X". The task list verifies the mechanism ran; the acceptance criterion verifies the behavior.
- `MODIFIED` / `REMOVED` are compatibility signals: they feed the Scope and Risk/blast-radius checks and hook `review-api-compat` when they touch a contract boundary.

Relation to [Completeness and gap](#completeness-and-gap): that section's *end-state* is the plan-level "done"; a Behavior delta's `Acceptance:` lines are the per-requirement "done". Use both — one exit criterion for the whole plan, one observable check per changed behavior.

Worked example:

```markdown
## Behavior delta
- ADDED: `/healthz` returns 200 with the build SHA once the server is ready.
  - Acceptance: `curl -s localhost:8080/healthz` returns 200 and a JSON body containing the current SHA.
- MODIFIED: login rejects passwords shorter than 12 chars (was 8).
  - Acceptance: a 10-char password is rejected with 422. (Blast-radius check: existing sessions stay valid.)
- REMOVED: the legacy `/v1/token` endpoint.
```

When to include: optional for small, internal-only plans; expected for any plan changing public API or user-visible behavior. (The SKILL.md plan-shape contract will flag its absence on boundary-crossing plans once the review-plan enforcement update lands.)

## Open questions

The most common plan failure: the plan looks complete but contains decisions the implementer must invent. Examples:
- "Use the standard cache" when the repo has multiple caches in use.
- "Follow the existing pattern" when there are competing patterns.
- "Add appropriate error handling" with no definition of "appropriate".
- "Choose a reasonable timeout" with no number.
- "Pick a good name" with no naming convention specified.

Each open question is either:
1. **Resolvable from existing project conventions** — fine; the plan should cite the convention.
2. **A decision the user must make** — block on it. Do not invent.
3. **A decision the implementer is empowered to make** — fine, but the plan should say so explicitly ("implementer's choice between A and B").

Flag every "appropriate", "reasonable", "good", "standard" without a referent.

## Ordering

- **Topological order**: if Task B depends on Task A's output, B is listed after A.
- **Independent tasks** can be in any order; flag opportunities to parallelize as `P3 / improvement` (not a blocker).
- **Risky tasks earlier** when feasible: do the hard, uncertain work first when failure should kill the plan; do the cleanup at the end.
- **Verification depends on prior tasks**: a task's verification cannot rely on functionality not yet built.
- **Migration ordering**: schema change → backfill → code uses new schema → remove old schema usage. Don't change the schema and the code that uses it in the same task on a shared database.

## Verification

Per-task verification options, in order of preference:
1. **Test invocation** with expected outcome: `task test ./internal/auth/... → PASS`. Best because automation-friendly.
2. **Command with expected output**: `curl /healthz → 200`. Concrete and quick.
3. **Manual smoke check**: "load /users in browser, see 3 entries". Acceptable for UI tasks where automation is expensive.
4. **"No regression": existing tests still pass**. Acceptable only when the task is intentionally invisible (refactor, rename); explicitly note when this is the verification.

Anti-patterns to flag:
- "Verify by reviewing the code" — that's review, not verification.
- "Verify by running the program" — too vague; what does success look like?
- No verification at all — the task can be "done" but broken.

Tasks that add tests are self-verifying: the test passes ⇔ the change is correct.

## Scope

- **Mentioned but not planned**: the plan name-drops something ("we'll also need to update the dashboard") but no task implements it. Either add a task or note "out of scope".
- **Planned but not mentioned**: a task does something the plan's narrative doesn't describe. Suspicious — the task may be over-reaching.
- **Out-of-scope sprawl**: the plan starts on Feature X and a task quietly changes Feature Y. Split or scope-cut.
- **Scope inflation through refactor**: "while we're here, let's clean up Z" — usually a sign the plan should be two plans. Flag as `P2 / scope`.
- **Behavior delta vs. tasks mismatch**: every `ADDED` / `MODIFIED` / `REMOVED` entry should be traceable to a task, and no task should change behavior the delta doesn't declare. A task altering behavior with no matching delta entry is scope creep.

A good plan has a clear scope statement up front. If absent, flag as `P2 / scope` and offer to add one.

## Risk and blast radius

Tasks that warrant explicit user confirmation before execution (not silent inclusion):
- **Destructive operations**: `DROP TABLE`, `rm -rf`, `git push --force`, deleting branches with unmerged work, dropping columns with backed data.
- **Production data touch**: any task that runs against prod data, even read-only when PII is involved.
- **Shared resource touch**: editing org-wide modules, modifying CI configs other teams depend on, changing API contracts consumed by other services.
- **Secret material**: rotating keys, regenerating tokens, changing IAM bindings.
- **Migrations on running systems**: schema changes that lock tables, large backfills.
- **`MODIFIED` / `REMOVED` behavior deltas**: a changed or removed behavior is a blast-radius signal — existing callers may depend on it. Trace who relies on it; recommend `review-api-compat` when it touches a contract boundary.

Flag these `P0 / risk` even when the plan is otherwise sound. They don't block READY but they must be called out so the executor pauses for confirmation at the right moment.

## Improvements

Non-blocking findings that make the plan better. Lowest priority; surfaced as `P3 / improvement`.

- **Better breakdown**: a 30-min task could be 3× 10-min tasks. Easier to recover from failure.
- **Missing intermediate commits**: a single task that touches 8 files would be 3 commits in human review. Suggest splitting.
- **Parallelization opportunity**: independent tasks could run as parallel PRs.
- **Skip-bisect markers**: tasks that intentionally leave the tree non-buildable (per `commit-per-phase` rule) should declare it.
- **Changelog entry hint**: plans for user-visible changes should reference adding a changelog entry (per `changelog-entries-are-per-pr` rule).
- **PR description draft**: noting "this becomes a PR titled X" makes wrap-up faster.

None of these block. Don't gate `READY` on them.
