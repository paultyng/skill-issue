# subagent-prompt-contract

Every subagent prompt must include four things, and every subagent must return in a predictable shape. Skipping either side wastes the delegation.

## Prompt — what the subagent receives

1. **Goal in one sentence.** What the subagent is producing, in active voice. Not "look into X" — "report whether X handles Y, with file:line evidence".
2. **Scene-setting context.** A short paragraph on why this matters and where the task fits in the broader work. Without it, the subagent makes incorrect assumptions about scope and produces generic answers.
3. **All needed context inline.** Paste the relevant file excerpts, error messages, plan fragments, or prior findings the subagent needs. **Do NOT ask the subagent to re-read files the parent already loaded** — that re-reads them in the subagent's context too, which defeats the delegation, and risks the subagent reading a different version if the tree has changed.
4. **Explicit output shape and length cap.** Markdown headings, bullets, or table format. Word/line cap (e.g. "under 200 words"). Otherwise the return is free-form prose that costs as much as just doing the work in main context.
5. **Hard constraints.** What the subagent must NOT do (e.g. "do not modify production code", "read-only", "do not spawn further subagents — Claude Code does not allow it anyway").

## Return — what the subagent produces

Default to a structured return so the parent can parse without re-reading the whole report. Lift the convention from [Superpowers](https://github.com/obra/superpowers):

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
<the actual report>
```

- **DONE** — task complete, no caveats.
- **DONE_WITH_CONCERNS** — task complete, but the subagent flags something the parent should consider before acting (uncertainty, edge case, alternative interpretation).
- **BLOCKED** — could not complete; explain what's missing or broken.
- **NEEDS_CONTEXT** — could not complete because the parent didn't supply enough; lists what's needed to retry.

The parent can branch on the status line without parsing the body.

## Anti-patterns

- **"Investigate X and report back."** No goal, no context, no output shape. Generic in, generic out.
- **"Read these files and tell me about them."** The parent should send the *content* it cares about, not file paths to re-read.
- **No length cap.** Subagent writes a 2000-word treatise; the parent loads all of it; delegation saved nothing.
- **Vague constraints.** "Be careful" is not a constraint. "Do not run any command that modifies the database" is.
- **Asking for a plan when you wanted a fix, or vice versa.** State the deliverable type unambiguously.

See `parallelize-subagents` for when to delegate, and `delegate-investigation` for which agent type to pick.
