---
name: discover-patterns
description: >-
  Use when exploring a new codebase's architecture, auditing codebase
  consistency, generating a patterns document, or preparing input for
  conformance checking during code review.
---

# Discover Patterns

Analyze a codebase to discover and document its implicit architectural and implementation patterns.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase (default), specific packages/directories, or specific concern.
- Explore the scoped code using parallel explore subagents. Read source files, test files, config files, and build files.
- Classify files by type: `has_go`, `has_proto`, `has_ts`, `has_infra`, etc.

### 2. Identify candidate patterns (Opus)

Launch up to 4 concurrent subagents (`subagent_type="generalPurpose"`, `model: opus` per `subagent-model-routing` — architecture-level pattern recognition requires deep reasoning across the codebase), each covering a group of pattern categories from the taxonomy. Each subagent reads all relevant files and **identifies candidate patterns** with a signature the counting stage can apply mechanically.

| Subagent | Categories | Requires |
|---|---|---|
| Structure & Layering | STRUCT | Any source files |
| Error Handling & Observability | ERR, OBS | Any source files |
| Config & DI | CFG, DI | Any source files |
| Testing | TEST | Any source + test files |
| Transport | XPORT | HTTP/gRPC code present |

Each subagent receives:
- The scoped file list for its relevant file types
- Reference: [reference-pattern-taxonomy.md](reference-pattern-taxonomy.md) for what to look for

For each candidate pattern, record:
- **Name**: short descriptive name
- **Description**: what the pattern is and how it works
- **Search signature**: a concrete way to find further occurrences. A grep regex, file glob, AST predicate (e.g. "calls to `context.Background()` outside `main.go`"), or symbol pattern. Must be specific enough that the counting stage applies it mechanically.
- **Seed exemplars**: 1-2 file:line references the discovery subagent already saw

This stage does NOT compute confidence or gather exhaustive exemplars. Step 2.5 handles that.

### 2.5. Count occurrences per pattern (Haiku fan-out)

For each candidate pattern from step 2, spawn an `Explore` subagent (`model: haiku` per `subagent-model-routing` — applying a known signature is mechanical). Run up to 4 concurrently; if more than 4 patterns, launch the first 4 and the rest after one completes.

Each subagent receives (per `subagent-prompt-contract`):
- **Goal**: apply the search signature to the scoped file list. Return match count, total relevant files, additional exemplars, counter-examples.
- **Inline context**: pattern name + description + search signature + the scoped file list (paste; do not re-derive scope).
- **Output shape**: structured per-pattern record (counts + 2-3 exemplars + up to 3 counter-examples), ≤80 words.
- **Constraints**: read-only; no further subagents.
- **Return**: prefixed with `Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`.

Parent computes confidence from the returned counts:
- **ESTABLISHED**: matches in >80% of relevant files
- **EMERGING**: 50-80%
- **INCONSISTENT**: <50% but ≥3 matches

Drop patterns with fewer than 3 total matches (anecdotal, not a pattern).

### 3. Consolidate

Merge per-pattern records from step 2.5 (confidence, exemplars, counter-examples) with the descriptions from step 2. Deduplicate overlapping patterns (e.g. a DI pattern that also appears as a testing pattern). Resolve confidence levels across the merged dataset.

### 4. Write output

If `REVIEW_DIR` was provided by the review-all orchestrator, use it. Otherwise, resolve it:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR="reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR="reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
mkdir -p "$REVIEW_DIR"
```

Write to `${REVIEW_DIR}/PATTERNS.md`. Present the report to the user.

## Output Template

```markdown
# Codebase Patterns

> Discovered on YYYY-MM-DD. Scope: [full codebase | specific paths].

## STRUCT — Structure & Layering

### [Pattern Name]
**Confidence:** ESTABLISHED
**Description:** Brief description of the pattern.
**Exemplars:**
- `path/to/file.go:42` — explanation
- `path/to/other.go:15` — explanation

### [Pattern Name]
**Confidence:** INCONSISTENT
**Description:** Brief description.
**Exemplars:**
- `path/to/file.go:10` — majority approach
**Counter-examples:**
- `path/to/outlier.go:25` — deviates because...

## ERR — Error Handling
...

## OBS — Observability
...

## CFG — Configuration
...

## DI — Dependency Injection
...

## TEST — Testing
...

## XPORT — Transport
...
```

## Guidelines

- Focus on patterns that are actionable; skip trivially obvious things (e.g., "files end with `.go`").
- A pattern requires at least 3 exemplars to be reported. Fewer is anecdotal, not a pattern.
- When confidence is INCONSISTENT, note which approach is more common and which is the outlier.
- Keep the output concise: 2-3 exemplars per pattern, not exhaustive file lists.
- For detailed discovery heuristics per category, see [reference-pattern-taxonomy.md](reference-pattern-taxonomy.md).
