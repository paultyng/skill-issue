# Census Axes and History Recipes

## Contents

- [Axis table](#axis-table)
- [Enumeration commands](#enumeration-commands)
- [Threshold rules](#threshold-rules)
- [Recipe: repository maturity](#recipe-repository-maturity)
- [Recipe: co-change ratio](#recipe-co-change-ratio)
- [Recipe: introduction position](#recipe-introduction-position)
- [Degenerate cases](#degenerate-cases)
- [Output template](#output-template)

## Axis table

The `Code` column maps to the `discover-patterns` taxonomy. That skill names
the pattern categories. It does not enumerate structural members, so the
`Enumerate` column below is specific to this skill.

Enumeration commands are starting points. Adapt them to the repository's
language and layout, and report what you actually ran.

| Axis | Code | Unit counted | Threshold |
|---|---|---|---|
| Entrypoints | STRUCT | A process start point: a `main` package, a `cmd/` subdirectory, a serverless handler | 3 |
| Transport surfaces | XPORT | A served protocol stack: HTTP mux, gRPC server, CLI root, queue consumer | 3 |
| Config sources | CFG | A distinct mechanism that reads configuration | 3 |
| DI / composition roots | DI | A function that assembles the dependency graph | 3 |
| Test harnesses | TEST | A fixture or server builder used by many tests | 3 |
| Retry implementations | STRUCT | A distinct retry or backoff helper | 2 |
| Error taxonomies | ERR | A distinct error hierarchy or sentinel family | 2 |
| Observability init | OBS | A tracer, meter, or logger construction site | 2 |

### Enumeration commands

Starting points. Adapt them to the repository's language and layout, and
report the command you actually ran.

```sh
# Entrypoints
find . -name main.go -not -path '*/vendor/*'; ls -d cmd/*/ 2>/dev/null
# Transport surfaces
grep -rlnE 'ListenAndServe|grpc.NewServer|cobra.Command\{' .
# Config sources
grep -rlnE 'viper\.|envconfig\.|flag.Parse|os.Getenv' .
# DI / composition roots
grep -rlnE 'wire.Build|func newApp|func wire' .
# Test harnesses
grep -rlnE 'func newTest|func setupTest|func testServer' .
# Retry implementations
grep -rlnE 'backoff\.|func retry|MaxRetries' .
# Error taxonomies
grep -rlnE 'errors.New\(|func \(e \*.*\) Error\(\)' .
# Observability init
grep -rlnE 'otel.SetTracerProvider|slog.New|zap.New' .
```

## Threshold rules

An axis **tips** when its member count reaches the threshold and the diff under
review is what brought it there, or carried it higher.

Axes that tip at 2 are the ones that should be singular. A second retry helper,
a second error taxonomy, or a second tracer setup is already a smell. Axes that
tip at 3 are ones where a second instance is ordinary.

On a greenfield repository (see the maturity recipe), drop every threshold by
1, **floored at 2**. Never drop a threshold to 1: that fires on the first
instance of a thing, which is not a signal about anything.

## Recipe: repository maturity

Greenfield is under 90 days of elapsed history. Commit volume is deliberately
not the metric. A prototype with 400 commits in three weeks is greenfield; 80
commits over four years is not.

```sh
FIRST_COMMIT_EPOCH=$(git log --reverse --format=%at | head -1)
AGE_DAYS=$(( ( $(date +%s) - FIRST_COMMIT_EPOCH ) / 86400 ))
# AGE_DAYS < 90  -> greenfield
```

## Recipe: co-change ratio

Of the commits that touched at least one member of the axis, the fraction that
touched two or more. `--name-only` combined with a pathspec lists only the
matching paths, so the per-commit count is the member count directly.

```sh
git log --format='%x00%H' --name-only -- <member1> <member2> <memberN> \
 | awk -v RS='\0' 'NR>1 {
     n=0; split($0, L, "\n")
     for (i=2; i<=length(L); i++) if (L[i] != "") n++
     if (n > 0) tot++
     if (n > 1) multi++
   } END {
     if (tot == 0) { print "0/0 = n/a"; exit }
     printf "%d/%d = %.2f\n", multi, tot, multi/tot
   }'
```

Read the result as:

- `>= 0.5`: the members change together. Consolidation is justified.
- `< 0.2`: the members have independent histories. Report `NOT COUPLED` and
  recommend no action.
- Between: report the ratio and make no recommendation.

Always report the numerator and denominator, not only the ratio. `2/3 = 0.67`
and `40/60 = 0.67` carry very different confidence.

## Recipe: introduction position

Each member's first appearance, as a percentile of total history measured in
commits. Calendar gaps are noise in a bursty repository.

```sh
TOTAL=$(git rev-list --count HEAD)
for m in <member1> <member2> <memberN>; do
  INTRO=$(git log --diff-filter=A --format=%H -- "$m" | tail -1)
  BEHIND=$(git rev-list --count "$INTRO..HEAD")
  printf "%s  %d%%\n" "$m" $(( 100 * (TOTAL - BEHIND) / TOTAL ))
done
```

The axis is **accelerating** when the members cluster in the most recent
fraction of history out of proportion to their count. Three members at 10%,
55%, and 92% is a stable axis. Three members at 88%, 94%, and 99% is a burst.

## Degenerate cases

- **All members at 0%.** They landed in the initial commit. The axis is
  original to the repository, not a burst. Do not report acceleration.
- **`0/0 = n/a` ratio.** No commit touched any member, which means the paths
  are wrong. Fix the enumeration before reporting anything.
- **Fewer than 2 members.** No axis, no verdict. Skip it silently.
- **A member was deleted and re-added.** `tail -1` takes the earliest add,
  which is the intended reading of "when did this first appear".

## Output template

Advisory. No severity column, because these are not defects.

```markdown
## Trajectory

**<Axis name> — <VERDICT>**

| | |
|---|---|
| Members | `path/one`, `path/two`, `path/three` |
| Count | 3 (threshold 3) |
| Co-change | 10/13 = 0.77 over <commit range> |
| Introduction | 12%, 71%, 94% of 132 commits |
| Maturity | established (205 days) |

<One paragraph: what the count and coupling mean together, and the cost of
consolidating now against the cost of consolidating later.>

**Proposed follow-up:** <backlog-shaped task, or "none" for NOT YET / NOT COUPLED.>
```

Verdicts: `NOT YET` (default), `NOT COUPLED`, `TIPPING`, `OVERDUE`.

For a greenfield repository, add a `Coupling` row reading
`UNPROVEN (history under 90 days)` and never present a ratio as evidence.
