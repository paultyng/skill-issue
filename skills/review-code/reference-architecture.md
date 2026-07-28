# Architecture and Design Reference

Reference sources:
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments): interface and package design
- [Effective Go](https://go.dev/doc/effective_go): embedding, composition, naming
- [Go Proverbs](https://go-proverbs.github.io/): design philosophy

## S. Single Responsibility Principle

A package or type should have one reason to change. Each package should own a single cohesive concern.

What to flag:
- **God packages**: a single package containing unrelated types and functions (e.g. `utils`, `common`, `helpers`, `misc`)
- **God structs**: a struct with many fields spanning multiple concerns (DB handle + HTTP client + business config + cache)
- **Functions doing too much**: a single function that validates input, calls the database, formats output, and sends notifications
- **Mixed abstraction levels**: a package that contains both low-level I/O and high-level business logic

What good looks like:
- Each package has a clear, statable purpose
- Types in a package are cohesive; they change together for the same reason
- Splitting a package is warranted when its types change for different reasons

## O. Open/Closed Principle

Software entities should be open for extension but closed for modification. In Go, this means extending behavior via interfaces and composition, not by modifying existing code.

What to flag:
- **Growing type switches**: `switch v := x.(type)` that must be edited every time a new variant is added. Consider an interface method instead
- **Hardcoded strategy selection**: `if config.Mode == "A" { ... } else if config.Mode == "B" { ... }`. Consider a strategy interface
- **Modification-heavy extension**: adding a new feature requires editing multiple existing files rather than adding new types that satisfy existing interfaces

What good looks like:
- New behavior is added by implementing an existing interface, not by editing switch statements
- Plugin points are interfaces accepted as function/constructor parameters
- Existing code is not modified when behavior is extended

## L. Liskov Substitution Principle

Any implementation of an interface must honor the full contract. Callers should be able to use any implementation interchangeably without surprises.

What to flag:
- **Partial implementations**: methods that `panic("not implemented")` or return `ErrNotSupported` for interface methods the caller expects to work
- **Surprising side effects**: an implementation that mutates shared state or has behavior not implied by the interface contract
- **Nil-returning errors**: implementations that silently swallow errors instead of returning them, breaking caller error-handling assumptions

What good looks like:
- All interface implementations are tested against the same contract expectations
- No implementation panics on methods defined in the interface
- Error behavior is consistent across implementations

## I. Interface Segregation Principle

Clients should not be forced to depend on methods they do not use. In Go: the bigger the interface, the weaker the abstraction.

What to flag:
- **Fat interfaces**: interfaces with many methods when callers only use one or two (e.g. a `Repository` interface with 20 methods when most callers only call `Get`)
- **Implementor-defined interfaces**: interfaces defined next to their implementation rather than at the call site, forcing consumers to depend on the full interface
- **Interfaces mirroring structs**: an interface that is a 1:1 copy of a struct's method set, serving no abstraction purpose

What good looks like:
- Interfaces are small (1 to 3 methods)
- Interfaces are defined where they are consumed, not where they are implemented
- Each interface captures a specific capability (`io.Reader`, `io.Writer`, `fmt.Stringer`)

## D. Dependency Inversion Principle

High-level modules should not depend on low-level modules. Both should depend on abstractions (interfaces). In Go: accept interfaces, return structs.

What to flag:
- **Direct infrastructure dependencies**: a business logic package that imports a database driver, HTTP client, or cloud SDK directly
- **Constructor returning interface**: `func New() MyInterface`. Return the concrete type, let the consumer define the interface it needs
- **Import direction violations**: a domain/business package importing an infrastructure/adapter package

What good looks like:
- Business logic depends on interfaces it defines
- Infrastructure packages implement interfaces defined by their consumers
- Constructors return concrete types; callers accept interfaces at their call sites
- Dependency injection wires concrete implementations at the composition root (main or server setup)

## Design Patterns (Gang of Four)

When code implements a recognized design pattern, it should use the canonical GoF name in types, variables, and comments for consistency and discoverability. A `Handler` that wraps another `Handler` adding behavior is a Decorator: name it accordingly.

**Patterns commonly used in Go:**

| Pattern | Go idiom | Canonical naming |
|---------|----------|------------------|
| Factory | Constructor functions (`New...`) | `NewX`, `XFactory` |
| Builder | Functional options (`With...`) | `Option`, `WithX` |
| Strategy | Interface parameter | name the interface for the capability |
| Decorator | Middleware, wrapping an interface | `XMiddleware`, `XWrapper`, or describe the decoration |
| Adapter | Struct implementing a target interface by wrapping a different type | `XAdapter` |
| Observer | Channels, callback functions | `Listener`, `Handler`, `Subscribe` |
| Facade | Package-level API hiding internal complexity | package name is the facade |
| Composite | Interface implemented by both leaf and container types | name reflects the domain, not the pattern |
| Chain of Responsibility | Middleware chains, handler pipelines | `Handler`, `Middleware`, `Interceptor` |
| Template Method | Embedding a base struct with hook methods | name the hooks for what they do |

**Design pattern anti-patterns to flag:**

- **Singleton via package globals**: global `var instance *Service` with `sync.Once`. Hides dependencies, prevents testing. Use DI instead.
- **Pattern name without the pattern**: types named `XFactory`, `XStrategy`, `XObserver` that don't actually implement the pattern. Misleading.
- **Forced patterns**: applying a GoF pattern where a plain function or simple struct would suffice (e.g. a `CommandFactory` that always creates the same command). Respect YAGNI.
- **Abstract Factory / Class hierarchy patterns**: these rely on inheritance and don't translate well to Go. Prefer interfaces + composition.
- **God Decorator chains**: deeply nested decorators that make the call stack hard to follow. Consider flattening into explicit steps.

**Pattern selection guidance:**

- If the code has a clear pattern match, name it canonically. If it doesn't match a pattern cleanly, don't force one.
- Prefer the simplest pattern that solves the problem: Strategy (interface parameter) over Abstract Factory, Decorator (middleware) over complex proxy chains.
- When reviewing, check that the chosen pattern fits the problem. A Strategy pattern for something that will only ever have one implementation is speculative (see Minimal-Changes Alignment).

## Package Design

**Cohesion:**
- Types and functions in a package are related and change together
- A package name describes what it provides, not what it contains
- Avoid generic names: `util`, `common`, `helpers`, `types`, `models`, `misc`
- Don't stutter: `chubby.ChubbyFile` → `chubby.File`

**Coupling:**
- Minimize cross-package dependencies; a package should have few imports relative to what it provides
- Avoid circular dependencies. If package A imports B and B imports A, one of them has the wrong responsibility
- Prefer narrow interfaces at package boundaries over passing concrete types across packages

**Acyclic Dependency Principle:**
- The package dependency graph must be a directed acyclic graph (DAG)
- Circular imports are a compile error in Go, but logical cycles (A → B → C → A through interfaces) still create tight coupling
- Break cycles by extracting shared types into a separate package or inverting the dependency with an interface

**A little copying is better than a little dependency:**
- Don't create shared packages just to avoid duplicating a small helper
- If the shared code is trivial (< 10 lines), prefer copying over coupling
- Shared packages must earn their existence through genuine reuse, not speculative DRY

## Minimal-Changes Alignment (scope)

Scope discipline, per the `minimal-changes` rule: the change should do only what was requested. This is distinct from *weight* (Over-Engineering, below) — here we flag work that shouldn't be in the diff at all.

What to flag (`ARCH-`):
- Unrequested work folded into the diff — cleanup, renames, reformatting, "while I'm here" edits not asked for.
- Something that should change but wasn't requested, silently included rather than mentioned after the requested work.

Speculative abstractions, premature generalization, and over-engineering of the *in-scope* code are weight concerns — grade them under Over-Engineering below, not here.

## Over-Engineering (implementation-minimalism)

*Weight*, not scope: for the code that IS in scope, was the least-code path taken? Grade against the `implementation-minimalism` ladder and cite the rung in the finding (`MIN-` IDs).

What to flag:
- **Rung 1 (YAGNI)**: speculative abstractions or extension points with a single implementation and no concrete second use case, premature generalization, unused parameters/return values, a single-caller helper.
- **Rung 2 (reuse)**: reimplementing something the codebase already provides.
- **Rung 3 (built-ins)**: a hand-rolled helper the standard library or platform already does (e.g. a manual `contains` loop over `slices.Contains`).
- **Rung 4 (deps)**: a new dependency where an existing one or stdlib suffices — defer the call to `evaluate-dependency`, don't re-argue it here. (`DEP-` covers import-graph / circular-dep / testability findings; the rung-4 *choice to add a dependency* is `MIN-`.)
- **Rung 5 (smaller)**: dense "clever" one-liners that read worse than the plain form — clear beats clever.
- **Rung 6 (minimal patterns)**: indirection without value (wrapper types that just delegate, factories always returning the same type), or config/generics nobody requested.

False-positive guard — do NOT flag as over-engineering:
- The non-negotiables: input validation, error handling, security checks, accessibility. Reducing these is a bug, not minimalism.
- A consumer-defined interface used for DI/mocking (per `go-defaults` / `testing-philosophy`) — the test fake is a genuine second implementation.
- Duplication that hasn't earned an abstraction yet — a little copying is better than a premature abstraction (rule of three, weighted to drift risk).

## Testability Indicators

Architecture decisions directly affect how testable the code is. These checks are informed by the testing philosophy: prefer real code and DI over static mocks.

**Dependency injection patterns:**
- Service constructors accept their dependencies as parameters (interfaces), not as package-level globals
- No `init()` functions that set up global state used by business logic
- Configuration is passed explicitly, not read from environment inside business logic

**Interface placement for testing:**
- Interfaces for external dependencies (gRPC clients, HTTP APIs, third-party SDKs) are defined in the consumer package
- Interfaces are minimal: only the methods the consumer calls
- The real implementation and test stub both satisfy the same interface

**Mock smell detection:**
- Tests requiring many mocks suggest the code under test has too many dependencies (SRP violation)
- Mocks that replicate complex behavior suggest the abstraction boundary is wrong
- If a mock is harder to write than a real test server (`httptest.Server`, in-memory DB), the mock is the wrong approach

**What good looks like:**
- Tests use real code, `httptest` servers, or dependency injection; mocks are a last resort
- Tests are self-contained; the only shared infrastructure is the database
- External services (gRPC clients, HTTP APIs, third-party SDKs) are stubbed via interfaces, never called for real
- Time-dependent tests use `testing/synctest` (Go 1.25+), not real sleeps

## Dead Code Detection

Reference: [deadcode](https://pkg.go.dev/golang.org/x/tools/cmd/deadcode)

Deadcode (official `golang.org/x/tools`) finds unreachable functions using Rapid Type Analysis (RTA) call graphs. Run via `go run golang.org/x/tools/cmd/deadcode@latest -filter=$(go list -m) ./...` (no install required).

- Builds a call graph from `main` entry points and reports functions not reachable from any `main`
- `-filter` restricts output to the module's own packages (use `go list -m` to get the module path)
- `-test` flag includes test executables; functions reachable only from tests are reported separately
- Unreachable code is a strong signal of architectural decay, abandoned features, or incomplete refactoring
- Functions that are "dead" but tested (reachable only from test code) may indicate unused internal APIs or over-testing of removed features

---

## Cross-references

- For documentation quality (doc comments, examples, README sync): see **review-documentation**
- For DoS-related security concerns (rate limiting, resource limits): see **review-security**
- For operational stability (graceful shutdown, circuit breakers, timeouts): see **review-reliability**
