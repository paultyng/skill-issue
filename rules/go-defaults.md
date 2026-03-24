---
paths:
  - "**/*.go"
---

# go-defaults

Universal Go conventions (not project-specific):

- Always pass `context.Context` as the first parameter on functions that do I/O.
- Wrap errors with `fmt.Errorf("...: %w", err)` and check with `errors.Is`/`errors.As`.
- Use `t.Parallel()` for independent tests.
- Use `testing/synctest` for time-dependent tests (Go 1.25+).
- Prefer table-driven tests.
