# Census Axes and History Recipes

## Axis table

The `Code` column maps to the `discover-patterns` taxonomy. An axis with fewer
than 2 members is not an axis; skip it silently.

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

Axes that tip at 2 are the ones that should be singular; a second one is
already a smell. Axes that tip at 3 are ones where a second instance is
ordinary. Never lower a threshold to 1: that fires on the first instance of a
thing, which is not a signal.

Enumerate members however fits the repository's language and layout (`find`
for directories, `grep -rl` for construction sites), and report the command
you ran.

## Repository maturity

```sh
FIRST_COMMIT_EPOCH=$(git log --reverse --format=%at | head -1)
AGE_DAYS=$(( ( $(date +%s) - FIRST_COMMIT_EPOCH ) / 86400 ))
# AGE_DAYS < 90  -> greenfield
```

## Co-change ratio

Of the commits that touched at least one member, the fraction that touched two
or more. `--name-only` with a pathspec lists only the matching paths, so the
per-commit line count is the member count directly.

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

## Introduction position

Each member's first appearance as a percentile of total history in commits.
`tail -1` takes the earliest add when a member was deleted and re-added, which
is the intended reading of "when did this first appear".

```sh
TOTAL=$(git rev-list --count HEAD)
for m in <member1> <member2> <memberN>; do
  INTRO=$(git log --diff-filter=A --format=%H -- "$m" | tail -1)
  BEHIND=$(git rev-list --count "$INTRO..HEAD")
  printf "%s  %d%%\n" "$m" $(( 100 * (TOTAL - BEHIND) / TOTAL ))
done
```

Members at 10%, 55%, and 92% are a stable axis. Members at 88%, 94%, and 99%
are a burst, and a burst is what makes an over-threshold axis `OVERDUE`.

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

For a greenfield repository, replace the `Co-change` row with
`Coupling | UNPROVEN (history under 90 days)` and never present a ratio as
evidence.
