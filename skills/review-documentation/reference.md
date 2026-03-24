# Documentation Review — Framework Reference

Detailed checklists for documentation quality dimensions. The SKILL.md workflow references this file.

Reference sources:
- [Go Doc Comments](https://go.dev/doc/comment)
- [Effective Go — Commentary](https://go.dev/doc/effective_go#commentary)
- [Go Code Review Comments — Doc Comments](https://go.dev/wiki/CodeReviewComments#doc-comments)
- [AEP Documentation Guidance](https://aep.dev/192)
- [Protobuf Style Guide](https://protobuf.dev/programming-guides/style/)
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)

## Go Package Documentation

- Every package has a `doc.go` (or package comment in one `.go` file). Multi-sentence package docs belong in `doc.go`.
- Package comment describes the package's purpose, not its implementation.
- No blank line between package comment and `package` clause.

## Go Exported Symbol Comments

- Every exported type, func, const, var, and method has a doc comment.
- Comment starts with the symbol name: `// Foo does ...` not `// This function does ...`.
- Comment ends with a period.
- Comment describes behavior, parameters, return values, and error conditions — not just restating the name.
- Deprecated symbols use `// Deprecated: use Bar instead.` format.
- Grouped `const`/`var` blocks: doc comment on the block and/or each individual entry.

## Go Examples

- Key exported APIs (constructors, primary methods, package-level functions) have `Example*` test functions.
- Examples compile and run (`go test` executes them).
- Example output comments (`// Output:`) match actual output.
- Examples demonstrate common use cases, not just trivial calls.

## Go doc Command Checks

- `go doc -all <pkg>` output renders cleanly (no malformed comments, no missing docs on prominent symbols).
- `go doc -all -short <pkg>` gives a useful summary (one-liners are meaningful, not empty).

## Proto Service and RPC Comments

- Every `service` has a leading comment describing its purpose.
- Every `rpc` method has a leading comment describing what it does, expected inputs, and side effects.
- Comments use `//` style (not `/* */`).

## Proto Message and Field Comments

- Every `message` has a leading comment.
- Fields with non-obvious names or semantics have comments.
- Enum values have comments, especially the zero value.
- `oneof` groups have a comment explaining the variant semantics.

## Proto-to-OpenAPI Sync

- Every proto comment on a service, RPC, message, or field appears as a `description` in the generated OpenAPI spec.
- OpenAPI `summary` and `description` on operations are non-empty.
- OpenAPI schema `description` fields on request/response objects are non-empty.
- No drift: if a proto comment is updated, the regenerated OpenAPI spec reflects the change. Flag when they diverge.

## Markdown and README Quality

- README.md exists at the repo root.
- README includes at minimum: project purpose, quickstart / usage, and build/run instructions.
- Relative links in markdown resolve to existing files.
- Code examples reference actual exported names and correct signatures.
- CLI flags, env vars, and config keys mentioned in docs exist in code.
- No stale version numbers or references to removed features.

## Documentation Gaps

Large gaps to flag explicitly:
- No README at repo root.
- No package-level doc on any Go package.
- No comments on any proto service or RPC.
- OpenAPI spec with empty descriptions throughout.
- No `Example*` tests anywhere in the module.
