#!/usr/bin/env bash
# pr-deeplink.sh — emit a Markdown link from a `path:line` reference to the
# GitHub PR /files tab, anchored at the line in the PR's diff view.
#
# Used by review-* skills to wrap finding references when the review is
# scoped to a GitHub PR. The display text stays `path:line`; only the link
# target carries the URL.
#
# Usage:
#   pr-deeplink.sh <pr-url> <path> <line> [side]
#     side: R (right/additions, default) or L (left/deletions)
#
#   pr-deeplink.sh <pr-url> <path>          # file-level link, no line anchor
#
# Output: a single line of Markdown, e.g.
#   [src/foo.go:42](https://github.com/o/r/pull/123/files#diff-abc...R42)
#
# Exits non-zero on malformed input. Empty pr-url prints the plain
# `path:line` form (no link), so callers can use it unconditionally.

set -euo pipefail

pr_url="${1:-}"
path="${2:-}"
line="${3:-}"
side="${4:-R}"

if [ -z "$path" ]; then
  echo "usage: $(basename "$0") <pr-url> <path> [line] [side]" >&2
  exit 2
fi

# Build display text first; same shape regardless of link mode.
if [ -n "$line" ]; then
  display="${path}:${line}"
else
  display="$path"
fi

# No PR scope → emit plain text.
if [ -z "$pr_url" ]; then
  printf '%s\n' "$display"
  exit 0
fi

# GitHub anchors files in PR /files by the first 32 hex chars of sha256(path).
diff_id=$(printf '%s' "$path" | shasum -a 256 | cut -c1-32)

if [ -n "$line" ]; then
  case "$side" in
    R|L) ;;
    *) echo "side must be R or L" >&2; exit 2 ;;
  esac
  url="${pr_url%/}/files#diff-${diff_id}${side}${line}"
else
  url="${pr_url%/}/files#diff-${diff_id}"
fi

printf '[%s](%s)\n' "$display" "$url"
