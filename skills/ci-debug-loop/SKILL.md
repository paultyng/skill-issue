---
name: ci-debug-loop
description: Watch a GitHub Actions CI run, diagnose failures from logs, apply fixes, re-push, and repeat until green or escalate. Use when CI is failing and the user wants to debug and fix it iteratively, or says "fix CI", "debug the build", or similar.
---

# CI Debug Loop

Iteratively watch CI, diagnose failures, fix, and re-trigger until the run passes or escalation is needed.

## 1. Identify the Run

Find the latest run for the current branch:

```bash
gh run list --branch $(git branch --show-current) --limit 1 --json databaseId,status,conclusion,name
```

If a specific run ID or workflow is provided by the user, use that instead.

## 2. Watch

If the run is still in progress:

```bash
gh run watch <run_id> --exit-status
```

If it already completed, proceed to diagnosis.

## 3. Diagnose Failure

On failure, fetch logs for the failed job(s):

```bash
gh run view <run_id> --log-failed
```

**Delegate log analysis to a two-stage subagent pipeline** when the failed-log output is more than ~200 lines. CI logs flood main context fast and the parent only needs the root cause, not the raw output. Per `parallelize-subagents`, `delegate-investigation`, and `subagent-model-routing`:

**Stage 1 — Extract (Haiku):** Spawn an `Explore` subagent (`model: haiku`) per failed job (parallel if multiple jobs failed). Prompt: paste the **command to fetch the log** (not the log itself); ask for "first failing assertion + ~10 lines of surrounding context, ≤50 lines, prefixed with `Status: ...`". Haiku handles the mechanical extraction; no interpretation needed at this stage.

**Stage 2 — Interpret (Sonnet):** After Stage 1 completes, spawn a `generalPurpose` subagent (`model: sonnet`) with the Stage 1 structured output pasted inline plus the failure categories below. Ask for "likely root cause + file:line if identifiable, ≤100 words, prefixed with `Status: ...`".

- Parent receives the Stage 2 summary, decides the fix.

For short logs (<200 lines), inspect inline.

Common failure categories:
- **Build errors**: compilation failures, missing dependencies
- **Test failures**: assertion errors, timeouts, flaky tests
- **Auth/permissions**: token scopes, registry auth, SSH keys
- **Config/YAML**: syntax errors, wrong flags, missing env vars, heredoc issues
- **Infrastructure**: runner issues, Docker rate limits, service unavailability

## 4. Fix

If the fix is **mechanical** (typo, missing flag, wrong version, import ordering, fmt issue):
- Apply the fix directly
- Commit using [Conventional Commits](https://www.conventionalcommits.org/) format
- Push

If the fix requires a **design decision** or is **ambiguous**:
- Present the diagnosis and options to the user
- Wait for direction before applying

## 5. Re-watch

After pushing the fix, wait for the new run to appear:

```bash
gh run list --branch $(git branch --show-current) --limit 1
```

Then watch it (back to step 2).

## 6. Escalation

**Stop and escalate to the user** if:
- The same job fails twice with the same error after a fix attempt
- The failure is in infrastructure outside the repo's control (runner issues, external service outages)
- The fix would require changes to a different repository or CI configuration not in this repo

Report what was tried, what failed, and what options remain.

**Escalate to `bisect`** when log analysis can't pinpoint *which change* broke the job. Typical signs: failure looks unrelated to the recent diff, error message points at code untouched in the branch, or a previously-green test on the same branch is now red. Hand the failing test/command to `/bisect` as the reproducer; it isolates the offending commit.
