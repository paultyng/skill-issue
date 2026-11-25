#!/usr/bin/env bash
# Claude Code Stop hook: build and test the repo before the agent ends its
# turn, when code changed since the last stop. On failure, block the stop and
# hand the failure output back to the agent.
#
# Toolchain: Taskfile `build`/`test` tasks, else Go (`go build`/`go test`).
# A repo whose full run took longer than SLOW_SECS switches to testing only
# the Go packages with changed files.
#
# Opt out for a session: CLAUDE_VERIFY_ON_STOP=0.
set -uo pipefail

SLOW_SECS=${VERIFY_ON_STOP_SLOW_SECS:-120}  # full runs slower than this switch the repo to per-package tests
TAIL_LINES=60     # failure output lines returned to the agent

[ "${CLAUDE_VERIFY_ON_STOP:-1}" = "0" ] && exit 0

input=$(cat)
# A second stop after a block: let it through so the hook cannot loop.
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0

cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] && cd "$cwd" 2>/dev/null || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0

has_task=0
if [ -f Taskfile.yaml ] || [ -f Taskfile.yml ]; then
    tasks=$(task --list-all --json 2>/dev/null | jq -r '.tasks[].name' 2>/dev/null)
    grep -qx -e build -e test <<<"$tasks" && has_task=1
fi
[ "$has_task" = 1 ] || [ -f go.mod ] || exit 0

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-verify-on-stop"
mkdir -p "$state_dir"
state="$state_dir/$(printf '%s' "$root" | shasum | cut -c1-16)"
last_head="" last_pass="" last_fail="" slow=0
# shellcheck disable=SC1090
[ -f "$state" ] && . "$state"

save() {
    printf 'last_head=%q\nlast_pass=%q\nlast_fail=%q\nslow=%q\n' "$head" "$last_pass" "$last_fail" "$slow" >"$state"
}

head=$(git rev-parse HEAD 2>/dev/null || echo none)
# Changed paths: uncommitted (tracked and untracked), plus commits since the last stop.
changed=$( {
    git diff --name-only HEAD 2>/dev/null
    git ls-files --others --exclude-standard
    if [ -n "$last_head" ] && [ "$last_head" != "$head" ]; then
        git diff --name-only "$last_head" "$head" 2>/dev/null
    fi
} | grep -v '\.md$' | sort -u)

if [ -z "$changed" ]; then
    save
    exit 0
fi

content=$( {
    git diff HEAD 2>/dev/null
    git ls-files -z --others --exclude-standard | xargs -0 cat 2>/dev/null
} | shasum | cut -c1-16)
key="$head:$content"
# Already passed, or already reported this exact failure: do not run again.
if [ "$key" = "$last_pass" ] || [ "$key" = "$last_fail" ]; then
    save
    exit 0
fi

log=$(mktemp)
trap 'rm -f "$log"' EXIT

run_full() {
    if [ "$has_task" = 1 ]; then
        if grep -qx build <<<"$tasks"; then task build || return 1; fi
        if grep -qx test <<<"$tasks"; then task test || return 1; fi
    else
        go build ./... && go test ./...
    fi
}

run_changed_pkgs() {
    local pkgs
    pkgs=$(grep '\.go$' <<<"$changed" | xargs -n1 dirname 2>/dev/null | sort -u |
        while read -r d; do [ -d "$d" ] && echo "./$d"; done)
    go build ./... || return 1
    [ -z "$pkgs" ] && return 0
    # shellcheck disable=SC2086
    go test $pkgs
}

start=$(date +%s)
if [ "$slow" = 1 ] && [ -f go.mod ]; then
    mode="changed packages"
    run_changed_pkgs >"$log" 2>&1
else
    mode="full"
    run_full >"$log" 2>&1
fi
rc=$?
elapsed=$(( $(date +%s) - start ))
if [ "$mode" = full ]; then
    if [ "$elapsed" -gt "$SLOW_SECS" ]; then slow=1; else slow=0; fi
fi

if [ "$rc" -eq 0 ]; then
    last_pass="$key"
    save
    exit 0
fi

last_fail="$key"
save
reason="verify-on-stop: build/test failed ($mode run, ${elapsed}s). Fix the failure before you report the work as done, or tell the user it is still failing.

$(tail -n "$TAIL_LINES" "$log")"
jq -n --arg r "$reason" '{decision: "block", reason: $r}'
exit 0
