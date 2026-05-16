# Implement Plan: Reference

Detailed subagent prompts, the reviewer dispatch table, and the red-flag rationalization table. SKILL.md references this file.

## Table of contents

- [Plan header conventions](#plan-header-conventions)
- [Implementer prompt template](#implementer-prompt-template)
- [Reviewer dispatch](#reviewer-dispatch)
- [Reviewer prompt template](#reviewer-prompt-template)
- [Red flags](#red-flags)
- [Rationalization table](#rationalization-table)
- [Status protocol](#status-protocol)
- [Nits accumulator format](#nits-accumulator-format)

## Plan header conventions

Plans are markdown. Most of a plan is the checkbox task list. A few optional sections near the top let the plan author override implement-plan's defaults *declaratively* — the policy lives with the plan, survives session resets, and is reviewable in the same diff as the tasks.

### `## Branch policy` (optional)

Controls Step 3 (branch setup). All fields are optional; absence means "use the default".

```markdown
## Branch policy
- Branch: feat/auth-rewrite       # explicit branch name; overrides the derived default
- Base: origin/main               # base ref to branch from; overrides origin/<default-branch>
- Chain: feat/payments-rewrite    # chained-PR mode; branch off this instead of Base
```

**Field semantics:**
- **`Branch:`** — explicit branch name. If absent, implement-plan derives `impl/<plan-slug>` from the plan filename (e.g. `2026-05-16-auth-rewrite.md` → `impl/2026-05-16-auth-rewrite`).
- **`Base:`** — base ref to fetch and branch from. If absent, `origin/<default-branch>` (detected via `git symbolic-ref refs/remotes/origin/HEAD`).
- **`Chain:`** — stacked-PR mode. When set, this is the base instead of `Base:` or the detected default. The named ref is fetched if it's a remote ref. Use when this plan's PR is expected to stack on top of another open PR / feature branch.

**Resolution order**: `Chain` > `Base` > detected default. `Branch:` is independent — it names the new branch regardless of which base is used.

**Examples:**

```markdown
## Branch policy
- Branch: feat/jwt-refresh
```
→ branch `feat/jwt-refresh` from `origin/<default>` (latest after fetch).

```markdown
## Branch policy
- Chain: feat/payments-rewrite
```
→ branch `impl/<plan-slug>` from `feat/payments-rewrite` (the existing branch this plan stacks on).

```markdown
## Branch policy
- Branch: hotfix/jwt-bug
- Base: origin/release-2026-q1
```
→ branch `hotfix/jwt-bug` from `origin/release-2026-q1` (e.g. a release branch hotfix, not main).

No `## Branch policy` section at all → default behavior: fresh `impl/<plan-slug>` from `origin/<default>`.

### Parsing rules

- Look for the literal heading `## Branch policy` (case-sensitive, level 2).
- Within that section, parse `- Key: Value` bullets case-insensitively on the key (`branch`, `base`, `chain`).
- First occurrence wins; ignore duplicates with a warning.
- Stop parsing the section at the next heading of level ≤ 2.
- Unrecognized keys: warn, do not abort.
- A heading present but empty → treat as absent.

### Why declarative

The plan file is the source of truth for the work. Putting branch policy in the plan rather than in a skill argument means:
- The policy is visible in the plan PR review.
- The policy survives session resets, re-invocations after escalation, and handoff to another operator.
- The plan author records intent (e.g. "this stacks on X") rather than the executor re-deciding each run.

This mirrors the precedent of Karpathy's "specs as scaffold" and Osmani's "external memory over context".

### Future plan-header sections

Reserved for future skills (not implemented here):
- `## Verification` — project-wide verification command overrides
- `## Risk` — declared destructive-operation gating

If a future plan declares these, implement-plan should ignore unknown sections and warn (don't abort).

## Implementer prompt template

Use this exact shape when spawning the implementer subagent. Substitute the bracketed sections.

```
You are implementing ONE task from an approved plan. Do this task only. Do not pull in adjacent work, do not "while I'm here" anything.

# Goal
Implement the following task and return DONE when it is complete, verified by you, and ready for review.

# Plan context
- Plan file: <plan-path>
- Plan goal (one paragraph): <plan-goal>
- Total tasks: <N>. This is task <i>/<N>.
- Prior tasks done: <list of completed task subjects>

# Your task
<verbatim task text including its checkbox line and any sub-bullets>

# Files in scope
<for each file the task names, paste the relevant excerpt or full content here>

# Constraints
- Touch only the files named in the task. If you need to change anything else to make this work, STOP and return NEEDS_CONTEXT with what you'd need to touch and why.
- Follow project conventions visible in the file excerpts (naming, error handling, imports).
- No new dependencies unless the task explicitly adds one.
- No refactoring outside the task scope (per minimal-changes rule).
- Do not run `git commit` — the parent will commit.

# Self-review before reporting DONE
- Does the change implement the task as written? (completeness)
- Did you add anything not requested? (scope discipline)
- Did you write a test where the task asked for one?
- Have you actually run the verification step from the task? Paste its output below.

# Return format
First line: one of DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
Followed by:
- Files changed: <list>
- Summary: <1-3 sentences>
- Verification output: <paste, if applicable>
- Concerns: <only if DONE_WITH_CONCERNS; specifically what worries you>
- Blocker: <only if BLOCKED; what specifically broke>
- Needed context: <only if NEEDS_CONTEXT; exactly what would unblock>
```

## Reviewer dispatch

Pick reviewers based on which file extensions / patterns changed in the task. Multiple may apply; run them **serially** in this order to avoid wasted retries (cheaper, broader reviewers first):

| Files changed | Reviewer(s) | Notes |
|---|---|---|
| Any `.go` source | review-code | Always when Go changes |
| Any `.proto` | review-code + review-api-compat | review-code for style, review-api-compat for breaking changes (only if `has_changes` against a base ref) |
| OpenAPI/Swagger spec changes | review-api-compat | Diff-aware; pass the base ref |
| `.sql` files or DB-driver code (`pgx`, `pq`, `database/sql`) | review-database | |
| `.tf` / `.tofu` / Kubernetes YAML / Dockerfile / Helm / mesh / gateway CRD | review-infrastructure | |
| `.github/workflows/*.yml` / composite `action.yml` / Dependabot/Renovate config / `.circleci/` / `.gitlab-ci.yml` / `Jenkinsfile` | review-ci | |
| Source touching auth, crypto, RPC handlers, secret material, or new external input boundaries | review-security (additive) | Run *in addition to* the language reviewer |
| Source touching loggers, metrics, tracers, or RPC instrumentation | review-observability (additive) | Run *in addition to* the language reviewer |

**Performance review (`review-performance`) is NOT auto-dispatched.** Plans that need it should request it explicitly per task ("run review-performance on this task").

**Coverage (`review-coverage`) is NOT auto-dispatched per task** — it's already implicit via `verify-when-complete` test runs. Run at end-of-plan as part of `review-all`.

**Documentation (`review-documentation`) is NOT auto-dispatched per task** — runs at end-of-plan as part of `review-all`.

## Reviewer prompt template

```
You are reviewing the diff produced by ONE plan task. Apply the <reviewer-skill-name> checklist.

# Context
- Plan: <plan-path>
- Task <i>/<N>: <task subject>
- Files changed in this task: <list>
- Diff: <inline git diff for this task's commit-in-progress>

# Constraints
- Review only the diff above. Do not expand scope.
- Cite findings as `path:line` (or `path:line-L` for removed code).
- Use severity per your skill's convention (P0/P1/P2/P3, or HIGH/MEDIUM/LOW, or bug/risk/nit).
- Follow the terse-comments convention: concrete fix, no praise, no restating the diff.
- Be honest. Do not rubber-stamp. If something is wrong, say so.

# Return format
First line: DONE | DONE_WITH_CONCERNS | BLOCKED
Followed by:
- Findings table per your skill's template
- Tracked column: `—` for new findings, existing tracking if you found it
```

## Red flags

Specific workarounds to refuse, even under pressure. If you catch yourself doing any of these, stop and re-read the rule.

- **Skipping the review-plan pre-flight gate.** Rationalization: "the plan looks fine". Reality: review-plan is the gate that catches plans-that-look-fine.
- **Continuing past a BLOCKED verdict.** Rationalization: "I'll just fix it as I go". Reality: BLOCKED means the plan literally cannot be executed; you'd be inventing.
- **Auto-creating a PR.** Rationalization: "we always create a PR at the end". Reality: per `defer-external-orchestration`, PR creation is user-triggered.
- **Pushing to remote.** Same as above.
- **Parallel implementers.** Rationalization: "tasks 3 and 4 don't touch the same files". Reality: file overlap is hard to predict; merge order matters; reviewers comment on diffs that change under them. Sequential always.
- **Skipping verify-when-complete.** Rationalization: "the implementer's report says it passed". Reality: per Superpowers, "do not trust the report". Run the command yourself.
- **Marking a task complete without ticking `- [ ]`.** Rationalization: "I'll batch the ticks at the end". Reality: the plan file is the source of truth for progress; the loop reads checkbox state.
- **`git commit --amend`.** Rationalization: "this commit belongs with the previous task". Reality: per `git-no-amend`, always new commits. Bisect needs distinct commits per phase.
- **"While I'm here" changes.** Rationalization: "the related code is also wrong". Reality: per `minimal-changes`, file an issue and link it from the nits file; don't expand the diff.
- **Asking "should I continue?" between tasks.** Rationalization: "checking in is polite". Reality: per Superpowers, this wastes the human's time. Execute through; halt only on the named escalation triggers.
- **Inventing an architectural decision.** Rationalization: "this is a reasonable default". Reality: per `escalation`, ask first. Wrong autonomous choices cost more than questions.

## Rationalization table

When pressured to break a rule, this is what the agent will tell itself, and the reality check.

| Excuse | Reality |
|---|---|
| "The plan is short, review-plan is overkill" | Short plans hide as many bugs as long ones; review-plan is 30 seconds |
| "BLOCKED is too strict; I can just figure it out" | If you could, the plan would not have been BLOCKED |
| "We're 90% done; let me skip verify on the last task" | The last task is where regressions hide; verify everything |
| "The reviewer is the same model family, the review is theater" | Opus-reviewing-Sonnet is the partial fix; don't make it worse by skipping |
| "I'll batch all the commits at the end for a cleaner history" | Bisect needs per-phase commits; clean history is a side-effect, not the goal |
| "Tasks 3 and 4 are independent, I'll parallelize" | "Independent" is a guess until merge; sequential makes it certain |
| "The user said 'do it' — they want fast" | "Do it" doesn't mean "skip the gates"; it means "start" |

## Status protocol

The same four-status protocol used across review-* and superpowers. Every subagent in this skill (implementer, each reviewer, review-plan) returns one of:

- `DONE`: task complete, no caveats.
- `DONE_WITH_CONCERNS`: complete, but the subagent flags something the parent should consider before proceeding.
- `BLOCKED`: could not complete; explain what is missing or broken.
- `NEEDS_CONTEXT`: could not complete because the parent didn't supply enough; list specifically what's missing.

The parent branches on the status line without parsing the body. The body is only consulted when the status warrants it.

## Nits accumulator format

The file `./.implement-plan-nits.md` is created (or appended) when a non-blocking finding (P2/P3/nit) is recorded. Format:

```markdown
# Nits accumulated during implement-plan

Plan: <plan-path>
Started: <run datetime>

## Task <i>: <subject>

- `path:line` — <finding text>. <suggested fix>. Source: review-code / review-infrastructure / ...
- `path:line` — ...

## Task <j>: <subject>

- ...
```

At end-of-plan the user is asked: address now, defer (keep the file), or discard (delete the file).

This file is not committed by the per-task commits. If the user chooses "defer", they decide whether to commit it.
