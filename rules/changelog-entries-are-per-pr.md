# changelog-entries-are-per-pr

Treat changelog entries as **per-PR artifacts**, not portable files.

- **One entry per PR.** Each PR creates exactly one changelog entry. If the work spans multiple concerns, combine them into a single entry. Do not create multiple changelog files for the same PR.
- **Never cherry-pick a changelog file across PRs.** The file is keyed to the PR/branch (filename, timestamp suffix, or contents reference the PR number). Each new PR generates its own.
- **Always use the project's tooling** to create the file: `pnpm changeset` (JS/TS via `@changesets/cli`), `towncrier create` (Python), `changie new` (Go), `task changelog:new`, or whatever the project provides. Never hand-author changelog YAML/Markdown directly; the tool sets timestamps, IDs, and required fields that hand-authoring gets wrong.
- Project-specific tooling workarounds (non-interactive flags, `EDITOR` shims, etc.) belong in project-level memory, not this rule.
