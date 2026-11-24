# Output Templates

Per-domain shapes each review subagent emits. The summarizer compresses them into SUMMARY.md.

## Contents

- [Consolidated security findings](#consolidated-security-findings)
- [Consolidated reliability findings](#consolidated-reliability-findings)
- [Consolidated code findings](#consolidated-code-findings)
- [Consolidated documentation findings](#consolidated-documentation-findings)
- [Consolidated infrastructure findings](#consolidated-infrastructure-findings)
- [Consolidated CI findings](#consolidated-ci-findings)
- [Consolidated observability findings](#consolidated-observability-findings)
- [Consolidated API compatibility findings](#consolidated-api-compatibility-findings)
- [Consolidated performance findings](#consolidated-performance-findings)
- [Consolidated coverage findings](#consolidated-coverage-findings)
- [Re-evaluation table (for follow-up reviews)](#re-evaluation-table-for-follow-up-reviews)


The `Tracked` column in every table below renders the unified tracking badge defined in [reference-tracking.md § Badge rendering](reference-tracking.md#badge-rendering). The example cell values (`—`, `TODO in file:line`) are placeholders — real rows render `[tracked: …]` or `[→ possibly overlaps: …]` per that section's rules.

## Consolidated security findings

```markdown
| Severity | ID | Finding | STRIDE | OWASP | Tracked |
|----------|----|---------|--------|-------|---------|
| CRITICAL | 1 | Description with code references | S1, E1 | A01, A07 | — |
| HIGH | 2 | Description with code references | T2 | A04 | TODO in file:line |
```

## Consolidated reliability findings

```markdown
| Priority | Finding | Impact | Effort | Tracked |
|----------|---------|--------|--------|---------|
| P0 | Description with code references | Impact on availability/latency | trivial / small / moderate / large | — |
```

## Consolidated code findings

```markdown
| Severity | ID | Finding | Source | Tracked |
|----------|----|---------|--------|---------|
| HIGH | 1 | Description with code references | ARCH1, DEP2 | — |
| MEDIUM | 2 | Description with code references | GO1, SA3 | TODO in file:line |
| MEDIUM | 3 | Description with code references | PB2, PBL1 | — |
| HIGH | 4 | Description with code references | REG1 | — |
| MEDIUM | 5 | Description with code references | CONF1, CONF2 | — |
```

## Consolidated documentation findings

```markdown
| Severity | ID | Finding | Source | Tracked |
|----------|----|---------|--------|---------|
| HIGH | 1 | Description with code references | DOC1, DOC4 | — |
| MEDIUM | 2 | Description with code references | DOC2 | TODO in file:line |
```

## Consolidated infrastructure findings

```markdown
| Priority | Surface | Finding | Impact | Effort | Tracked |
|----------|---------|---------|--------|--------|---------|
| P0 | k8s | Description with code references | Impact | trivial / small / moderate / large | — |
| P1 | terraform | Description with code references | Impact | Effort | FIXME in file:line |
```

## Consolidated CI findings

```markdown
| Priority | Workflow | Finding | Impact | Effort | Tracked |
|----------|----------|---------|--------|--------|---------|
| P0 | release.yml | Description with code references | Supply chain / security | trivial / small / moderate / large | — |
```

## Consolidated observability findings

```markdown
| Priority | Signal | Finding | Impact | Effort | Tracked |
|----------|--------|---------|--------|--------|---------|
| P0 | tracing | Description with code references | MTTR / debuggability | trivial / small / moderate / large | — |
```

## Consolidated API compatibility findings

```markdown
| Priority | Surface | Change | Class | Recommendation | Tracked |
|----------|---------|--------|-------|----------------|---------|
| P0 | proto | `pkg.Service.Method` removed at file:line | wire-breaking | Deprecate first; remove in next major version | — |
```

## Consolidated performance findings

Only emitted when `include_performance` is true.

```markdown
| Priority | Category | Finding | Impact | Effort | Evidence | Tracked |
|----------|----------|---------|--------|--------|----------|---------|
| P1 | allocation | Description with code references | Allocations on hot path | small | profile needed | — |
```

## Consolidated coverage findings

Per-package coverage (omit Delta column when no prior baseline exists):

```markdown
| Package | Coverage | Delta | Affected Functions |
|---------|----------|-------|--------------------|
| internal/auth | 78.4% | +2.1% | 3 changed, 1 uncovered |
| internal/store | 64.2% | — | 5 changed, 4 uncovered |
```

Uncovered functions (grouped by package, sorted by severity):

```markdown
| Severity | ID | Package | Function | File:Line | Tracked |
|----------|----|---------|----------|-----------|---------|
| HIGH | COV1 | internal/auth | `verifyToken` | auth/verify.go:42 | — |
| MEDIUM | COV2 | internal/render | `(*Page).Render` | render/page.go:104 | — |
| LOW | COV3 | internal/store | `formatRowKey` | store/key.go:18 | TODO in store/key.go:15 |
```

## Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Brief explanation of the fix |
| 2. Description | Still applicable | No changes |
```

