#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

DRY_RUN=0
MIGRATE=0
PRUNE=0

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

# Placeholder dispatch (sync logic added in Task 6+)
if [[ $DRY_RUN -eq 1 ]]; then
  echo "[dry-run] Would sync files from $REPO_DIR to $CLAUDE_DIR"
fi

if [[ $MIGRATE -eq 1 ]]; then
  echo "[migrate] Would remove $CLAUDE_DIR/.git and $CLAUDE_DIR/.gitignore"
fi

if [[ $PRUNE -eq 1 ]]; then
  echo "[prune] Would remove stale files tracked in $CLAUDE_DIR/.skill-issue-manifest.json"
fi
