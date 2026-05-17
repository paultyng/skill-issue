---
name: active-read
description: Use when the user wants interactive active-recall study on a document or topic. Triggers: "study this with me", "help me understand", "digest this", "let's study this", "walk me through", "explain and test me", "active reading", "active-read this", "/active-read". Do NOT use for passive reading (`Read`), code review (review-code), or plan review (review-plan).
---

# Active Read

Drive an interactive study session over a document or topic via active recall: ingest → section-by-section summary → typology-driven understanding questions → user-led pace → synthesis. Honest evaluation, not flattery.

## Workflow

### 1. Intake

Capture four dimensions before ingesting the source:

- **source** — file path, URL, Notion page, or pasted prose.
- **goal** — decide / understand / evaluate / brief someone else.
- **time budget** — 15 min / 1 hour / multi-session.
- **familiarity** — cold / warm / refresher (warm = some prior exposure; refresher = solid prior exposure, want a recap).

Source detection rules:

- Path-looking arg with a file ext (e.g. `.pdf`, `.md`, `.txt`) → local file; read via the `Read` tool.
- URL schema (`http://`, `https://`) → web source; fetch via `WebFetch`.
- `notion.so/` host or Notion URL pattern → Notion page; fetch via `mcp__notion__notion-fetch`.
- Else → pasted prose fallback; treat the user's text in-conversation as the source.

If the user invokes with no source, ask once and stop until they provide one. Do not infer.

### 2. Ingest & map

Read the source and produce a section map before any questions.

**Section detection:**

- First-pass: split on `## ` headings (level-2 markdown). Each heading + its body is one section.
- Fallback when no `## ` headings exist: split into ~2k-char chunks at paragraph boundaries.

**Chunking for large sources:**

- For sources >15k chars, fan out parallel Haiku subagents on ~6k-char chunks. Each subagent produces a per-section "what + why this matters" one-line summary. Merge results into a single section map.
- Smaller sources: read inline and produce the map directly.

**Thesis extraction (one-shot, here):**

Extract the source's central thesis — the one sentence the author would write on a sticky note if asked "what's the point?" — and **store it in conversation state for use in synthesis (Task 6 / Section 4). Do NOT re-extract at synthesis time.** Anchoring risk: re-extracting after the user has written their own summary risks the agent anchoring on the user's phrasing rather than the source's actual claim. Extract once, freeze.

**User confirmation:**

Present the section map (titles + one-line "what + why") to the user. They confirm, reorder, drop, or merge sections. No question loop runs until the map is confirmed.

### 3. Section loop

For each confirmed section, in order:

**Summary first.** Emit a ≤6-bullet summary. Jargon is defined inline the first time it appears in a section, never re-defined within the same section.

**Questions next.** Draw **2 questions by default** from the typology in `reference.md`. Use **3 when the section is dense / high-stakes / introduces ≥3 new concepts** (judgment call; bias slightly toward 2 to keep pace).

**Rotation rule:** Track which question types have been asked in this section (internal array). Do not double up — every new question in the same section must be a different type from those already asked. If the typology is exhausted for this section, say so explicitly rather than repeating a type.

**Wait, don't drive.** After emitting questions, stop. The user controls the pace via verbs:

- `next` — advance to the next section.
- `redo` / `retry` / `let me try again` — re-pose the current question; optionally rephrase it from a different angle.
- `more` — request more questions on this section. **`more` lifts the default count** of 2/3 — the agent keeps emitting new-type questions until the user says `next` / `got it`, or the typology is exhausted.
- `got it` — advance to the next section.
- `harder` / `push me` — request a stricter question or a harder-Bloom-level type from the typology.

If the user answers, evaluate per the rubric in `reference.md` (Task 10 fills the rubric); per evaluation, the agent then waits for the next verb. Do not advance unprompted.

### 4. Synthesis

When the user signals end-of-sections (`synthesize` / `summarize` / `wrap up` / `I'm done`):

**Step 1 — User summary.** Ask the user to produce a **3-sentence summary in their own words.** If they paraphrase the source's wording back, push back: "that's reading, not synthesizing — re-state it as you'd explain it to a teammate."

**Step 2 — Diff against the stored thesis.** Compare the user's summary against the **thesis stored in Task 4** (step 2 of the workflow). Do NOT re-extract the thesis here. See the anchoring note in `### 2. Ingest & map`: re-extraction at synthesis time risks the agent anchoring on the user's phrasing rather than the source's actual claim. The whole point of storing the thesis up front is that this diff is independent.

