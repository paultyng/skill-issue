# subagent-model-routing

When delegating to a subagent (per `parallelize-subagents`), pick a model tier matched to the task. Default Sonnet. Drop to Haiku for mechanical work. Reach for Opus only when the task needs deep reasoning Sonnet won't deliver.

## Decision table

| Task | Model | Why |
|---|---|---|
| Mechanical: 1-2 file edits, well-defined transforms, format/lint/regen, exact-match lookups, schema-driven extraction | Haiku | Output bounded; no architectural reasoning |
| Summarization: condense raw output (logs, blame, transcripts) into a tight summary | Haiku | Compress in, compress out; no new insight required |
| Scoring against an explicit rubric (HIGH/MEDIUM/LOW with clear criteria) | Haiku | Rule application, not judgment |
| Investigation: multi-file pattern survey, "where is X" | Haiku or Sonnet | Haiku for "find and list"; Sonnet for "interpret what we found" |
| Analysis: code review with structured findings, log interpretation, multi-file integration where intent matters | Sonnet | Default tier; moderate reasoning |
| Synthesis: dedup + prioritize across many sources, semantic conflict resolution, PR-body authoring from a non-trivial diff | Sonnet | Combining pieces requires real reasoning |
| Design: architecture review, ambiguous trade-offs, novel debugging, multi-step refactors, threat modeling | Opus | Reserve for actually-hard problems |
| Unsure | Sonnet | Default; don't pick Opus "to be safe", it overpays on bounded tasks |

## How to specify

The Task tool accepts a `model` parameter (`haiku` / `sonnet` / `opus` / a full model ID / `inherit`). Set it explicitly when invoking from a skill:

```
Task(subagent_type="general-purpose", model="haiku", prompt="...")
```

`inherit` (or omitted) uses the parent's model. Override when:
- The task is bounded and Haiku will do (saves cost and latency).
- The task needs Opus and the parent is on Sonnet (bumps reasoning quality where needed).

## Two-stage pattern (recommended for voluminous input)

When the work has two phases (extract structured data from raw input, then interpret it), split:

1. **Haiku stage**: extract relevant data into a structured form (e.g. "first failing assertion plus 10 lines of context").
2. **Sonnet stage**: interpret the structured data (e.g. "what likely broke").

Examples:
- `ci-debug-loop` log analysis: Haiku extracts the first failing line and nearby context; Sonnet interprets the cause.
- `audit-history` memory analysis: Haiku does structural checks (file exists, in MEMORY.md, duplicates a rule); Sonnet synthesizes cross-project patterns.

## Anti-patterns

- Defaulting everything to Opus "to be safe". You pay for reasoning the task doesn't use.
- Defaulting everything to Haiku for cost. Synthesis-heavy tasks degrade visibly.
- Setting `model:` once and never revisiting. Tier choices age as the skill evolves.
- Skipping the model param entirely for high-volume fan-out (e.g. per-file blame across 50 files). At scale, the default tier is the biggest cost lever.

See `subagent-prompt-contract` for prompt structure regardless of model, and `parallelize-subagents` for when to delegate at all.
