---
name: push-and-watch
description: Push local commits to the remote, ensure a draft PR exists, and monitor the GitHub Actions run until completion. Use when the user says "push and watch", "push it", or asks to push and monitor CI.
---

# Push and Watch

Push local commits to the remote and monitor the CI run until completion.

## 1. Pre-flight Checks

- Verify the working tree is clean (`git status`). If there are uncommitted changes, stop and ask.
- Verify there are local commits ahead of the remote (`git status` should show "Your branch is ahead"). If not, report "nothing to push" and stop.

## 2. Push

```bash
git push -u origin HEAD
```

If the push fails (e.g. rejected, no access), stop and report the error.

## 3. Ensure Pull Request Exists

Skip this step if on `main` or `master`.

Check whether a PR already exists for the current branch:

```bash
gh pr view --json url 2>/dev/null
```

If no PR exists, create one in draft mode:

```bash
gh pr create --draft --fill
```

Report the PR URL.

## 4. Wait for Run

Wait a few seconds for CI to pick up the push, then list runs for the current branch:

```bash
gh run list --branch $(git branch --show-current) --limit 1
```

If no run appears after 30 seconds of polling, report and stop.

## 5. Watch

Use `gh run watch <run_id> --exit-status` to stream the run status until completion.

## 6. Report

After the run completes, report:

- **Status**: passed or failed
- **Jobs**: list each job with its status and duration
- **Failures**: if any job failed, fetch its logs with `gh run view <run_id> --log-failed` and include the relevant error output (truncated to the last 50 lines per failed job)

If the run passed, report success concisely. If it failed, include enough log context to diagnose the failure.
