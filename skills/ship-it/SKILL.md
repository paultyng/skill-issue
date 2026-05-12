---
name: ship-it
description: End-to-end shipping workflow. Formats, lints, tests, creates a changelog entry, commits with conventional commits, pushes, updates PR description, and suggests reviewers. Use when the user says "ship it", "commit and push", "fmt lint test commit push", or similar shipping commands.
---

# Ship It

Run the full pre-commit pipeline, commit, push, and handle PR housekeeping.

## 1. Verify

Run verification per [verify-when-complete](../verify-when-complete/SKILL.md). Stop if any step fails.

## 2. Changelog

Check if the project has a changelog convention:

1. If `Taskfile.yaml` has a `changelog` task, run `task changelog` and follow its output.
2. Otherwise, look for existing changelog entries:
   - Per-PR fragment directories like `.changeset/` (JS/TS via `@changesets/cli`), `.changes/` (Python via `towncrier`), or similar project-defined conventions
   - `CHANGELOG.md` at the repo root
3. If a convention is found, create a terse entry following the existing format and patterns.
4. If no changelog convention exists, skip this step.

## 3. Commit

Stage all changes and commit using [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <description>
```

Common types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`.

Always create a new commit. Never amend.

Apply `terse-output` commit-message tone: imperative subject ≤72 chars, body explains *why* (the diff shows what), no "this commit does X" / "I" / "we" / "now". Keep the `Co-Authored-By: Claude…` attribution.

## 4. Push and PR

Push the current branch:

```bash
git push -u origin HEAD
```

If a PR exists for the current branch, update its title and description to reflect the current state:

```bash
gh pr edit --title "<title>" --body-file /tmp/pr-body.md
```

For PRs with diffs over ~20 files or ~500 lines, **delegate body authoring to a subagent** per `parallelize-subagents` and `subagent-prompt-contract`: paste the commit list and `git diff --stat` inline, ask for a summary section + bullet list of notable changes capped at ~200 words, and have the subagent return with the four-state Status line. Main writes `/tmp/pr-body.md` from the summary. Small PRs stay inline.

If no PR exists, run [create-pr](../create-pr/SKILL.md) to open one.

## 5. Suggest Reviewers

If a PR exists, query reviewer state and present suggestions:

```bash
gh api graphql -f query='
{ repository(owner:"OWNER", name:"REPO") { pullRequest(number:NUM) {
  reviewRequests(first:10) { nodes { requestedReviewer { ... on User { login } ... on Team { slug } } } }
  latestReviews(first:10) { nodes { author { login } state } }
  suggestedReviewers { reviewer { login } isAuthor isCommenter }
} } }'
```

Logic:
- If someone already reviewed, suggest re-requesting the same reviewer.
- If a review is already requested, note who.
- If no reviewer yet, present GitHub's `suggestedReviewers` list.
- For deeper git-history-based suggestions, use `/analyze-knowledge`. It fans out per-area analysis to subagents for PRs with >20 files, so keep the parent context clean.
- Do **not** auto-assign. Present suggestions and let the user decide.
