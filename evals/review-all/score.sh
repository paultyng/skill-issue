#!/usr/bin/env bash
# Scores review-all eval runs written by run.sh.
# Usage: score.sh <out-dir>
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out-dir>" >&2; exit 2; }
out=$(cd "$1" && pwd)
tsv="$out/fixture/MANIFEST.tsv"
tol=3 # a cited line within this distance of the planted line counts as a hit

# finding_rows <summary>: table rows of the findings sections.
finding_rows() {
  awk '/^## /{f = ($0 ~ /^## Findings/)} /<summary>Findings/{f=1} f && /^\|/' "$1" | grep -v -E '^\|[- |]*\|$|\| *Category *\|' || true
}

# cites <file> <line> <text-on-stdin>: prints each input line citing file:N with |N-line| <= tol.
cites() {
  local re=${1//./\\.}
  awk -v re="(^|[^[:alnum:]_./-])${re}:[0-9]+" -v want="$2" -v tol="$tol" '{
    s = $0
    while (match(s, re)) {
      m = substr(s, RSTART, RLENGTH); sub(/.*:/, "", m)
      d = m - want; if (d < 0) d = -d
      if (d <= tol) { print; next }
      s = substr(s, RSTART + RLENGTH)
    }
  }'
}

# dispatch <stream.jsonl>: one label per top-level subagent, from its description
# ("Payments lens review" -> lens:payments, "Security review" -> security).
dispatch() {
  jq -r 'select(.type == "assistant" and .parent_tool_use_id == null) | .message.content[]?
    | select(.type == "tool_use" and (.name == "Agent" or .name == "Task"))
    | .input.description // "other" | ascii_downcase
    | if test("\\blens\\b") then "lens:" + ((capture("(?<id>[a-z0-9-]+) lens") // capture("lens:? (?<id>[a-z0-9-]+)")).id // "?")
      elif test("depend") then "dependency"
      elif test("summar") then "summarizer"
      elif test("coverage") then "coverage"
      else sub(" (review|evaluation|check)$"; "") | gsub(" "; "-") end' "$1" 2>/dev/null | sort || true
}

hitlog=$(mktemp)
trap 'rm -f "$hitlog"' EXIT
printf '## Runs\n\n| Run | Blocking | Non-blocking | P0/P1 rows | Dispatch |\n|---|---|---|---|---|\n'
for d in "$out"/runs/*/; do
  run=$(basename "$d")
  s="$d/SUMMARY.md"
  dispatch "$d/stream.jsonl" >"$d/dispatch.txt"
  disp=$(uniq -c <"$d/dispatch.txt" | awk '{printf "%s%s%s", sep, $2, ($1 > 1 ? "×" $1 : ""); sep=", "}')
  if [ ! -s "$s" ]; then
    printf '| %s | no SUMMARY.md | | | %s |\n' "$run" "$disp"
    continue
  fi
  b=$(grep -o -m1 -E '\*\*[0-9]+ blocking' "$s" | grep -o -E '[0-9]+' || echo '?')
  nb=$(grep -o -m1 -E '[0-9]+ non-blocking' "$s" | grep -o -E '[0-9]+' || echo '?')
  p01=$(finding_rows "$s" | awk -F'|' '$3 ~ /CRITICAL|HIGH|P0|P1/' | wc -l | tr -d ' ')
  printf '| %s | %s | %s | %s | %s |\n' "$run" "$b" "$nb" "$p01" "$disp"
  echo "$b" >"$d/blocking.txt"

  case $run in planted-*) ;; *) continue ;; esac
  while IFS=$'\t' read -r id file line kind kw; do
    case $kind in
      finding) n=$(finding_rows "$s" | awk -F"|" '$2 !~ /^ *coverage *$/' | cites "$file" "$line" | wc -l) ;;
      merged) n=$(finding_rows "$s" | cites "$file" "$line" | wc -l); [ "$n" -eq 1 ] || n=0 ;;
      coverage) n=$(grep -c -E "COVERAGE \| file=$file \| status=(read-fully|skimmed)" "$d/stream.jsonl" || true) ;;
      lens-flagged) n=$(awk '/^## /{f = ($0 ~ /^## Not checked/)} f' "$s" | grep -i lens | grep -c -i -w "$kw" || true) ;;
      lens-not-dispatched) grep -q -x "lens:$kw" "$d/dispatch.txt" && n=0 || n=1 ;;
    esac
    if [ "$n" -gt 0 ]; then echo "$id" >>"$hitlog"; fi
  done < <(tail -n +2 "$tsv")
done

np=$(find "$out/runs" -maxdepth 1 -name 'planted-*' -type d | wc -l | tr -d ' ')
printf '\n## Per-defect hit rate (planted, %s runs)\n\n| Id | Kind | Hits |\n|---|---|---|\n' "$np"
while IFS=$'\t' read -r id _ _ kind _; do
  printf '| %s | %s | %s/%s |\n' "$id" "$kind" "$(grep -c -x -F "$id" "$hitlog" || true)" "$np"
done < <(tail -n +2 "$tsv")

printf '\n## Stability\n\n'
for br in planted control; do
  sets=$(for f in "$out"/runs/"$br"-*/dispatch.txt; do [ -e "$f" ] || continue; sort -u "$f" | paste -s -d, -; done | sort | uniq -c | wc -l | tr -d ' ') || sets=0
  verdicts=$(cat "$out"/runs/"$br"-*/blocking.txt 2>/dev/null | awk '{print ($1 > 0 ? "blocking" : "clear")}' | sort | uniq -c | awk '{printf "%s%s %s", sep, $1, $2; sep=", "}') || true
  printf -- '- %s: %s distinct dispatch set(s); verdicts: %s\n' "$br" "$sets" "${verdicts:-none}"
done
