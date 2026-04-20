# fix: skill issue

Personal user-level agent skills, rules, and settings. Available across all projects.

## Install

Clone or symlink this repo to the user-level config directory:

| Editor | Path |
|--------|------|
| [Claude Code](https://docs.claude.com/en/docs/claude-code/skills) | `~/.claude/` |
| [Cursor](https://cursor.com/) | `~/.cursor/` |

## Skills

| Skill | Description |
|-------|-------------|
| [analyze-knowledge](skills/analyze-knowledge/SKILL.md) | Analyze git history to surface code expertise, suggest reviewers, and assess knowledge concentration risk. |
| [audit-history](skills/audit-history/SKILL.md) | Audit past agent sessions and memory health — surface friction, stale memories, and gaps; optionally clean up. |
| [ci-debug-loop](skills/ci-debug-loop/SKILL.md) | Watch a CI run, diagnose failures, apply fixes, and re-trigger until green or escalate. |
| [create-decision-document](skills/create-decision-document/SKILL.md) | Create or update a Notion decision doc with a terse options/pros/cons/recommendation template. |
| [create-jira-item](skills/create-jira-item/SKILL.md) | Create Jira issues (stories, epics, initiatives) with custom field introspection. |
| [create-rule](skills/create-rule/SKILL.md) | Create or update Claude Code rule files with proper format and path scoping. |
| [create-skill](skills/create-skill/SKILL.md) | Create well-structured Cursor agent skills following best practices. |
| [discover-patterns](skills/discover-patterns/SKILL.md) | Explore a codebase's architecture, audit consistency, and generate a patterns document for conformance checking. |
| [fix-pr-conflict](skills/fix-pr-conflict/SKILL.md) | Resolve merge conflicts on a pull request by rebasing onto the base branch. |
| [push-and-watch](skills/push-and-watch/SKILL.md) | Push local commits to the remote, ensure a draft PR exists, and monitor the GitHub Actions run until completion. |
| [rebase-pr-chain](skills/rebase-pr-chain/SKILL.md) | Rebase a chain of dependent PRs sequentially, fixing conflicts along the way. |
| [review-all](skills/review-all/SKILL.md) | Comprehensive review orchestrator — launches review-security, review-reliability, review-code, review-database, and review-documentation as parallel subagents and consolidates results. |
| [review-code](skills/review-code/SKILL.md) | Review code architecture (SOLID, design patterns, package design), Go best practices, and protobuf/API design using manual analysis and static analysis tools. |
| [review-database](skills/review-database/SKILL.md) | Review database usage for migration safety, query performance, connection/transaction management, and schema design (PostgreSQL and MySQL). |
| [review-documentation](skills/review-documentation/SKILL.md) | Review documentation quality and sync with implementation across Go doc comments, proto comments, OpenAPI specs, markdown files, and example tests. |
| [review-reliability](skills/review-reliability/SKILL.md) | Review reliability covering graceful shutdown, gRPC production patterns, and stability patterns/anti-patterns. |
| [review-security](skills/review-security/SKILL.md) | Security review using STRIDE threat modeling, OWASP Top 10 analysis, and automated scanning (gosec, govulncheck). |
| [set-session-context](skills/set-session-context/SKILL.md) | Set session name and color based on the current branch context. Auto-invoked on branch switches. |
| [ship-it](skills/ship-it/SKILL.md) | End-to-end shipping workflow: fmt, lint, test, changelog, commit (conventional commits), push, update PR, and suggest reviewers. |
| [verify-when-complete](skills/verify-when-complete/SKILL.md) | Run format, lint, build, and test verification before claiming work is complete. Detects project toolchain automatically. |

## Rules

Rules load automatically every session (or on file-path match) and shape agent behavior.

| Rule | Description |
|------|-------------|
| [auto-verify-after-rebase](rules/auto-verify-after-rebase.md) | Run fmt/lint/build automatically after rebase, merge, or cherry-pick. |
| [draft-prs](rules/draft-prs.md) | Always create draft PRs unless explicitly told otherwise. |
| [escalation](rules/escalation.md) | Stop and ask a human before making ambiguous or architectural decisions. |
| [git-no-amend](rules/git-no-amend.md) | No `--amend` unless asked. Conventional Commits format. |
| [go-defaults](rules/go-defaults.md) | Universal Go conventions: context, error wrapping, testing. |
| [minimal-changes](rules/minimal-changes.md) | Only make the changes that were requested. |
| [no-generated-file-edits](rules/no-generated-file-edits.md) | Never modify generated files — fix generator inputs instead. |
| [parallelize-subagents](rules/parallelize-subagents.md) | Launch independent subagents in parallel, not sequentially. |
| [prefer-jq](rules/prefer-jq.md) | Prefer jq over Python for JSON/JSONL processing in shell commands. |
| [research-tools](rules/research-tools.md) | Pick the right tool: Sourcegraph, web search, or Notion. |
| [session-context](rules/session-context.md) | Auto-invoke `/set-session-context` on branch switches or hook prompts. |
| [taskfile-not-make](rules/taskfile-not-make.md) | Use go-task (`Taskfile.yaml`), not Makefiles. |
| [terse-output](rules/terse-output.md) | Concise, direct output. No filler. |
| [testing-philosophy](rules/testing-philosophy.md) | Real code over mocks. Tests may use a real database. |

## Statusline

Custom status line scripts (`statusline.sh` / `statusline.ps1`) that display live session info below the prompt. No API calls — all data comes from stdin JSON and local git/gh commands.

**Segments displayed:**

- **Model** — current model name (context size suffix stripped)
- **Git** — `repo@branch` with Jira ticket (extracted from branch name), worktree indicator, and diff stats (`+N -M`) vs default branch. Default branch renders dim; feature branches render orange.
- **Context usage** — tokens used / total with percentage, color-coded green → yellow → orange → red
- **Effort level** — current reasoning effort setting
- **Rate limits** — 5-hour and 7-day usage percentages with reset times

Inspired by [ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine).

## Suggested MCP Servers

Some skills expect these MCP servers to be available. All are optional -- skills degrade gracefully without them.

| MCP Server | Used by | Docs |
|------------|---------|------|
| [Atlassian](https://github.com/atlassian/atlassian-mcp-server) | create-jira-item | [Getting started](https://support.atlassian.com/rovo/docs/getting-started-with-the-atlassian-remote-mcp-server) |
| [Notion](https://github.com/makenotion/notion-mcp-server) | create-decision-document | [Setup](https://developers.notion.com/docs/get-started-with-mcp) |
| [Sourcegraph](https://sourcegraph.com/docs/api/mcp) | review-*, create-decision-document | [Setup](https://sourcegraph.com/docs/api/mcp) |

Inspired and influenced by [Superpowers](https://github.com/obra/superpowers).

## License

[MIT](LICENSE)