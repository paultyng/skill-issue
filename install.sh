#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

DRY_RUN=0
PRUNE=0
BACKUP=0

SYNC_DIRS=(skills rules scripts)
TOP_LEVEL_FILES=(CLAUDE.md)
SHARED_KEYS_REPLACE=(model effortLevel statusLine enabledPlugins extraKnownMarketplaces)

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install skills, rules, scripts, and settings from this canonical clone into CLAUDE_DIR.

Options:
  --dry-run   Show what would be done without making any changes
  --prune     Remove files previously installed by this script that canonical no longer ships
  --backup    Tar CLAUDE_DIR to CLAUDE_DIR.backup-<epoch>.tar.gz before any changes
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
    --prune)
      PRUNE=1
      shift
      ;;
    --backup)
      BACKUP=1
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
echo "PRUNE:      $PRUNE"
echo "BACKUP:     $BACKUP"

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

do_backup() {
  if [[ ! -d "$CLAUDE_DIR" ]]; then
    echo "[backup] $CLAUDE_DIR does not exist, nothing to back up"
    return
  fi
  local backup
  backup="${CLAUDE_DIR}.backup-$(date +%s).tar.gz"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] tar -czf $backup -C $(dirname "$CLAUDE_DIR") $(basename "$CLAUDE_DIR")"
    return
  fi
  echo "[backup] tarring $CLAUDE_DIR -> $backup"
  tar -czf "$backup" -C "$(dirname "$CLAUDE_DIR")" "$(basename "$CLAUDE_DIR")"
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

  if [[ -f "$user" ]]; then
    if ! jq empty "$user" >/dev/null 2>&1; then
      echo "error: $user is not valid JSON; aborting merge" >&2
      return 1
    fi
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

do_prune() {
  local manifest="$CLAUDE_DIR/.skill-issue-manifest.json"

  if [[ ! -f "$manifest" ]]; then
    echo "[prune] no manifest found, skipping"
    return
  fi

  local stale_files=()
  while IFS= read -r path; do
    case "$path" in
      /*|*..*)
        echo "[prune] skipping unsafe manifest entry: $path" >&2
        continue
        ;;
    esac
    if [[ ! -e "$REPO_DIR/$path" ]]; then
      stale_files+=("$path")
    fi
  done < <(jq -r '.files[]' "$manifest")

  if [[ ${#stale_files[@]} -eq 0 ]]; then
    echo "[prune] no stale files found"
    return
  fi

  for path in "${stale_files[@]}"; do
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[prune] would remove: $CLAUDE_DIR/$path"
    else
      echo "[prune] removing: $CLAUDE_DIR/$path"
      rm -f "$CLAUDE_DIR/$path"
      rmdir -p "$(dirname "$CLAUDE_DIR/$path")" 2>/dev/null || true
    fi
  done

}

[[ $BACKUP -eq 1 ]] && do_backup
[[ $PRUNE -eq 1 ]] && do_prune

do_sync
merge_settings
