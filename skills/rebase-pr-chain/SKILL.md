---
name: rebase-pr-chain
description: Rebase a chain of dependent pull requests sequentially, fixing conflicts along the way. Use when the user asks to rebase a PR chain, fix conflicts on multiple chained PRs, or mentions sequential/stacked PRs that need updating.
---

# Rebase PR Chain

Rebase a chain of dependent PRs so they are all up-to-date and mergeable.

## 1. Identify the Chain

Accept PR numbers from the user, or detect the chain automatically:

```bash
gh pr list --state open --json number,baseRefName,headRefName
```

Build the dependency graph: each PR's `baseRefName` points to the branch of the PR it depends on. Sort topologically (base branch first).

If the user provides explicit PR numbers (e.g. "33, 34, 35, 36, 37"), use that order directly.

## 2. Rebase Each PR

For each PR in the chain (starting from the one closest to the trunk):

### a. Fetch and checkout

```bash
git fetch origin <baseRefName> <headRefName>
git checkout <headRefName>
```

Verify the working tree is clean.

### b. Rebase

```bash
git rebase origin/<baseRefName>
```

If the rebase completes cleanly, skip to step (d).

### c. Resolve Conflicts

Follow the same conflict resolution strategy as [fix-pr-conflict](../fix-pr-conflict/SKILL.md):

1. List conflicting files: `git diff --name-only --diff-filter=U`
2. For each file, understand both sides and classify:
   - **Mechanical**: independent changes to nearby lines. Keep both.
   - **Semantic**: incompatible changes to the same logic. Resolve if the outcome is clear.
   - **Ambiguous**: design decisions or unclear intent. **Abort the rebase** (`git rebase --abort`) and escalate to the user with a description of the conflict.
3. After resolving: `git add <file>` then `git rebase --continue`
4. Repeat until the rebase completes or escalation is needed.

### d. Verify

Run verification per [verify-when-complete](../verify-when-complete/SKILL.md). Fix any issues from bad conflict resolution. If errors are unrelated, note them.

### e. Force push

```bash
git push --force-with-lease
```

## 3. Verify Chain Mergeability

After all PRs are rebased, verify each is mergeable:

```bash
gh pr view <number> --json mergeable,mergeStateStatus
```

If GitHub still reports conflicts (recomputation delay), wait a few seconds and re-check once.

## 4. Report

Present a summary table:

| PR | Branch | Status |
|----|--------|--------|
| #33 | feature-a | Mergeable |
| #34 | feature-b | Mergeable |
| #35 | feature-c | Conflict (escalated) |
