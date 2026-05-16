---
name: implement-plan
description: Use when the user wants to execute an approved implementation plan and says any of "do it" (with a plan in scope), "lets do it" / "let's do it", "confirmed" (as approval to proceed on a plan), "implement the plan", "implement this", "execute the plan", "start implementing", "work through the plan", "implement the next phase", "build it out", "knock out the plan", or "/implement-plan PATH". Also use when a plan file (`./PLAN.md`, or any `./docs/plans/*.md`) is present and the user signals readiness to begin coding. Do NOT use when the user is still discussing, refining, or asking questions about the plan, nor when no plan exists — short imperatives like "do it" or "confirmed" alone are ambiguous; verify a plan is in scope before activating.
---

# Implement Plan

Drive an approved implementation plan to completion: review-plan gate → per-task loop (implementer → verify → reviewer → triage → commit → tick) → end-of-plan review. Manual invocation only. Never auto-creates PRs.

## Workflow

### 1. Resolve the plan and check preconditions

**Plan resolution** (priority order):
1. Explicit path argument (e.g. `/implement-plan docs/plans/auth-rewrite.md`).
2. `./PLAN.md` in cwd.
3. Latest by mtime in `./docs/plans/*.md`.
4. None resolve → **stop, ask the user**. Do not guess. Do not assume "do it" meant something else; if no plan, this skill should not have activated — exit cleanly.

