# Reference: Data Pipelines and Scoring

## Table of Contents

- [Git Log Parsing](#git-log-parsing)
- [Recency Bucketing](#recency-bucketing)
- [Aggregation](#aggregation)
- [Bot Patterns](#bot-patterns)

## Git Log Parsing

Tier 2 output format and conversion to JSONL for jq processing:

```bash
# Produce parseable output
git log --no-merges --since="2 years ago" $MAILMAP_FLAG \
  --format='COMMIT:%H|%an|%aI' --numstat -- <paths> \
  > /tmp/git-log-raw.txt
```

Convert to JSONL (one record per file-change):

```bash
awk -F'\t' '
  /^COMMIT:/ {
    split(substr($0,8), parts, "|")
    hash=parts[1]; author=parts[2]; date=parts[3]
    next
  }
  NF==3 && $1 ~ /^[0-9]+$/ {
    print "{\"hash\":\"" hash "\",\"author\":\"" author "\",\"date\":\"" date "\",\"added\":" $1 ",\"deleted\":" $2 ",\"file\":\"" $3 "\"}"
  }
' /tmp/git-log-raw.txt > /tmp/git-log.jsonl
```

## Recency Bucketing

Apply time weights to each record:

```bash
jq -c --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  def age_weight:
    (($now | fromdateiso8601) - (.date | fromdateiso8601)) / 86400 |
    if . < 180 then 1.0
    elif . < 365 then 0.7
    elif . < 730 then 0.4
    else 0.1
    end;
  . + {weight: age_weight, changes: (.added + .deleted)}
' /tmp/git-log.jsonl > /tmp/git-log-weighted.jsonl
```

## Aggregation

### Per-author, per-file scores

```bash
jq -s '
  group_by(.author) | map({
    author: .[0].author,
    total_weighted: (map(.changes * .weight) | add),
    files: (group_by(.file) | map({
      file: .[0].file,
      weighted: (map(.changes * .weight) | add)
    }) | sort_by(-.weighted)),
    last_date: (map(.date) | sort | last)
  }) | sort_by(-.total_weighted)
' /tmp/git-log-weighted.jsonl
```

### Per-directory concentration (distribution mode)

```bash
jq -s '
  # Add directory field (1 level deep)
  map(. + {dir: (.file | split("/")[0:2] | join("/"))}) |
  group_by(.dir) | map({
    dir: .[0].dir,
    authors: (group_by(.author) | map({
      author: .[0].author,
      weighted: (map(.changes * .weight) | add)
    }) | sort_by(-.weighted)),
    total: (map(.changes * .weight) | add)
  }) | map(. + {
    top_pct: (if .total > 0 then (.authors[0].weighted / .total * 100 | round) else 0 end),
    lottery_factor: ([.authors[] | select(.weighted / .total >= 0.10)] | length)
  }) | sort_by(.lottery_factor)
' /tmp/git-log-weighted.jsonl
```

### Reviewer scoring (reviewer mode)

Given a file list in `/tmp/scope-files.txt`:

```bash
jq -s --slurpfile scope <(jq -R '.' /tmp/scope-files.txt | jq -s '.') '
  [.[] | select(.file as $f | $scope[0] | any(. == $f))] |
  group_by(.author) | map({
    author: .[0].author,
    score: (map(.changes * .weight) | add),
    file_count: (map(.file) | unique | length),
    files: (map(.file) | unique),
    last_date: (map(.date) | sort | last)
  }) | sort_by(-.score) |
  map(. + {
    score_norm: (.score / (.[0].score // 1) | . * 100 | round / 100)
  })
' /tmp/git-log-weighted.jsonl
```

## Bot Patterns

Filter these from results:

```bash
jq -c 'select(
  (.author | test("\\[bot\\]$") | not) and
  (.author | test("^(dependabot|renovate|github-actions|snyk-bot)"; "i") | not) and
  (.author | test("^(mergify|codecov|greenkeeper)"; "i") | not)
)'
```
