# active-read skill

Implementation plan for `~/.claude/skills/active-read/` — an interactive learning skill that drives active-recall study sessions: ingest source → section-by-section summary → typology-driven understanding questions → user-led pace → synthesis at end. v1 is in-session only.

## Branch policy

- Branch: feat/active-read-skill
- Base: origin/main

## Goal

Add a workflow skill that helps the user digest large documents (proposals, architectures, vendor docs) via active-recall rather than passive summarization. Questions probe mental model, not memory. Evaluator is honest, not flattering. User controls pace.

## Definition of Done

- `~/.claude/skills/active-read/SKILL.md` exists with valid frontmatter, description starting `Use when…`, ≤1024-char description, ≤500-line body.
- `~/.claude/skills/active-read/reference.md` exists with TOC, question typology table (≥7 types mapped to Bloom levels), evaluation rubric, bad-question detector.
- Manual smoke test against a real source (one of the just-merged `review-*` SKILL.md files in this repo) produces: intake → section map → loop with ≥2 questions per section that pass the bad-question detector → honest evaluation → synthesis.
- "Out of scope for v1" section explicitly names: persistence, multi-session resume, progress scoring, spaced repetition, multi-source synthesis, evaluator-subagent.

## Constraints

- Mirror existing skill conventions: frontmatter shape, `Sources` section, terse-output, no narrative storytelling.
- Single-agent v1 (no evaluator subagent). Document the self-agreement risk as a known v1 limitation.
- Anti-sycophancy enforced via a rationalization table in the SKILL.md body, mirroring `implement-plan`'s pattern.
- All 4 input modalities: local files (PDF/MD/TXT via `Read`), URLs (via `WebFetch`), Notion pages (via `mcp__notion__notion-fetch`), pasted prose (inline conversation).
- Source detection rules: path-looking arg → file; URL schema → web; `notion.so/` host or Notion URL pattern → Notion; else pasted prose fallback.
- No external content reused under license; no Superpowers MIT notice needed for this skill.

## Tasks

- [ ] **Task 1: Scaffold the skill directory and frontmatter.** Create `~/.claude/skills/active-read/SKILL.md` with frontmatter (`name: active-read`, `description: Use when …` placeholder), H1 title, empty workflow body. Create `~/.claude/skills/active-read/reference.md` with a TOC placeholder. Files: `skills/active-read/SKILL.md`, `skills/active-read/reference.md`. Verify: `ls ~/.claude/skills/active-read/` shows both files; `head -3 SKILL.md` shows valid frontmatter.

- [ ] **Task 2: Write the description with triggers and Do-NOT guard.** Description includes triggers: "study this with me", "help me understand X", "digest this", "let's study this", "walk me through this", "explain and test me", "active reading", "active-read this", `/active-read PATH-OR-URL`. Include a `Do NOT use` guard: not for plain summary requests (use `Read` + summarize directly), not for code review (use `review-code`), not for plan review (use `review-plan`). Files: `skills/active-read/SKILL.md`. Verify: description starts with "Use when", is ≤1024 chars, contains both trigger phrases and Do-NOT guard.

- [ ] **Task 3: Intake phase + source detection.** Document phase 1 in SKILL.md: capture source (file / URL / Notion / paste), goal (decide / understand / evaluate / brief someone), time budget (15 min / 1 hour / multi-session), familiarity (cold / warm / refresher). Document source detection rules verbatim from Constraints. Files: `skills/active-read/SKILL.md`. Verify: section "### 1. Intake" present, all 4 source types named, 4 intake dimensions captured.

- [ ] **Task 4: Ingest & map phase with chunking and thesis extraction.** Document phase 2: detect sections via first `## ` heading; fallback to ~2k-char budget when no headings exist. For sources >15k chars, fan out parallel Haiku subagents on ~6k-char chunks to produce per-section "what + why this matters" summaries. **Extract the source's thesis once, here, and store it in conversation state for use in synthesis (Task 6). Do NOT re-extract at synthesis time.** User confirms or reorders the section map before continuing. Files: `skills/active-read/SKILL.md`. Verify: section "### 2. Ingest & map" present; chunking threshold (15k), chunk size (~6k), and thesis-storage-at-step-2 all stated explicitly.

