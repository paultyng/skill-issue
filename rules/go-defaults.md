---
paths:
  - "**/*.go"
---

# go-defaults

Universal Go conventions (not project-specific):

## Context
- Always pass `context.Context` as the first parameter on functions that do I/O.
- `context.Context` must not carry dependencies or non-request-scoped data; primary function arguments must be explicit.
- Never store `context.Context` in a struct or embed/wrap it.

## Errors
- Wrap errors with `fmt.Errorf("...: %w", err)` and check with `errors.Is`/`errors.As`.
- Error messages should not start with "failed". The error itself implies failure.
- Define static sentinel errors (`var ErrX = errors.New(...)`) for errors callers need to match; avoid inline `errors.New()` in return paths.
- Errors should generally only be logged once (at the handler/boundary).

## Interfaces and DI
- Accept interfaces, return structs.
- Define interfaces at the **consumer** site, not the implementor package.
- Keep interfaces small; prefer one- or two-method interfaces.
- Wire dependencies manually in `main()` or a composition root. No DI frameworks.

## Functions and Design
- Use the functional options pattern (`With*` funcs) when a function has >=3 optional parameters.
- Organize packages by domain, not function. No `util` or `helper` grab-bag packages.
- File order: type definition → constructor → exported methods (grouped by receiver) → unexported helpers, sorted by rough call order.

## Logging
- When using `log/slog`, prefer typed attribute funcs (`slog.String()`, `slog.Int()`) over raw variadic key-value pairs.

## Testing
- Use `t.Parallel()` for independent tests.
- Use `testing/synctest` for time-dependent tests (Go 1.25+).
- Prefer table-driven tests.

## Other
- Generate UUID random defaults in Go code, not via database defaults (e.g., `DEFAULT (UUID())`).
