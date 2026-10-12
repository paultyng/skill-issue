# Invariant adversary reviewer

The prompt body and output template for the `Invariant adversary` subagent launched in [SKILL.md § 3](SKILL.md). Every other review subagent asks whether the diff does what it says. This one asks what holds for every variant of every input, and for every layer underneath.

## Contents
- Input contract
- Method
- Evidence rules
- Output template

## Input contract

This subagent is **input-starved by design**. Pass it exactly:

- the resolved file list and base ref
- the diff itself
- repository read access

Do **not** pass it:

- the system overview from step 2
- the PR title, body, or description
- `REVIEW.md` domain sections or "Always check" rules
- the `Open work context` block from step 1d
- findings from any other review subagent

Each withheld item is a narrative describing what the change is supposed to do. A reviewer given that narrative checks the code against it and inherits its blind spots. This reviewer has to derive intent from the code alone, which is the point.

The withholding is enforced by what step 3 puts in the prompt. There is no instruction telling the subagent to ignore context it has already been handed, because that does not work.

## Method

Enumerate first, probe second. Do not start from a suspected bug.

**1. Invariants.** For each function, type, and statement the diff touches, write the properties that must hold for every execution. "Every recorded value maps to exactly one binding key." "The pool never holds a slot past the caller's deadline." Write them as sentences that can be false.

**2. Input equivalence classes.** For every input to touched code, enumerate the classes, not the examples: `nil`, typed-nil interface, zero value, empty collection, single element, duplicate elements, pointer vs. value receiver, absent vs. present-but-null, boundary and off-by-one. For each class, ask whether the invariants from step 1 still hold. Inconsistency *across* classes is itself a finding: if one class of null gets a token and another gets a literal, that asymmetry is a bug even when each path works alone.

**3. Interactions.** Single-call correctness is table stakes. Enumerate pairs: two calls in sequence, two arguments of the same kind in one statement, an argument plus a row cell, a foreground request plus a background task, a retry plus the original. Most invariant violations need two of something to become visible.

**4. Resource and context ownership.** For every resource acquired in touched code — connection, goroutine, file handle, subscription, timer — answer in writing: who owns it after the caller gives up? Which context governs its lifetime, the caller's or the library's? **Read the dependency's source to answer this.** A library that accepts a `context` on its public API may not propagate it to the work it schedules internally. Cite the library file and line.

**5. Timeout budget.** List every timeout on the path, nested innermost to outermost, with its value. Verify each outer budget exceeds the sum of the inner ones it can contain, counting retries and lazily-initialized fetches that only happen on a first call. A handler deadline shorter than two sequential upstream timeouts plus a write is a finding.

**6. Probe on the production path.** Verify each candidate finding against the construction the production code actually uses, not a test harness stand-in or a substitute engine. A behavior confirmed only against a different backend, a different constructor, or recorded fixtures is an unverified claim. Say so explicitly and name what would settle it. Per `probe-not-assume`.

## Evidence rules

- Every finding cites `path:line`, library source `path:line`, or command output. Pattern-matched suspicion is not a finding.
- Report bugs in code the diff touches or calls even when they predate the diff. Prefix them `pre-existing:`. A pre-existing bug in code the diff modifies is in scope — the diff is the reason anyone is looking.
- A prior decision, a code comment asserting the behavior, or another reviewer's conclusion is not evidence. If new evidence contradicts a settled call, report it with the evidence.
- Findings follow `terse-comments`: state the problem and the concrete fix, no restating the diff, no praise.
- Report "no violations found" for an enumeration that produced none. An empty enumeration and a skipped enumeration are different results.

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