- [ ] **Task 5: Section loop phase with user-led verbs.** Document phase 3: per section, agent emits ≤6-bullet summary (jargon defined once on first appearance) + 2-3 questions drawn from typology in reference.md, then waits. Cap 3 questions per section. Track which question types have been asked (internal array) and avoid doubling up within the same section. Supported user verbs: `next` (advance section), `redo` / `retry` / `let me try again` (re-pose current question, optionally rephrased), `more` (request more questions on this section, up to cap), `got it` (advance section), `harder` / `push me` (request a stricter question or harder type). Files: `skills/active-read/SKILL.md`. Verify: section "### 3. Section loop" present; all 5 user verbs (`next`, `redo`, `more`, `got it`, `harder`) documented; cap stated; rotation rule stated.

- [ ] **Task 6: Synthesis phase using stored thesis.** Document phase 4: user produces 3-sentence summary in own words → agent compares against thesis stored in Task 5 (NOT re-extracted) → identifies gaps citing specific source passages → asks "what would you do with this?" (apply / decide / discard / share). Anchoring risk explicitly addressed: thesis is from step 2, immune to the user's summary phrasing. Files: `skills/active-read/SKILL.md`. Verify: section "### 4. Synthesis" present; the no-re-extraction rule stated explicitly; one-line note about anchoring-risk mitigation.

- [ ] **Task 7: Anti-sycophancy guardrails + rationalization table.** Add a section to SKILL.md with: banned phrases ("Yes, exactly!", "Great answer!", "You've got it!", "Perfect!" without substantive content), required evaluation structure (what was right [specific quote from user] → what was missing [specific concept from source] → which passage to re-read [specific section/paragraph]), and a rationalization table mirroring `implement-plan/SKILL.md`'s reference-table pattern with ≥5 rows (e.g. "user sounds confident" → "still wrong if Y is missing"; "answer paraphrases source" → "recall, push for application"). Files: `skills/active-read/SKILL.md`. Verify: section present; ≥4 banned phrases listed; rationalization table has ≥5 rows.

- [ ] **Task 8: Out-of-scope-for-v1 section + Sources.** Add a section explicitly naming what is NOT in v1: persistence to disk, multi-session resume, progress scoring, spaced-repetition scheduling, multi-source synthesis (read 3 vendor docs together), evaluator-as-subagent. State each as a future hook, not "we'll come back to this in v1". Add a Sources section citing: Bloom's taxonomy ("Taxonomy of Educational Objectives", 1956), the self-explanation effect (Chi et al., 1989), the Feynman technique, Karpathy (Sequoia Ascent 2026, "specs as scaffold"), Osmani ("How to write a good spec for AI agents"). Files: `skills/active-read/SKILL.md`. Verify: both sections present; out-of-scope has all 6 items; Sources has all 5 citations with URLs where applicable.

- [ ] **Task 9: reference.md — question typology + Bloom mapping.** Populate `~/.claude/skills/active-read/reference.md` with: TOC at top; section "Question typology" with a table of ≥7 question types (compare/pick, predict failure, find the trade-off, apply to your stack, translate down, push back, why-not-the-obvious) each with: example phrasing, Bloom level mapping (comprehension / application / analysis / synthesis / evaluation — never "knowledge"), when to use, when NOT to use. Files: `skills/active-read/reference.md`. Verify: TOC present; table has ≥7 rows; every row has all 4 columns; no row is mapped to Bloom level "knowledge" (that's the recall/cmd-f category we're banning).

- [ ] **Task 10: reference.md — evaluation rubric and bad-question detector.** Add two sections to reference.md: (1) "Evaluation rubric" stating the three required parts of every answer evaluation (what was right + what was missing + which passage to re-read), with one worked example; (2) "Bad-question detector" listing 3 criteria — (a) user could answer via Cmd-F on the source, (b) question targets Bloom "knowledge" level, (c) same type already asked in this section. If a candidate question matches any criterion, reject and re-pick. Files: `skills/active-read/reference.md`. Verify: both sections present; rubric has 3 required parts and a worked example; detector has all 3 criteria.

- [ ] **Task 11: Smoke test against a real source.** Reload Claude Code (`claude` restart or `/help` refresh). Invoke the new skill manually with: `study this with me ~/.claude/skills/review-plan/SKILL.md`. Confirm: skill activates (does not get out-shadowed by `review-plan` itself); intake phase asks the 4 dimensions; section map produced; loop fires at least 2 questions; each question passes the bad-question detector (no Cmd-F-able questions); evaluation follows the 3-part rubric. Write a 1-paragraph "Test result" note at the bottom of THIS plan file before marking the task complete. Files: `docs/plans/2026-05-16-active-read.md` (this file). Verify: "Test result" paragraph appended; all task boxes ticked.
