# Go Best Practices — Reference

Reference sources:
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Go Proverbs](https://go-proverbs.github.io/)
- [Effective Go](https://go.dev/doc/effective_go)
- [Go Test Comments](https://go.dev/wiki/TestComments)

## Error Handling

- Errors are values — handle them, don't discard with `_`
- Don't just check errors, handle them gracefully
- Don't panic for normal error handling; use error and multiple return values
- Indent error flow: keep the happy path at minimal indentation, return early on error
- Error strings: lowercase, no trailing punctuation (they compose into larger messages)
- Wrap errors with context (`fmt.Errorf("doing X: %w", err)`)

## Naming and Style

- Variable names: short for limited scope, descriptive for wider scope
- Receiver names: one or two letter abbreviation of type, consistent across methods; never `this`, `self`, `me`
- Initialisms: consistent case (`URL` not `Url`, `ID` not `Id`)
- Mixed caps: `maxLength` not `MAX_LENGTH` for unexported

## Concurrency

- Don't communicate by sharing memory, share memory by communicating
- Concurrency is not parallelism
- Channels orchestrate; mutexes serialize
- Goroutine lifetimes: make it clear when they exit; document if not obvious
- Prefer synchronous functions over async — callers can add concurrency

## Functions and Design

- A little copying is better than a little dependency
- Clear is better than clever
- Make the zero value useful
- Receiver type: use pointer when in doubt, don't mix receiver types
- Pass values, not pointers, for small fixed-size types (`string`, `io.Reader`)
- Avoid naked returns in medium+ functions
- Named result parameters: only when they add clarity to godoc, not to save a `var` declaration

## Testing

- Useful test failures: say what was wrong, with what inputs, what was got, what was expected
- Table-driven tests for multiple cases
- `Foo(%q) = %d; want %d` format (actual != expected order)

## Imports and Dependencies

- Group imports: stdlib, blank line, external
- Avoid renaming imports unless collision
- `import _` only in `main` or tests
- `import .` only for circular dependency test workarounds
- Use `crypto/rand` for keys, never `math/rand`

## Cyclomatic Complexity

Reference: [gocyclo](https://github.com/fzipp/gocyclo)

Cyclomatic complexity measures the number of linearly independent paths through a function. High complexity correlates with harder-to-test, harder-to-understand code.

**Tooling:** Run `go run github.com/fzipp/gocyclo/cmd/gocyclo@latest -over 12 -ignore "_test|vendor" ./...` (no install required). Functions exceeding the threshold are flagged.

**Refactoring strategies for high-complexity functions:**
- Extract helper functions for distinct logical steps
- Use early returns to reduce nesting depth
- Simplify compound boolean expressions (extract to named variables or predicate functions)
- Convert long if/else or switch chains to table-driven logic (map lookups, slices of handler funcs)
- Split functions that mix validation, business logic, and I/O into separate layers

## Static Analysis

Reference: [staticcheck](https://staticcheck.dev)

Staticcheck provides ~150 checks built on Go's SSA representation, covering bugs, simplifications, dead code, and deprecated API usage. Run via `go run honnef.co/go/tools/cmd/staticcheck@latest ./...` (no install required).

Key check categories:
- **SA** (staticcheck): correctness bugs — nil dereferences, infinite loops, unreachable code, leaked goroutines, deprecated stdlib usage
- **S** (simple): simplifications — redundant type conversions, unnecessary nil checks, replaceable loops
- **ST** (stylecheck): style — naming conventions, doc comment format, error string capitalization
- **QF** (quickfix): automated refactoring suggestions

## Unchecked Errors

Reference: [errcheck](https://github.com/kisielk/errcheck)

Errcheck detects unchecked error return values — the single most common Go bug pattern. Run via `go run github.com/kisielk/errcheck@latest ./...` (no install required).

- Reports one line per unchecked error with file:line:col
- Very low false-positive rate
- Can exclude specific functions via `-exclude` file

## Nil Safety

Reference: [nilaway](https://github.com/uber-go/nilaway)

NilAway (Uber) detects potential nil pointer dereferences statically using type-flow inference. Run via `go run go.uber.org/nilaway/cmd/nilaway@latest ./...` (no install required).

- Tracks nil flows both within and across packages
- Complements staticcheck's SA-series nil checks with deeper cross-function analysis
- Under active development; may produce some false positives but high signal for crash prevention

## Exhaustive Enum Checks

Reference: [exhaustive](https://github.com/nishanths/exhaustive)

Exhaustive checks that switch statements on enum types cover all values. Run via `go run github.com/nishanths/exhaustive/cmd/exhaustive@latest ./...` (no install required).

- Catches missing cases that cause silent bugs when new enum values are added
- Also checks map literal keys with enum key types
- Treats `default` case as exhaustive by default (configurable via `--default-signifies-exhaustive=false`)

---

## Cross-references

- For documentation quality (doc comments, examples, README sync): see **review-documentation**
- For DoS-related security concerns (rate limiting, resource limits): see **review-security**
- For operational stability (graceful shutdown, circuit breakers, timeouts): see **review-reliability**
