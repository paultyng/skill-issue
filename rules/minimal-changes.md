# minimal-changes

When implementing a requested change, make **only** the changes the user asked for.

- Do not make additional "cleanup" or "consistency" changes alongside the requested work.
- If you notice something that should be changed but wasn't requested, mention it after completing the requested work — don't silently include it.
- When presenting multiple implementation paths, wait for the user to choose before writing any code.
- Never commit review artifacts (DEEP-REVIEW.md, analysis files, etc.) unless explicitly asked.
- Never document internal/private behavior unless explicitly asked.
- Never expose additional public API surface (new exports, new endpoints, new proto fields) beyond what was requested.
