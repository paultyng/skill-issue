#!/usr/bin/env bash
# terseness-check.sh — measure whether the terse-output and terse-comments
# rules are reducing assistant message length over time.
#
# Reads ~/.claude/projects/*/*.jsonl (Claude Code session transcripts) modified
# in the last 35 days, extracts assistant text-message character lengths, and
# reports pre/post-rule cohort stats plus a weekly trend.
#
# Pre-rule push timestamp: 2026-05-08T20:00:00Z (commits 95d2067 + 635706c).
#
# Baseline (2026-05-11):
#   Pre-rule  n=9325  p50=110  p90=835   p99=3024  mean=323
#   Post-rule n=1303  p50=94   p90=1363  p99=3811  mean=417
#   Median dropped ~14% (suggestive); p90 inflated by content mix.

set -euo pipefail

CUTOFF="2026-05-08T20"
TMP=${TMPDIR:-/tmp}/terseness-$$
trap 'rm -f "$TMP".*' EXIT

# 1. Extract assistant text-message lengths with timestamps.
find ~/.claude/projects -maxdepth 2 -name "*.jsonl" -mtime -35 2>/dev/null | while read -r f; do
  jq -rc 'select(.type=="assistant" and (.message.content[0].type == "text")) | "\(.timestamp) \(.message.content[0].text | length)"' "$f" 2>/dev/null
done > "$TMP.all"

# 2. Pre/post split.
awk -v cutoff="$CUTOFF" '$1 <  cutoff {print $2}' "$TMP.all" | sort -n > "$TMP.pre"
awk -v cutoff="$CUTOFF" '$1 >= cutoff {print $2}' "$TMP.all" | sort -n > "$TMP.post"

stats() {
  local f=$1
  local n p50 p90 p99 mean
  n=$(wc -l < "$f")
  if [ "$n" -eq 0 ]; then
    echo "n=0 (no data)"
    return
  fi
  p50=$(awk -v n="$n" 'NR == int(n*0.50)+1' "$f")
  p90=$(awk -v n="$n" 'NR == int(n*0.90)+1' "$f")
  p99=$(awk -v n="$n" 'NR == int(n*0.99)+1' "$f")
  mean=$(awk '{s+=$1} END {if (NR>0) print int(s/NR); else print 0}' "$f")
  echo "n=$n p50=$p50 p90=$p90 p99=$p99 mean=$mean"
}

PRE=$(stats "$TMP.pre")
POST=$(stats "$TMP.post")

# 3. Weekly buckets.
WEEKLY=$(awk '
{
  d=substr($1,1,10); c=$2
  split(d,a,"-"); jd=(a[2]-1)*31+a[3]
  week=int((jd-96)/7)
  bucket[week]=bucket[week]" "c
  if (range[week]=="") range[week]=d
  range_end[week]=d
}
END {
  for (w in bucket) {
    cmd="echo \"" bucket[w] "\" | tr \" \" \"\\n\" | grep -v ^$ | sort -n"
    n=0
    while ((cmd|getline line)>0) a[n++]=line
    close(cmd)
    if (n==0) continue
    p50=a[int(n*0.50)]; p90=a[int(n*0.90)]; p99=a[int(n*0.99)]
    sum=0; for (i=0;i<n;i++) sum+=a[i]; mean=(n>0)?sum/n:0
    printf "| wk%d | %s..%s | %d | %d | %d | %d | %.0f |\n",
      w, range[w], range_end[w], n, p50, p90, p99, mean
    delete a
  }
}' "$TMP.all" | sort)

# 4. Compute verdict from p50 shift.
PRE_P50=$(echo "$PRE" | grep -oE 'p50=[0-9]+' | cut -d= -f2)
POST_P50=$(echo "$POST" | grep -oE 'p50=[0-9]+' | cut -d= -f2)
VERDICT="INCONCLUSIVE"
if [ -n "$PRE_P50" ] && [ -n "$POST_P50" ] && [ "$PRE_P50" -gt 0 ]; then
  # 100 * (1 - post/pre) as percentage drop
  PCT=$(awk -v a="$PRE_P50" -v b="$POST_P50" 'BEGIN{printf "%.0f", (1 - b/a) * 100}')
  if [ "$PCT" -gt 20 ]; then VERDICT="CONFIRMED ($PCT% p50 drop)"
  elif [ "$PCT" -gt 10 ]; then VERDICT="SUGGESTIVE ($PCT% p50 drop)"
  else VERDICT="INCONCLUSIVE ($PCT% p50 change)"
  fi
fi

# 5. Report.
cat <<EOF
# Terseness Trend Check — $(date -u +%Y-%m-%d)

## Headline (pre/post terse-rule push at $CUTOFF)

| Cohort | Stats |
|---|---|
| Pre  | $PRE |
| Post | $POST |

## Weekly trend

| Week | Range | n | p50 | p90 | p99 | mean |
|---|---|---|---|---|---|---|
$WEEKLY

## Verdict

**$VERDICT**

Baseline (2026-05-11): pre p50=110, post p50=94 — median dropped ~14% (suggestive).

## Caveats

- In-flight sessions started before the rule push don't reload rules mid-flight, so the "post" cohort understates the true effect.
- Content mix (planning-heavy weeks) inflates p90/p99 regardless of rule — p50 is the cleaner chat-reply signal.
- Compare this run's p50 to the baseline (94). A continued drop confirms; flat or rising suggests confounders dominate.
EOF
