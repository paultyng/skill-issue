# parallelize-subagents

Use subagents (via the Task tool) for two distinct reasons. Either reason on its own justifies delegation. Speed is not the only optimization.

## When to delegate

**Parallelism (speed).** When a task has multiple independent steps (exploring different areas of the codebase, running independent commands, making changes to unrelated files), launch subagents in parallel rather than serially.

**Context preservation (avoiding pollution).** Even for a single sequential task, delegate when the work would flood the main conversation with output the parent doesn't need to retain. From the Claude Code docs:

> "Use one when a side task would flood your main conversation with search results, logs, or file contents you won't reference again: the subagent does that work in its own context and returns only the summary."

Concrete examples of context-flood work that belongs in a subagent:

- Multi-file investigation (`grep -r`, `find`, walking a tree to answer one question)
- Analyzing voluminous logs, build output, or test output to identify one root cause
- Running expensive checks (full test suite, full review) when only the summary matters
- Reading more than ~2 files just to gather context for a single decision

## Rules

- Batch independent explorations, searches, and file reads into concurrent subagent calls.
- Only serialize steps with true data dependencies on prior results.
- Delegate single-task investigations of >2 files even when sequential. The subagent returns the summary; the raw reads stay in its context.
- Prefer multiple focused subagents over one sweeping walkthrough; focused prompts produce better summaries.
- Subagents cannot spawn subagents. The parent owns all fan-out; plan it up front.

## Anti-patterns

- Pulling raw `grep -r` / `find` output into the main conversation to "browse" results.
- Reading file after file in main context to answer one question instead of delegating.
- Doing heavy work in main context "because it's faster". Context window is a finite resource separate from latency.

See also: `delegate-investigation` (which agent type to pick for read-only work) and `subagent-prompt-contract` (how to write the prompt and return shape).
