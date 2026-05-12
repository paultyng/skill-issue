# Pattern Taxonomy Reference

Heuristics for discovering implicit codebase patterns. Each category describes what to look for, how to assess confidence, and what counter-examples look like.

## STRUCT: Structure & Layering

**What to look for:**
- Package naming convention: singular (`user`) vs plural (`users`), flat vs nested
- Layering: cmd/ → internal/ → pkg/, or domain-driven (feature folders)
- Dependency direction: always inward? Do handlers import services but never vice versa?
- Entrypoint structure: main.go layout, init functions, wire/fx providers
- Handler/service/repo separation: are these distinct layers or mixed?
- Shared packages: is there a `common/` or `shared/` package, or do packages stay independent?

**How to assess:**
- Map import graphs across 10+ packages to find directional consistency
- Check if all cmd/ entrypoints follow the same initialization pattern
- Look for packages that break the layering (e.g., a repo importing a handler)

**Counter-example signals:**
- A handler that directly queries the database (bypassing service layer)
- A service that imports HTTP-specific types (leaking transport)
- A package that imports from cmd/ (wrong dependency direction)

## ERR: Error Handling

**What to look for:**
- Wrapping style: `fmt.Errorf("...: %w", err)` vs custom error types vs bare `return err`
- Sentinel errors: `var ErrNotFound = errors.New(...)` vs inline error strings
- Error message format: lowercase? no punctuation? includes context?
- Where errors are logged: at creation, at propagation, or only at the top-level handler?
- Error checking: early return (`if err != nil { return }`) vs else chains

**How to assess:**
- Sample 20+ error return sites across different packages
- Check if wrapping depth is consistent (always one wrap per layer, or inconsistent)
- Look for `_ = someFunc()` patterns (suppressed errors)

**Counter-example signals:**
- A package that logs errors AND returns them (double logging)
- Mixed wrapping: some functions wrap, some return bare, in the same package
- Error strings starting with capital letters or ending with punctuation in some places but not others

## OBS: Observability

**What to look for:**
- Logger type: `slog`, `zap`, `zerolog`, `logrus`, stdlib `log`
- Structured logging: consistent field names (e.g., always `"user_id"` not sometimes `"userId"`)
- Log level conventions: what's INFO vs DEBUG vs WARN
- Tracing: OpenTelemetry spans, naming convention for spans
- Metrics: naming convention (e.g., `http_request_duration_seconds`), labels

**How to assess:**
- Grep for logger initialization patterns across packages
- Check if structured field names are consistent across 10+ call sites
- Look for packages that use a different logger than the rest

**Counter-example signals:**
- A package using `fmt.Println` for logging when everything else uses `slog`
- Inconsistent span naming (`getUserByID` vs `get_user_by_id` vs `GetUser`)

## CFG: Configuration

**What to look for:**
- Config struct pattern: single config struct? Per-package config? Nested?
- Loading mechanism: `envconfig`, `viper`, `koanf`, manual `os.Getenv`
- Where config is accessed: injected via constructor? Global? Context?
- Feature flags: how toggled, where checked
- Defaults: hardcoded fallbacks? Required with no default?

**How to assess:**
- Find all config struct definitions and compare structure
- Trace how config reaches the code that uses it (DI chain vs global access)
- Check if all env vars are loaded in one place or scattered

**Counter-example signals:**
- A service reading `os.Getenv` directly when everything else uses a config struct
- A package defining its own config loading when a centralized loader exists

## DI: Dependency Injection

**What to look for:**
- Constructor pattern: `func NewService(deps...) *Service`. What gets injected?
- Interface placement: defined in consumer package or implementor package?
- Wire/fx usage: are providers consistent? All in one file or scattered?
- Test doubles: mocks (mockgen), fakes (hand-written), or stubs?
- Scope: are dependencies scoped per-request, per-service, or global?

**How to assess:**
- Sample 10+ constructors and compare their signature patterns
- Check if interfaces are consistently in consumer packages
- Look for `var _ Interface = (*Impl)(nil)` compile-time checks

**Counter-example signals:**
- A service that takes a concrete type where siblings take interfaces
- Interfaces defined in the implementor package (Go anti-pattern)
- A test using a real HTTP client when everything else uses httptest

## TEST: Testing

**What to look for:**
- Test file location: same package (`foo_test.go`) vs external (`foo_test` package)
- Table-driven tests: consistent structure? `tt` vs `tc` vs `test` variable name?
- Fixtures: file-based (`testdata/`), inline, or factory functions?
- Test helpers: `testutil` package? Per-package helpers?
- Assertion style: `testify` assert/require, stdlib `if got != want`, custom helpers
- Setup/teardown: `TestMain`, `t.Cleanup`, `setUp` functions

**How to assess:**
- Sample 10+ test files across different packages
- Check if table-driven test structure is consistent
- Look for test helper patterns that repeat

**Counter-example signals:**
- A test file using `testify` when everything else uses stdlib assertions
- Inline test data when everything else uses `testdata/` fixtures
- A test that doesn't use the project's test helper for DB setup

## XPORT: Transport

**What to look for:**
- Handler function signatures: `(w, r)` style vs framework-specific (echo, gin, fiber)
- Middleware chain: ordering, how middleware is registered
- Request validation: where it happens (handler, middleware, service layer)
- Response envelope: consistent JSON structure? Error response format?
- gRPC interceptors: unary vs stream, ordering
- Route registration: centralized or scattered?

**How to assess:**
- Read all handler/endpoint registrations
- Compare 5+ handler implementations for structural similarity
- Check if error responses follow a consistent format

**Counter-example signals:**
- A handler that validates input inline when everything else uses a validation middleware
- An endpoint returning a different error format than the rest
- A gRPC service missing interceptors that all others have
