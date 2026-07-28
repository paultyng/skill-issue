# Go dependency specifics

- [Standard library & golang.org/x first](#standard-library--golangorgx-first)
- [Semantic Import Versioning (SIV)](#semantic-import-versioning-siv)
- [Toolchain commands](#toolchain-commands)
- [Metadata sources](#metadata-sources)
- [Go-specific footguns](#go-specific-footguns)
- [Capability analysis](#capability-analysis)
- [When to flag CAUTION rather than NO-GO](#when-to-flag-caution-rather-than-no-go)

Read this **before** running the general evaluation in `SKILL.md` when the dep is a Go module. The path is the dep; picking it wrong invalidates every other criterion.

## Standard library & golang.org/x first

Before evaluating any third-party module, check whether the need is already covered — in ladder order (per `implementation-minimalism` rung 3): **stdlib > `golang.org/x/*` > third-party**. If stdlib or an `x` package covers it, the third-party candidate is CAUTION (needless dependency) or NO-GO.

`golang.org/x/*` is the quasi-standard tier: Go-team-maintained, versioned, proven, but deliberately not in the stdlib. Prefer it over an unaffiliated module for the same need.

| Need | stdlib | `golang.org/x` |
|---|---|---|
| Slice / map helpers | `slices`, `maps` | — |
| Ordered comparison | `cmp` | — |
| Error wrapping / matching | `errors`, `fmt` | — |
| Structured logging | `log/slog` | — |
| min / max / clear | builtins | — |
| errgroup / semaphore / singleflight | — | `golang.org/x/sync/...` |
| Rate limiting | — | `golang.org/x/time/rate` |
| Unicode normalization, cases, language tags | `unicode`, `unicode/utf8` | `golang.org/x/text` |
| Crypto beyond stdlib (bcrypt, argon2, chacha20) | `crypto/...` | `golang.org/x/crypto` |
| HTTP/2 | `net/http` (transparent over TLS) | — |
| WebSocket, proxy dialers | — | `golang.org/x/net/{websocket,proxy}` (websocket is minimal — a third-party lib is often preferred) |
| Experimental generics helpers | — | `golang.org/x/exp` (unstable — pin, expect churn) |

`min` / `max` / `clear` are language builtins, not a stdlib package — but still already-there, no dependency.

Only after confirming neither tier fits, evaluate the third-party candidate.

## Semantic Import Versioning (SIV)

Go's major versions ≥ 2 live at a **different import path**:

- `github.com/foo/bar` → v0.x and v1.x only
- `github.com/foo/bar/v2` → v2.x
- `github.com/foo/bar/v3` → v3.x
- ... and so on

Failure modes to catch:

1. **Importing the root path when a higher major exists.** Users name `github.com/foo/bar` because that's what the README at the repo root said in 2019; meanwhile maintainers shipped `/v2` two years ago and abandoned the v1 line. The agent must always probe higher majors before accepting the root path.

2. **`+incompatible` v2+ from the root path.** When a Go module reaches v2+ but stays at the root import path without a `/v2` suffix, the Go toolchain marks the version `+incompatible`. It works, but it signals the module isn't following SIV: sometimes deliberate, often legacy. Surface as a smell.

3. **Tag exists at one path, not the other.** A `v2.3.1` tag at the root path is not the same as `v2.3.1` at `/v2`. Always confirm the resolved coordinate.

### Probe commands

```sh
# Tags at the named path (might be the root, might be /vN)
go list -m -versions github.com/foo/bar

# Probe higher major-version suffixes until "no matching versions"
go list -m -versions github.com/foo/bar/v2
go list -m -versions github.com/foo/bar/v3
# ... continue until empty

# Confirm the canonical module the resolved coordinate corresponds to
go list -m -json github.com/foo/bar/v2
```

The canonical coordinate to recommend is the **highest stable major** that has the features needed. Drop to a lower major only with a hard, named reason.

## Toolchain commands

| Command | Purpose |
|---|---|
| `go list -m -versions <path>` | All tags at this import path |
| `go list -m -json <path>` | Full metadata (version, replace, deprecated, etc.) |
| `go list -m -u all` | Direct deps with available updates |
| `go mod why <path>` | What in the current module pulls this dep in (post-add) |
| `go mod graph` | Full dep graph; pipe to `grep` for chains involving a specific dep |
| `govulncheck ./...` | Vulnerability scan limited to functions the code actually calls |

## Metadata sources

- **[pkg.go.dev/<module>](https://pkg.go.dev/)**: license detection, "Imported by" count, latest version per path, README rendering, godoc.
- **[vuln.go.dev](https://vuln.go.dev/)**: Go vulnerability database, queryable per module.
- **GitHub repo**: last commit, release cadence, open-issue health, maintainer signals.

## Go-specific footguns

- **`init()` side effects.** Some Go libraries register handlers, mutate globals, or open files in `init()`. Importing them has effects beyond the explicit API. Skim package-level `init()` functions in the candidate.
- **Embedded mutable globals.** A package exposing a `var Default *Client` at package level is hostile to test isolation. Prefer ones that require construction.
- **Replace directives.** A candidate's `go.mod` with `replace` directives pointing at forks or local paths inherits whatever those resolve to in the consumer's build. Treat as a smell.
- **`internal/` leakage.** A library importing another library's `internal/` packages won't compile for outside consumers. Rare in well-maintained libs, common in extracted-from-monorepo code.
- **CGO. Prefer pure Go.** A CGO dep brings a C-toolchain requirement, breaks cross-compilation, complicates Docker builds (musl vs glibc, static linking), and adds a different memory/error model at the boundary. Accept only when a pure-Go alternative with comparable coverage doesn't exist, and even then, name the pure-Go option you considered and rejected, with the reason. (Example: `mattn/go-sqlite3` is CGO; `modernc.org/sqlite` is pure-Go. Usually prefer the latter unless a specific feature forces the former.)
- **Platform-specific build constraints.** A dep with `//go:build linux` or similar constrains the consuming project. Note in the verdict; usually a CAUTION rather than NO-GO unless the constraint conflicts with the consumer's target platforms.
- **Generated code dependencies.** Libraries like `protoc-gen-go`, `sqlc`, etc. need a corresponding generator version. Document the generator pinning.

## Capability analysis

`capslock` ([github.com/google/capslock](https://github.com/google/capslock)) classifies the privileged operations a package transitively reaches. It builds a callgraph over the candidate and its dependency closure, then maps every reachable stdlib function to one of ~15 capability classes (`NETWORK`, `FILES`, `EXEC`, `REFLECT`, `CGO`, `UNSAFE_POINTER`, `ARBITRARY_EXECUTION`, `SYSTEM_CALLS`, `MODIFY_SYSTEM_STATE`, `READ_SYSTEM_STATE`, etc.).

Install: `go install github.com/google/capslock/cmd/capslock@latest`. Run JSON: `capslock -output=json ./...`.

### Selection mode — snapshot scan

Before adopting a Go dep, capslock on the candidate. Surface the row's `Finding` cell as a short list of present capabilities, then flag the high-signal patterns:

- **`CAPABILITY_ARBITRARY_EXECUTION` (any presence)**: `plugin.Open`, codegen at runtime. Always merits human review.
- **`CAPABILITY_REFLECT` + `CAPABILITY_EXEC`**: dynamic-code gadget. High-signal supply-chain combination.
- **`CAPABILITY_EXEC` in a non-exec-purpose dep**: "why does my JSON parser shell out?"
- **`CAPABILITY_CGO` / `CAPABILITY_UNSAFE_POINTER`**: not necessarily bad, but they are SSA-analyzer blind spots — every downstream check (taint, nilness, callgraph) loses fidelity at these boundaries. Note presence so the verdict accounts for reduced confidence.
- **`CAPABILITY_UNANALYZED` count**: high count = lots of code outside the analyzer's reach (asm, plugins). Calibrates trust in the rest of the report.

The JSON output's per-finding `path[]` field contains filename, line, column at every hop in the transitive call chain — useful for citing the actual reachability path in the verdict instead of just "EXEC present".

### Review mode — capability diff on a bump

When a PR bumps a Go dep, capslock the **new** version and diff against the **old**. Concrete recipe:

```sh
# At base commit:
capslock -output=json ./... > /tmp/caps-base.json

# At head commit:
capslock -output=json ./... > /tmp/caps-head.json

# Diff capability sets:
jq -r '.capabilityInfo[]? | "\(.packageName) \(.capability)"' /tmp/caps-base.json | sort -u > /tmp/caps-base.txt
jq -r '.capabilityInfo[]? | "\(.packageName) \(.capability)"' /tmp/caps-head.json | sort -u > /tmp/caps-head.txt
diff /tmp/caps-base.txt /tmp/caps-head.txt
```

**New capabilities appearing in the diff are the actionable signal** — a dep that previously had no `NETWORK` reach now has it; either a deliberate telemetry feature, or a supply-chain payload. The August 2022 `os.Setenv` / `http.Post` / `exec.Command` init-payload pattern is exactly this shape.

### Blind spots

capslock relies on SSA + callgraph. It misses code reached via reflection (`reflect.Value.Call`), the `cgo` boundary, `unsafe.Pointer` arithmetic, and build-tag-gated paths for inactive tags. A clean report is not a safety proof — read it alongside the `UNANALYZED` count.

## When to flag CAUTION rather than NO-GO

A Go dep that's slightly stale (last commit 12–18 months) but otherwise sound is often CAUTION with the mitigation "pin to specific minor + revisit in 6 months." Use NO-GO only when there's a clear blocker: license incompatibility, unfixed CVE in code paths the user calls, abandoned maintenance >24 months with no alternative path forward.
