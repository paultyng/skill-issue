# Finding tracking — reference

How `/review-all` decides whether a consolidated finding is `tracked` and how the result renders. The summarization step (step 4 of the workflow) reads this file.

**Contents:** [Finding header](#finding-header) · [Schema](#schema) · [Signal classes](#signal-classes) · [Badge rendering](#badge-rendering) · [Findings layout in SUMMARY.md](#findings-layout-in-summarymd)

## Finding header

Every reviewer prefixes each finding with one line, and lists one coverage row per file in its domain scope (SKILL.md step 1; in full-codebase scope, only files it opened) after its findings. An empty domain scope emits no coverage rows. A skill that emits findings as table rows puts the `FINDING` lines in a fenced block right after each table, one per row in row order:

```
FINDING | rule_id=<id> | sev=<P0-P3> | blocking=<y|n> | conf=<high|med|low> | dkey=<path>:<line>:<rule_id>
COVERAGE | file=<path> | status=<read-fully|skimmed|not-read>
```

| Field | Meaning |
|---|---|
| `sev` | P0–P3. A skill that grades in words maps CRITICAL→P0, HIGH→P1, MEDIUM→P2, LOW→P3. Renders as CRITICAL / HIGH / MEDIUM / LOW in SUMMARY.md |
| `blocking` | Fix before merge. Default `y` for P0–P1, `n` for P2–P3; an override needs a one-clause reason |
| `conf` | `high`: traced to `file:line` and read. `med`: pattern match read in context. `low`: line read, but the defect depends on runtime behavior or context not visible statically |
| `rule_id` | A CWE when one applies, else a kebab defect class (`stale-epoch-commit`). Fixed ids: logged secret `CWE-532`, hardcoded secret `CWE-798`, SQL injection `CWE-89`, missing authorization `CWE-862` |
| `dkey` | `<path>:<line>:<rule_id>`, where `line` is the defect's first line, or `0` for a file-level finding |

A missing or unparseable header, or missing coverage rows for a non-empty domain scope, is a reviewer defect: record it under **Not checked** per SKILL.md step 4, never as a clean result.

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

## Findings layout in SUMMARY.md

Section order, the headline, `## Coverage gaps`, and `## Not checked` follow SKILL.md step 5; they precede the findings. Both findings sections in `SUMMARY.md` render as a single **flat** table — categories are a column, not a section header. Per-domain templates in [reference-output.md](reference-output.md) describe what each subagent emits; the summarization subagent compresses them into this unified shape.

```markdown
## Findings — untracked

| Category | Severity | Blocking | Conf | Finding | Class | Tracked |
|----------|----------|----------|------|---------|-------|---------|
| security | HIGH     | y        | high | <description with file:line> | S1, A01 |  |
| code     | MEDIUM   | n (low-confidence) | low | <description with file:line> | GO1, SA3 | [→ possibly overlaps: PR #4] |

<details><summary>Findings — tracked (N)</summary>

| Category | Severity | Blocking | Conf | Finding | Class | Tracked |
|----------|----------|----------|------|---------|-------|---------|
| security | HIGH     | y        | med  | <description with file:line> | T2 | [tracked: ISSUE #5] |

</details>
```

Rules:

- **Class column** holds category-specific tags compressed from the per-domain templates: STRIDE/OWASP for security; `Impact / Effort` joined with `/` for reliability / infra / ci / observability / performance; source IDs (ARCH1, GO1, etc.) for code / documentation / coverage; change-class for api-compatibility. Empty when not applicable.
- **Severity scale** is unified to `CRITICAL / HIGH / MEDIUM / LOW`. Per-domain `P0 / P1 / P2 / P3` map to `CRITICAL / HIGH / MEDIUM / LOW`.
- **Severity / Blocking / Conf columns** carry the merged `sev`, `blocking`, and `conf` from the pre-merge set, never values re-read from raw reviewer output. A demoted finding renders `n (low-confidence)`. A merged finding's `Category` lists every domain that raised it (`security, observability`).
- **Sort order:** severity desc, then category alpha.
- **Tracked column** renders per [Badge rendering](#badge-rendering) above.
- **Empty groups:**
  - Tracked empty → omit the `<details>` block entirely.
  - Untracked empty → render `> No untracked findings at this scope.` callout in place of the table (meaningful signal — don't render an empty table).
  - Both empty → render `> No findings.` and skip both sections.
