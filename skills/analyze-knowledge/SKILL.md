---
name: analyze-knowledge
description: >-
  Use when the user asks who knows specific code, who should review a PR or
  files, what the lottery factor is, whether knowledge is concentrated or spread,
  who to talk to about a code area, or when suggesting reviewers beyond
  GitHub's built-in suggestions.
---

# Analyze Knowledge

Analyze git history to surface code expertise, suggest reviewers, and assess knowledge concentration risk.

## 1. Determine Mode and Scope

Auto-detect from user intent:

| Mode | Triggers | Default scope |
|---|---|---|
| **Reviewer** | "who should review", "find reviewers", "suggest reviewers" | Changed files: `git diff --name-only $(git merge-base HEAD main)..HEAD` |
| **Distribution** | "who knows", "lottery factor", "bus factor", "knowledge spread", "expertise" | User-specified directory, or repo root |

If scope is ambiguous, ask. Accept:
- Explicit paths or globs
- A PR number (extract changed files via `gh pr diff --name-only`)
- A directory
- "whole repo" (default for distribution mode)

Exclude generated files: check for `// Code generated` or `DO NOT EDIT` headers.

## 2. Normalize Authors

```bash
# Check for .mailmap
if [ -f .mailmap ]; then
  MAILMAP_FLAG="--use-mailmap"
else
  MAILMAP_FLAG=""
fi
```

- Pass `$MAILMAP_FLAG` to all git commands.
- If no `.mailmap`, group by author name (not email) to merge multiple addresses.
- Filter bots: exclude authors matching `[bot]`, `dependabot`, `renovate`, `github-actions`, or emails containing `noreply@github.com` with non-human names.

## 3. Collect Data (Tiered)

### Tier 1 — Commit counts (always run, fast)

```bash
git shortlog -sne --no-merges $MAILMAP_FLAG -- <paths> | head -20
```

Use this for a quick overview. Sufficient when the user just wants a rough sense.

### Tier 2 — File-level changes (default)

```bash
git log --no-merges --since="2 years ago" $MAILMAP_FLAG \
  --format='COMMIT:%H|%an|%aI' --numstat -- <paths>
```

Parse with jq pipelines from [reference.md](reference.md). This produces per-author, per-file change counts with timestamps for recency weighting.

For large repos or broad scope, add `--since="1 year ago"` to keep it fast.

### Tier 3 — Line-level blame (opt-in, small file sets only)

Only use when:
- User explicitly asks for deep/line-level analysis
- Scope is ≤15 files

```bash
git blame --porcelain $MAILMAP_FLAG <file> | \
  awk '/^author /{print}' | sort | uniq -c | sort -rn
```

Parallelize across files with `xargs -P4`.

## 4. Analyze

### Recency Weighting

Weight contributions by age:

| Age | Weight |
|---|---|
| < 6 months | 1.0 |
| 6–12 months | 0.7 |
| 12–24 months | 0.4 |
| > 24 months | 0.1 |

### Reviewer Mode

1. For each file in scope, compute weighted contribution score per author
2. Aggregate across all files — an author touching many of the changed files scores higher
3. Exclude the PR author (current `git config user.name`) from suggestions
4. Rank by score, present top 3–5
5. For each reviewer, list the directories/files where they have the most expertise

### Distribution Mode

1. Group files by directory (auto-detect depth: <20 files → no grouping, 20–200 → 1 level, 200+ → 2 levels)
2. Per area, compute:
   - **Top experts**: authors ranked by weighted contribution
   - **Lottery factor**: count of authors contributing ≥10% of weighted changes
   - **Concentration**: percentage of changes from the top contributor
3. Flag risk levels:
   - **HIGH**: lottery factor = 1 (single expert)
   - **MEDIUM**: lottery factor = 2
   - **LOW**: lottery factor ≥ 3

## 5. Present Results

Output directly to terminal. No file output.

### Reviewer Mode

```
## Suggested Reviewers (<N> files from <source>)

| Rank | Reviewer       | Score | Key areas                   | Last active  |
|------|----------------|-------|-----------------------------|--------------|
| 1    | Alice Smith    | 0.82  | internal/auth/, pkg/tokens/ | 2 weeks ago  |
| 2    | Bob Jones      | 0.65  | internal/auth/              | 1 month ago  |
| 3    | Carol Lee      | 0.41  | pkg/tokens/, cmd/server/    | 3 months ago |
```

### Distribution Mode

```
## Knowledge Distribution: <scope>

| Area                 | Top experts                       | Lottery factor | Risk   |
|----------------------|-----------------------------------|----------------|--------|
| internal/auth/oauth/ | Alice (0.9)                       | 1              | HIGH   |
| internal/auth/jwt/   | Alice (0.6), Bob (0.5)            | 2              | MEDIUM |
| internal/auth/rbac/  | Bob (0.4), Carol (0.3), Dan (0.3) | 3              | LOW    |

### Concentration Warnings

- **internal/auth/oauth/**: single expert — Alice authored 94% of recent changes
- **internal/auth/jwt/**: two experts with significant overlap
```

## Edge Cases

- **Squash-imported repo**: if total unique authors < 3 or median commits/author < 2, warn that history may not be representative
- **Monorepo with many contributors**: use tier 2 scoped to paths + time window; never run tier 3 on broad scope
- **No changes in scope** (reviewer mode): fall back to directory-level analysis of the files' parent directories

## Guidelines

- Use `jq` for all JSON/pipeline processing (see [reference.md](reference.md) for templates)
- Present findings conversationally — tables for data, plain text for warnings and recommendations
- When suggesting reviewers, mention *why* each person is suggested (which files/areas they know)
- For distribution analysis, lead with the highest-risk areas
