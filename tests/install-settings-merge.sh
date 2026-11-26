#!/usr/bin/env bash
# Checks how install.sh merges settings.merge.json into an existing
# settings.json. Runs install.sh against throwaway CLAUDE_DIRs only.
#
# Usage: tests/install-settings-merge.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANON="$REPO_DIR/settings.merge.json"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fails=0

# install_into <name> <settings.json content or "none">: prints the merged settings path.
install_into() {
    local dir="$WORK/$1"
    mkdir -p "$dir"
    [ "$2" != none ] && printf '%s' "$2" >"$dir/settings.json"
    CLAUDE_DIR="$dir" "$REPO_DIR/install.sh" >"$dir/install.log" 2>&1 || {
        echo "FAIL $1: install.sh exited non-zero"; cat "$dir/install.log"; fails=$((fails + 1))
    }
    echo "$dir/settings.json"
}

# expect <name> <jq filter that must be true> <settings file>
expect() {
    if jq -e "$2" "$3" >/dev/null; then echo "PASS $1"; else
        echo "FAIL $1: $2"; jq -c '{enabledPlugins, extraKnownMarketplaces, model}' "$3"; fails=$((fails + 1))
    fi
}

canon_plugin=$(jq -r '.enabledPlugins | keys[0]' "$CANON")
canon_market=$(jq -r '.extraKnownMarketplaces | keys[0]' "$CANON")

user='{
  "model": "user-model",
  "enabledPlugins": {"local-only@example-market": true, "off-locally@example-market": false, "'"$canon_plugin"'": false},
  "extraKnownMarketplaces": {"example-market": {"source": {"source": "github", "repo": "example/market"}}},
  "localOnlyKey": 1
}'
s=$(install_into existing "$user")
expect "user-only enabled plugin kept" '.enabledPlugins["local-only@example-market"] == true' "$s"
expect "user-only disabled plugin kept as false" '.enabledPlugins["off-locally@example-market"] == false' "$s"
expect "canonical plugin value wins on conflict" ".enabledPlugins[\"$canon_plugin\"] == $(jq ".enabledPlugins[\"$canon_plugin\"]" "$CANON")" "$s"
expect "user-only marketplace kept" '.extraKnownMarketplaces["example-market"].source.repo == "example/market"' "$s"
expect "canonical marketplace added" ".extraKnownMarketplaces[\"$canon_market\"] == $(jq -c ".extraKnownMarketplaces[\"$canon_market\"]" "$CANON")" "$s"
expect "replace keys still replaced" ".model == $(jq '.model' "$CANON")" "$s"
expect "unmanaged user keys untouched" '.localOnlyKey == 1' "$s"

before=$(jq -S . "$s")
CLAUDE_DIR="$WORK/existing" "$REPO_DIR/install.sh" >/dev/null 2>&1
if [ "$before" = "$(jq -S . "$s")" ]; then echo "PASS second install is a no-op"; else
    echo "FAIL second install changed settings"; fails=$((fails + 1)); fi

s=$(install_into fresh none)
expect "no settings.json: canonical plugins only" ".enabledPlugins == $(jq -c '.enabledPlugins' "$CANON")" "$s"

s=$(install_into no-plugin-keys '{"model": "x"}')
expect "settings without plugin keys gets canonical ones" ".extraKnownMarketplaces == $(jq -c '.extraKnownMarketplaces' "$CANON")" "$s"

[ "$fails" -eq 0 ] && echo "all passed" || echo "$fails failed"
exit "$fails"
