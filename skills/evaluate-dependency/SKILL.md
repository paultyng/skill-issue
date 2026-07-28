---
name: evaluate-dependency
description: Use when adding or evaluating a project dependency in any language, phrases like "should I use X library", "evaluate <package>", "what library for Y", or when reviewing a PR that touches a manifest (go.mod, package.json, requirements.txt, pyproject.toml, Cargo.toml, Gemfile, mix.exs, composer.json). Also use when comparing alternatives, choosing between major versions of the same package, or when review-security / review-code encounters a new dep in scope. Produces a GO/CAUTION/NO-GO verdict with the canonical package coordinate to use. Language-specific quirks (Go's semantic import versioning /v2 paths, npm scoping, etc.) live in references/.
---

# Evaluate Dependency

Dual-purpose: upfront selection when adding a new dep, and review when a PR adds or bumps one. Same evaluation criteria either way, with per-language addenda for ecosystem-specific quirks.

## When to use

| Mode | Triggers |
|---|---|
| **Selection** | Considering adding a dep, asks "should I use X", compares alternatives, before `go get` / `npm install` / `pip install` / `cargo add` |
| **Review** | PR diff touches a manifest, or `review-security` / `review-code` sees a new dep in scope |

## Language-specific quirks (read first)

The canonical package coordinate usually has ecosystem-specific gotchas that override the general criteria. The wrong coordinate is the wrong dep, no matter how good the package is.

- **Go**: [references/go.md](references/go.md). Semantic import versioning (`/v2`, `/v3` paths), `+incompatible` smell, `pkg.go.dev` / `vuln.go.dev`, `govulncheck`.
- Other ecosystems: not yet covered here. Run the [general checklist](#evaluation-criteria) and flag uncertainty about the canonical coordinate with `unsure:` (per `terse-output`) rather than guessing.

Future addenda: npm (scoped vs unscoped, deprecated packages, ESM/CJS), Python (package vs distribution name, wheel/sdist, ABI compatibility), Rust (pre-1.0 churn, crate renames), Ruby (transitive native-extension hazards). Add when a real evaluation surfaces the need.

## Evaluation criteria

Run through these. Cite specific data: no hand-waving, no `I think`.

1. **License.** Detect via the ecosystem's registry or the repo's `LICENSE` / `LICENSE.md` / `COPYING`. Permissive (MIT, BSD, Apache-2.0, ISC, MPL-2.0) is generally fine. Copyleft (GPL, AGPL, LGPL) needs an explicit compatibility check against the user's project license. **No license = no use.** Note relicense history; relicenses are a red flag.

2. **Internal precedent.** Before weighing external popularity, check whether the candidate (or an equivalent) is already used or wrapped internally. Sources, in order:
   1. Project-local hints: `CLAUDE.md`, `REVIEW.md`, `.claude/rules/`, and the manifests of sibling services if mounted locally.
   2. Internal code search if available: Sourcegraph (`mcp__sourcegraph__keyword_search` / `mcp__sourcegraph__list_repos`), `gh search code` scoped to the user's orgs.
   3. Internal package registry / module index if the project documents one.

   A candidate with strong internal precedent beats a marginally more-popular external alternative — consistency, shared CVE response, shared tooling all compound. An internal wrapper or replacement (e.g. an `internal/x` package covering the same need) usually means **don't add the external dep**; use the internal one. If no internal-search tooling is reachable, mark this row `unsure: no internal index available` rather than skipping.

3. **Popularity / community signal.** Stars (rough proxy), the ecosystem's "depended by" / "imported by" count, Sourcegraph importer search if available. Popularity without recent maintenance is a trap, not validation.

4. **Maintenance / activity.** Last commit date: `<12 months` = active, `12–24` = stale, `>24` = abandoned. Last release vs last commit (releases lagging commits = pre-release work or maintainer absent). Open issues / PRs ratio; unanswered bug reports older than 6 months; "looking for maintainers" signals.

5. **Vulnerability history.** Check the ecosystem's vuln DB ([vuln.go.dev](https://vuln.go.dev/) for Go, [GitHub Advisory DB](https://github.com/advisories), [OSV](https://osv.dev/), `npm audit`, `pip-audit`, [RustSec](https://rustsec.org/)). Pattern of repeat CVEs in the same subsystem = avoid.

6. **API stability.** Semver discipline. Major-version bump cadence: every six months is chaotic. `v0.x.y` after years signals unstable surface. Look for a documented breaking-changes / release-notes practice.

7. **Surface and transitive cost.** Each dep brings its own deps. Count transitive deps; smaller is better when alternatives are comparable. Note pulled-in transitive risk (e.g. a Go module that quietly pulls in a deprecated logger).

8. **Fit.** Does it do what's needed with minimal surface? A library doing 10× what's needed brings 10× the risk. **Check the language's standard library / built-ins first.** Many ecosystems' stdlib covers what third-party libs once owned (e.g. Go's `slices`, `maps`, `cmp`, `errors`; Python's `pathlib`, `dataclasses`; JS's modern `URL`, `fetch`, `structuredClone`).

9. **Footguns.** Ecosystem-specific (init-time side effects, monkey-patching, peer-dep churn, global mutable state, unbounded goroutines/threads). Check the language reference for known patterns; surface anything weird in the README or top-level types.

10. **Capabilities.** What privileged operations can the dep (and its transitive closure) reach? A logging library that transitively pulls `os/exec` or `net/http` is doing more than it advertises. For Go, capslock (see [references/go.md](references/go.md#capability-analysis)) classifies transitive calls into capability buckets (`NETWORK`, `FILES`, `EXEC`, `REFLECT`, `CGO`, `UNSAFE_POINTER`, `ARBITRARY_EXECUTION`, etc.). Two modes:
   - **Selection mode**: snapshot capabilities of the candidate. Flag high-signal combinations — `ARBITRARY_EXECUTION` (any), `REFLECT + EXEC` (dynamic-code gadget), `EXEC` in a non-exec-purpose dep, `CGO` / `UNSAFE_POINTER` (analyzer blind spots downstream).
   - **Review mode (bump)**: diff capabilities against the prior version. A dep gaining `NETWORK` or `EXEC` it didn't have before is a strong supply-chain signal, regardless of release notes.
   - For non-Go ecosystems, equivalents are immature; use `unsure: no capability tool available` rather than skipping.
   - **SSA / callgraph blind spots**: capability analysis relies on SSA + call graph; reflection, `cgo` boundaries, `unsafe.Pointer` arithmetic, and inactive build tags are invisible. A clean capslock report doesn't prove safety — calibrate against the `UNANALYZED` count.

11. **Tenure / track record.** How long the package has existed **and** been continuously maintained — the *duration* of the maintenance history, not just recent activity (that's #4). A steadily-maintained multi-year package is lower-risk than a six-month-old one with a star spike and daily commits. Reward proven longevity (Lindy / boring-technology bias). Flag the **new-hotness anti-signal**: high stars + recent creation + rapid churn = hype; discount it. Novelty without a track record is a trap — the mirror of #3's "popularity without maintenance is a trap." **Guardrail**: tenure is not unalloyed good. An old-but-abandoned package (caught by #4) or one that never adapted (missing modern idioms — no context support, no ESM, dead ecosystem) is stale, not proven. Weight tenure *alongside* #4 (recency) and #6 (API stability), never instead of them.

## Workflow

1. **Confirm scope** (per `confirm-before-implementing`): selection (prospective add) or review (PR touched manifest). Identify the language and the candidate package.

2. **Resolve canonical coordinate.** Read the per-language reference if one exists; apply its rules **first**. This is non-negotiable. Examples: Go's `/vN` path probe, npm's scope check, Python's distribution-name lookup.

3. **Survey alternatives** (selection mode, optional). When multiple candidates are in the running, delegate per-candidate data lookups to `Explore` subagents (`model: haiku` per `subagent-model-routing` — mechanical lookup across 11 fixed criteria; per `parallelize-subagents` and `delegate-investigation`). Each subagent returns one verdict table prefixed with `Status:` per `subagent-prompt-contract`. Parent merges and applies the final verdict synthesis (`model: opus` per `subagent-model-routing` — hard reasoning combining multiple criteria across candidates).

4. **Run the 11 criteria** against the resolved coordinate. Cite specific numbers, dates, license names.

5. **Produce verdict**: GO / CAUTION / NO-GO. Always include the **coordinate to use** explicitly (so the user doesn't import the wrong major / wrong scope / wrong distribution).

6. **Review mode**: output as a finding row suitable for `review-code` or `review-security` finding tables, wrapped per the existing `path:line` deep-link convention if `pr_url` is set. Severity prefix per `terse-comments`: `risk:` (CAUTION) or `bug:` (NO-GO).

## Output format

```markdown
## Dependency Evaluation: `<canonical coordinate>`

**Verdict:** GO | CAUTION | NO-GO
**Coordinate to use:** `<canonical coordinate>` (note any path/scope/name gotcha the user might miss)

| Criterion | Finding |
|---|---|
| Language-specific path/coordinate | (e.g. v2 is current; root path is at v1.4.7, 2022) |
| License | (e.g. Apache-2.0) |
| Internal precedent | (e.g. used in 3 sibling repos as `internal/httpx` wrapper; or: no internal usage found) |
| Popularity | (e.g. 12.4k stars, ~3200 importers) |
| Last commit | (e.g. 2026-04-29, active) |
| Tenure / track record | (e.g. first released 2016, 9y of steady releases — proven; or: created 2026-01, 4mo old with a star spike — discount the hype) |
| Vulnerabilities | (e.g. None at v2.1.0; govulncheck clean) |
| API stability | (e.g. v2 released 2023-06, no major bumps since) |
| Surface | (e.g. 4 transitive deps, all common) |
| Fit | (e.g. Covers HTTP-client retry; no stdlib equivalent) |
| Capabilities | (e.g. NETWORK, FILES — expected; or: EXEC unexpectedly transitive via `findExternalDriver`; or: `unsure: no capability tool available`) |

**Mitigations** (CAUTION only): pin to specific minor; vendor; wrap behind an internal interface.
**Alternatives** (NO-GO only): `<alt-1>` — brief reason; `<alt-2>` — brief reason.
```

## Cross-references

- `delegate-investigation`: surveying alternatives belongs in `Explore` subagents.
- `subagent-prompt-contract`: when fanning out per-candidate evaluation.
- `terse-output`: verdict tables; use `unsure:` when a criterion can't be confirmed.
- `terse-comments`: review-mode findings follow the review-comment shape with severity prefix.
- `review-security` and `review-code`: this skill is their natural delegation target when a new dep appears in scope.

## Anti-patterns

- Skipping the per-language reference. The wrong coordinate is the wrong dep.
- Verdict without a recommended coordinate. Always name the exact import path / package name / scope to use.
- Recommending an older major because docs are better. Name a *hard* reason (missing feature, breaking change incompatible with caller) or recommend current.
- Accepting "X is popular" as sufficient. Popularity without recent maintenance is a trap.
- Recommending the new hotness over a proven, long-maintained solution without a hard reason. Novelty without a track record is a trap.
- Hand-waving with hedge words instead of citing numbers ("seems active", "I think it's maintained"). Use `unsure:` when you don't know.
- Auto-running `go get` / `npm install` / `pip install`. Out of scope; the skill recommends, the user applies.
- Recommending an external dep when an internal package already covers the use case. Internal precedent overrides external popularity unless there's a hard reason (missing feature, abandoned, license incompatibility) — name it.
- Per `~/.claude/rules/probe-not-assume.md`: confirm via tool/command before recommending; do not infer.
