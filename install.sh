#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

DRY_RUN=0
MIGRATE=0
PRUNE=0

SYNC_DIRS=(skills rules scripts)
TOP_LEVEL_FILES=(CLAUDE.md)
SHARED_KEYS_REPLACE=(model effortLevel statusLine enabledPlugins extraKnownMarketplaces)

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install skills, rules, scripts, and settings from this canonical clone into CLAUDE_DIR.

Options:
  --dry-run   Show what would be done without making any changes
  --migrate   Remove ~/.claude/.git and .gitignore before syncing (one-time migration)
  --prune     Remove files previously installed by this script that canonical no longer ships
  --help      Show this help message and exit

Environment:
  CLAUDE_DIR  Install target directory (default: \$HOME/.claude)

Current settings:
  REPO_DIR    = $REPO_DIR
  CLAUDE_DIR  = $CLAUDE_DIR
EOF
}

# Arg parse
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --migrate)
      MIGRATE=1
      shift
      ;;
    --prune)
      PRUNE=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Summary
echo "REPO_DIR:   $REPO_DIR"
echo "CLAUDE_DIR: $CLAUDE_DIR"
echo "DRY_RUN:    $DRY_RUN"
echo "MIGRATE:    $MIGRATE"
echo "PRUNE:      $PRUNE"

write_manifest() {
  if [[ $DRY_RUN -eq 1 ]]; then
    return
  fi
  local manifest="$CLAUDE_DIR/.skill-issue-manifest.json"
  {
    for dir in "${SYNC_DIRS[@]}"; do
      if [[ -d "$CLAUDE_DIR/$dir" ]]; then
        find "$CLAUDE_DIR/$dir" -type f
      fi
    done
    for f in "${TOP_LEVEL_FILES[@]}"; do
      if [[ -f "$CLAUDE_DIR/$f" ]]; then
        echo "$CLAUDE_DIR/$f"
      fi
    done
  } | sed "s|^$CLAUDE_DIR/||" | sort -u | jq -Rn '{files: [inputs] | sort | unique}' > "$manifest"
}

do_sync() {
  mkdir -p "$CLAUDE_DIR"

  local rsync_flags=(-a)
  if [[ $DRY_RUN -eq 1 ]]; then
    rsync_flags+=(--dry-run)
  fi

  for dir in "${SYNC_DIRS[@]}"; do
    if [[ -d "$REPO_DIR/$dir" ]]; then
      echo "Syncing $dir/ -> $CLAUDE_DIR/$dir/"
      rsync "${rsync_flags[@]}" "$REPO_DIR/$dir/" "$CLAUDE_DIR/$dir/"
    fi
  done

  for f in "${TOP_LEVEL_FILES[@]}"; do
    if [[ -f "$REPO_DIR/$f" ]]; then
      echo "Syncing $f -> $CLAUDE_DIR/$f"
      rsync "${rsync_flags[@]}" "$REPO_DIR/$f" "$CLAUDE_DIR/$f"
    fi
  done

  write_manifest
}

merge_settings() {
  local canonical="$REPO_DIR/settings.merge.json"
  local user="$CLAUDE_DIR/settings.json"

  if [[ ! -f "$canonical" ]]; then
    return
  fi

  if [[ $DRY_RUN -eq 0 && ! -f "$user" ]]; then
    echo "{}" > "$user"
  fi

  # Build jq replace expressions for scalar/object keys
  local jq_replace=""
  for key in "${SHARED_KEYS_REPLACE[@]}"; do
    jq_replace+="| if (\$c | has(\"${key}\")) then .${key} = \$c.${key} else . end "
  done

  local jq_program
  jq_program=$(cat <<'JQEOF'
  . as $u
  | $c[0] as $c
  REPLACE_PLACEHOLDER
  | .permissions //= {}
  | .permissions.allow = ((.permissions.allow // []) + ($c.permissions.allow // []) | unique | sort)
  | .hooks = (
      (.hooks // {}) as $hu
      | reduce ($c.hooks // {} | keys[]) as $ev (
          $hu;
          . + {
            ($ev): (
              (($hu[$ev] // []) | map(select(.matcher as $m | ($c.hooks[$ev] | map(.matcher) | index($m)) == null)))
              + ($c.hooks[$ev])
            )
          }
        )
    )
JQEOF
)
  # Substitute the replace expressions
  jq_program="${jq_program/REPLACE_PLACEHOLDER/$jq_replace}"

  local result
  if [[ -f "$user" ]]; then
    result=$(jq --slurpfile c "$canonical" "$jq_program" "$user")
  else
    result=$(echo "{}" | jq --slurpfile c "$canonical" "$jq_program")
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "=== settings.json (dry-run merge result) ==="
    echo "$result"
  else
    echo "$result" > "${user}.tmp"
    mv "${user}.tmp" "$user"
    echo "Merged settings.json"
  fi
}

if [[ $MIGRATE -eq 1 ]]; then
  echo "[migrate] Would remove $CLAUDE_DIR/.git and $CLAUDE_DIR/.gitignore"
fi

if [[ $PRUNE -eq 1 ]]; then
  echo "[prune] Would remove stale files tracked in $CLAUDE_DIR/.skill-issue-manifest.json"
fi

do_sync
merge_settings
