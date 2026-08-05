# gh-active-account

The `gh` CLI active account is **machine-global state, not session-scoped**. It reverts whenever another session, tool, or hook switches it, so a switch you made earlier in a session does not reliably still hold.

**IMPORTANT**: when a repo requires a non-default `gh` account (common when a personal repo needs a personal account but the machine default is an org/Enterprise Managed User account), re-assert the account **immediately before every `gh` operation** that hits the REST/GraphQL API:

- `gh pr create` / `merge` / `ready` / `edit` / `view --json`, `gh api`, `gh issue`, etc.
- Run `gh auth switch -u <user>` right before the call. Do not assume a prior switch persists.
- Verify with `gh api user --jq .login` when unsure which account is active.

Git `push`/`fetch` over SSH is unaffected — only the `gh` API surface cares about the active account.

Enterprise Managed User (EMU) accounts are rejected by GitHub for personal-account content with `Unauthorized: As an Enterprise Managed User, you cannot access this content`. If you see that, the wrong account is active.

The specific account names, which repos need which account, and any enterprise details are **project-specific** — keep them in project memory or `CLAUDE.md`, not in this portable rule.
