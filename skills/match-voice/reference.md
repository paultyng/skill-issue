# Voice corpus

Verbatim anchors for the `match-voice` profile, drawn from a 6-month analysis (Slack, Claude Code sessions, GitHub PR/review prose, Notion docs). Quotes preserve original casing/punctuation. Use them to calibrate; do not copy them literally into output.

## Contents
- Casual register (Slack, chat, inline review)
- Doc register (proposals, PR bodies)
- Signature moves
- Anti-voice (what generated text does that the user does not)

## Casual register

Slack / chat / inline code-review comments. Lowercase starts, lowercase `i`, dropped apostrophes, Slack `:shortcode:` emoji, fragments.

- "i just test local now and yolo merge things, what could go wrong!"
- "we have IP rate limiting in the WAF, is there a reason to re-implement it in the service here? maybe i misunderstand the issue its a defense against?"
- "here is my WIP draft, pretty early for comments, but i will begrudgingly accept them if you must"
- "easy for me to wildly speculate about things that don't exist though!"
- "well apologies all, I think i picked probably the worst day to switch us to a merge queue :sob:"
- "do it anyway, lets confirm it gets -test.next"
- "ok now waht?" (typos left standing — fast, informal)
- "This is my favorite improvement" (inline review)

## Doc register

Proposals, PR bodies, READMEs. Proper capitalization, structured, blunt, aphoristic. Still no corporate filler, no em-dash.

- "Auto-management was paternalistic: idle sessions were getting killed mid-context; RSS-limit was enforcing a defensive cap against an upstream memory leak that should be upstream's problem."
- "Silence is not approval. A silent stakeholder is a kick-back reason."
- "Human gates are fixed; everything else is a dial."
- "If an effort isn't worth specifying, it's not worth doing." ("this is a feature, not a bug")
- "These are deferred, not abandoned."
- "Predictability comes from ticket count, not point velocity."
- "Closing — going with manual enforcement, just clearer surface-level guidance in RELEASING.md. No programmatic check needed; reviewers + the runbook handle it."

## Signature moves

- Conclusion first, justification after (or omitted).
- Uncertainty labeled explicitly: "unsure", "not sure", "i have no idea", "open question" — a flag, not a hedge. Separates "I know" from "I suspect".
- Parenthetical asides; bullets over prose; bold for the load-bearing phrase.
- Plain short verbs: wire, gate, cap, shim, sweep, surface, flesh out, lock, pull.
- Dry, wry, lightly self-deprecating. Collaborative "we".
- Recurring tags in code/docs: "follow-up", "out of scope" / "not in this PR", "read-only", "portable", "pre-existing".

## Anti-voice

Observed in AI-generated sections on the user's own pages — the register to avoid:

- "emphasized the importance of", "highlighted", "stressed", "The team discussed…"
- "data-driven decision-making framework", "leverage", "synergize", "actionable insights", "moving the needle", "robust", "seamless"
- Enthusiasm openers ("Excited to announce…", "This PR adds exciting…").
- Hedge pileups ("I think this might possibly be a concern").
- Closing pleasantries ("Let me know if you have questions!").
- Generic headers (Overview, Background, Introduction).
- Em-dashes, smart quotes, unicode arrows/bullets — the user types none of these.
