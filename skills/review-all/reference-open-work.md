# Open Work Context

Step 1d of [SKILL.md](SKILL.md).


Surface in-flight work that may overlap with the (post-gate) scope so subagents can flag conflicts and duplicates. Skip the entire step if `REVIEW.md` declares `Open context: Skip: true`.

**Keyword extraction** from the changed file list (output of step 1):

1. Unique top-level dirs from changed paths.
2. Unique immediate parent dir names.
3. For `.go` files: `filepath.Base(pkg_dir)`.
4. For `.proto` files: the declared `package` line.

De-dup, lowercase, drop the stop-list `(internal|pkg|cmd|test|tests|vendor|gen|api|proto|src|lib)`. If the resulting keyword set is empty (e.g. all changed files sit inside stop-listed dirs), skip step 1d entirely — no useful filter is possible.

The keyword set drives the three source queries below (PRs, issues, Jira).

**Source: open GitHub PRs**

Skip if `REVIEW.md` declares `Open context: Skip: true` or `Open context: Include PRs: false`.

```sh
gh pr list --state open --limit 50 \
  --search "updated:>$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)" \
  --json number,title,headRefName,labels,updatedAt,url 2>/dev/null
```

Post-filter the JSON result: keep entries where `title || headRefName || labels[*].name` contains ≥1 keyword (case-insensitive substring). Sort by `updatedAt` desc, cap at 10.

**Fail-soft**: if `gh` errors (no auth, no remote, command not found), record one line `PR lookup unavailable: <reason>` under **Not checked** and continue with the remaining sources.

**Source: open GitHub issues**

Skip if `REVIEW.md` declares `Open context: Skip: true` or `Open context: Include issues: false`.

```sh
gh issue list --state open --limit 100 \
  --search "updated:>$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)" \
  --json number,title,labels,updatedAt,url 2>/dev/null
```

Post-filter: keep entries where `title || labels[*].name` contains ≥1 keyword. Sort by `updatedAt` desc, cap at 10.

**Label boost**: when a hit carries any of `bug`, `regression`, `flaky`, `security`, prefix the rendered row with `★` (visual emphasis only — ordering is unchanged).

**Fail-soft**: same as the PR source — record `Issue lookup unavailable: <reason>` under **Not checked** and continue.

**Source: open Jira tickets (opt-in)**

Run this substep **only** when `REVIEW.md` declares `Open context: Jira project: <KEY>`. No default; absence means no Jira lookup.

Use the MCP tool `claude_ai_Atlassian_Rovo:searchJiraIssuesUsingJql` with this JQL template (substitute `<KEY>` and `<RECENCY>`; `<RECENCY>` defaults to 30, override via `Open context: Recency days:`):

```
project = <KEY> AND statusCategory != Done AND updated >= -<RECENCY>d
```

Post-filter: keep entries where `summary || description` contains ≥1 keyword (case-insensitive substring). Sort by `updated` desc, cap at 10. Render each as `<KEY>-<NUM>: <summary>` with status.

**Fail-soft**: if the MCP is unavailable or returns an auth error, record `Jira lookup unavailable: <reason>` under **Not checked** and continue.

**Rendered block** — `Open work context`:

```markdown
## Open work context

Filter: changed-path keywords `<keyword-list>`; updated within last 30 days.

**Open PRs (n)**
| # | Title | Branch | Updated |
| --- | --- | --- | --- |
| [#412](url) | <title> | <branch> | YYYY-MM-DD |

**Open issues (n)**
| # | Title | Labels | Updated |
| --- | --- | --- | --- |
| ★[#523](url) | <title> | bug | YYYY-MM-DD |

**Open Jira (n)**
| Key | Summary | Status | Updated |
| --- | --- | --- | --- |
| [AUTH-2583](url) | <summary> | In Progress | YYYY-MM-DD |
```

Omit each sub-block when count is 0. Omit the whole section when all three counts are 0 (do not render an empty `## Open work context` heading).
