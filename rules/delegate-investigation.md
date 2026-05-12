# delegate-investigation

For any task that is **read-only investigation** (finding, locating, scanning, "where is X", "who uses Y", "how is Z implemented"), default to the **`Explore`** built-in subagent, not `general-purpose`.

`Explore` is denied `Write`/`Edit`, runs in its own context, and is purpose-built for exactly this use case. From the Claude Code docs:

> "Claude delegates to Explore when it needs to search or understand a codebase without making changes."

`Explore` accepts a thoroughness level: `quick` / `medium` / `very thorough`. Pick the lowest level that will plausibly answer the question.

## When to apply

- Any user question whose answer requires reading >2 files in main context.
- Symbol or call-site lookups across the codebase.
- "Where is this configured?" / "How does this work?" / "Does anything use Z?"
- Pattern surveys, conformance checks, "is this consistent?" questions.

## When NOT to use Explore

Use `general-purpose` instead when the task requires both exploration AND modification, complex reasoning to interpret results, or multiple dependent steps. `Explore` is read-only by design.

Use a direct tool call (Read/Bash) when the target is already known: a single known file path, a specific known symbol. Don't spin up an agent to do one `Read`.

## Anti-patterns

- Spawning `general-purpose` for a "find / locate / where is X" task. That's what `Explore` exists for.
- Skipping the thoroughness level. Passing nothing makes the agent guess.
- Doing a multi-file investigation in main context because "it's just a few greps". Main-context grep output sticks around for the rest of the session.

See `parallelize-subagents` for the broader "when to delegate at all" guidance, and `subagent-prompt-contract` for prompt structure.
