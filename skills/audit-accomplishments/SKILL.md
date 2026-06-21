---
name: audit-accomplishments
description: Use when preparing a performance self-reflection, midyear or annual review, promotion packet, or brag document; when asked to collect, mine, gather, or summarize your accomplishments, contributions, or impact over a period; or when assembling cited evidence of work done across GitHub, Jira, Notion, Slack, and local agent histories over the last N months.
disable-model-invocation: true
---

# Audit Accomplishments

Mine a person's contribution evidence across every source where their work lives, over a configurable window, and emit **cited** achievement summaries for review prep. Collection only — this skill does not draft the review.

Sibling of `audit-history`: that skill mines sessions to improve agent config; this one mines work across external systems to surface achievements. The **local-history + memory discovery** is shared — reuse `audit-history` Phase 1 rather than re-deriving it.

## Inputs

- **window** — default **last 6 months**. Accept an override as dates (`2026-01-01..2026-06-24`) or duration (`3 months`). Compute concrete start/end dates up front and state them.
- **sources** — default all (below). Accept a subset override.
- **taxonomy** (optional) — a review template's dimensions / career-level areas, supplied as an arg or a path. When absent, group by discovered theme only; do not invent a rubric.
- **output dir** — default `./review-material/` in the cwd.

## Guardrails

- **Read-only** across every external system. Never post, edit, comment, transition, or mutate.
- **Cite everything.** Each claim carries a re-fetchable reference (URL, `file:line`, ticket id, transcript UUID) so it can be expanded during drafting.
- **Completion over creation.** Weight what was *finished* in the window (PR merged, issue resolved), not what was opened or merely discussed.
- **No invention or embellishment.** If a section has no evidence, say so. Stay grounded in what was found.

## Phase 1 — Discover identities & sources (mechanical, read-only)

Resolve *who* the person is on each source and *where* to look. Do not summarize yet.

- **GitHub** — `gh auth status` enumerates logged-in hosts/accounts. Record each `host` + `login`. The person may have multiple (e.g. work + personal); mine all unless overridden.
- **Jira** — call the Atlassian MCP `atlassianUserInfo` (server name varies by install) for the account id; `getAccessibleAtlassianResources` for the cloud id(s).
- **Notion** — get the self user via the Notion MCP (`get-users` / self lookup).
- **Slack** — the search tool reports the logged-in `user_id`. **Enumerate active channels + DMs first**: a single global `from:me` search is incomplete (it misses DMs and needs real keywords, not stopwords). Run `from:me after:<start>` to collect the set of channels the person actually posts in, then drive Phase 2 per-channel.
- **Local agent histories + memory** — reuse `audit-history` Phase 1: Claude Code transcripts under `~/.claude/projects/*`, Cursor under `~/.cursor/projects/*`, memory under `~/.claude/projects/*/memory/`. Filter to files modified in the window.

Report a one-screen inventory (accounts found per source, channel count, transcript/memory counts) before proceeding.

## Phase 2 — Mechanical raw dump (read-only)

Run read-only queries per source and write **raw** results to `review-material/<source>.*`. No interpretation. These are the evidence base and the citation source.

Representative queries (adapt to tool versions; prefer `jq -c` for JSON):

- **GitHub** — for each host/account (switch via `gh auth switch` or `GH_HOST`):
  - Merged in window: `gh search prs "author:@me merged:>=<start>" --json number,title,repository,url,createdAt,closedAt --limit 500`
  - Opened in window (for in-flight work): `... "author:@me created:>=<start>"`
  - Reviews given: `gh search prs "reviewed-by:@me updated:>=<start>" --json ...`
  - Substantive commits where PR data is thin: `gh search commits "author:@me committer-date:>=<start>" --json ...`
- **Jira** — `searchJiraIssuesUsingJql`:
  - `assignee = currentUser() AND resolved >= "<start>" ORDER BY resolved DESC` (primary — completed)
  - `(reporter = currentUser() OR assignee = currentUser()) AND updated >= "<start>"` (broader activity)
