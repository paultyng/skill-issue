# Go dependency specifics

Read this **before** running the general evaluation in `SKILL.md` when the dep is a Go module. The path is the dep — picking it wrong invalidates every other criterion.

## Semantic Import Versioning (SIVB)

Go's major versions ≥ 2 live at a **different import path**:

- `github.com/foo/bar` → v0.x and v1.x only
- `github.com/foo/bar/v2` → v2.x
- `github.com/foo/bar/v3` → v3.x
- ... and so on

Failure modes to catch:

1. **Importing the root path when a higher major exists.** Users name `github.com/foo/bar` because that's what the README at the repo root said in 2019; meanwhile maintainers shipped `/v2` two years ago and abandoned the v1 line. The agent must always probe higher majors before accepting the root path.

2. **`+incompatible` v2+ from the root path.** When a Go module reaches v2+ but stays at the root import path without a `/v2` suffix, the Go toolchain marks the version `+incompatible`. It works, but it signals the module isn't following SIVB — sometimes deliberate, often legacy. Surface as a smell.

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

- **[pkg.go.dev/<module>](https://pkg.go.dev/)** — license detection, "Imported by" count, latest version per path, README rendering, godoc.
- **[vuln.go.dev](https://vuln.go.dev/)** — Go vulnerability database, queryable per module.
- **GitHub repo** — last commit, release cadence, open-issue health, maintainer signals.

## Go-specific footguns

- **`init()` side effects.** Some Go libraries register handlers, mutate globals, or open files in `init()`. Importing them has effects beyond the explicit API. Skim package-level `init()` functions in the candidate.
- **Embedded mutable globals.** A package exposing a `var Default *Client` at package level is hostile to test isolation. Prefer ones that require construction.
- **Replace directives.** A candidate's `go.mod` with `replace` directives pointing at forks or local paths inherits whatever those resolve to in the consumer's build. Treat as a smell.
- **`internal/` leakage.** A library importing another library's `internal/` packages won't compile for outside consumers. Rare in well-maintained libs, common in extracted-from-monorepo code.
- **CGO and platform-specific build constraints.** A dep that needs CGO or has `// +build linux` constraints constrains the consuming project. Note in the verdict.
- **Generated code dependencies.** Libraries like `protoc-gen-go`, `sqlc`, etc. need a corresponding generator version. Document the generator pinning.

## When to flag CAUTION rather than NO-GO

A Go dep that's slightly stale (last commit 12–18 months) but otherwise sound is often CAUTION with the mitigation "pin to specific minor + revisit in 6 months." Use NO-GO only when there's a clear blocker: license incompatibility, unfixed CVE in code paths the user calls, abandoned maintenance >24 months with no alternative path forward.
