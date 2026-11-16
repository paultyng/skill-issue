# Plan Review: Framework Reference

What a defect looks like in each finding category, and the format of the plan sections `implement-plan` consumes. SKILL.md states the goals and verdict; this file is the catalog it draws on.

Sources:
- [Karpathy: Software 3.0 / specs as scaffold](https://karpathy.bearblog.dev/sequoia-ascent-2026/)
- [Osmani: How to write a good spec for AI agents](https://addyo.substack.com/p/how-to-write-a-good-spec-for-ai-agents): "a vague spec multiplies errors across the entire fleet"
- [obra/superpowers: writing-plans](https://github.com/obra/superpowers/blob/main/skills/writing-plans/SKILL.md), the origin of the plan-shape contract (MIT, copyright Jesse Vincent)

## Table of contents

- [Feasibility](#feasibility)
- [Completeness and gap](#completeness-and-gap)
- [Behavior delta](#behavior-delta)
- [Branch policy](#branch-policy)
- [Open questions](#open-questions)
- [Ordering](#ordering)
- [Verification](#verification)
- [Scope](#scope)
- [Risk and blast radius](#risk-and-blast-radius)
- [Improvements](#improvements)

## Feasibility

The plan assumes something about the world that is false. Each of these is checkable with a read or grep, and the finding cites what you found.

- A file or symbol the task edits does not exist and no earlier task creates it (`P0`).
- A library the task uses is not a dependency and no earlier task adds it.
- Infrastructure the task writes to (a queue, a table, a service) does not exist and nothing provisions it.
- A stated assumption about the code ("the handler is stateless", "config is loaded once") does not hold.
- A task crosses a boundary the plan never names: prod config, shared org modules, files outside the repo.

## Completeness and gap

The plan has holes between tasks or no exit.

- No end-state: the plan cannot say how it knows it is done. Acceptable forms are a passing test, an endpoint returning a value, a user action that now works. "The feature works" is not one.
- Task N produces A, Task N+1 consumes B, and nothing says how A becomes B.
- A state transition between tasks is asserted without content ("now everything works").
- Temporary scaffolding (flags, shims, dual-writes) is added and never removed or tracked.
- A schema change has no rollback note, even a one-liner.

## Behavior delta

An optional plan section stating *what changes about system behavior* before the tasks say *how*. Required on any plan that crosses a public-API or user-visible boundary; `P3` when absent from an internal-only plan. It gives the gap, scope, and risk checks something concrete to test against, and `implement-plan` runs its `Acceptance:` criteria at end-of-plan.

Format:

```markdown
## Behavior delta
- ADDED: <one-line requirement: a behavior the system did not have>
  - Acceptance: <observable criterion that proves it>
- MODIFIED: <one-line requirement: a behavior that changes>
  - Acceptance: <criterion for the new behavior>
- REMOVED: <one-line requirement: a behavior that goes away>
```

Well-formed means: every entry carries one of the three tags, and every `ADDED` / `MODIFIED` entry has at least one `Acceptance:` line that observes behavior (a response, a rejection, a visible state), not mechanism ("grep for X"). Task verification proves the mechanism ran; acceptance proves the behavior holds. Plan-level end-state and per-entry acceptance are both needed: one exit for the whole plan, one check per changed behavior.

`MODIFIED` and `REMOVED` are compatibility signals. Trace who depends on the old behavior; when the boundary is a contract (proto, public API, wire format), recommend a `review-api-compat` pass.

Example:

```markdown
## Behavior delta
- ADDED: `/healthz` returns 200 with the build SHA once the server is ready.
  - Acceptance: `curl -s localhost:8080/healthz` returns 200 and a JSON body containing the current SHA.
- MODIFIED: login rejects passwords shorter than 12 chars (was 8).
  - Acceptance: a 10-char password is rejected with 422. (Blast radius: existing sessions stay valid.)
- REMOVED: the legacy `/v1/token` endpoint.
```

## Branch policy

An optional `## Branch policy` section near the top of the plan, read by `implement-plan` to pick the base and branch. Fields are `Base: <ref>`, `Chain: <ref>`, `Branch: <name>`; the format and precedence live in `implement-plan`'s reference (Plan header conventions). For review, the question is whether each ref resolves (`git rev-parse --verify <ref>`). A `Chain:` or `Base:` ref that does not exist is `P0 / feasibility`; the executor will fail at branch setup.

## Open questions

The most common failure in plans that look complete: a decision the implementer must invent. The tell is an evaluative word with no referent: "appropriate error handling", "a reasonable timeout", "a good name", "the standard cache", "the existing pattern" where two patterns coexist.

Each one is in exactly one of three states, and the plan must make clear which:

1. Resolvable from a project convention the plan cites. Fine.
2. A decision the user has to make. `BLOCKED`; do not invent it.
3. Delegated to the implementer, explicitly ("implementer's choice between A and B"). Fine.

An unanswered question that is answerable from the codebase (you can find the convention; the plan did not cite it) is `NEEDS_REVISION` with the answer in the recommendation.

## Ordering

- A task depends on output of a task listed after it.
- A task's verification relies on something a later task builds.
- Schema and the code that reads it change in the same task against a shared database. The safe sequence is expand the schema, backfill, switch readers, then contract.
- Risky or uncertain work is scheduled last when it should go first so failure kills the plan early. `P3` unless the late task can invalidate earlier ones.

Independent tasks in any order are fine; a chance to parallelize is `P3 / improvement`.

## Verification

Verification is a probe that can fail. In order of preference: a test command with expected pass; a command with expected output; a manual check naming what you see (acceptable where automation is expensive, such as UI); "existing tests still pass", acceptable only for intentionally invisible changes (rename, pure refactor) and stated as such.

Not verification: "review the code", "run the program", "section X present", "file exists", or nothing. Each passes for broken work.

A task that adds a test is self-verifying.

## Scope

- Mentioned but not planned: the narrative names work no task does. Add a task or mark it out of scope.
- Planned but not mentioned: a task does work the narrative never describes. Often over-reach.
- A task changes behavior no Behavior delta entry declares, or a delta entry maps to no task.
- "While we're here" refactors riding along. Usually two plans. `P2 / scope`.
- No scope statement at all. `P2 / scope`; the recommendation is the sentence to add.

## Risk and blast radius

Steps the executor must pause on for user confirmation, even when the plan is otherwise sound. Flag `P0 / risk`; it does not block `READY`, but the executor needs the marker to stop at the right moment.

- Destructive operations: dropping tables or columns with data, `rm -rf`, force-push, deleting branches with unmerged work.
- Prod data, including read-only access to PII.
- Shared resources: org-wide modules, CI other teams depend on, API contracts other services consume.
- Secret material: key rotation, token regeneration, IAM changes.
- Migrations that lock tables or backfill at scale on a running system.
- `MODIFIED` / `REMOVED` behavior with untraced dependents.

A destructive step with no confirmation gate at all is `BLOCKED`, not `P0 / risk`; the difference is whether the plan acknowledges the pause.

## Improvements

Non-blocking, `P3`. A 30-minute task that could be three 10-minute tasks; a task touching eight files that would be three commits; independent task groups that could be separate PRs; intentionally non-buildable intermediate states missing a `[skip-bisect]` marker (`commit-per-phase`); user-visible changes with no changelog task (`changelog-entries-are-per-pr`); no note of what the eventual PR is titled.
