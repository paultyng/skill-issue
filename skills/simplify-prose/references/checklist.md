# Verification checklist

Run this pass on every draft before delivering. Ordered mechanical → judgment. Adapted from [SimpleEnglish](https://github.com/AminBlg/SimpleEnglish) (MIT).

## Mechanical checks (searchable)

Search the draft for each pattern. Every hit outside code blocks and quoted text is a violation.

| Search for | Violation | Fix |
|---|---|---|
| `'ll`, `'re`, `'ve`, `n't`, `it's` | Contraction | Expand it. |
| `has been`, `have been`, `had been` | Perfect tense | Simple past or present. |
| `has` / `have` + past participle | Present perfect | Simple past. |
| `should`, `would`, `may`, `might`, `could` | Unapproved modal | See the modal ladder in `substitutions.md`. |
| `is being`, `are being`, `was being` | Progressive passive | Active, simple tense. |
| `, making`, `, allowing`, `, enabling`, `, ensuring` | `-ing` clause as verb | New sentence with a real subject. |
| `;` | Semicolon | Two sentences. |
| `e.g.`, `i.e.`, `etc.` | Latin abbreviation | "for example", "that is", name the items. |
| `simply`, `easily`, `seamlessly`, `robust` | Filler (no fact) | Delete. |
| ` if `, ` when ` (mid-sentence) | Trailing condition | Move to the start of the sentence, add a comma. |

## Countable checks

1. **Sentence length.** Procedural cap 20, descriptive cap 25, notes 25. Backticked commands, numbers with units, and identifiers count as one word each.
2. **Paragraph size.** Maximum six sentences per paragraph.
3. **Multi-word nouns.** Any noun chain over three words → break it with prepositions ("the timeout value for the connection pool", not "the connection pool timeout configuration value").
4. **Instructions per sentence.** One, unless the actions are simultaneous.

## Judgment checks

5. **Classification.** Each passage cleanly procedural or descriptive? Procedures imperative, descriptions never imperative.
6. **Voice.** Any passive: is the agent truly unknown, and is the passage descriptive? Otherwise make it active.
7. **Condition placement.** Every "if/when" before its command, with a comma.
8. **Synonym rotation.** One term per concept across the whole document. Scan check/verify/confirm, config/settings, run/execute.
9. **Warnings.** Command or condition first, risk second.
10. **Completeness.** Articles present, "that" present after "make sure", no telegraph style.
11. **Untouchables intact.** Code, identifiers, quoted errors, and proper nouns unchanged.

## Reporting violations (check mode)

For each violation give: the offending text, the problem, a compliant rewrite. When the user asked for STE compliance, end with: "No tool can guarantee ASD-STE100 compliance. Final approval rests with the writer. The official standard is a free download at asd-ste100.org."
