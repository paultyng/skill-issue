---
name: harvest-artifacts
description: Use when the user asks to harvest, distill, sweep, or clean up old plans or reviews, asks what from `.plans/` or `.reviews/` belongs in AGENTS.md, CLAUDE.md, README, REVIEW.md, rules, or memory, asks to "clean up the review files" or "sweep old plans", or when stale plans and review directories have accumulated. Also /harvest-artifacts with an optional path or age.
---

# Harvest Artifacts

Plans and reviews pile up in `.plans/` and `.reviews/`. A few facts in them
are durable: an invariant a reviewer proved, a convention a pattern scan
found, a check reviewers keep needing. The rest is history the code and
`git log` already hold. Move the durable facts to the right home, then delete
what was consumed. This is a periodic sweep of the long tail of finished
work, not a post-merge step.

What each producing skill writes, and where its harvestable content sits:
[reference.md](reference.md).

## Arguments

- None: sweep artifacts older than 7 days.
- A path (`.reviews/2026-11-19`, `.plans/x.md`): only that artifact, any age.
- An age (`3d`, `all`): override the 7-day retention for this run.

Age is the review directory's date, or the file's mtime for plans and
`nits.md`. Artifacts inside retention are not read and not listed.

## Goal

Every candidate fact (a finding, nit, Behavior delta entry, decision, or
pattern) ends in exactly one place:

| Candidate | Home |
|---|---|
| A constraint every agent working in this repo must respect | `AGENTS.md`. If only `CLAUDE.md` exists, use it. If `CLAUDE.md` imports `@AGENTS.md`, AGENTS.md is canonical |
| A class of defect reviewers should check for in this repo | `REVIEW.md` (review-* skills read it at runtime) |
| A narrow, file-type-scoped behavior | Project `.claude/rules/<topic>.md`, written via `create-rule` |
| User-facing behavior or usage | `README.md` |
| An invariant of the code that no test defends | Follow-up: a test (per `derive-tests-from-invariants`). Do not write the code |
| A fact about the user, true across repos, not derivable from any repo | Auto-memory: a topic file in the project memory directory plus a one-line pointer in its `MEMORY.md` |
| Open finding, open nit, unchecked plan task, trajectory `Proposed follow-up` | Follow-up list in the report. Never post it anywhere |
| Fixed, already recorded (in the target, a rule, or memory), or no longer true | Dropped, with the reason |

A fixed bug is not documentation. The fix and its commit are the record;
"`Verify` uses `<`" in a README describes code, it does not constrain it.
Harvest the *constraint* a fix revealed, if there is one, not the fix.

## Invariants

- **Probe every candidate against HEAD before routing it.** A review describes
  the code at its metadata SHA. Grep or run to establish whether the finding
  is still open, fixed, or no longer applicable. Cite what you ran.
- **Dedup against the target, project rules, and memory first.**
- **Durability test.** A fact earns a place only if it would change what a
  future agent or reader does, and cannot be cheaply derived from the code or
  `git log`. Most findings fail. A short harvest is the normal outcome.
- **Routing an open item to the follow-up list consumes it.** Its artifact can
  then be deleted. "This is the only record" is why the report carries it,
  not a reason to keep the file.
- **MUST prompt before every write, and MUST NOT write unapproved content.**
  - One prompt per modified file, showing its diff.
  - One prompt per file that does not exist yet. Creating AGENTS.md,
    REVIEW.md, or a rule is a bigger step than editing one.
  - Approval of edits never implies approval of deletions.
  - Repo file edits land on a branch as one commit. The user triggers any PR
    (`defer-external-orchestration`).
- **MUST prompt for the deletion list separately, and MUST NOT delete
  unapproved artifacts.** `.plans/` and `.reviews/` are gitignored, so a
  deletion cannot be undone.
- **Never commit `.plans/` or `.reviews/` content.**
- **When you cannot prompt** (running as a subagent, or headless), stop
  before the first write and return the prompts as your output. "The user
  said quickly" is not approval.

## Deletion safety

List every artifact older than retention, each marked:

- **safe**, with the reason:
  - plan: every task is `- [x]` and its branch is merged into the default
    branch (`git branch --merged <default>`), or the user said it is abandoned
  - review directory: the metadata SHA is reachable from the default branch
    (`git merge-base --is-ancestor <sha> <default>`), and every finding in it
    is routed or dropped
  - `nits.md`: every entry is routed or dropped
- **not safe**, with what is still open (unchecked task, unmerged branch, SHA
  not on the default branch, no metadata SHA). The user can delete it anyway.

An artifact with no metadata SHA (`PATTERNS.md`) is not safe unless a newer
`PATTERNS.md` supersedes it.

## Output

```markdown
## Harvest: <N> artifacts read (<retention or argument>)

### Proposed edits
<per target file: path, (new file) if created, the diff>

### Follow-ups
- <open item> — <source artifact>:<line> — <probe that shows it is open>

### Dropped
<count>, plus one line each for any reason that is not obvious

### Cleanup
| Artifact | Age | Verdict | Reason |
```

Then the prompts, in order: each modified file, each created file, the
deletion list. Apply only what each prompt approves.

## Rationalizations

From a baseline run without this skill:

| Excuse | Reality |
|---|---|
| "The user said quickly, and I cannot ask interactively." | Speed is not approval. If you cannot prompt, return the prompts and stop. |
| "I limited deletions to one resolved review file." | It was 2 days old, inside retention. Age decides what is listed, not resolution. |
| "The strict-expiry rule is worth documenting." | That was a fixed bug. The fix is the record. Harvest a constraint, not a fix. |
| "Deleting the only record would lose it." | Route it to follow-ups. The report is the record, and the artifact is then consumed. |
| "It's an invariant, so it goes in the README." | README is for users. A constraint agents must respect goes in AGENTS.md, and an undefended invariant needs a test. |

## See also

- `audit-history`: harvests transcripts and memory. This skill harvests
  `.plans/` and `.reviews/`.
- `create-rule`: writes a project rule when routing picks one.
- `probe-not-assume`, `minimal-changes`, `defer-external-orchestration`.
