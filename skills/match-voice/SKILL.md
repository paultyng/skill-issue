---
name: match-voice
description: Use when asked to rewrite or format text in the user's voice, "make this sound like me", "match my voice", "de-stiffen this", when text "reads too corporate / businessy / stiff", to "strip the em-dashes / agent typography", or to draft a Slack announcement, PR body, or doc in the user's voice. Also /match-voice.
---

# Match Voice

Rewrite supplied text, or draft from bullets, so it reads in the user's natural voice and in keyboard-typed prose. Preserve meaning; never invent claims or facts. Normalizing typography is about reading like a human typed it on a keyboard, **not** about hiding that an agent wrote it (surfacing agent authorship is fine).

Output lands in Slack announcements, docs, PRs, commit bodies. It is always properly capitalized (sentence casing).

## Modes

- **Rewrite** — text is supplied: recast it in-voice.
- **Draft** — only bullets/intent supplied: write it in-voice. Add no facts beyond the input.

## The voice

Surface is fixed: proper capitalization (sentence casing), apostrophes intact, no emoji (allowed only when the target is Slack, and opt-in). Lowercase-everything is not the voice, it was just the casual surface. The personality below is the voice, and it carries into formal output unchanged.

- **Conclusion first.** State the call, then the why. ("Auto-management was paternalistic." then the reasons.)
- **Blunt and dry, lightly self-deprecating.** The wit is load-bearing, not decoration. Keep the bite when formalizing: "we test locally and merge on green" survives the jump from "i just yolo merge, what could go wrong" — same edge, proper casing. Do not sand it into corporate-neutral.
- **Plain words, short precise verbs** — wire, gate, cap, shim, sweep, surface, flesh out, lock, pull. Jargon only when needed, defined on first use.
- **Label uncertainty; don't hedge it.** Say "unsure", "not sure", "open question" as explicit flags. Separate what you know from what you suspect. Never a hedge pileup ("I think this might possibly").
- **Parenthetical asides** for the side-thought. **Bullets** over prose for lists. **Bold** the load-bearing phrase.
- **Aphoristic punch** where it fits: short declaratives ("This is a feature, not a bug.").
- **"we"** framing for shared work.

## Strip the anti-voice

Cut on sight:

- **Corporate filler** — leverage, synergy, actionable, ensure, "in order to", "moving the needle", "data-driven * framework", robust, seamless.
- **Enthusiasm openers** — "Excited to announce", "This PR adds exciting".
- **Hedge pileups** — "I think this might possibly".
- **Closing pleasantries** — "Let me know if you have questions!", "Hope this helps".
- **AI recap verbs** — emphasized, highlighted, stressed, "The team discussed".
- **Generic headers** — Overview, Background, Introduction. Name the section for what it says.

## Normalize typography to keyboard ASCII

Two layers, then verify.

1. **Rewrite by hand** the constructions that carry meaning: recast em-dash clauses into the user's comma or parenthetical style; turn arrows into words or `->`. Don't blind-swap where the phrasing itself should change.
2. **Run the deterministic pass** on the result (portable `sed`, no extra files):
   ```bash
   sed -e 's/—/ - /g' -e 's/–/-/g' -e 's/…/.../g' \
       -e 's/[“”]/"/g' -e "s/[‘’]/'/g" \
       -e 's/↔/<->/g' -e 's/→/->/g' -e 's/⇒/=>/g' -e 's/←/<-/g' \
       -e 's/[•·]/-/g' -e 's/≥/>=/g' -e 's/≤/<=/g' -e 's/≠/!=/g' \
       < draft.txt > clean.txt
   ```
3. **Verify mechanically** — prove no tells remain, don't assume:
   ```bash
   LC_ALL=C grep -n '[^ -~	]' clean.txt   # any non-ASCII byte (tab allowed); expect no output
   ```
   The grep is the real guarantee — it catches anything the `sed` missed (stray unicode spaces, exotic symbols). Fix each flagged spot by hand (e.g. a non-breaking space becomes a normal space) and re-run until clean. No "looks clean" without this grep.

## Output

Print the rewritten/drafted text, then a one-line note of what changed:

> _voice: normalized 3 em-dashes + smart quotes; cut "leverage", "seamless", a closing pleasantry._

## Anti-patterns

- Going casual on the surface — lowercase `i`, dropped apostrophes, unprompted emoji. Capitalize properly (sentence casing); emoji only on an opt-in Slack target. (Keep the personality, drop the casing.)
- Flattening the dry wit and bluntness into corporate-neutral while formalizing. The voice is the content.
- Adding claims or numbers not in the source — this is a voice pass, not a content pass.
- Claiming typography is clean without running the verify grep.
- Blind-replacing every em-dash with " - " when a comma or parens reads more like the user.
- Applying `simplify-prose` (ASD-STE100) here. That skill is for technical docs and deletes persuasion by design; in voice output the voice is the content.

See [reference.md](reference.md) for the verbatim voice corpus the profile is drawn from.
