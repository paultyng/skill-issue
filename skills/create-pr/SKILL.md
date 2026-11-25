---
name: create-pr
description: Use when creating a GitHub pull request, opening a PR for the current branch, opening several PRs at once or from a script, rewriting an existing PR's title or body, marking a draft PR ready, or when another skill (like ship-it, push-and-watch, or implement-plan) needs a PR created or its body updated.
---

# Create PR

Every PR body goes through this skill: new PRs, body updates on existing PRs, and PRs opened in bulk. The repo's PR guidance wins over the defaults here.

## 1. Preconditions

- Current branch must be pushed to a remote. If `git rev-parse --abbrev-ref --symbolic-full-name @{u}` fails, run `git push -u origin HEAD` first.
- If `gh pr view --json number,url 2>/dev/null` succeeds, a PR exists: run steps 2–5, then update it with `gh pr edit` in step 6.

## 2. Read the repo's PR guidance

**Template.** Use the first match:

1. `.github/pull_request_template.md`
2. `.github/PULL_REQUEST_TEMPLATE.md`
3. `docs/pull_request_template.md`
4. `pull_request_template.md` (repo root)
5. `.github/PULL_REQUEST_TEMPLATE/*.md`. If multiple, prefer one matching the dominant commit type (`feature.md` or `feat-*` for `feat:` commits, `bugfix.md` for `fix:`, etc.). If still ambiguous, ask the user which to use.

Filename matching is case-insensitive on macOS but case-sensitive on Linux; check both common cases.

**Contributing docs.** Read the PR sections of `CONTRIBUTING.md` (root, `.github/`, `docs/`), `AGENTS.md`, and `CLAUDE.md`. These often set title format, issue-link syntax, required disclosures, and a check script to run.

## 3. Determine title

If the contributing docs prescribe a title format, use it. Otherwise use [Conventional Commits](https://www.conventionalcommits.org/) derived from `git log <base>..HEAD`:

- Single commit: use its subject line verbatim.
- Multiple commits: synthesize one conventional-commit-style title covering the change. Keep under 72 chars.

## 4. Generate body

Apply `terse-output` to the body: bullets over prose, no filler, no hedge openers. Lead with what changed and why. Where the repo's guidance conflicts with these defaults, the repo wins.

Source the body from `git diff <base>...HEAD` and the full commit messages (`git log <base>..HEAD`, not `--oneline`; commit bodies carry issue references and context).

**With template**, fill its sections:

- **Template comments are instructions.** Follow every one: word caps, required sections, required disclosures, link syntax. Keep the comments in the body.
- **Keep the structure byte-exact.** Marker comments, headings, and checkbox text stay as written, in order. Do not reword, merge, or drop them; checks often match them literally.
- **Tick only what the diff proves**, such as "tests added" when it adds tests.
- **MUST NOT tick a box that attests to something a person did or agrees to**: "I have reviewed", "I have read the guidelines", "I agree", sign-off, CLA. Leave them for the author, even when the work looks done.
- **Never tick a box for work not done** (benchmarks, docs, manual testing). Leave it unticked and list it in the step 6 report.
- **AI disclosure:** if the template or docs ask, state truthfully which AI tool was used and what it did.
- For sections that do not apply, write `N/A` only if the template requires a value; otherwise leave the section body empty.

**Without template**, use this body:

```markdown
## Summary

<1–3 bullets covering what changed and why>

## Test plan

- [ ] <specific verification steps>
```

## 5. Check the body

Write the body to a file from `mktemp`.

- **Repo check script.** If the template, contributing docs, or `AGENTS.md` name a script that checks PR bodies, or `.github/scripts/` holds one (name contains `pr-body`, `pr-template`, or `validate-pr`), read it first, then run it on the body file. Fix the body and rerun until it passes.
- **No script.** Confirm that every template heading, marker comment, and checkbox line appears verbatim in the body (`grep -F`), and that each word cap holds (`wc -w`).
- **Either way**, walk each PR requirement from the contributing docs and the template comments, and confirm the title or body meets it. A passing script covers only what it checks.

## 6. Confirm, then create or update

Per [no-post-without-confirmation](../../rules/no-post-without-confirmation.md), show the user before posting:

- the title and the full body
- the check result (script output, or the self-check)
- boxes left unticked for the author, and boxes that need work not done yet

After approval:

```bash
gh pr create --draft --title "<title>" --body-file "$BODY_FILE"   # new PR
gh pr edit --title "<title>" --body-file "$BODY_FILE"             # existing PR
```

Always pass `--draft` on create per [draft-prs](../../rules/draft-prs.md). Only omit it if the user explicitly asked for a ready PR.

Print the PR URL on both paths (`gh pr view --json url --jq .url` after an edit).

**Before `gh pr ready`**, rerun step 5 on the current body (`gh pr view --json body --jq .body`). CI template checks often skip drafts, so a failure shows up only after the PR is marked ready.

## Bulk and scripted creation

When opening more than one PR, or from a script:

1. Run steps 2–5 for each PR and write each body to its own file.
2. Show all titles, bodies, and check results together for one approval.
3. Create each PR with `gh pr create --draft --title ... --body-file <its file>`.

MUST NOT build bodies inline in a loop (`--body "..."`) or use `--fill`. Both skip the template and the check.
