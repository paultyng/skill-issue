# Review-all: run metadata header

Capture once near `REVIEW_DIR` resolution and prepend to every output document this skill writes (and require subagents that write their own files to do the same):

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
GIT_SUBJECT=$(git log -1 --pretty=%s)
# When scope is diff-based, also capture:
# BASE_REF=<base, e.g. main>; BASE_COMMIT=$(git rev-parse --short "$BASE_REF")
```

Header template (place at the very top of the output `.md`, before the H1 title):

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Base:** {BASE_REF} @ {BASE_COMMIT}   <!-- omit when scope is not diff-based -->
> **Scope:** {scope description, e.g. "changed files (PR #42)" or "full codebase" or "./internal/auth/..."}
```
