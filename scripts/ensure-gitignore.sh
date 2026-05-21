#!/usr/bin/env bash
# Idempotently append one or more patterns to ./.gitignore under a
# "Claude Code working files" section header. Safe to call from any
# skill before writing outputs like .plans/ or .reviews/.
#
# Usage: ensure-gitignore.sh <pattern> [<pattern>...]
set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "usage: $(basename "$0") <pattern> [<pattern>...]" >&2
    exit 2
fi

HEADER='# Claude Code working files'

for pat in "$@"; do
    [ -n "$pat" ] || continue
    [ -f .gitignore ] || : > .gitignore
    if ! grep -qxF -- "$pat" .gitignore; then
        if ! grep -qxF "$HEADER" .gitignore; then
            printf '\n%s\n' "$HEADER" >> .gitignore
        fi
        printf '%s\n' "$pat" >> .gitignore
    fi
done
