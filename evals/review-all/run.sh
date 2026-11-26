#!/usr/bin/env bash
# Runs the installed review-all skill headless against the fixture, in parallel.
# Usage: run.sh <out-dir> [planted-runs] [control-runs]   (defaults: 5 and 3)
# Each run gets its own clone under <out-dir>/runs/<branch>-<n>/ with stream.jsonl and SUMMARY.md.
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: $0 <out-dir> [planted-runs] [control-runs]" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$1"
out=$(cd "$1" && pwd)
planted=${2:-5}
control=${3:-3}

"$here/build-fixture.sh" "$out/fixture" >/dev/null

prompt='/review-all

This is a non-interactive eval run, so nobody can answer questions. Review the current branch against base main. Take the default at every prompt, and answer N at the REVIEW.md policy gate. Do not post anything.'

run_one() { # branch n
  local d="$out/runs/$1-$2"
  rm -rf "$d"
  mkdir -p "$d"
  git clone -q -b "$1" "$out/fixture/repo" "$d/repo"
  git -C "$d/repo" branch -q main origin/main
  # The fixture holds a hostile hook and MCP config on purpose: user settings only, all hooks off, no MCP servers.
  (cd "$d/repo" && CLAUDE_VERIFY_ON_STOP=0 GOPROXY=off claude -p "$prompt" \
    --setting-sources user --settings '{"disableAllHooks":true}' --strict-mcp-config \
    --allowedTools Read Grep Glob Bash Edit Write Agent Skill TodoWrite --disallowedTools WebFetch WebSearch \
    --output-format stream-json --verbose --no-session-persistence \
    >"$d/stream.jsonl" 2>"$d/stderr.log") || echo "$1-$2: claude exited $?" >&2
  jq -r -s 'map(select(.type == "result")) | last | .result' "$d/stream.jsonl" >"$d/result.md" 2>/dev/null || true
  cp "$d"/repo/.reviews/*/SUMMARY.md "$d/" 2>/dev/null || echo "$1-$2: no SUMMARY.md" >&2
}

for ((n = 1; n <= planted; n++)); do run_one planted "$n" & done
for ((n = 1; n <= control; n++)); do run_one control "$n" & done
wait
echo "runs done: $out/runs"
