# Observability Review: Framework Reference

Detailed checklists for observability analysis. SKILL.md references this file.

Reference sources:
- [OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
- [Prometheus Best Practices: Naming](https://prometheus.io/docs/practices/naming/), [Histograms and summaries](https://prometheus.io/docs/practices/histograms/), [Instrumentation](https://prometheus.io/docs/practices/instrumentation/)
- [Google SRE Book: Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/) (Four Golden Signals: latency, traffic, errors, saturation)
- [Cindy Sridharan: Distributed Systems Observability](https://www.oreilly.com/library/view/distributed-systems-observability/9781492033431/) (three pillars + correlation)

## Table of contents

- [Logging](#logging)
- [Metrics](#metrics)
- [Tracing](#tracing)
- [Correlation across signals](#correlation-across-signals)
- [Configuration and pipeline](#configuration-and-pipeline)

## Logging

**Structure:**
- Logs are structured (key-value or JSON), not freeform sprintf. Go: `slog`, `zap`, `zerolog`. JS/TS: `pino`, `winston` with `format.json`. Python: `structlog`, `python-json-logger`.
- Log statements include a stable `msg` (constant string) and variable data as fields, not interpolated into the message. (`logger.Info("user signed in", "user_id", id)`, not `logger.Info(fmt.Sprintf("user %s signed in", id))`.)
- Levels are used appropriately: `DEBUG` for development noise, `INFO` for steady-state observations, `WARN` for recoverable abnormal conditions, `ERROR` for failures requiring attention. `FATAL`/`PANIC` exits the process — used only for unrecoverable startup failures.

**Sufficiency:**
- Every RPC handler entry / exit has at least one log entry capturing method, duration, and outcome — or these are emitted by an interceptor. Flag handlers without either.
- Every error path logs the error with enough context to debug (operation name, input identifiers, downstream service if applicable). `log.Error(err)` alone is rarely enough.
- Non-error decisions worth observing: rate limit applied, cache miss/hit ratio shift, retry attempts, feature flag changes affecting behavior.
- Background workers log start, stop, and per-iteration outcome (counts, errors). Not every iteration; sampled or aggregated.

**Hot loops:**
- No log statement inside a tight loop without sampling or rate limiting. `INFO` logs in a request handler are fine; `INFO` logs inside a per-row iteration are a problem.
- Use `slog.LogAttrs` or pre-computed `zap.Field` slices to avoid allocation on hot paths.

**Sensitive data:**
- Auth tokens, session cookies, passwords, PII (when not the business of this service) never appear in logs. Use redaction middleware or explicit field exclusion lists.
- For Go: `error` types that wrap user input should not implement `LogValuer` to dump the input verbatim.
- This is the floor; deeper PII/security review is `review-security`.

**Sink and shipping:**
- Logs go to stdout/stderr (for k8s) or a structured collector, not local files that nobody ships.
- Log shippers (Fluent Bit, Vector, otel-collector logs receiver) configured to parse JSON without dropping fields.

## Metrics

**Four golden signals (per service, per critical path):**
- **Latency**: histogram of request duration (`http_request_duration_seconds` or equivalent). Use histograms, not summaries, for aggregation across instances. Buckets tuned to the SLO (don't use the default `[0.005, 0.01, ... 10]` for a service whose p99 is 30ms).
- **Traffic**: counter of requests (`http_requests_total`) — partitioned by method and status code, not by user-controlled labels.
- **Errors**: counter or rate of failures. Often derived from traffic counter by status_code filter, sometimes separate (`errors_total{type="..."}`).
- **Saturation**: queue depth, pool utilization, goroutine count, connection pool in-use vs. max. The "how full" measure.

**Naming and units (Prometheus convention):**
- Name format: `<namespace>_<subsystem>_<name>_<unit>`. Example: `auth_jwt_validation_duration_seconds`.
- Units in the name: `_seconds` for time, `_bytes` for size, `_total` for counters. Avoid milliseconds / microseconds in the name — use seconds and let Grafana format.
- Counters end in `_total`. Gauges and histograms do not.

**Cardinality:**
- Labels are bounded. Acceptable: `method` (~10 values), `status_code` (~7 values), `route` (must be the template, not the raw URL with IDs), `service`, `version`.
- Forbidden as labels: user ID, request ID, raw URL with IDs, error message strings, customer name, trace ID. These belong in spans/logs, not metrics.
- Rule of thumb: keep total active time-series per metric under ~10k; under ~1k is comfortable.
- `route` should be the route template (`/users/:id`) not the matched URL (`/users/12345`).

**Histogram buckets:**
- Tuned to actual observed distributions. Default Prometheus buckets are rarely right.
- Native histograms (Prometheus 2.40+) preferred when supported by the storage; native buckets are exponential and auto-scaling.
- Don't use summaries (`Summary`) for cross-instance aggregation — they cannot be aggregated; histograms can.

**Instrumentation library:**
- One client library used consistently per language. Mixing `prometheus/client_golang` with `opentelemetry-go/metric` in the same service produces confusing dashboards.
- Instrumentation middleware applied at the transport layer (gRPC interceptor, HTTP middleware) for uniform coverage — not hand-written per handler.

**Cost:**
- High-frequency `Counter.Inc` is cheap; high-cardinality label sets are not. The cost is in series count × retention, not in samples per second.

## Tracing

**Sufficiency:**
- Every external RPC and DB call is a span. Otel auto-instrumentation (`otelgrpc`, `otelhttp`, `otelsql`, `otelpgx`, etc.) provides this; hand-rolled clients must add it.
- Every "interesting" internal function — anything that takes > a few ms or that has its own error semantics — is a span. Use the span name as a debugging anchor (e.g. `auth.validateJWT`, `db.users.upsert`).
- Error spans set `span.SetStatus(codes.Error, ...)` and `span.RecordError(err)`. Otherwise the error is invisible in trace search.

**Propagation:**
- W3C `traceparent` / `tracestate` headers propagated on every outbound RPC. `otelgrpc` and `otelhttp` clients handle this automatically; hand-rolled clients must inject manually.
- For async work (queues, scheduled jobs), the parent span context is propagated through the message envelope. Otherwise the worker's spans are roots with no parent — debuggability degrades.

**Span attributes:**
- Follow [OTel Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/) where they exist (`http.request.method`, `db.system`, `messaging.system`, `rpc.service`, etc.) rather than inventing keys.
- Attributes are bounded — don't put per-row data inside a span attribute for a span that wraps many rows.
- `service.name`, `service.version`, `deployment.environment` set as resource attributes once, not per span.

**Sampling:**
- Head-based sampling at a fixed rate (e.g. 1%) is the baseline. For production, prefer **tail-based sampling** in the Collector so that all errors and slow traces are kept regardless of the rate.
- Sampling decisions are propagated downstream; don't sample independently per service or traces will be incomplete.

**Span events vs. logs:**
- Use span events (`span.AddEvent`) for instantaneous observations within a span (e.g. "cache miss", "retry attempt"). They are cheaper than emitting a log line and stay attached to the trace.
- Use logs for events outside any active span (background tasks, startup).

**Cost:**
- Default tail-sampled coverage of errors and slow traces is the highest-value, lowest-cost configuration.
- Span counts > 1000 per request indicate over-instrumentation; consolidate into fewer, semantically meaningful spans.

## Correlation across signals

The pillars only pay off when you can pivot from one to another.

**Logs ↔ traces:**
- Every log entry includes `trace_id` and `span_id` when emitted inside a span context. Go: `slog.With(logging.TraceContext(ctx))` or equivalent middleware.
- Logging library's context-propagation helper used at the start of each request handler.
- Trace UI shows logs for the trace; log UI links to the trace.

**Metrics ↔ traces:**
- Exemplars on Prometheus histograms link to representative traces (`prometheus-client-go` supports `ObserveWithExemplar`).
- Slow buckets in a latency histogram are clickable to find example traces.

**Metrics ↔ logs:**
- Less direct, but a shared `service` and `route` label vocabulary lets a metrics spike be cross-referenced with logs filtered by the same `route`.

**Stable IDs across services:**
- A "request ID" or "correlation ID" header is propagated through the call chain and emitted on every log line. With OTel, `trace_id` does this job — don't reinvent.

## Configuration and pipeline

**OTel Collector:**
- A Collector deployment exists if exporters need transformation, sampling, or batching. Direct application → backend exporters work for small services but become a bottleneck at scale.
- Pipeline has clear stages: receivers → processors (batch, memory_limiter, tail_sampling) → exporters.
- `memory_limiter` processor configured to prevent OOM on backpressure.
- Tail sampling rules cover at minimum: keep errors, keep slow traces (> p95 SLO), sample the rest.

**Prometheus scrape:**
- Scrape configs use `kubernetes_sd_configs` with role-based selection, not hardcoded targets.
- `metric_relabel_configs` drop high-cardinality labels added by misbehaving exporters before they hit storage.
- Recording rules pre-aggregate expensive queries; alerts query the recording rule, not raw series.

**Versioning:**
- OTel SDK and Collector versions pinned. Mismatched protocol versions silently drop data.
- Prometheus exposition format version is consistent across services (most use `text/plain; version=0.0.4`).

**Resource attributes:**
- `service.name`, `service.version`, `service.namespace`, `deployment.environment`, `k8s.pod.name`, `k8s.namespace.name` set as resource attributes (per-process, not per-signal). Set once via the SDK config; don't repeat per span/metric/log.
