# Rule Patterns Reference

## Glob Pattern Cheat Sheet

| Pattern | Matches |
|---|---|
| `**/*.go` | All Go files in any directory |
| `**/*_test.go` | All Go test files |
| `**/*.{ts,tsx}` | TypeScript and TSX files |
| `**/*.test.ts` | TypeScript test files |
| `**/*.spec.{ts,js}` | Spec files (TS or JS) |
| `src/**/*` | All files under `src/` |
| `src/api/**/*.ts` | TypeScript files under `src/api/` |
| `migrations/**/*.sql` | SQL migration files |
| `e2e/**/*.go` | Go files under `e2e/` |
| `*.md` | Markdown files in project root only |

Multiple patterns are OR-ed together — a file matching any pattern triggers the rule.

## Good vs Bad Rules

### Too vague (bad)
```markdown
# code-quality

Write clean, maintainable code. Be consistent. Follow best practices.
```

### Specific and verifiable (good)
```markdown
# code-quality

- Use 2-space indentation for TypeScript and JSON
- Max line length: 100 characters
- Prefer `const` over `let`; never use `var`
- Export types explicitly; do not use `export default` for types
```

---

### Duplicates Claude's defaults (bad)
```markdown
# error-handling

Always handle errors. Don't ignore exceptions. Log errors when they occur.
```

### Adds project-specific knowledge (good)
```markdown
# error-handling

- Wrap errors with `fmt.Errorf("context: %w", err)` — never discard the original
- Check errors with `errors.Is` / `errors.As`, not string matching
- Return errors to callers; only log at the top-level handler (never both log and return)
- Use `slog.Error` with structured fields, not `log.Printf`
```

---

### Wrong scope — Go-only rule always-loaded (bad)
```markdown
# go-context

Always pass context.Context as the first parameter.
```
*(Loads in every session even when not working on Go)*

### Correctly path-scoped (good)
```markdown
---
paths:
  - "**/*.go"
---

# go-context

Always pass `context.Context` as the first parameter on functions that do I/O.
Propagate the context — never create a new `context.Background()` inside a function
that already received a context.
```

---

### Contradicts another rule (bad)
```markdown
# commits

Amend the previous commit when adding small fixups.
```
*(Contradicts a `git-no-amend` rule — Claude picks one arbitrarily)*

### Consistent with existing rules (good)
```markdown
# commits

Always create a new commit for additional changes. Never amend unless the user
explicitly asks. Use Conventional Commits format: `<type>[scope]: <description>`.
```

## Always-Load Rule Examples

These apply universally — no `paths` needed:

```markdown
# escalation

Stop and ask before proceeding if requirements are ambiguous or you are about
to make an architectural decision not covered by existing docs or rules.
```

```markdown
# output-style

Default to terse output. Prefer bullet points over prose. No filler or preamble.
```

```markdown
# task-runner

Use `task <name>` (go-task / Taskfile.yaml) for automation. Do not use Makefiles
or bare shell scripts. Add new automation as Taskfile tasks.
```

## Path-Scoped Rule Examples

These only load when relevant files are opened:

```markdown
---
paths:
  - "**/*.go"
---

# go-defaults

- Always pass `context.Context` as first parameter on I/O functions
- Wrap errors: `fmt.Errorf("operation: %w", err)`
- Check errors: `errors.Is` / `errors.As`
- Prefer table-driven tests
```

```markdown
---
paths:
  - "**/*_test.go"
  - "e2e/**/*.go"
---

# testing

- Prefer real implementations and `httptest` over mocks
- Mock only external services (gRPC, HTTP APIs, third-party SDKs)
- Use `t.Parallel()` for independent tests
- Use `testing/synctest` for time-dependent tests (Go 1.25+)
```

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/routes/**/*.ts"
---

# api-design

- Validate all inputs at the handler boundary
- Return errors in the standard envelope: `{ error: { code, message } }`
- Include OpenAPI JSDoc on every public endpoint
- Use kebab-case for URL paths, camelCase for JSON properties
```

## Splitting Large Rules

If a rule file is growing past 200 lines, split by sub-topic:

```
rules/
├── go-defaults.md          # universal Go conventions
├── go-testing.md           # test-specific Go rules (paths: **/*_test.go)
├── go-errors.md            # error handling (paths: **/*.go)
├── api-design.md           # API conventions (paths: src/api/**/*.ts)
└── api-auth.md             # auth-specific API rules (paths: src/api/auth/**/*.ts)
```

Prefer more files over fewer large files.
