---
name: create-pr
description: Use when creating a new GitHub pull request, opening a PR for the current branch, or when another skill (like ship-it) needs a PR created for a branch that does not have one yet.
---

# Create PR

Open a new GitHub pull request for the current branch using the repo's PR template if one exists. Defaults to `--draft`.

## 1. Preconditions

- Current branch must be pushed to a remote. If `git rev-parse --abbrev-ref --symbolic-full-name @{u}` fails, run `git push -u origin HEAD` first.
- Skip creation if a PR already exists for the branch: `gh pr view --json number 2>/dev/null` returns 0. In that case the caller likely wants `gh pr edit` instead.

## 2. Detect PR template

Check for a template in this order and use the first match:

1. `.github/pull_request_template.md`
2. `.github/PULL_REQUEST_TEMPLATE.md`
3. `docs/pull_request_template.md`
4. `pull_request_template.md` (repo root)
5. `.github/PULL_REQUEST_TEMPLATE/*.md` — if multiple, prefer one matching the dominant commit type (`feature.md` or `feat-*` for `feat:` commits, `bugfix.md` for `fix:`, etc.). If still ambiguous, ask the user which to use.

Filename matching is case-insensitive on macOS but case-sensitive on Linux — check both common cases.

If none found, use the standard body in step 4.

## 3. Determine title

Use [Conventional Commits](https://www.conventionalcommits.org/) format derived from the branch's commits (`git log <base>..HEAD`):

- Single commit: use its subject line verbatim.
- Multiple commits: synthesize one conventional-commit-style title covering the change. Keep under 72 chars.

## 4. Generate body

Apply `terse-output` to the body: bullets over prose, no filler ("just", "really"), no hedge openers ("I noticed that…", "You might want to consider…"). Lead with what changed and why; skip implementation play-by-play.


**With template**: read the template file and fill its sections from the diff (`git diff <base>...HEAD`) and commit history. Preserve the template's structure, headings, comments, and checklists exactly. Leave checklist items unchecked unless the work demonstrably satisfies them. For sections that do not apply, mark them `N/A` only if the template requires a value — otherwise leave the section body empty.

Do not strip HTML comments from the template (they are often instructions to the PR author and may be intentionally rendered as hidden guidance).

**Without template**, use this body:

```markdown
## Summary

<1–3 bullets covering what changed and why>

## Test plan

- [ ] <specific verification steps>
```

## 5. Confirm and create

Per [no-post-without-confirmation](../../rules/no-post-without-confirmation.md), present the title and body to the user and wait for explicit approval before creating.

After approval, write the body to a temp file (avoids shell-escaping issues with multiline markdown) and create the PR:

```bash
gh pr create --draft --title "<title>" --body-file /tmp/pr-body.md
```

Always pass `--draft` per [draft-prs](../../rules/draft-prs.md). Only omit `--draft` if the user explicitly asked for a ready/non-draft PR.

Print the resulting PR URL.
