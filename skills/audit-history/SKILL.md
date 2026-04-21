---
name: audit-history
description: Use when reviewing past agent sessions, auditing memory health, identifying repeated corrections or friction, cleaning up stale memories, proposing new skills and rules from usage patterns, or identifying mechanical improvements (testing, linting, static analysis, tooling) that could improve outcomes.
disable-model-invocation: true
---

# Audit History

Review past agent sessions and memory files to surface friction patterns, stale memories, and gaps. Synthesize findings into ranked recommendations for new skills, rules, and memory cleanup actions.

## Phase 1 -- Discover Sources

### Transcripts

Transcripts come from two sources. Both use JSONL format but have different schemas.

#### Cursor

Cursor agent transcripts live under `~/.cursor/projects/*/agent-transcripts/`.

1. List all project workspace directories under `~/.cursor/projects/`
2. For each, list `.jsonl` files in `agent-transcripts/`
3. **Distinguish parent from subagent transcripts**: parent transcripts are top-level `.jsonl` files; subagent transcripts live in subdirectories named by the parent's UUID. Only analyze parent transcripts

#### Claude Code

Claude Code session transcripts live under `~/.claude/projects/*/sessions/`. Project directory names are URL-encoded absolute paths (e.g. `%2FUsers%2Fpaul%2Fsrc%2Fmyproject`).

1. List all project directories under `~/.claude/projects/`
2. For each, list `.jsonl` files in `sessions/`

### Memory

Memory files live under `~/.claude/projects/*/memory/`.

1. Scan all project directories for `memory/` subdirectories
2. For each, list `.md` files (separate MEMORY.md index from content files)
3. Also scan `~/.claude/rules/` for global rules (needed for duplicate detection)

### Inventory

Report the combined inventory before proceeding:

```
Found N transcripts across M projects, Z memories across P projects:

Cursor (X transcripts):
- project-a: X1 transcripts

Claude Code (Y transcripts, Z memories):
- project-b: Y1 transcripts, Z1 memories (feedback x2, project x1)
- project-c: Y2 transcripts, 0 memories

Global rules: R rules in ~/.claude/rules/
Empty memory directories: [list]
Projects with sessions but no memories: [list]
```

## Phase 2 -- Batch and Dispatch

Launch transcript subagents and memory subagent **in parallel**.

### Transcript Subagents

Split transcripts into batches of ~25-30 for parallel processing.

1. Launch up to 4 parallel subagents, one per batch
2. Each subagent receives a file list and the extraction schema below
3. Use `jq` for JSONL extraction instead of reading raw content or using Python:
   - User messages: `jq -c 'select(.role == "human" or .role == "user") | .content' < file.jsonl`
   - Tool use: `jq -c 'select(.type == "tool_use") | {tool: .name}' < file.jsonl`
   - Message counts: `jq -c '.role' < file.jsonl | sort | uniq -c`
   - Truncate large fields: pipe through `jq '.content |= (tostring | .[0:500])'`

#### Transcript Extraction Schema

```
For each transcript (.jsonl file), extract:

- **Topic/title**: 3-6 word summary
- **User corrections**: instances where the user redirected the agent
  Signals: "no", "stop", "actually", "don't", "wrong", "drop",
  "wait", "not what I asked", "undo", "revert"
  Quote the user's exact words
- **Repeated commands**: commands typed multiple times
- **Frustrations/friction**: anything that slowed the user down or caused rework
- **Technologies/tools**: languages, frameworks, CLIs, MCP servers used

Return per transcript:
  Source: Cursor | Claude Code
  UUID: <filename without .jsonl>
  Topic: <3-6 words>
  Corrections: [quoted corrections]
  Repeated commands: [list]
  Friction: [friction points]
  Tools: [list]
```

### Memory Subagent

Launch **1 subagent** to analyze all memory files across all projects.

#### Structural Checks

- MEMORY.md entries pointing to missing files on disk
- Files on disk not listed in MEMORY.md
- Empty memory directories or empty MEMORY.md files

#### Content Staleness Checks

- For memories with `originSessionId`, verify the session `.jsonl` file still exists
- For memories referencing specific file paths in content, check paths exist (`test -f`)
- Compare memory content against global rules in `~/.claude/rules/` -- flag if a memory substantially duplicates a global rule
- Check project activity: if no session files modified in last 30 days, flag as inactive

#### Cross-Project Checks

