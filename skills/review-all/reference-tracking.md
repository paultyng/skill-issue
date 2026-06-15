# Finding tracking — reference

How `/review-all` decides whether a consolidated finding is `tracked` and how the result renders. The summarization step (step 4 of the workflow) reads this file.

## Schema

Every consolidated finding carries:

```
tracking:
  status: tracked | untracked
  sources: []                  # promoted matches (tier-1 / tier-2 / in-repo)
  possibly_overlaps: []        # weak external matches (tier-3 only)
```

A source entry:

```
{
  kind: in-repo | github-pr | github-issue | jira,
  ref:  "<pointer or #N or KEY-NUM>",
  match: path | symbol | keyword | in-repo,   # only for external kinds; in-repo omits
  url:  "<deep-link when available>"
}
```

`status = tracked` iff `sources` is non-empty. Tier-3 matches go on `possibly_overlaps`, never on `sources`.

## Signal classes

### In-repo (always evaluated)

Source reviews mark findings tracked when the code carries a `TODO` / `FIXME` / `HACK` / `XXX` comment at or near `path:line`, a README note, or an inline issue-tracker reference. Carry these forward as `{kind: in-repo, ref: "TODO at path:line"}` (or similar). Any in-repo signal promotes to `tracked`.

### Open-work (only when the step 1d block is non-empty)

Match each finding against the open-work set returned by step 1d using three tiers. Record the matched tier on the source entry.

- **tier-1 (path):** the PR description, issue body, or Jira description contains the literal finding `path` (file-level) or `path:line` (exact line). Strongest signal.
- **tier-2 (symbol):** the body contains the symbol name (function / type / const) at `finding.path:finding.line`. Extract the enclosing symbol cheaply from the file at HEAD (e.g. `awk` the enclosing `func` / `type` / `const`).
- **tier-3 (keyword):** title / labels / branch contain a changed-path keyword (the existing matcher from step 1d).

### Promotion rule

- Tier-1 and tier-2 promote → append to `sources`, set `status: tracked`.
- Tier-3 matches do **not** promote → append to `possibly_overlaps` instead, finding stays `untracked`.

### Terminal-state invariant

Step 1d filters to non-terminal items (`gh … --state open`; Jira `statusCategory != Done`). Re-confirm at match time: a closed / merged PR, a closed issue, or a `statusCategory = Done` Jira ticket never produces a source entry — drop it silently. A finding whose only match has gone terminal stays `untracked`.

## Badge rendering

The `Tracked` column on every consolidated finding table renders this badge. Display format:

- **Untracked, no overlap:** empty cell (absence is the signal — do not emit `[untracked]`).
- **Tracked (any `sources` entry):** `[tracked: <list>]`. Join sources with ` + `. Examples:
  - `[tracked: TODO at foo.go:42]`
  - `[tracked: PR #412]`
  - `[tracked: PR #412 + JIRA AUTH-2583]`
  - `[tracked: TODO at foo.go:42 + ISSUE #523]`
- **Untracked + tier-3 only (`possibly_overlaps` non-empty):** `[→ possibly overlaps: <refs>]`. Examples:
  - `[→ possibly overlaps: PR #412]`
  - `[→ possibly overlaps: ISSUE #523 + JIRA AUTH-2583]`

Rules:

- Sources / overlaps are rendered as Markdown links when the source entry has a `url` (use the URL captured in step 1d).
- In-repo sources that include `path:line` follow the same wrapping as [Finding link wrapping](SKILL.md#finding-link-wrapping).
- A tracked finding never carries `→ possibly overlaps` alongside its `tracked` badge — promotion (tier-1/tier-2) supersedes weak matches; do not render both.
