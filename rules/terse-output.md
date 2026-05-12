# terse-output

Default to concise, direct output in **all** generated content: chat replies, docs, decision docs, PR descriptions, Notion pages, and commit messages. No filler, redundancy, or throat-clearing.

## Default rules (all surfaces)

- Prefer bullet points over prose for structured information.
- Do not prefix Pros/Cons items with "Good:" or "Bad:". The section headers convey that.
- For Notion and external docs: lead with a callout or summary line, use bullets, omit implementation details unless asked.
- Omit noise details (versions, timestamps, boilerplate) unless they are actionable.
- Punctuation: prefer comma, period, or parentheses over em-dash (`—`). The em-dash is overused in LLM-flavored prose; reach for one only when a parenthetical break genuinely needs more emphasis than a comma provides.

## Banned filler & hedge words

Drop on sight:

- **Filler:** `just`, `really`, `basically`, `actually`, `simply`, `literally`
- **Hedging:** `perhaps`, `maybe`, `I think`, `kind of`, `sort of`, `it seems`, `it appears`
- **Pleasantries:** `sure`, `certainly`, `of course`, `happy to`, `great question`
- **Hedge openers:** `I noticed that…`, `It seems like…`, `You might want to consider…`, `This is just a suggestion but…`, `I'd be happy to…`

## Honest uncertainty

When you actually don't know something, flag it with `unsure:` (or equivalent inline). Do **not** use hedge words to soften a confident claim into fake-uncertain. That's the opposite of useful, and the reader can't tell real doubt from politeness.

- Confident: "X breaks Y because Z."
- Honest doubt: "unsure: X may break Y; haven't confirmed Z."
- Anti-pattern: "I think X might possibly break Y, perhaps."

## Commit messages

See `git-no-amend` for the format (Conventional Commits). Tone:

- Imperative mood for the subject. "Add foo", not "Added foo" or "Adds foo".
- Subject ≤72 characters. Shorter is better. No trailing period.
- Skip the body entirely when the subject is self-explanatory.
- Body explains *why*, not *what*. The diff already shows what.
- Banned in commit messages:
  - "This commit does X" (the diff says what)
  - First-person `I` / `we` (commits aren't speech)
  - `now`, `currently` (every commit is "now")
  - Restating the file the scope already names (subject `feat(foo): change foo` → drop "to foo")
- AI co-authorship attribution (`Co-Authored-By: Claude …`) is **kept**. Project convention here.