- **Notion** — search is keyword-based and cannot filter by editor+date directly. Search broadly for likely topics, then `fetch` candidates and keep those whose `created_by`/`last_edited_by` is the self user and whose edit time is in-window. Capture page title + url + edit date.
- **Slack** — per channel from Phase 1: `from:me in:<#channel> after:<start>`. Keep substantive messages (unblocking, explaining, decisions, proposals); **drop** acknowledgements (👍, "thanks", "sgtm") and recurring standup posts. Separately, capture **praise received**: search `<name> after:<start>` for shoutouts / kudos / Bonusly mentions naming the person.
- **Local** — extract per-transcript work topic + tools + outcomes via `jq` (see `audit-history` extraction patterns). Pull project memory files in-window.

## Phase 3 — Fan-out summarization (subagents)

Promote raw dumps into structured **achievement cards**. Hybrid two-stage:

1. **Enumerate** the work-list per source (cheap; from Phase 2 dumps).
2. **Fan out** summarization subagents only where volume warrants. Subdivide **per-artifact** (one PR/doc/ticket) for low volume, or **per-time-bucket** (e.g. per week / per month) when a source has many small items — bucketing keeps each subagent's context tight and preserves chronology.

Each subagent follows `subagent-prompt-contract`: one-sentence goal, the relevant raw dump pasted inline (do **not** ask it to re-read this SKILL.md or re-query the source), the card schema below as the output cap, and a `Status:` prefix line. Use `model: haiku` for schema-driven extraction, `model: sonnet` where interpreting impact requires judgment (per `subagent-model-routing`).

### Achievement card schema

```
- title:     <short, outcome-oriented>
- what:      <1-2 sentences: what was done>
- impact:    <speed | reliability | quality | understanding | cost | scope; quantify if the evidence does>
- timing:    <opened YYYY-MM-DD; merged/resolved YYYY-MM-DD>   # explicit dates
- evidence:  [<re-fetchable refs: PR url, ticket id, Notion url, file:line, Slack permalink, transcript UUID>]
- theme:     <discovered grouping>
- dimension: <from supplied taxonomy, if any; else omit>
- ai_usage:  <include ONLY when the work was notably AI/agent-driven; one line on how>   # an aspect, not a required field
```

## Phase 4 — Synthesize

In the parent, after subagents return:

1. **Dedup cross-source.** The same work surfaces as a PR *and* a Jira ticket *and* a Notion doc *and* a Slack thread *and* a transcript. Merge into one card; collect all refs under `evidence`.
2. **Group by theme.** Cluster cards into a handful of named themes.
3. **Map to taxonomy** (if supplied). Tag each card's `dimension`; note which dimensions are well-covered.
4. **Gap-flag.** Call out dimensions/themes with thin or no evidence — so the person knows where to add detail or seek opportunities. Do not pad.
5. **Surface AI-capability examples.** Collect cards with an `ai_usage` aspect into a dedicated list — concrete examples of AI/agentic work, with citations.

### Output

- `review-material/` — per-source raw dumps (retained as the evidence base).
- `review-material/highlights.md` — synthesized, grouped, cited cards; a **Gaps** section; an **AI-capability examples** section.

Optionally seed reflection with these prompts (answer only from the cards, not invention):

- What did I do that made someone else's job easier?
- Where was there impact — speed, reliability, quality, understanding?
- Which "small wins" might I forget in six months?

## Anti-patterns

- Summarizing before the raw dump is written — you lose the citations.
- A single global Slack `from:me` query — incomplete; enumerate channels first.
- Counting opened/planned work as accomplished — weight completion.
- Inventing a rubric when none was supplied — group by theme instead.
- Any write/post/mutate call — this skill is strictly read-only.
- Hardcoding identities, hosts, org names, or level taxonomies — discover them at runtime.

## Sources

- Reuses local-history/memory discovery from the sibling `audit-history` skill.
