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
