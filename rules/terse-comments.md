# terse-comments

Comments — in source code, in PR review comments, anywhere prose is attached *to* code — should be rare and load-bearing. The default is **no comment**.

## Source-code comments

- **Default to writing no comments.** Only add one when the *why* is non-obvious: a hidden constraint, a subtle invariant, a workaround for a specific bug, behavior that would surprise a reader. If removing the comment wouldn't confuse a future reader, don't write it.
- **Don't explain *what* the code does.** Well-named identifiers already do that. If a comment is needed to explain what, the names are wrong.
- **Don't reference the current task / fix / PR / callers.** "Used by FooBar", "added for #123", "see commit X" — those rot as the codebase evolves and belong in the commit message or PR description, not in the source.
- **One short line max** for inline comments. No multi-paragraph block comments. Public-API docstrings are the only exception, and even those should lead with one short line.

## PR review comments

Shape: `[path:line](url) — <problem>. <fix>.`

- Use the deep-link wrapping convention from the `review-*` skills.
- Optional severity prefix: `bug:` / `risk:` / `nit:` / `unsure:` (where `unsure:` flags honest doubt, per `terse-output`).
- Drop per-comment praise. The PR-level review can carry praise; line-level shouldn't.
- Don't restate what the diff does — the reviewer sees the diff.
- Don't use hedge openers (`I noticed that…`, `You might want to consider…`); state the problem and the fix.
- Keep: exact line refs, exact symbol names in backticks, concrete fix (not "consider refactoring").

## Anti-patterns

- `// TODO: cleanup later` — fix it now or open an issue and reference the issue.
- `// removed: the old foo() implementation` — git history holds removals.
- `// added in PR #42` — see above; PRs don't belong in source.
- Per-comment praise in a code review (`Nice work!`) — say it once at PR-level if it matters.
- Multi-paragraph "design rationale" comments at the top of a function — that's a doc, not a comment.

See `terse-output` for the broader prose conventions and the `unsure:` marker.
