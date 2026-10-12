# Reliability Review: Framework Reference

Checklists for reliability analysis. The SKILL.md workflow reads this file.

## Contents
- Graceful Shutdown Contract
- gRPC Production Patterns
- Stability Patterns
- Resource and Context Ownership
- Stability Anti-Patterns

Reference sources:
- [Release It!](https://pragprog.com/titles/mnee2/release-it-second-edition/), Michael Nygard (stability patterns and anti-patterns)
- [gRPC Health Checking Protocol](https://github.com/grpc/grpc/blob/master/doc/health-checking.md): `grpc.health.v1`
- [gRPC Service Config](https://grpc.io/docs/guides/service-config/): retry policies, method deadlines, load balancing
- [Kubernetes Graceful Shutdown as a Contract](https://www.michal-drozd.com/en/blog/kubernetes-graceful-shutdown-rollouts/)

## Graceful Shutdown Contract

Four invariants for zero-downtime rollouts on Kubernetes:

1. **Stop routing new traffic first**: the readiness probe returns not-ready before the process drains. Kubernetes then removes the pod from endpoints before the shutdown logic runs.
2. **Stop accepting new work inside the process**: the server stops new RPCs and connections, for example with `grpcServer.GracefulStop()`.
3. **Finish in-flight work within a bounded time**: every in-progress request completes or is cancelled before the deadline. Wrap `GracefulStop` in a context with a timeout.
4. **Exit before SIGKILL**: the total drain time (preStop hook, drain, safety margin) must fit inside `terminationGracePeriodSeconds`.

Check in code that:

- A SIGTERM handler is registered and starts the shutdown sequence
- A `preStop` hook or a readiness-probe flip gives Kubernetes time to propagate endpoint removal
- `GracefulStop()` runs with a bounded deadline and falls back to `Stop()` on timeout
- Background goroutines and workers have a cancellation path (context or done channel)
- The shutdown path closes database connections, file handles, and other resources

## gRPC Production Patterns

**Health checking:**
- The service implements `grpc.health.v1.Health`. A gRPC service does not use an HTTP health endpoint
- Per-service health status is registered, not only a global check
- Health status reflects real readiness, such as database connectivity. "The process is alive" is not readiness
- Kubernetes probes use the `grpc` probe type (K8s 1.24 and later), not `exec` with `grpc_health_probe`

**Deadline and context propagation:**
- Every outbound RPC sets a deadline with `context.WithTimeout` or `context.WithDeadline`
- The incoming request context propagates through the whole call chain, including database queries and downstream RPCs
- Long operations check `ctx.Done()` and return early on cancellation
- Server-side handlers respect the client deadline and do not run unbounded

**Load balancing and connection management:**
- `MaxConnectionAge` and `MaxConnectionAgeGrace` force periodic reconnection, which distributes load across pods
- The client uses client-side load balancing or a headless service. A standard `ClusterIP` distributes gRPC traffic poorly, because HTTP/2 connections persist
- Keepalive parameters (`Time`, `Timeout`, `PermitWithoutStream`) are set on both client and server

**Status codes and error handling:**
- RPCs return specific `codes.*` values (`InvalidArgument`, `NotFound`, `Unavailable`, `DeadlineExceeded`), not `Unknown` or `Internal` for every error
- Errors from downstream dependencies are translated to gRPC status codes, not passed through raw
- `codes.Unavailable` marks a transient failure, which tells the client to retry

**Interceptors:**
- A recovery interceptor (`grpc_recovery`) catches panics and returns `Internal`. The process does not crash
- Logging and metrics interceptors capture per-method latency, status code, and request metadata
- An auth interceptor validates credentials before the handler runs

## Stability Patterns (Release It!)

Check that these patterns are present:

**Timeouts:**
- Every outbound call (database query, HTTP request, gRPC dial, gRPC call) has an explicit timeout or context deadline
- No operation blocks without bound. Watch for `select` without `ctx.Done()`, and for channel receives without a timeout
- Every layer sets a timeout, not only the top-level handler
- Each layer's budget fits inside the caller's remaining time. A child deadline is shorter than its parent's
- The sum of sequential inner calls, plus their retries, fits the outer handler deadline
- The budget counts first-call work, not only the warm path: lazy key or metadata fetches, connection warm-up, schema introspection. A deadline sized for the warm path can be too short on the first request
- Each route has a written budget: outer deadline, each inner timeout, retry count. An untabulated budget is an unchecked budget

**Circuit Breaker:**
- A circuit breaker wraps every call to a remote dependency that can fail
- The breaker trips after a threshold of failures, and fails fast while it is open
- A half-open state sends probe requests to test recovery

**Bulkheads:**
- Independent failure domains use separate resources, for example separate database connection pools for critical and background work
- Worker pools or semaphores bound concurrent access to shared resources
- A failure in one subsystem does not exhaust the resources another subsystem needs

**Fail Fast:**
- A request that cannot succeed is rejected at once, not queued or partly processed. Examples: a missing required field, invalid auth
- Resource exhaustion (full queue, exhausted pool) returns an error and does not block

**Handshaking:**
- Health checks test real dependency connectivity, not only that the process started
- Startup validation checks database reachability, config correctness, and required services before the process marks itself ready

**Steady State:**
- Nothing grows without bound. Logs rotate, caches evict, connection pools have a maximum size
- Goroutine counts are bounded. Leaked goroutines are detectable
- Temporary files, buffers, and queues have size limits and a cleanup path

**Goroutine leak test coverage** ([goleak](https://github.com/uber-go/goleak)):
- A package that spawns goroutines must have a goroutine leak check in its tests. Look for `go func` and for the `go ` keyword
- `goleak.VerifyTestMain(m)` in `TestMain` gives package-wide leak detection
- `goleak.VerifyNone(t)` in a single test gives per-test leak detection
- Report a package that spawns goroutines and has no goleak usage in its `*_test.go` files. This is a strong proxy for whether anyone tests for goroutine leaks

## Resource and Context Ownership

Who owns a resource after the caller gives up. To answer this, read the dependency's source, not its documentation.

- Name the owner of each resource acquired on a request path, after the caller's context is cancelled. This covers connections, goroutines, file handles, subscriptions, and timers
- A `context` on a library's public API does not mean the library governs its internal work with that context. A pool that dials on its own long-lived context holds the slot past the caller's deadline. Read the dependency source and cite `path:line`
- Cancellation releases the *caller*, not always the resource. A cancelled request can leave a connect in flight, and that connect still occupies capacity
- An acquisition that can block has its own timeout, separate from the work it guards
- Error paths and early-return paths release everything the success path releases
- A finding about release behavior cites the dependency's source. "The API takes a context" is not evidence that the library honors the context

**Check on the production construction path:**
- Behavior checked against a test harness stand-in says nothing about production. Example: a bare driver handle instead of the project's pool constructor
- Behavior checked against a substitute backend says nothing about the real one. One SQL engine can stand in for another, or recorded fixtures can stand in for a live service. Engine-specific statements, privileges, and system objects differ
- If only a stand-in is available, say so in the finding and name the check that settles it. Per `probe-not-assume`

## Stability Anti-Patterns (Release It!)

Report these anti-patterns:

**Integration Points:**
- An outbound call with no timeout, no retry policy, or no error handling. Each one is a cascading failure vector
- Direct coupling to a dependency's internal behavior. Example: the code parses raw error strings instead of reading status codes

**Cascading Failures:**
- A failing downstream dependency makes the caller fail the same way. Example: the service returns `Internal` because a cache is down, when it can run without that cache
- A readiness probe that checks downstream health. One failing leaf then takes the whole upstream chain not-ready

**Blocked Threads:**
- A goroutine that waits without bound on a channel receive, a mutex lock, or I/O, with no context cancellation
- A `sync.WaitGroup` wait with no timeout and no cancellation path
- A blocking call inside a mutex-held critical section

**Unbounded Result Sets:**
- A database query without `LIMIT` or pagination
- A list RPC that does not enforce `page_size` and `page_token`
- In-memory collection of streaming RPC results with no size bound

**Slow Responses:**
- A missing deadline on an outbound call. A slow dependency then ties up handler goroutines
- No server-side timeout on incoming RPCs. A misbehaving client can then hold a connection without bound
- A synchronous call to a non-critical dependency in the hot path, with no timeout

**SLA Inversion:**
- The critical path depends synchronously on a less reliable service, with no fallback, timeout, or degraded mode
- No circuit breaker and no fallback for a dependency with weaker availability guarantees

**Unbalanced Capacities:**
- A streaming RPC with no flow control and no backpressure
- A producer that enqueues work faster than the consumer processes it, with no admission control and no shedding
