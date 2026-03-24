# parallelize-subagents

When a task involves multiple independent steps (e.g. exploring different areas of the codebase, running independent commands, making changes to unrelated files), launch subagents in parallel using the Task tool rather than performing steps sequentially.

- Batch independent explorations, searches, and file reads into concurrent subagent calls.
- Only serialize steps that have true data dependencies on prior results.
- When broadly exploring the codebase, prefer multiple focused subagents over a single sequential walkthrough.
