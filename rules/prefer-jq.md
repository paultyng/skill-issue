# prefer-jq

Prefer `jq` over Python for JSON and JSONL processing in shell commands.

- For extracting fields, filtering, or transforming JSON/JSONL, use `jq`.
- For JSONL files, pipe through `jq -c` with `select()` for filtering.
- Only use Python when the transformation requires logic `jq` cannot express (stateful aggregation, HTTP calls, complex string manipulation).
- This applies to Bash tool commands, not to application code in Go or other languages.
