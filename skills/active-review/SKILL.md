---
name: active-review
description: Use when the user wants to prepare for a manual PR code review and asks for help targeting it — a terse PR summary, ranked files to read first, and paste-ready inline comment drafts with GitHub deep-links. Triggers: "active review this PR", "walk me through this PR", "help me review this", "give me inline comments to add manually", "give me files and lines with terse comments", "summary with files and lines", "/active-review [PR|branch]". Do NOT use to post comments (use `code-review --comment` or `review` for that), to run the actual analysis (this skill consumes `/review-all` output), or to review plans / documentation (use `review-plan` / `review-documentation`).
---

# Active Review

Prepare a human to review a PR. Reshape a `/review-all` pass into three terse blocks: PR summary, the files most worth eyeballing, and paste-ready inline comment drafts with GitHub deep-links. The skill never posts — the user posts manually.

Mirror to `active-read`: the agent loads the context, the human stays in the loop.

## Workflow

### 1. Resolve target

Determine what's being reviewed and capture metadata.

- Argument forms accepted: `<PR number>`, `<PR URL>`, `<branch>`, or nothing (default).
- Default: current branch's PR (`gh pr view --json number,url,headRefOid,baseRefName,title,body,headRepository,headRepositoryOwner`). If no PR exists for the current branch, fall back to a branch-vs-base diff and skip the deep-link generation steps that require a PR.
- Capture: `pr_url`, `pr_number`, `org` (from `headRepositoryOwner.login`), `repo` (from `headRepository.name`), `head_sha`, `base_ref`, `title`, `body` (PR description, may be empty).

If a `<branch>` argument is given but no PR exists, ask the user once whether to (a) open a draft PR first, or (b) proceed branch-only without deep-links. Do not infer.

### 2. Detect fresh review artifact

`/review-all` writes `.reviews/<date>/SUMMARY.md` with a metadata header that includes the full HEAD SHA. Reuse if fresh; otherwise re-run.

```sh
LATEST=$(ls -t .reviews/*/SUMMARY.md 2>/dev/null | head -1)
if [ -n "$LATEST" ] && grep -q "$head_sha" "$LATEST"; then
  echo "reusing review: $LATEST"
  SUMMARY="$LATEST"
else
  echo "running fresh /review-all (no artifact for $head_sha)"
  SUMMARY=""
fi
```

State the chosen path to the user in one line before proceeding: `reusing review from <sha>` or `running fresh review`.

### 3. Run /review-all if needed

When `SUMMARY` is empty, invoke `/review-all` against the resolved scope. Pass `--focus "<area>"` through if the user supplied it. Wait for the artifact, then set `SUMMARY` to the resulting `.reviews/<date>/SUMMARY.md`.

If `/review-all` errors or produces zero findings, **say so explicitly** and stop. Do not fabricate findings to fill the output.

### 4. Fetch existing PR comments

Always fetch the PR's inline review comments so findings can be tagged against what reviewers already said. Skip only in branch-only fallback mode (no PR).

```sh
gh api repos/$org/$repo/pulls/$pr_number/comments --paginate \
  --jq '.[] | {author: .user.login, path: .path, line: (.line // .original_line), body: .body}'
```

Capture each comment's `author`, `path`, `line`, and `body`. Group by `path`.

### 5. Assess coverage

For each in-scope finding, look for existing comments on the same `path` at or near its line (same line, or within a few lines when the diff shifted). For each overlap, read the comment `body` and judge it against the finding's concern:

- **full** — the comment already raises the same concern. The user likely need not re-comment.
- **partial** — the comment touches the area but misses an aspect of the finding. A follow-up is warranted; the draft should target the **uncovered** aspect.
- **unrelated** — the comment is on the same location but a different topic. Treat as **not covered** — do not tag it as commented (that would mislead).

When several comments overlap one finding with different judgments, take the most-covering (full > partial > unrelated) and tag only that author.

Coverage is a semantic judgment on the comment body, not a line-number match. Never drop a finding because a comment overlaps it; annotate and keep it (except under `--gap`, see Modes).

### 6. Synthesize

Read `SUMMARY.md` and the PR metadata. Produce the output below.