Read the plan file fully. Capture: total task count, unchecked task count, and any **Branch policy** section (see [reference.md → Plan header conventions](reference.md#plan-header-conventions)).

**Precondition checks** (fail-fast — abort with a clear message if any fails):

```sh
# In a git repo?
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || abort "not a git repo"

# Working tree clean? Catches uncommitted + untracked.
[ -z "$(git status --porcelain)" ] || abort "working tree not clean — commit, stash, or discard first"

# origin remote exists?
git remote get-url origin >/dev/null 2>&1 || abort "no 'origin' remote — see reference.md for fallback"
```

If the plan file itself is uncommitted, the clean-tree check will catch it. Tell the user to commit the plan first, then re-invoke.

### 2. Pre-flight gate: review-plan

Invoke the `review-plan` skill as a subagent. Pass the resolved plan path. Branch on the returned verdict:

| Verdict | Action |
|---|---|
| `READY` | Continue to step 3. |
| `NEEDS_REVISION` | Surface findings. Ask the user: **revise the plan, proceed anyway, or abort?** Do not pick for them. |
| `BLOCKED` | Halt. Surface findings. Exit. The user must edit the plan and re-invoke. |

**Do not skip this gate.** "The plan looks fine" is not a substitute for the review-plan checklist. See [reference.md](reference.md) for the rationalization table.

### 3. Branch setup

Determine the target branch and base, then switch (or resume).

#### Determine policy

Read the plan's **Branch policy** section if present (see [reference.md → Plan header conventions](reference.md#plan-header-conventions)). Resolve, in priority order:

1. **Plan declares `Chain: <ref>`** → chained-PR mode. Base = `<ref>`. Branch name = plan-derived default (or `Branch:` if also declared). Fetch the chain base if it's a remote ref.
2. **Plan declares `Base: <ref>`** → use that base. Branch name = `Branch:` if declared, else plan-derived default.
3. **Default** → base = `origin/<default-branch>`. Branch name = plan-derived default.

**Plan-derived default branch name**: `impl/<plan-slug>`, where `<plan-slug>` is the plan filename without `.md`. Example: `docs/plans/2026-05-16-auth-rewrite.md` → `impl/2026-05-16-auth-rewrite`.

**Default-branch detection**:

```sh
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/origin/||')
[ -z "$DEFAULT_BRANCH" ] && abort "could not detect origin's default branch — set Base: in plan or run 'git remote set-head origin -a'"
```

#### Resume check

Before creating a branch, detect resume mode:

```sh
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TICKED_COUNT=<count of '- [x]' lines in the plan>

if [ "$CURRENT_BRANCH" = "$TARGET_BRANCH" ] && [ "$TICKED_COUNT" -gt 0 ]; then
  # Resume mode: stay on this branch, skip branch creation.
  echo "Resuming on $CURRENT_BRANCH ($TICKED_COUNT tasks already done)"
  # Proceed to step 4.
fi
```

#### Fresh branch creation

If not resuming:

```sh
git fetch origin "$BASE_BRANCH"

# If the target branch already exists, ask the user:
#   - reuse it (e.g. you renamed and want to continue),
#   - delete and recreate fresh from BASE,
#   - or pick a different name.
# Do NOT silently overwrite.

git switch -c "$TARGET_BRANCH" "origin/$BASE_BRANCH"
```

Surface a one-liner to the user: `Branch: <target> from <base> (latest @ <short-sha>)`.

### 4. Per-task loop

For each unchecked `- [ ]` task in plan order:

#### (a) Implementer subagent

Spawn a `general-purpose` subagent at `model: sonnet` (per `subagent-model-routing`) with Edit/Write/Bash. Build the prompt per [reference.md → Implementer prompt template](reference.md#implementer-prompt-template).

**Critical**: the parent reads the task's named files **once** and injects content inline. The subagent must NOT re-read them — that defeats the delegation and risks reading a different version.

The subagent returns one of: `DONE` / `DONE_WITH_CONCERNS` / `BLOCKED` / `NEEDS_CONTEXT`.

#### (b) Verify in parent

Run the `verify-when-complete` skill in the parent process (fmt → lint → build → test). This is not delegated — completion claims require fresh, parent-visible evidence (per Superpowers' verification-before-completion rule).

On failure: loop back to (a) with the failure output appended to the implementer's context. Max **2 retries**. Then escalate per step 4.

#### (c) Reviewer subagent dispatch

Determine which reviewers apply based on what changed in this task. Use the table in [reference.md → Reviewer dispatch](reference.md#reviewer-dispatch).

Run reviewers **serially**, not parallel — they all comment on the same diff and parallel runs produce duplicated findings.

Use `model: opus` for reviewers. Deeper judgment than the implementer, and the model-mismatch partially defeats self-agreement bias when implementer and reviewer are otherwise the same family.

#### (d) Triage findings

In the parent:
- **P0, P1, `bug`, `risk`** → loop back to (a) with the finding text. Max **2 retries**. Then escalate.
- **P2, P3, `nit`** → append to `./.implement-plan-nits.md` (a plan-scoped accumulator). Non-blocking.

#### (e) Commit

One commit per task that leaves the tree buildable (per `commit-per-phase` rule). Conventional Commits subject. No `--amend` ever (per `git-no-amend` rule). If the task is intentionally mid-refactor and would leave the tree non-buildable, include `[skip-bisect]` in the commit message.

#### (f) Tick the checkbox

Edit the plan file in place: `- [ ]` → `- [x]`. Same commit as (e) is fine; this is metadata on the same logical change.

#### (g) Next

Move to the next unchecked task. Do not pause to ask "should I continue?" — that is one of the named red flags (see [reference.md → Red flags](reference.md#red-flags)).

### Halt conditions (during the task loop)

Halt the loop and surface to the user when any of:

- Implementer returns `BLOCKED` or `NEEDS_CONTEXT`.
- The same error has appeared 3 iterations on the same task (kill criterion).
- A reviewer P0 finding has not been resolved within 2 retries.
- The implementer encounters an architectural decision that is not in the plan (per `escalation` rule — never invent).
- A destructive operation appears at execution time (even if review-plan didn't block it — double-check at the moment of action per `defer-external-orchestration`).

Surface: current task number, status line, last subagent return, and the specific decision needed. Do not auto-resume after escalation — wait for the user.

### 5. End-of-plan handoff

When all `- [ ]` tasks are `- [x]`:

1. **Spawn `review-all`** across the full branch diff against the plan's base ref. Surface its findings as one final cross-cutting review.
2. **Surface the nits file** (`./.implement-plan-nits.md`). Ask: address now, defer, or discard?
3. **Do NOT auto-create the PR** (per `defer-external-orchestration`). Print the suggested command, e.g.:
   ```
   gh pr create --draft --title "<plan title>" --body "<...>"
   ```
   Wait for the user to run it.

---

## Output (user-facing status updates)

Per `terse-output`: one sentence per key moment. Not every step. Examples:

- `Preconditions OK. Plan: docs/plans/2026-05-16-auth-rewrite.md (8 tasks).` — Step 1 done
- `review-plan: READY (3 nits noted)` — Step 2 done
- `Branch: impl/2026-05-16-auth-rewrite from origin/main (@a1b2c3d).` — Step 3 done (new branch) — or
- `Resuming on impl/2026-05-16-auth-rewrite (3/8 tasks already done).` — Step 3 done (resume mode)
- `Task 4/8: starting (touches internal/auth/jwt.go)` — task start
- `Task 4/8: DONE; review-code clean; committed feat(auth): add JWT validator` — task end (single line)
- `Task 5/8: implementer returned BLOCKED — needs cache library choice. Halting.` — escalation
- `All 8 tasks complete. Running review-all.` — handoff to end-of-plan

Silence between these is fine. Don't narrate deliberation.

---

## Plan path conventions

- Plans live in `./docs/plans/` (working directory; typically a repo root) or `./PLAN.md` for ad-hoc.
- Filename convention: `YYYY-MM-DD-<feature-slug>.md` (matches Superpowers' convention and most "writing-plans" skills).
- This skill does not create plans. Use Claude Code's native Plan mode or a future writing-plans skill upstream.
- Plans are **committed to the repo** before invocation — the clean-tree precondition in Step 1 enforces this. Plans are not session-scoped or hidden.
- Plans may declare branch policy in a `## Branch policy` section near the top — see [reference.md → Plan header conventions](reference.md#plan-header-conventions). Absence means: fresh branch off `origin/<default>`.

---

## Cross-references

- Pre-flight: `review-plan`
- Post-implementation gate: `verify-when-complete`
- Reviewer dispatch: `review-code`, `review-infrastructure`, `review-ci`, `review-database`, `review-security`, `review-observability`, `review-api-compat`
- End-of-plan: `review-all`
- Rules consulted: `subagent-prompt-contract`, `subagent-model-routing`, `parallelize-subagents`, `commit-per-phase`, `escalation`, `defer-external-orchestration`, `minimal-changes`, `confirm-before-implementing`, `git-no-amend`, `terse-output`, `auto-verify-after-rebase` (applies to the chained-PR case if a rebase is needed mid-loop)

For detailed subagent prompt templates, the reviewer dispatch table, and the red-flag rationalization table, see [reference.md](reference.md).

---

## Sources

- [obra/superpowers: subagent-driven-development](https://github.com/obra/superpowers/blob/main/skills/subagent-driven-development/SKILL.md), used under [MIT License](https://github.com/obra/superpowers/blob/main/LICENSE), copyright Jesse Vincent. The orchestrator-with-personas pattern and "do not trust the report" reviewer framing are drawn from this skill.
- [Addy Osmani: Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/) — Ralph Loop, kill criteria, focused-context-per-agent.
- [Karpathy: Sequoia Ascent 2026](https://karpathy.bearblog.dev/sequoia-ascent-2026/) — context-as-program, specs-in-files-not-prompts.
