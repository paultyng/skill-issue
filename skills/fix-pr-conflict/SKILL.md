---
name: fix-pr-conflict
description: Resolve merge conflicts on a pull request by rebasing onto the base branch. Use when a PR is not mergeable, has merge conflicts, or the user asks to fix conflicts on a PR.
---

# Fix PR Conflict

Resolve merge conflicts on a pull request so it becomes mergeable.

## 1. Identify the PR

Determine the PR number using these sources, in order of priority:

1. Explicit number from the user's request.
2. A PR created earlier in this conversation (check chat history for `gh pr create` output or PR URLs).
3. The current branch via `gh pr view`.

```bash
# Try the current branch first
gh pr view --json number,headRefName,baseRefName,mergeable,mergeStateStatus 2>/dev/null

# Or by explicit number
gh pr view <number> --json headRefName,baseRefName,mergeable,mergeStateStatus
```

If the PR is already mergeable, report that and stop.

## 2. Prepare

```bash
git fetch origin <baseRefName> <headRefName>
git checkout <headRefName>
```

Verify the working tree is clean before proceeding.

## 3. Rebase onto Base Branch

```bash
git rebase origin/<baseRefName>
```

If the rebase completes with no conflicts, skip to step 5.

## 4. Resolve Conflicts

When the rebase stops on a conflict:

1. **List conflicting files**: `git diff --name-only --diff-filter=U`
2. **For each conflicting file**, understand both sides:
   - Read the file to see the conflict markers.
   - Check what the base branch changed: `git log --oneline origin/<baseRefName> -- <file>` and read the relevant commits.
   - Check what the PR branch changed: review the current commit being applied (`git log --oneline -1 REBASE_HEAD`).
3. **Classify the conflict**:
   - **Mechanical**: both sides changed nearby lines but the intent is independent (e.g. adjacent import additions, unrelated function changes). Resolve by keeping both changes with correct formatting.
   - **Semantic**: both sides changed the same logic or API in incompatible ways. Attempt to resolve if the correct outcome is clear from context.
   - **Ambiguous**: the conflict involves a design decision, requirement tradeoff, or unclear intent. **Stop, abort the rebase** (`git rebase --abort`), and escalate to the user with a description of the conflict and what options exist.
4. **After resolving each file**: `git add <file>`
5. **Continue the rebase**: `git rebase --continue`
6. **Repeat** until the rebase completes or an ambiguous conflict requires escalation.

## 5. Verify

Run verification per [verify-when-complete](../verify-when-complete/SKILL.md). If failures stem from a bad conflict resolution, fix and amend the relevant commit. If errors are unrelated, report them.

## 6. Force Push

```bash
git push --force-with-lease
```

Then verify the PR is now mergeable:

```
gh pr view <number> --json mergeable,mergeStateStatus
```

Report the result. If GitHub still reports conflicts (can take a few seconds to recompute), wait and re-check once.
