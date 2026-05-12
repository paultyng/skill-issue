# Reliability Review: Framework Reference

Detailed checklists for reliability analysis. The SKILL.md workflow references this file.

Reference sources:
- [Release It!](https://pragprog.com/titles/mnee2/release-it-second-edition/), Michael Nygard (stability patterns and anti-patterns)
- [gRPC Health Checking Protocol](https://github.com/grpc/grpc/blob/master/doc/health-checking.md): `grpc.health.v1`
- [gRPC Service Config](https://grpc.io/docs/guides/service-config/): retry policies, method deadlines, load balancing
- [Kubernetes Graceful Shutdown as a Contract](https://www.michal-drozd.com/en/blog/kubernetes-graceful-shutdown-rollouts/)

## Graceful Shutdown Contract

Four invariants for zero-downtime rollouts on Kubernetes:

1. **Stop routing new traffic first**: readiness probe returns not-ready before the process begins draining, so Kubernetes removes the pod from endpoints before shutdown logic runs
2. **Stop accepting new work inside the process**: server stops accepting new RPCs/connections (e.g. `grpcServer.GracefulStop()`)
3. **Finish in-flight work within a bounded time**: all in-progress requests complete or are cancelled before the deadline; use a context with timeout wrapping `GracefulStop`
4. **Exit before SIGKILL**: the total drain time (preStop hook + drain + safety margin) must fit within `terminationGracePeriodSeconds`

What to check in code:
- SIGTERM signal handler is registered and triggers the shutdown sequence
- `preStop` hook or readiness probe flip gives Kubernetes time to propagate endpoint removal
- `GracefulStop()` is called with a bounded deadline, falling back to `Stop()` on timeout
- Background goroutines and workers have cancellation paths (context or done channel)
- Database connections, file handles, and other resources are closed in the shutdown path

## gRPC Production Patterns

**Health checking:**
- Service implements `grpc.health.v1.Health` (not HTTP health endpoints for gRPC services)
- Per-service health status is registered, not just a global check
- Health status reflects actual readiness (e.g. DB connectivity), not just "process is alive"
- Kubernetes probes use `grpc` probe type (available since K8s 1.24), not `exec` with `grpc_health_probe`

**Deadline and context propagation:**
- Every outbound RPC sets a deadline via `context.WithTimeout` or `context.WithDeadline`
- Incoming request context is propagated through the entire call chain (DB queries, downstream RPCs, etc.)
- Long operations check `ctx.Done()` and return early on cancellation
- Server-side handlers respect the client's deadline rather than running unbounded

**Load balancing and connection management:**
- `MaxConnectionAge` / `MaxConnectionAgeGrace` keepalive settings are configured to force periodic reconnection for load distribution across pods
- Client-side load balancing or headless services are used (standard `ClusterIP` does not distribute gRPC traffic effectively due to HTTP/2 persistent connections)
- Keepalive parameters (`Time`, `Timeout`, `PermitWithoutStream`) are set on both client and server

**Status codes and error handling:**
- RPCs return appropriate `codes.*` status codes (`InvalidArgument`, `NotFound`, `Unavailable`, `DeadlineExceeded`, etc.) rather than generic `Unknown` or `Internal` for all errors
- Errors from downstream dependencies are translated to appropriate gRPC status codes, not passed through raw
- `codes.Unavailable` is returned for transient failures (signals clients to retry)

**Interceptors:**
- Recovery interceptor (`grpc_recovery`) catches panics and returns `Internal` instead of crashing the process
- Logging/metrics interceptors capture per-method latency, status code, and request metadata
- Auth interceptor validates credentials before handler execution

## Stability Patterns (Release It!)

Patterns to check for presence in the codebase:

**Timeouts:**
- Every outbound call (DB query, HTTP request, gRPC dial, gRPC call) has an explicit timeout or context deadline
- No unbounded blocking operations (`select` without `ctx.Done()`, channel receives without timeout)
- Timeouts are set at each layer, not just at the top-level handler

**Circuit Breaker:**
- Calls to remote dependencies that can fail are wrapped in a circuit breaker
- The breaker trips after a threshold of failures and fails fast during the open state
- Half-open state allows probe requests to test recovery

**Bulkheads:**
- Independent failure domains use separate resources (e.g. separate DB connection pools for critical vs. background work)
- Worker pools / semaphores bound concurrent access to shared resources
- A failure in one subsystem does not exhaust resources needed by another

**Fail Fast:**
- Requests that cannot succeed are rejected immediately (e.g. missing required fields, invalid auth) rather than queued or partially processed
- Resource exhaustion (full queue, pool exhausted) returns an error rather than blocking indefinitely

**Handshaking:**
- Health checks verify actual dependency connectivity, not just that the process started
- Startup validation confirms DB reachability, config correctness, and required services before marking ready

**Steady State:**
- Nothing grows without bound: logs rotate, caches evict, connection pools have max sizes
- Goroutine counts are bounded; leaked goroutines are detectable
- Temporary files, buffers, and queues have size limits and cleanup

**Goroutine leak test coverage** ([goleak](https://github.com/uber-go/goleak)):
- Packages that spawn goroutines (look for `go func` and `go ` keyword patterns in source) should have goroutine leak checks in their tests
- `goleak.VerifyTestMain(m)` in `TestMain` provides package-wide leak detection
- `goleak.VerifyNone(t)` in individual tests provides per-test leak detection
- Flag packages that spawn goroutines but have no goleak usage in `*_test.go` files. This is a strong proxy for whether goroutine leaks are being tested for

## Stability Anti-Patterns (Release It!)

Anti-patterns to detect and flag:

**Integration Points:**
- Outbound calls without timeout, retry, or error handling; each is a cascading failure vector
- Direct coupling to a dependency's internal behavior (e.g. parsing raw error strings instead of using status codes)

**Cascading Failures:**
- A failing downstream dependency causes the caller to fail in the same way (e.g. returning `Internal` because a cache is down, when the service could operate without cache)
- Readiness probe checks downstream health, causing the entire upstream chain to go not-ready when one leaf fails

**Blocked Threads:**
- Goroutines waiting indefinitely on channel receives, mutex locks, or I/O without context cancellation
- `sync.WaitGroup` waits without timeout or cancellation path
- Blocking calls inside a mutex-held critical section

**Unbounded Result Sets:**
- Database queries without `LIMIT` or pagination
- List RPCs without `page_size` / `page_token` enforcement
- In-memory collection of results from streaming RPCs without size bounds

**Slow Responses:**
- Missing deadlines on outbound calls, allowing slow dependencies to tie up handler goroutines
- No server-side timeout on incoming RPCs (a misbehaving client can hold a connection indefinitely)
- Synchronous calls to non-critical dependencies in the hot path without timeout

**SLA Inversion:**
- Critical path depends synchronously on a less-reliable service with no fallback, timeout, or degraded mode
- No circuit breaker or fallback for dependencies that have weaker availability guarantees

**Unbalanced Capacities:**
- Streaming RPCs without flow control or backpressure
- Producer can enqueue work faster than consumer can process, with no admission control or shedding