`SUMMARY.md` is laid out as two flat tables (see `review-all`'s [reference-tracking.md § Findings layout in SUMMARY.md](../review-all/reference-tracking.md#findings-layout-in-summarymd)): `Findings — untracked` above the fold, `Findings — tracked` in a collapsed `<details>` block. **Default to untracked.** Tracked findings have an owner already — they're not where the human reviewer's eyeballs should go first.

Hard rules:

- Every finding emitted must trace to a row in the loaded `SUMMARY.md` (or to the underlying review-* subagent output it was deduped from). No inventing findings.
- Comment drafts are **rewrites for tone and brevity**, not new analysis. The agent may compress, soften, or sharpen the original finding text; it may not add a new problem statement that wasn't in `SUMMARY.md`.
- Use `~/.claude/scripts/pr-deeplink.sh` to build deep-links. Do not hand-construct GitHub anchor URLs.

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>   # → [path:line](...#diff-<hash>R<line>)
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path>          # → [path](...#diff-<hash>) (file-level)
```

For each in-scope **untracked** finding (severity filter applied — default `medium+`):

- Build the line-level deep-link.
- Write a terse paste-ready comment body — single sentence preferred, ≤2 sentences max. Imperative mood. No "consider…", "you might want to…", "I noticed…" hedging.
- Tag with severity (`high` / `medium` / `low` / `nit`).
- If an existing comment covers the finding (from step 5), append a trailing coverage note naming the author and the state: `· @<author> commented here — full; likely skip` or `· @<author> commented here — partial (<what's uncovered>); follow-up warranted`. For `partial`, rewrite the draft to target the uncovered aspect. Never suppress — the finding stays in its severity section. `unrelated` overlaps get no note.
- Carry over any `→ possibly overlaps: <ref>` annotation from `SUMMARY.md` as a trailing `(see also: <ref>)` note on the comment draft. Do not let weak overlap suppress the comment.

When `--include-tracked` is set, also emit a `Tracked (already known)` section after the untracked drafts. Each row keeps its source badge (`[tracked: PR #N + JIRA …]`) so the human can decide whether to comment again or defer to the existing owner.

For the "Read these first" ranking, weight by:

1. Number and severity of findings the file carries.
2. Surface area changed (lines added/removed).
3. Whether the file is on a security / API-contract / data-path boundary (review-all already flags these).

Rank no more than 5 files unless the user asks for more. The point is targeting, not enumeration.

### 7. Present

Emit the output template below inline. No file written. After presenting, **stop**. Do not offer to post the comments. Do not auto-advance to a follow-up step. The user drives next steps.

## Output template

```markdown
## TL;DR
<2–3 sentences: what the PR does + overall risk read. Mention the most concentrated risk area by name.>

## Read these first
1. [path/to/file.ext](<file-level deeplink>) — <one-line why this matters>
2. [path/to/other.ext](<file-level deeplink>) — <one-line why this matters>
…

## Inline comment drafts (medium+, untracked)

### high
- [path:line](<line deeplink>) — <terse paste-ready comment> (see also: PR #4)   <!-- only when carrying a tier-3 overlap -->
- [path:line](<line deeplink>) — <terse paste-ready comment> · @alice commented here — full; likely skip   <!-- only when an existing comment covers it -->
- [path:line](<line deeplink>) — <terse paste-ready comment targeting the gap> · @bob commented here — partial (misses the nil path); follow-up warranted

### medium
- [path:line](<line deeplink>) — <terse paste-ready comment>
…

<!-- Only emit this footer if there are low / nit findings -->
_<N> low / nit items hidden. Ask "show all" to surface them._

<!-- Only when --include-tracked is set AND there are tracked findings -->
## Tracked (already known)
- [path:line](<line deeplink>) — <terse comment> · [tracked: PR #412]
- [path:line](<line deeplink>) — <terse comment> · [tracked: TODO at path:line + ISSUE #523]
```

## Modes

Recognize these arguments after the target (`/active-review <PR> --rereview`, etc.):

- **`--severity high|medium|low|all`** — default `medium`. Filter the inline-comments section to this floor and above.
- **`--focus "<area>"`** — passed through to `/review-all` when a fresh run is needed. Ignored when reusing a fresh artifact (the focus was baked in at run time; re-run if the scope shifted).
- **`--include-tracked`** — also emit the `Tracked (already known)` section after the untracked drafts. Default omits it (tracked items have owners; redirect the human's eyes to untracked).
- **`--rereview`** — assumes a prior `SUMMARY.md` exists at an earlier SHA. Load both, and in the inline-comments section group findings as: **still present**, **addressed**, **new since last review**. Use this when the author has pushed updates.
- **`--gap`** — narrow the drafts to the *remaining gap*: emit only findings that are **not fully covered** by an existing comment (findings with no comment, plus `partial` ones), hiding `full` ones. Coverage is assessed for every run (steps 4–5); this flag only changes what's emitted. Frame the output as "things you may have missed".

The flags compose: `--rereview --severity high` is "what's still broken at high severity since I last looked." `--rereview --gap` applies coverage within each rereview bucket (still present / addressed / new).

## Constraints

- **Never posts.** No `gh pr review`, no `gh api … POST`, no comment-creation MCP tools. Output is for the human to paste.
- **Local only.** No telemetry. No external writes.
- **No file output.** All three blocks render inline.
- **No fabrication.** If `SUMMARY.md` is empty or `/review-all` returns zero findings, say "no findings at <severity> floor" and stop. Do not invent placeholder concerns.
- **Deep-links are required** when a PR URL exists. Plain `path:line` is acceptable only in branch-only fallback mode.

## Disambiguation

Quick distinction from neighboring skills:

| Skill | When |
|---|---|
| `review-all` | Run the actual multi-domain analysis. `active-review` **consumes** its `SUMMARY.md`. |
| `code-review` | Review-and-post (with `--comment`) on the current diff. `active-review` is the **non-posting** counterpart for human-driven posting. |
| `review` | Posts a structured review on a PR. `active-review` produces drafts for the human to post. |
| `review-plan` / `review-documentation` | Different artifact types (plan / docs prose). `active-review` is PR-code-targeted. |
| `active-read` | Sibling. Active study of a document. `active-review` is the same shape applied to code review prep. |

## Anti-patterns

- **Posting comments "to save the user a step".** Forbidden. Even if the user previously approved posting in a different session, that does not carry over. The skill's contract is human-posts.
- **Re-running `/review-all` on every invocation.** The fresh-artifact check exists for a reason. Reuse when SHA matches.
- **Padding "Read these first" with every changed file.** Five is plenty. If the agent can't pick five, pick three.
- **Verbose comment drafts.** "Consider possibly refactoring this to perhaps handle the edge case where…" is wrong. Use the imperative: "Handle nil case before deref."
- **Sycophantic framing.** No "great PR overall!" / "the author did a wonderful job here". The TL;DR is a risk read, not a vibe check.
- **Inventing severity.** If `SUMMARY.md` doesn't grade a finding, mark it `medium` and move on. Do not invent `critical` to look thorough.

## Rationalization table

| Excuse | Reality |
|---|---|
| "Posting one inline comment is faster than copy-paste." | The user wants to post manually — that's the whole point. The skill is a drafting tool, not an actor. |
| "The review artifact is from 2 hours ago, surely it's still fresh." | If the SHA doesn't match, code may have moved. Re-run. |
| "The PR is small — I don't need `/review-all`, I can review it myself." | Then the skill is the wrong tool. Step out and let the user invoke the right one. Do not "lightweight-review" inline. |
| "No findings at medium+ — let me surface some low/nits to be useful." | Say "no medium+ findings" and stop. Surfacing nits the user filtered out is a CSO violation. |
| "I should also suggest a fix for each comment." | The user wrote "terse comment". Comments name the problem; fixes are a separate conversation. |

## Out of scope for v1

- **Posting** (any form). Intentionally permanent — this is the skill's identity.
- **Multi-PR batch review.** One PR per invocation.
- **Conversation threading / reply chains.** Coverage assessment reads each comment's author and body, but treats comments as a flat set — it does not follow reply threads or resolve/unresolve state.
- **Persisted walkthrough state across sessions.** Each invocation is self-contained; reuse comes from the `/review-all` artifact, not from active-review's own memory.
- **Correlation against open issues / PRs / Jira.** Owned by `/review-all`'s summarization step; consume what's already tagged in `SUMMARY.md`.