**Step 3 — Identify gaps.** For each gap (a claim in the stored thesis that the user's summary missed, distorted, or contradicts), cite the specific source passage. Use the evaluation rubric structure from `reference.md`: what was right (quote the user) / what was missing (quote the source) / which passage to re-read. Honest, not flattering.

**Step 4 — Action.** Ask "what would you do with this?" — `apply` (use it in current work) / `decide` (it feeds a pending decision) / `discard` (not actionable) / `share` (forward to someone). Do not assume on the user's behalf.

## Anti-sycophancy guardrails

The evaluator's job is to be useful, not encouraging. Flattery without substance teaches the user nothing.

**Banned phrases** — never emit without substantive content immediately following:

- "Yes, exactly!"
- "Great answer!"
- "You've got it!"
- "Perfect!"
- "Spot on!"
- "Absolutely!"

If the user is actually right, name *what specifically they got* (cite the source) — that's evaluation, not flattery.

**Required evaluation structure** — every grade has all three parts:

1. **What was right** — quote the specific phrase or claim from the user's answer that matches the source's argument.
2. **What was missing** — name the specific concept, caveat, or implication from the source that the user did not surface.
3. **Which passage to re-read** — point to the specific section, paragraph, or page where the missing piece lives.

If you cannot fill all three parts honestly, the user's answer is too thin to evaluate; re-pose or push back instead of fabricating an evaluation.

### Rationalization table

| Excuse | Reality |
|---|---|
| "User sounds confident; I should agree." | Confidence is not correctness. If Y is missing, say so. |
| "Answer paraphrases the source nicely." | Paraphrase is recall (Bloom 1). Push to application or analysis (per `reference.md`). |
| "Pointing out gaps will discourage them." | Hiding gaps trains them to plateau. Trust from honesty compounds; encouragement from flattery doesn't. |
| "Their answer is partial; the rest will come." | Will it? Surface what's missing now; don't bet on future epiphany. |
| "I should be a 'coach,' not a 'critic.'" | A coach who only encourages is decorative. The diff between coach and critic is honest feedback the user can act on. |
| "There's no specific source passage to cite." | Then your evaluation is opinion, not evidence. Find the passage or downgrade your claim. |

Per `~/.claude/rules/probe-not-assume.md` (forthcoming): evaluation cites probed source passages, not paraphrase from memory. If you cannot quote the source, you have not read it carefully enough to grade.

## Out of scope for v1

These are future hooks, intentionally excluded from v1 to keep the skill focused. Each is a future skill or a v2 of active-read, not a backlog item for v1:

- **persistence to disk** — no `./notes/` files written; all state stays in the conversation.
- **multi-session resume** — no way to pick up a study session a day later.
- **progress scoring** — no quiz score / accuracy metric across sessions or topics.
- **spaced-repetition scheduling** — no Anki-style review-at-intervals.
- **multi-source synthesis** — no "read these 3 vendor docs and compare"; single source per session.
- **evaluator-as-subagent** — evaluator runs in the same agent as the question-poser. Known self-agreement risk; v2 splits it to a separate Opus subagent (mirroring `implement-plan`'s reviewer pattern).

## Sources

- Bloom, B. S. (Ed.) (1956). *Taxonomy of Educational Objectives: The Classification of Educational Goals*. Bloom's taxonomy levels (knowledge / comprehension / application / analysis / synthesis / evaluation) underpin the question typology in `reference.md`.
- Chi, M. T. H., Bassok, M., Lewis, M. W., Reimann, P., & Glaser, R. (1989). "Self-explanations: How students study and use examples in learning to solve problems." *Cognitive Science 13*, 145-182. Active-recall and self-explanation as drivers of retention.
- The Feynman technique — explain a concept in simple terms, identify gaps, simplify. Popularized via Gleick, J. (1992) *Genius: The Life and Science of Richard Feynman*.
- Karpathy, A. (2026). "Sequoia Ascent 2026." <https://karpathy.bearblog.dev/sequoia-ascent-2026/>. "Specs as scaffold" framing for LLM-assisted comprehension and the "context is the program" lineage.
- Osmani, A. "How to write a good spec for AI agents." <https://addyo.substack.com/p/how-to-write-a-good-spec-for-ai-agents>. Spec clarity reduces error multiplication; informs the intake + section-map design.
