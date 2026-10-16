---
name: review-trajectory
description: Use when the user asks whether it is time to refactor, consolidate, simplify, or re-architect, asks "is this the third time we have done this", "should we extract this", "are we duplicating too much", "is now the time to consolidate", or asks for a trajectory review, architectural drift check, duplication census, or tipping-point analysis. Also use when another skill dispatches a trajectory review.
---

# Trajectory Review

A review that asks where the codebase is heading, not whether the diff is
correct. It counts structural members, checks whether they change together,
and reports whether this diff is the point at which consolidation becomes
worth doing.

The output is advisory. It never asks for a change to the diff under review.

## What makes this review different

Every other reviewer reports defects in changed files. This one reports a
count across the whole repository, and the diff that triggers it is usually
clean.

A third entrypoint that copies the existing two conforms perfectly. The
conformance check passes it. The minimalism lens finds nothing premature,
because nothing was abstracted. The duplication it adds is an explicit
false-positive guard in `review-code/reference-architecture.md`. The signal is
the count, and the count is invisible to a reviewer scoped to changed files.

So this reviewer is **anti-scoped**. It reads the members the diff never
touches, because that is the only way to count past one.

## Workflow

### 1. Resolve scope and repository state

- The scope of **findings** is the whole repository. The diff only decides
  which axes are worth examining first.
- Get the diff under review: `git diff --name-only --diff-filter=d <base>...HEAD`.
  The default `<base>` is `main`. For a PR number, use `gh pr diff <number> --name-only`.
- Measure repository maturity with the recipe in
  [reference-census-axes.md](reference-census-axes.md). Under 90 days of
  elapsed history is greenfield.
- If the repository has fewer than 2 commits, stop. There is no history.

### 2. Census

For each axis in the table in [reference-census-axes.md](reference-census-axes.md),
count the members present in the tree at HEAD. Record the member paths, not
only the count. The paths are evidence and the report must cite them.

Run the enumeration commands the table gives, and adapt them to the
repository's language and layout. Report the command you actually ran.

Skip an axis that has fewer than 2 members.

### 3. Identify tipping axes

An axis tips when the count reaches its threshold **and** the diff under
review brought it there or carried it higher.

On a greenfield repository, drop every threshold by 1, floored at 2.

An axis that is already above threshold but that this diff did not touch is
still reportable, as `OVERDUE`. Rank it below an axis this diff tipped.

If no axis tips, say so in one line and stop. That is the common case and it
is a useful answer.

### 4. Compute history for tipping axes only

Run the co-change and introduction-position recipes from
[reference-census-axes.md](reference-census-axes.md) against the members of
each tipping axis.

Compute history only for axes that tip. Running `git log` across every axis on
every review is wasteful and slow.

On a greenfield repository, do not compute a co-change ratio. The history is
too short to support one. Record coupling as `UNPROVEN` instead.

### 5. Assign a verdict

| Verdict | Condition |
|---|---|
| `NOT YET` | Below threshold. State the count and what would tip it. This is the default. |
| `NOT COUPLED` | At or above threshold, co-change ratio under 0.2. |
| `TIPPING` | This diff crossed the threshold, ratio 0.5 or higher. |
| `OVERDUE` | Threshold was crossed earlier, ratio 0.5 or higher, members accelerating. |

A ratio between 0.2 and 0.5 gets the count and the ratio reported, and no
recommendation.

For `TIPPING` and `OVERDUE`, estimate both costs: consolidating now, and
consolidating after the axis grows at its current rate. The cost comparison is
what makes the verdict actionable.

### 6. Present results

Use the output template in [reference-census-axes.md](reference-census-axes.md).

If the review-all orchestrator supplied `REVIEW_DIR`, write
`${REVIEW_DIR}/TRAJECTORY.md`. Otherwise resolve it:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Write the run metadata header first. See [Run metadata header](#run-metadata-header).

Present the report to the user.

## Guards

Without these the review becomes a generator of architecture proposals that
nobody reads.

- **MUST NOT request a change to the diff under review.** The output is a
  proposal for separate work, shaped as a backlog item. This is what keeps the
  review from fighting `minimal-changes` and `implementation-minimalism`.
- **The default verdict is `NOT YET`.** Reaching for a refactor proposal on an
  ordinary diff is the failure mode this review exists to avoid.
- **Every verdict MUST cite** the member paths, the count, the threshold, the
  co-change numerator and denominator, and the commit range. Per
  `~/.claude/rules/probe-not-assume.md`. A verdict without counts is an
  opinion.
- **No consolidation recommendation when the ratio is under 0.2.** Members
  with independent histories are independent things. Report `NOT COUPLED` and
  move on.
- **Report at most 2 axes**, ranked by count multiplied by co-change ratio. A
  wall of refactor proposals gets ignored in full.
- **On a greenfield repository, do not skip the review and do not invent a
  ratio** from a handful of commits. Report the count, the lowered threshold,
  and the cheapness argument, and label coupling `UNPROVEN`.

## Run metadata header

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
TOTAL_COMMITS=$(git rev-list --count HEAD)
```

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT}
> **History:** {TOTAL_COMMITS} commits over {AGE_DAYS} days ({greenfield|established})
> **Base:** {BASE_REF}
```

## Guidelines

- Axis thresholds in the reference table are starting values chosen by
  judgment. Move them when a real run proves them wrong, and say in the report
  which threshold you applied.
- A `NOT YET` verdict is a successful run, not an empty one. State the count
  and the distance to the threshold so the next run has a baseline.
- Consolidation is not always extraction. Three entrypoints can collapse into
  one with a mode flag, share a bootstrap helper, or lose two of the three.
  Name which shape you mean.
- **REVIEW.md integration**: treat an axis named in `REVIEW.md` as a tipping
  axis at one member below its normal threshold.
- For the axis table, thresholds, git recipes, and the output template, see
  [reference-census-axes.md](reference-census-axes.md).
