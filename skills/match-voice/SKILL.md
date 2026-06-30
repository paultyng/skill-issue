---
name: match-voice
description: Use when asked to rewrite or format text in the user's voice, "make this sound like me", "match my voice", "de-stiffen this", when text "reads too corporate / businessy / stiff", to "strip the em-dashes / agent typography", or to draft a Slack message, PR body, or doc in the user's voice. Also /match-voice.
---

# Match Voice

Rewrite supplied text — or draft from bullets — so it reads in the user's natural voice and in keyboard-typed prose. Preserve meaning; never invent claims or facts. Normalizing typography is about reading like a human typed it on a keyboard, **not** about hiding that an agent wrote it (surfacing agent authorship is fine).

## Modes

- **Rewrite** — text is supplied: recast it in-voice for the target register.
- **Draft** — only bullets/intent supplied: write it in-voice. Add no facts beyond the input.

## 1. Pick the register

Infer from where the text will land; override if the user says so. Casual tics belong **only** in the casual register.

| Register | Casing | Apostrophes | Emoji | Lands in |
|---|---|---|---|---|
| casual | lowercase sentence starts, lowercase `i` | drop them (`lets`, `thats`, `dont`) | ok, as Slack `:shortcode:` (`:sob:`, `:sweat_smile:`) | Slack DMs/chat, inline code-review comments |
| doc | normal capitalization | keep | none | PR bodies, Notion proposals, READMEs, commit bodies |

When unsure, default to **doc** — the safer, less-tic'd register.

## 2. Apply the voice

Core moves, every register:

- **Conclusion first.** State the call, then the why. ("Auto-management was paternalistic." then the reasons.)
- **Plain words, short precise verbs** — wire, gate, cap, shim, sweep, surface, flesh out, lock, pull. Jargon only when needed, defined on first use.
- **Label uncertainty; don't hedge it.** Say "unsure", "not sure", "open question", "i have no idea" as explicit flags. Separate what you know from what you suspect. Never a hedge pileup ("I think this might possibly").
- **Dry and wry, lightly self-deprecating.** No warmth-performance, no morale-pumping.
- **Parenthetical asides** for the side-thought. **Bullets** over prose for lists. **Bold** the load-bearing phrase.
- **Aphoristic punch** where it fits: short declaratives ("This is a feature, not a bug.").
- **"we"** framing for shared work.

## 3. Strip the anti-voice

Cut on sight, any register:

- **Corporate filler** — leverage, synergy, actionable, ensure, "in order to", "moving the needle", "data-driven * framework", robust, seamless.
- **Enthusiasm openers** — "Excited to announce", "This PR adds exciting".
- **Hedge pileups** — "I think this might possibly".
- **Closing pleasantries** — "Let me know if you have questions!", "Hope this helps".
- **AI recap verbs** — emphasized, highlighted, stressed, "The team discussed".
- **Generic headers** — Overview, Background, Introduction. Name the section for what it says.

## 4. Normalize typography to keyboard ASCII

Two layers, then verify.

1. **Rewrite by hand** the constructions that carry meaning: recast em-dash clauses into the user's comma or parenthetical style; turn arrows into words or `->`. Don't blind-swap where the phrasing itself should change.
2. **Run the deterministic pass** on the result:
   ```bash
   perl scripts/strip-tells.pl < draft.txt > clean.txt
   ```
   It maps em/en dashes, smart quotes, ellipsis, arrows, bullets, unicode spaces, and math/section symbols to ASCII. Slack emoji stay as `:shortcode:` (already ASCII).
3. **Verify mechanically** — prove no tells remain, don't assume:
   ```bash
   LC_ALL=C grep -n '[^ -~	]' clean.txt   # any non-ASCII byte (tab allowed); expect no output
   ```
   If it prints anything, fix those spots and re-run. No "looks clean" without this grep.

## 5. Output

Print the rewritten/drafted text in the chosen register, then a one-line note of what changed:

> _voice: doc register; normalized 3 em-dashes + smart quotes; cut "leverage", "seamless", a closing pleasantry._

## Anti-patterns

- Casual tics (lowercase `i`, dropped apostrophes, emoji) in a doc-register PR body or proposal.
- Adding claims or numbers not in the source — this is a voice pass, not a content pass.
- Claiming typography is clean without running the verify grep.
- Blind-replacing every em-dash with " - " when a comma or parens reads more like the user.
- Flattening the dry humor or the honest "unsure" into bland corporate-neutral.

See [reference.md](reference.md) for the verbatim voice corpus the profile is drawn from.
