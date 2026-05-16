# Performance Review: Framework Reference

Detailed checklists for performance analysis. SKILL.md references this file.

Reference sources:
- [Go: Profiling Go programs (pprof)](https://go.dev/blog/pprof)
- [Dave Cheney: High-performance Go](https://dave.cheney.net/high-performance-go-workshop/dotgo-paris.html)
- [Bryan C. Mills: Rethinking Classical Concurrency Patterns](https://www.youtube.com/watch?v=5zXAHh5tJqQ)
- [Brendan Gregg: Systems Performance methodology (USE method)](https://www.brendangregg.com/usemethod.html)

## Table of contents

- [Allocation (Go)](#allocation-go)
- [Algorithmic complexity](#algorithmic-complexity)
- [Concurrency efficiency (Go)](#concurrency-efficiency-go)
- [Benchmark sufficiency](#benchmark-sufficiency)
- [I/O batching and connection reuse](#io-batching-and-connection-reuse)
- [Cross-language notes](#cross-language-notes)
- [What this review will NOT find](#what-this-review-will-not-find)

## Allocation (Go)

The most common Go perf issues are allocation-driven: GC pressure, escapes-to-heap, and per-request garbage. Static review can flag patterns; only a profile confirms impact.

**Common hotspot patterns:**
- `fmt.Sprintf` / `fmt.Errorf` in hot paths. Each call allocates and reflects over arguments. Use `strconv` for simple conversions; prefer `errors.New` over `fmt.Errorf` when no formatting is needed.
- String concatenation with `+=` in a loop. Use `strings.Builder` with `Grow()` pre-sized.
- `[]byte` ↔ `string` conversions in a loop. Each conversion is a copy. Stage the conversion once outside the loop, or use `unsafe.String`/`unsafe.Slice` (Go 1.20+) when the slice is provably immutable.
- `append` without preallocation on a known-size append target. `make([]T, 0, n)` saves grow-and-copy.
- Map operations as a hot-path cache without consideration for GC scanning. Maps of pointers walked by GC every cycle.

**Escape analysis tells:**
- Returning a `*Foo` from a constructor when callers don't need pointer semantics. Pointer = heap. Value = stack (often). Don't mechanically convert — measure first.
- Closures capturing loop variables by reference can escape.
- Interface satisfaction allocates if the concrete type's value receiver implements the interface but the concrete value is a non-pointer. `io.Reader{} = bytes.Buffer{}` is a hidden allocation; `= &bytes.Buffer{}` is not.

**Buffer pooling:**
- `sync.Pool` for per-request buffers when allocation shows up in profile. Don't introduce a Pool without evidence; the contention can be worse than the alloc.
- HTTP/gRPC body decoding: reuse buffers across requests where the protocol allows.

**Common false alarms:**
- "Defer is slow" — true at the nanosecond level, false at any real workload scale. Don't remove `defer` for "perf" without a profile.
- "Range over a map is non-deterministic and therefore slow" — non-determinism is by design and is not a perf concern.

## Algorithmic complexity

**Hot-path patterns to flag:**
- O(n²) over user-controlled input. Nested loops where both bounds scale with input size. Example: deduping a slice with a nested `for ... contains()` instead of a `map[T]struct{}`.
- Linear scan inside a per-request handler over a large fixed dataset. Move to a precomputed map / sorted index.
- N+1 queries — `review-database` covers this, but if you see a loop with one DB call per iteration here, surface it.
- Recursive descent without memoization on overlapping subproblems.

**Bounded-N safe-list:**
- Nested loops over inputs both bounded by a small constant (e.g. up to 8 ports per service) are fine. Don't flag.

## Concurrency efficiency (Go)

**Goroutine usage:**
- Per-request goroutine for downstream calls is normal; goroutine-per-row in a result set is not. Use a bounded worker pool or `errgroup.Group.SetLimit`.
- Unbounded fan-out (`for _, item := range items { go work(item) }` without a cap) on user-controlled input is a memory and scheduler hazard.

**Locks and contention:**
- A single mutex protecting a hot-path map: candidate for `sync.RWMutex` if reads dominate writes, or sharded map / `sync.Map` (the latter only for read-heavy workloads with stable keys).
- Holding a mutex across an I/O call (DB query, RPC). Almost always wrong — surface as a high-priority finding.
- Mutex around a `time.Now()` or counter: prefer `atomic.Int64`.

**Channels:**
- Unbuffered channels in a fast producer/slow consumer setup. Either buffer with a sane bound or use a queue with explicit overflow semantics.
- `select` with a default case in a tight loop = busy-wait. Add a sensible block or sleep.

**Context handling:**
- `context.Background()` used inside a request handler. Should be `ctx` from the request. Cancellation propagation is a *correctness* concern (review-reliability) but it's also a perf concern: handlers that don't watch `ctx.Done()` keep working after the client gives up.

## Benchmark sufficiency

**Coverage:**
- Hot-path functions identified in step 2 have at least one `Benchmark*` function. If not, that's a finding (`benchmarks` / P2).
- Benchmarks cover representative input sizes (typically 3+: small / typical / large). A single-size benchmark hides O(n) vs. O(n²) issues.
- Allocations are tracked: `b.ReportAllocs()` enabled (or the package uses `-benchmem` consistently). Allocation deltas are usually more informative than time deltas.

**Quality:**
- Benchmark loops follow the standard `for b.Loop()` (Go 1.24+) or `for i := 0; i < b.N; i++` pattern. No fixed-iteration loops masquerading as benchmarks.
- Benchmarks reset the timer after setup: `b.ResetTimer()` after expensive `b.Run` setup.
- Benchmarks use `testing.Benchmark` correctly when called programmatically.

**Anti-patterns:**
- Benchmarks that compare against the wall clock or stdlib instead of measuring something the code under test does.
- Microbenchmarks of trivial functions that aren't on any hot path — noise.
- Benchmarks that drift in stability with `b.N`. Use `benchstat` to compare runs.

## I/O batching and connection reuse

**HTTP/gRPC clients:**
- Clients are reused (`http.DefaultClient` or a singleton). Creating a new `http.Client` per request bypasses the connection pool.
- `http.Transport.MaxIdleConns`, `MaxIdleConnsPerHost`, `IdleConnTimeout` set deliberately when the default doesn't fit the workload.
- gRPC clients use a single `ClientConn` per upstream — one dial, many calls.

**Database:**
- Connection pool sized via `db.SetMaxOpenConns` / `SetMaxIdleConns` / `SetConnMaxIdleTime`. Default is unbounded — a hazard.
- Batched insert / `COPY` over per-row insert when bulk-loading.
- Prepared statements where the driver and DB benefit (read driver docs).

**Queue / message bus:**
- Producer batches messages where the protocol supports it.
- Consumer prefetch tuned to the workload (RabbitMQ `prefetch`, Kafka `max.poll.records`).

## Cross-language notes

**TypeScript / Node.js:**
- Avoid `JSON.parse`/`JSON.stringify` of large objects in a synchronous handler. Stream where possible.
- Memoize hot computed values across requests; clear on relevant invalidation.
- Avoid `Array.prototype.map`/`filter` chains on large arrays in a hot path — single-pass loop is faster.

**Python:**
- Use `__slots__` on hot dataclasses to reduce per-instance memory.
- Bulk APIs (`executemany`, `bulk_create`) for ORM loops.
- Profile with `cProfile` + `snakeviz`; allocation profiling with `tracemalloc`.

**Rust:**
- The compiler usually wins; perf review is rare. When applicable: `Vec::with_capacity` over default, `Cow<str>` where applicable, `BTreeMap` vs `HashMap` chosen by access pattern.

## What this review will NOT find

- Anything that requires a profile to be sure. We list candidates; the user runs `pprof` or `benchstat` to confirm.
- Perf regressions across versions — that's `review-api-compat`-style work but for benchmarks. Out of scope here.
- Database query plans — `review-database` covers `EXPLAIN` analysis.
- Dashboard / alert SLO tuning — observability concern.
- Disk / network / OS-level tuning — beyond the source code.
