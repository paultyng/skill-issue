---
name: analyze-sessions
description: Use when reviewing past agent sessions, auditing chat history for friction, identifying repeated corrections or commands, or proposing new skills and rules from usage patterns.
disable-model-invocation: true
---

# Analyze Sessions

Review past agent sessions to surface friction patterns, repeated commands, and user corrections. Synthesize findings into ranked recommendations for new skills and rules.

## Phase 1 -- Discover Transcripts

Transcripts come from two sources. Both use JSONL format but have different schemas.

### Cursor

Cursor agent transcripts live under `~/.cursor/projects/*/agent-transcripts/`.

1. List all project workspace directories under `~/.cursor/projects/`
2. For each, list `.jsonl` files in `agent-transcripts/`
3. **Distinguish parent from subagent transcripts**: parent transcripts are top-level `.jsonl` files; subagent transcripts live in subdirectories named by the parent's UUID. Only analyze parent transcripts

### Claude Code

Claude Code session transcripts live under `~/.claude/projects/*/sessions/`. Project directory names are URL-encoded absolute paths (e.g. `%2FUsers%2Fpaul%2Fsrc%2Fmyproject`).

1. List all project directories under `~/.claude/projects/`
2. For each, list `.jsonl` files in `sessions/`

### Inventory

After discovering both sources:

1. Group by source and project, count totals
2. Report the inventory before proceeding:

```
Found N transcripts across M projects:

Cursor (X transcripts):
- project-a: X1 transcripts
- project-b: X2 transcripts

Claude Code (Y transcripts):
- project-c: Y1 transcripts
- project-d: Y2 transcripts
```

## Phase 2 -- Batch and Dispatch

Split transcripts into batches of ~25-30 for parallel processing.

1. Launch up to 4 parallel subagents, one per batch
2. Each subagent receives a file list and the extraction schema below
3. Use `jq` for JSONL extraction instead of reading raw content or using Python:
   - User messages: `jq -c 'select(.role == "human" or .role == "user") | .content' < file.jsonl`
   - Tool use: `jq -c 'select(.type == "tool_use") | {tool: .name}' < file.jsonl`
   - Message counts: `jq -c '.role' < file.jsonl | sort | uniq -c`
   - Truncate large fields: pipe through `jq '.content |= (tostring | .[0:500])'`

### Extraction Schema

Each subagent should extract the following per transcript:

```
For each transcript (.jsonl file), read the content and extract:

- **Topic/title**: 3-6 word summary of what the session was about
- **User corrections**: instances where the user redirected the agent
  Look for signals: "no", "stop", "actually", "don't", "wrong", "drop",
  "wait", "not what I asked", "undo", "revert"
  Quote the user's exact words
- **Repeated commands**: commands or sequences the user typed multiple times
  across this session or that match patterns from other sessions
- **Frustrations/friction**: anything that slowed the user down, caused
  rework, or required multiple attempts
- **Technologies/tools**: languages, frameworks, CLIs, MCP servers used

Return structured output per transcript:
  Source: Cursor | Claude Code
  UUID: <filename without .jsonl>
  Topic: <3-6 words>
  Corrections: [list of quoted corrections]
  Repeated commands: [list]
  Friction: [list of friction points]
  Tools: [list]
```

## Phase 3 -- Aggregate and Rank

After all subagents complete:

1. Merge findings from all batches
2. Group friction patterns across sessions -- count how many sessions each pattern appears in
3. Rank by frequency (most common first)
4. Cross-reference with existing skills and rules:
   - Scan `~/.cursor/skills/` for personal skills
   - Scan `~/.cursor/rules/` for personal rules
   - Scan `.cursor/skills/` and `.cursor/rules/` in project workspaces under `~/src/`
5. Identify rules duplicated across multiple projects (candidates for promotion to user-level)
6. Note which friction patterns are already addressed by existing skills/rules

## Phase 4 -- Synthesize Recommendations

### Skill vs Rule

- **Skill**: reusable multi-step workflow the agent executes (e.g. shipping, CI debugging, PR management)
- **Rule**: behavioral guidance that shapes how the agent works (e.g. terseness, escalation policy, commit conventions)

### For Each Recommendation

Provide:
- **Name**: following verb-first / gerund naming convention
- **Type**: skill or rule
- **Evidence**: session count + example quotes from transcripts
- **Proposed content outline**: key sections and what they'd cover

Use the `create-skill` skill to author any recommended skills.

### Output Format

Present findings as a plan with two sections:

**Ranked friction table:**

```markdown
| Rank | Pattern | Sessions | Example quotes |
|------|---------|----------|----------------|
| 1    | ...     | ~N       | "..."          |
| 2    | ...     | ~N       | "..."          |
```

**Recommendations:**

For each proposed skill or rule:

```markdown
### N. `skill-name` (type: skill|rule)

Evidence: appeared in ~N sessions
- "quoted user correction" (session UUID)
- "quoted friction point" (session UUID)

Proposed content:
- Section 1: ...
- Section 2: ...
```

## Notes

- When the user scopes the analysis (e.g. "just the last 2 weeks", "only this project"), filter accordingly by modification time or project path
- If the user has previously run this analysis, diff against prior findings to surface new patterns
- Present the friction table and recommendations as a plan for user review before creating any skills or rules