- Overlapping memories across projects (candidates for global rule promotion)
- Contradicting memories across projects (may be intentional project-specific overrides -- flag for review, don't auto-classify as errors)

#### Memory Extraction Schema

```
For each memory file, extract:
  Project: <project name>
  File: <filename>
  Type: user | feedback | project | reference
  OriginSession: <UUID or none>
  OriginSessionExists: true | false
  InMemoryIndex: true | false
  ReferencedPaths: [file paths mentioned in content]
  ReferencedPathsExist: [true/false each]
  DuplicatesGlobalRule: <rule filename or none>
  Staleness: fresh | structural-issue | content-stale | project-inactive
```

## Phase 3 -- Aggregate and Rank

After all subagents complete:

1. Merge transcript findings from all batches
2. Group friction patterns across sessions -- count how many sessions each pattern appears in
3. Rank by frequency (most common first)
4. Cross-reference with existing skills and rules:
   - Scan `~/.cursor/skills/` and `~/.claude/skills/` for personal skills
   - Scan `~/.cursor/rules/` and `~/.claude/rules/` for personal rules
   - Scan `.cursor/skills/`, `.cursor/rules/`, `.claude/skills/`, `.claude/rules/` in project workspaces under `~/src/`
5. Identify rules duplicated across multiple projects (candidates for promotion to user-level)
6. Note which friction patterns are already addressed by existing skills/rules
7. **Cross-reference memory with friction**:
   - If a friction pattern matches an existing memory's guidance but kept recurring → "memory exists but not effective"
   - If repeated friction has no corresponding memory → "missing memory"
8. Rank memory issues by severity: structural > content-stale > project-inactive

## Phase 4 -- Synthesize Recommendations

### Recommendation Types

- **Skill**: reusable multi-step workflow the agent executes
- **Rule**: behavioral guidance that shapes how the agent works
- **Memory**: project-specific context that should be created, updated, or promoted to a global rule
- **Mechanical improvement**: tooling, configuration, or infrastructure change that prevents classes of errors without agent behavioral changes (e.g. linter rules, static analysis checks, git hooks, pre-commit hooks, test coverage for friction-prone areas, CI checks)

### For Each Recommendation

Provide:
- **Name**: following verb-first / gerund naming convention
- **Type**: skill, rule, memory, or mechanical
- **Evidence**: session count + example quotes from transcripts, or memory analysis findings
- **Proposed content outline**: key sections and what they'd cover (for skills/rules/memory) or specific tooling/config change (for mechanical)

Use the `create-skill` skill to author any recommended skills.

### Mechanical Improvement Signals

Look for these patterns in transcripts that indicate a mechanical fix would help:

- **Same error corrected multiple times** → linter rule or static analysis check could catch it automatically
- **Manual formatting or style corrections** → formatter config or pre-commit hook
- **Repeated test failures in the same area** → missing test coverage or flaky test infrastructure
- **Agent repeatedly running the same verification steps** → CI check, git hook, or hook automation
- **Type errors or nil panics discovered late** → stricter compiler flags, `staticcheck`, `golangci-lint` rules
- **Proto/API issues caught in review** → `buf lint` or `buf breaking` rules

### Output Format

Present findings as a plan with three sections:

**Ranked friction table:**

```markdown
| Rank | Pattern | Sessions | Example quotes | Memory |
|------|---------|----------|----------------|--------|
| 1    | ...     | ~N       | "..."          | Gap    |
| 2    | ...     | ~N       | "..."          | Stale  |
```

**Memory health table:**

```markdown
| Status | Project | Memory | Issue | Action |
|--------|---------|--------|-------|--------|
| STALE  | ...     | ...    | Duplicates global rule | Remove |
| ORPHAN | ...     | ...    | Not in MEMORY.md | Add to index |
| GAP    | ...     | —      | N sessions, 0 memories | Review |
| EMPTY  | ...     | —      | Empty memory dir | Remove |
```

**Recommendations:**

```markdown
### N. `name` (type: skill|rule|memory|mechanical)

Evidence: appeared in ~N sessions / found in memory analysis
- "quoted correction" (session UUID)

Proposed content:
- Section 1: ...
- (for mechanical: specific tool, config change, or hook to add)
```

## Phase 5 -- Memory Cleanup Plan

Always runs after Phase 4. Produces a **dry-run report only** -- does not execute anything.

Categorize proposed actions by risk:

**Safe removals** (no content loss):
- Empty memory directories with no files
- Memories that exactly duplicate a global rule in `~/.claude/rules/`

**Index fixes** (structural repairs):
- Add missing files to MEMORY.md
- Remove MEMORY.md entries pointing to nonexistent files

**Requires judgment** (present for review):
- Merging overlapping memories
- Removing memories for inactive projects (may just be paused)
- Memories that partially overlap global rules

## Phase 6 -- Execute Cleanup

After presenting the cleanup plan, ask the user:

```
Would you like me to execute any cleanup actions?
1. Safe removals only
2. Safe removals + index fixes
3. All (confirm each judgment item individually)
4. Skip cleanup
```

For each action executed:
- Delete files or directories as needed
- Rewrite MEMORY.md indexes to match actual files
- For merges: show proposed merged content before writing
- Log every action taken

## Notes

- When the user scopes the analysis (e.g. "just the last 2 weeks", "only this project"), filter accordingly by modification time or project path
- If the user has previously run this analysis, diff against prior findings to surface new patterns
- Present all findings as a plan for user review before creating any skills, rules, or executing cleanup
