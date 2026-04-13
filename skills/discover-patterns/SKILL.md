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

### 2. Launch discovery subagents in parallel

Launch up to 4 concurrent subagents (`subagent_type="generalPurpose"`), each covering a group of pattern categories from the taxonomy. Each subagent reads all relevant files and identifies recurring patterns.

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

For each pattern discovered, record:
- **Name**: short descriptive name
- **Description**: what the pattern is and how it works
- **Confidence**: ESTABLISHED (>80% of relevant files follow it), EMERGING (50-80%), INCONSISTENT (<50%)
- **Exemplars**: 2-3 file:line references showing the pattern
- **Counter-examples**: file:line references that deviate (for EMERGING/INCONSISTENT patterns)

### 3. Consolidate

Merge subagent outputs. Deduplicate overlapping patterns (e.g., a DI pattern that also appears as a testing pattern). Resolve confidence levels across the full dataset.

### 4. Write output

Create the output directory (`mkdir -p reviews`) and write to `reviews/PATTERNS.md`. Overwrite if it already exists. Present the report to the user.

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

- Focus on patterns that are actionable — skip trivially obvious things (e.g., "files end with `.go`").
- A pattern requires at least 3 exemplars to be reported. Fewer is anecdotal, not a pattern.
- When confidence is INCONSISTENT, note which approach is more common and which is the outlier.
- Keep the output concise: 2-3 exemplars per pattern, not exhaustive file lists.
- For detailed discovery heuristics per category, see [reference-pattern-taxonomy.md](reference-pattern-taxonomy.md).
