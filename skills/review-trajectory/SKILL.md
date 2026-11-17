---
name: review-trajectory
description: Use when the user asks whether it is time to refactor, consolidate, simplify, or re-architect, asks "is this the third time we have done this", "should we extract this", "are we duplicating too much", "is now the time to consolidate", or asks for a trajectory review, architectural drift check, duplication census, or tipping-point analysis. Also use when another skill dispatches a trajectory review.
---

# Trajectory Review

Answer one question: is this diff the point at which consolidating some
structural axis of the repository becomes worth doing? The answer rests on a
count of members across the whole tree and on whether those members change
together in git history. The diff under review is usually clean. It only
decides which axes to examine first.

The output is advisory. It describes separate work, shaped as a backlog item.

## Why this reviewer exists

Every other reviewer reports defects in changed files. A third entrypoint that
copies the existing two passes all of them: it conforms, it abstracts nothing,
and the duplication it adds is an explicit false-positive guard in
`review-code/reference-architecture.md`. The signal is the count, and a
reviewer scoped to changed files cannot count past one.

So this reviewer is **anti-scoped**: it reads the members the diff never
touches. Findings concern the repository, not the resolved file list.

## What a good finding is

One axis from [reference-census-axes.md](reference-census-axes.md), with:

- the members, enumerated by path, and the enumeration you actually ran;
- the count against the threshold you applied, and why that threshold;
- a co-change ratio as numerator and denominator over a stated commit range
  (`2/3 = 0.67` and `40/60 = 0.67` carry different confidence);
- each member's introduction position as a percentile of history in commits;
- what count and coupling mean together, and the cost of consolidating now
  against the cost after the axis grows at its current rate;
- a follow-up that names the shape of consolidation. Three entrypoints can
  collapse into one with a mode flag, share a bootstrap helper, or lose two of
  the three. "Extract an abstraction" is not a shape.

Evidence is counted members and actual git history. An impression that "this
looks duplicated" is not a finding. A verdict without counts is an opinion, per
`~/.claude/rules/probe-not-assume.md`.

## Verdicts

| Verdict | Meaning |
|---|---|
| `NOT YET` | Below threshold. The default. State the count and the distance to the threshold so the next run has a baseline. |
| `NOT COUPLED` | At or above threshold, ratio under 0.2. Independent histories mean independent things. Recommend nothing. |
| `TIPPING` | This diff crossed the threshold, ratio 0.5 or higher. |
| `OVERDUE` | Threshold crossed before this diff, ratio 0.5 or higher, members clustering in recent history. Rank below an axis this diff tipped. |

A ratio between 0.2 and 0.5 gets the count and ratio reported, with no
recommendation.

## Invariants

- **MUST NOT request a change to the diff under review.** This is what keeps
  the review from fighting `minimal-changes` and `implementation-minimalism`.
- **Every verdict MUST cite** member paths, count, threshold, co-change
  numerator and denominator, and commit range.
- **MUST NOT recommend consolidation when a measured ratio is under 0.2.**
- **Report at most 2 axes**, ranked by count multiplied by ratio. A wall of
  refactor proposals gets ignored in full.
- **Greenfield (under 90 days of elapsed history): lower every threshold by 1,
  floored at 2, and label coupling `UNPROVEN`.** Do not compute a ratio from a
  handful of commits, and do not skip the review. Report the count, the lowered
  threshold, and the cheapness argument. The ratio conditions in the verdict
  table do not apply: assign `TIPPING` or `OVERDUE` on count alone. Commit volume is not maturity; 400
  commits in three weeks is still greenfield.
- **Fewer than 2 commits: stop.** There is no history to read.
- **No axis tips: say so in one line and stop.** The orchestrator omits the
  section on that answer. It is the common case and a useful one.

## Lessons from past runs

- An axis tips only when the count reaches threshold **and** this diff brought
  it there or carried it higher. Already-over axes the diff did not touch are
  `OVERDUE`, not `TIPPING`.
- Compute history only for axes that tip. `git log` across every axis on every
  review is slow and buys nothing.
- Measure introduction position in commits, not calendar time. Calendar gaps
  are noise in a bursty repository. Members all at 0% landed in the initial
  commit; that is an original axis, not a burst.
- A `0/0` ratio means the member paths are wrong. Fix the enumeration before
  reporting anything.
- Thresholds in the reference table are judgment calls. Move one when a run
  proves it wrong, and say in the report which you applied. An axis named in
  the project's `REVIEW.md` tips one member early.

## Inputs and output

Diff: `git diff --name-only --diff-filter=d <base>...HEAD`, default base
`main`; for a PR number, `gh pr diff <number> --name-only`.

Use the output template in
[reference-census-axes.md](reference-census-axes.md). When the review-all
orchestrator supplied `REVIEW_DIR`, write `${REVIEW_DIR}/TRAJECTORY.md`;
otherwise resolve it:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Write the [run metadata header](#run-metadata-header) first, then present the
report to the user.

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
