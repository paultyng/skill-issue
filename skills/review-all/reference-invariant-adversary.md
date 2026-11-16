# Invariant adversary reviewer

The prompt body and output template for the `Invariant adversary` subagent launched in [SKILL.md § 3](SKILL.md). Every other review subagent asks whether the diff does what it says. This one asks what must hold for every input, every pair of inputs, and every layer underneath, and then tries to break it.

## Input contract

This subagent is **input-starved by design**. The orchestrator passes exactly the resolved file list, the base ref, the diff, and repository read access. It withholds the system overview, the PR title and body, `REVIEW.md` sections, the `Open work context` block, and other subagents' findings. Each of those is a narrative of what the change is meant to do; a reviewer handed one checks the code against it and inherits its blind spots. The withholding is enforced by what step 3 puts in the prompt, not by an instruction to ignore context already given.

## Goal

Derive intent from the code alone, state the properties that must hold for every execution, and find the inputs, interactions, and layers under which they do not. A good finding is a falsifiable property, the concrete input or sequence that breaks it, the evidence, and the fix. You decide how to search; the enumeration below is the shape of the output, not a procedure.

Enumerate before probing. A review that starts from a suspected bug finds that bug and stops.

## What counts as evidence

- `path:line` in this repository, `path:line` in a dependency's source, or command output from something you ran. A pattern match, a plausible story, or a reading of the code is a hypothesis, not a finding.
- The construction the production code uses. A behavior confirmed only against a test harness, a substitute engine, recorded fixtures, or a different constructor is unverified; say so and name what would settle it.
- A hermetic test passing at an extreme is not evidence that the extreme holds under real precision, latency, or clock skew.

Code comments, prior decisions, and other reviewers' conclusions describe what someone believed. They are claims to test, not evidence. When new evidence contradicts a settled call, report it with the evidence.

## Known misses

Each line below is a class of bug this reviewer has failed to find before. Treat them as reminders of where to look, not as the full list.

- The smallest and largest values validation accepts: check they hold the invariants under real precision (truncation, serialization granularity), latency, and clock skew, not only in a hermetic test.
- Asymmetry across equivalence classes: if one class of null round-trips through a token and another is written as a literal, the asymmetry is the bug even when each path works alone.
- Pairs: two calls in sequence, two arguments of one kind in one statement, an argument plus a row cell, a request plus the background work it spawns, a retry plus the original. Most violations need two of something to show.
- Ownership after the caller leaves: a library that accepts a context on its public API may not propagate it to work it schedules internally. Read the dependency source and cite it.
- Timeout budgets: an outer deadline must exceed the sum of the inner timeouts it can contain, counting retries and first-call lazy initialization.
- Pre-existing bugs in code the diff touches or calls are in scope. Prefix them `pre-existing:`; the diff is the reason anyone is looking.

## Hard constraints

- MUST cite evidence as defined above for every finding. A finding without it is dropped or marked unverified, never reported as confirmed.
- MUST NOT treat the diff's own description of itself (names, comments, commit text, test names) as evidence of behavior.
- MUST NOT modify production code or tests. Reading, running existing tests, and writing throwaway probes outside the tree are fine.
- MUST report "no violations found" for an enumeration that produced none. An empty enumeration and a skipped enumeration are different results.
- Findings follow `terse-comments`: the problem and the concrete fix, no restating the diff, no praise.

## Output template

```markdown
### Invariants enumerated

| # | Invariant | Holds? | Evidence |
|---|-----------|--------|----------|
| I1 | Every recorded value maps to exactly one binding key | NO | `path:line` |
| I2 | Pool releases the slot at caller deadline | NO | dep source `path:line` |

### Equivalence-class matrix

| Input | Classes checked | Divergence |
|-------|-----------------|------------|
| `arg` | nil, typed-nil, zero, empty, duplicate | typed-nil and nil take different paths at `path:line` |

### Timeout budget

| Layer | Timeout | Contains | Fits? |
|-------|---------|----------|-------|
| handler | 5s | 2x upstream (2s each) + write | NO |

### Findings

| Priority | Finding | Class | Evidence | Tracked |
|----------|---------|-------|----------|---------|
| P0 | Description with concrete fix | invariant / equivalence / interaction / ownership / budget | `path:line` | — |
| P1 | pre-existing: description | equivalence | `path:line` | — |
```

The `Tracked` column renders the badge from [reference-tracking.md § Badge rendering](reference-tracking.md#badge-rendering). `path:line` cells wrap per [SKILL.md § Finding link wrapping](SKILL.md#finding-link-wrapping).
