# Producer Catalog

What other skills leave on disk, and where the harvestable content sits. When
a producer changes its output format, update this file.

## Locations

- `.plans/` and `.reviews/` are gitignored on first use by
  `~/.claude/scripts/ensure-gitignore.sh`. A project `CLAUDE.md` directive
  `Plans live in <path>` moves plans; read it first.
- A review directory is `.reviews/YYYY-MM-DD`, or `.reviews/YYYY-MM-DD-HHMM`
  when a second run happens the same day (`review-all/SKILL.md`, `REVIEW_DIR`).
  The name is its age.
- Every review file except `PATTERNS.md` opens with a run-metadata blockquote
  (`review-all/reference-metadata.md`). Its `> **Branch:**` line carries the
  full SHA in backticks, which is what deletion safety checks. A plan review
  carries `> **Plan:**` instead of a scope line.

## Artifacts

| Artifact | Producer | Harvest from | Lifecycle |
|---|---|---|---|
| `.plans/*.md` | User or plan mode. Read by `implement-plan`, `review-plan` | `## Behavior delta` entries with `Acceptance:` lines (`review-plan/reference.md`); decisions in Problem or Design sections; `- [ ]` tasks still unchecked. Branch: `Branch:` under `## Branch policy`, else `impl/<filename stem>` | Ticked in place by implement-plan; nothing deletes them |
| `.plans/nits.md` | `implement-plan` (format in its `reference.md`) | `## Task <i>` entries, ``- `path:line` — finding. fix. Source: <skill>``. P2, P3, or `nit:` only | Appended per task; end-of-plan asks address, defer, or discard |
| `<review dir>/SUMMARY.md` | `review-all` | `## Findings — untracked` (columns include `Blocking`, `Conf`, `Class`, `Tracked`); `## Coverage gaps` and `## Not checked`, which carry open items; tracked findings in a `<details>` block (`review-all/reference-tracking.md`); recommended fix order; a Trajectory section | Never deleted; a follow-up review appends a re-evaluation table to the newest one |
| `<review dir>/<DOMAIN>-REVIEW.md` | Each `review-*` skill run on its own (CODE, SECURITY, RELIABILITY, DATABASE, DOCUMENTATION, COVERAGE, INFRASTRUCTURE, CI, OBSERVABILITY, PERFORMANCE, API-COMPAT, AUTHORING, ACCESSIBILITY) | Findings tables, P0–P3 | None. Not written when the skill runs under review-all |
| `<review dir>/TRAJECTORY.md` | `review-trajectory` | `## Trajectory`, one `**<Axis> — <VERDICT>**` block per axis, `**Proposed follow-up:**` (`review-trajectory/reference-census-axes.md`) | None |
| `<review dir>/PATTERNS.md` | `discover-patterns` | `# Codebase Patterns`: conventions with exemplars and counter-examples, a source for AGENTS.md | Newest one is read by `review-code`. No metadata header |
| `<review dir>/PLAN-REVIEW.md` | `review-plan` | `**Verdict:**` line and findings table | None |

## What usually survives the durability test

- A constraint a fix revealed (a minimum, an ordering, a precision limit) that
  the code does not explain where an agent would see it.
- A `PATTERNS.md` convention that the code follows in most places and
  violates in some. AGENTS.md is where an agent learns it.
- A finding class that recurs across several review directories. That is a
  `REVIEW.md` line.
- A `Behavior delta` entry describing user-visible behavior that the README
  does not mention.

## Out of scope

- `review-material/`: audit-accomplishments keeps it on purpose as evidence.
- `CHANGELOG.md`: committed, not a working file.
- Claude Code transcripts and existing memory: `audit-history`.
