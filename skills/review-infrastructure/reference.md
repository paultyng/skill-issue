# Infrastructure Review: Framework Reference

Detailed checklists for infrastructure review. SKILL.md references this file.

Reference sources:
- [Terraform Best Practices](https://developer.hashicorp.com/terraform/language/style)
- [Kubernetes Production Best Practices](https://learnk8s.io/production-best-practices)
- [Docker Build Best Practices](https://docs.docker.com/build/building/best-practices/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Envoy Production Best Practices](https://www.envoyproxy.io/docs/envoy/latest/configuration/best_practices/edge) (edge gateway)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Linkerd Production Runbook](https://linkerd.io/2/tasks/)
- [Istio Production Checklist](https://istio.io/latest/docs/ops/best-practices/)

## Table of contents

- [Terraform / OpenTofu](#terraform--opentofu)
- [Kubernetes manifests](#kubernetes-manifests)
- [Dockerfile](#dockerfile)
- [Helm](#helm)
- [Gateway (north-south)](#gateway-north-south)
- [Service mesh (east-west)](#service-mesh-east-west)

## Terraform / OpenTofu

**State and backend:**
- Remote backend configured (S3 + DynamoDB lock, GCS, Terraform Cloud, etc.); no local state for shared resources
- State is encrypted at rest and not committed to git (`.terraform/`, `*.tfstate` ignored)
- `terraform { required_version = "..." }` pins core version; `required_providers` pins each provider with `~>` or exact version

**Inputs and outputs:**
- Sensitive variables marked `sensitive = true`; sensitive outputs likewise
- No hardcoded credentials, ARNs of secrets, or tokens in `.tf` / `.tfvars` (use `data` sources or secret managers)
- Variable defaults are safe (no plaintext passwords, no wildcard CIDRs as default)

**Resource hygiene:**
- `lifecycle { prevent_destroy = true }` on stateful resources (databases, KMS keys, state buckets)
- `lifecycle { ignore_changes = [...] }` only for fields managed out-of-band, with a comment explaining why
- Implicit dependencies preferred (reference attributes); `depends_on` only when implicit ordering is insufficient
- `count` / `for_each` use is correct: `count` for boolean toggles; `for_each` for unique-key collections; no `count = length(var.list)` (use `for_each = toset(var.list)`)

**Modules:**
- Module sources pinned by tag, SHA, or registry version (never `main`/`master`)
- Module inputs validated with `validation` blocks for non-trivial constraints
- Outputs documented and minimal (no leaking the entire resource)

**Drift and CI safety:**
- `terraform plan` runs in CI on PRs and posts the plan
- Apply is gated (manual approval or main-branch only); no auto-apply on every push to feature branches
- Workspace separation between environments (dev/staging/prod) or fully separate state backends

## Kubernetes manifests

**Workload basics:**
- `resources.requests` AND `resources.limits` set on every container (CPU + memory). Limits matter for OOM kill semantics and noisy-neighbor isolation
- `livenessProbe`, `readinessProbe`, `startupProbe` configured appropriately; readiness reflects actual readiness (DB/dependency), liveness reflects "process is wedged"
- Image references pin a SHA digest (`image: foo@sha256:...`) or at minimum an immutable tag; never `:latest`
- `imagePullPolicy: IfNotPresent` for pinned tags/digests; `Always` only when using mutable tags (and then question why mutable tags are used)
- `replicas` ≥ 2 for any workload that should survive a node drain
- `topologySpreadConstraints` or `podAntiAffinity` for HA workloads to spread across nodes/zones

**Security context:**
- `securityContext.runAsNonRoot: true`
- `securityContext.readOnlyRootFilesystem: true` (with `emptyDir` volumes mounted where writes are needed)
- `securityContext.allowPrivilegeEscalation: false`
- `securityContext.capabilities.drop: ["ALL"]`; only add back what is strictly required
- `seccompProfile.type: RuntimeDefault` (or `Localhost` with a profile)
- `automountServiceAccountToken: false` on workloads that do not call the Kubernetes API

**Disruption and policy:**
- `PodDisruptionBudget` for every HA workload (`minAvailable` or `maxUnavailable`)
- `NetworkPolicy` defines ingress/egress; default-deny at namespace level then explicit allow rules
- `ResourceQuota` and `LimitRange` per namespace bound aggregate consumption
- Pods reference a non-default `ServiceAccount` with least-privilege `Role` / `ClusterRole` bindings

**Config and secrets:**
- ConfigMaps and Secrets mounted as files preferred over env vars when values are large or rotated
- `Secret` objects are not committed in plaintext; use sealed-secrets, external-secrets, or SOPS
- `imagePullSecrets` scoped to the ServiceAccount, not duplicated per pod

**Scheduling and capacity:**
- `priorityClassName` set on system-critical workloads
- Anti-affinity prevents co-located replicas of the same Deployment on the same node/zone
- Node selectors / tolerations match real labels on the cluster (verify, not assume)

**Note:** Pod *termination* (preStop, terminationGracePeriodSeconds, SIGTERM handling) is reviewed by `review-reliability`, not here.

## Dockerfile

**Base image:**
- Base image is pinned by digest (`FROM debian:bookworm@sha256:...`) or at minimum an immutable tag with a major+minor (never `latest`)
- Use minimal base images (`distroless`, `alpine`, `chainguard`) when the workload doesn't need a full OS
- Multi-stage builds: `FROM ... AS build` then `FROM <minimal> AS final` copies only the artifact

**Layering and cache:**
- Dependencies installed before source is copied (`COPY go.mod go.sum ./` + `RUN go mod download` then `COPY . .`) so source edits don't bust the dep cache
- Single `RUN` per logical step; combine `apt-get update && apt-get install -y --no-install-recommends ... && rm -rf /var/lib/apt/lists/*` to avoid stale package indexes and bloated layers

**Runtime hardening:**
- `USER <non-root>` set in the final stage. Don't run as root
- `WORKDIR` set explicitly; not `/`
- `HEALTHCHECK` defined when the orchestrator doesn't provide one (k8s usually does — skip in that case to avoid duplicate probes)
- `ENTRYPOINT` uses exec form (`["./app"]`), not shell form, so signals propagate
- `STOPSIGNAL` matches what the app handles (SIGTERM default is usually correct)

**Surface area:**
- No build tools, package managers, or shells in the final image when not needed
- No secrets in the image: no tokens baked in, no `.git/` copied, no SSH keys; use `--mount=type=secret` (BuildKit) for build-time secrets
- `.dockerignore` excludes `.git`, `node_modules`, secrets, test fixtures
- Image size is sane for the workload type (a Go binary in distroless is ~20-50MB, not 1GB)

## Helm

**Chart hygiene:**
- `Chart.yaml` pins `apiVersion: v2`, `version`, `appVersion`; `kubeVersion` constraint reflects tested cluster versions
- `dependencies:` use pinned versions; `helm dependency update` run in CI
- CRDs in `crds/` directory or templated with `Helm.Hook` annotations; never in main `templates/` unless intentional (Helm does not manage CRD upgrades)

**Templating:**
- Values referenced with `{{ .Values.foo | default "x" | quote }}` — quote strings that might contain numbers, dots, or YAML special chars
- Indentation uses `nindent` (newline + indent) not `indent` when starting a new block
- Range loops over lists/dicts close cleanly; no dangling `{{- end }}`
- `Release.Name`, `Chart.Name`, `Chart.Version` used in labels (`app.kubernetes.io/managed-by`, `helm.sh/chart`)

**Values:**
- `values.yaml` defaults are safe-for-prod (or safe-by-omission with required fields marked); examples in `values-dev.yaml`, `values-prod.yaml`
- `values.schema.json` validates structure and prevents typos
- Sensitive values are externalized (sealed-secrets, external-secrets, vault) and not committed in plaintext `values-*.yaml`

**Rendering and lifecycle:**
- `helm lint` and `helm template | kubeconform` pass
- `NOTES.txt` reflects what was actually deployed (URLs, credentials retrieval steps)
- Pre-install / pre-upgrade hooks are idempotent; failed hooks don't leave partial state
- `helm rollback` is tested for at least one prior release

## Gateway (north-south)

This section covers traffic *entering* the cluster: edge termination, TLS, authn/authz at the boundary, and routing to backends. Envoy used as an edge proxy belongs here, **not** in the service mesh section.

**Detection signals:**
- Envoy bootstrap files (`envoy.yaml`, `bootstrap.yaml`, files with `static_resources:` + `listeners:`) → standalone Envoy gateway
- `apiVersion: gateway.networking.k8s.io/*` (`Gateway`, `HTTPRoute`, `TLSRoute`, `GRPCRoute`) → Gateway API
- `apiVersion: networking.k8s.io/v1` `kind: Ingress` → Ingress controller
- `apiVersion: getambassador.io/*` → Emissary/Ambassador
- `apiVersion: projectcontour.io/*` → Contour

### Envoy (edge gateway)

**Listener and filter chain:**
- Listeners bind to expected addresses; admin interface (`9901`) bound to `127.0.0.1` only — never `0.0.0.0` in any environment
- TLS listeners use SDS for certs or pinned cert/key paths; private keys never committed; cert rotation path documented
- HTTP/2 enabled on gRPC listeners and upstream clusters; `idle_timeout`, `request_timeout`, `max_stream_duration` set explicitly
- `use_remote_address: true` and trusted proxy hop count set when behind L4 LB, so client IP is correct

**Routing and clusters:**
- Each upstream cluster has explicit `connect_timeout`, `circuit_breakers.thresholds` (`max_connections`, `max_pending_requests`, `max_requests`, `max_retries`), and `outlier_detection`
- Active health checks defined per upstream cluster
- Retry policy bounded: `num_retries` ≤ 3, `retry_on` explicit (e.g. `5xx,gateway-error,reset,connect-failure`), only on idempotent methods
- Rate limiting / `local_ratelimit` or global `ratelimit` filter applied to public-facing routes

**Filters and authn/authz:**
- `jwt_authn` filter validates JWTs at the edge when end-user auth is required
- `ext_authz` filter delegates to an auth service for richer policies
- `cors` filter explicit (no wildcard `*` for credentialed requests)
- `lua` / `wasm` filters reviewed for safety; arbitrary user-supplied code is a red flag

**Observability:**
- Access logs configured with structured (JSON) format; sensitive headers (`authorization`, `cookie`, `set-cookie`) redacted
- StatsD / Prometheus stats sink configured; per-cluster, per-listener, per-filter metrics enabled
- Tracing (OpenTelemetry / Zipkin / Datadog) configured with sampling

**xDS (if dynamic config in use):**
- Control plane connection over TLS (mTLS preferred); xDS endpoint references a stable DNS / service
- Bootstrap pinned to a known control plane version

### Kubernetes Ingress / Gateway API

**Ingress:**
- `ingressClassName` set explicitly; no default-class assumption
- TLS section references real `secretName`; cert managed by cert-manager or external provisioner, not pasted in
- Annotations are reviewed for ingress-controller specifics (e.g. `nginx.ingress.kubernetes.io/ssl-redirect`, `kubernetes.io/tls-acme`)
- `host` and `pathType` are explicit; `pathType: Prefix` preferred over `ImplementationSpecific`

**Gateway API:**
- `Gateway.listeners[].hostname` is explicit (not wildcard outside test)
- `listeners[].tls.mode` is `Terminate` (or `Passthrough` when intentional); `certificateRefs` reference Secrets in the gateway namespace with `ReferenceGrant` if cross-namespace
- `HTTPRoute.parentRefs` correctly target the `Gateway` and `sectionName`/`port`
- `HTTPRoute` rules set `timeouts.request` and `timeouts.backendRequest` explicitly; no implicit "wait forever"
- `BackendTLSPolicy` set for upstream TLS validation when backends use TLS

**Both:**
- WAF / bot management posture defined (or explicitly out-of-scope) for public-facing routes
- Default-deny posture at the L7 edge; routes are allow-listed, not deny-listed
- Backend `Service` is `ClusterIP` (not `LoadBalancer` / `NodePort`) when fronted by a gateway

## Service mesh (east-west)

This section covers in-cluster service-to-service traffic: which pods can call which, on what ports, with what authentication, and with what failure semantics. Mesh ingress gateways (e.g. `istio-ingressgateway`) are reviewed under [Gateway](#gateway-north-south) when used for north-south.

**Detection signals:**
- `linkerd.io/inject: enabled` (annotation on namespace or pod) → Linkerd
- `sidecar.istio.io/inject: "true"` or `istio-injection=enabled` (namespace label) → Istio
- CRDs with `apiVersion: networking.istio.io/*`, `security.istio.io/*` → Istio
- CRDs with `apiVersion: policy.linkerd.io/*` (`Server`, `ServerAuthorization`, `HTTPRoute`) → Linkerd

### Linkerd

**Injection:**
- Mesh injection is explicit per workload or per namespace (`linkerd.io/inject: enabled`); rely on `disabled` only for opt-out
- `config.linkerd.io/proxy-cpu-request`, `proxy-memory-request`, and corresponding limits set on the sidecar — defaults are often too small for high-throughput workloads
- `linkerd-proxy` is not skipped via `config.linkerd.io/skip-outbound-ports` unless required (every skip is a hole in mTLS coverage)

**Authorization:**
- Each `Server` resource has at least one `ServerAuthorization` or `HTTPRoute` + `AuthorizationPolicy` granting access; no orphan `Server` (default-deny when any `Server` matches but no auth allows)
- `MeshTLSAuthentication` and `NetworkAuthentication` are scoped (specific ServiceAccounts/namespaces), not wildcard
- Service profiles (`ServiceProfile`) set per-route retries and timeouts; retries are bounded and only on idempotent routes

**Observability and operations:**
- `linkerd viz` (or equivalent metrics) is wired to scraping
- Trust anchor (`linkerd-identity-trust-roots`) rotation plan documented; cert expiry monitored
- Multicluster gateways (`linkerd-gateway`) are scoped to expected remote clusters only

### Istio

**Injection and PeerAuthentication:**
- Namespace-level `PeerAuthentication` sets mTLS mode (`STRICT` strongly preferred for prod east-west; `PERMISSIVE` is migration-only)
- `Sidecar` resources limit per-workload egress to known destinations; reduces config-push and blast radius
- Sidecar resources set explicitly (default proxy CPU/memory is often insufficient)

**Authorization:**
- `AuthorizationPolicy` resources implement default-deny per workload, then allow specific principals/methods
- No wildcard principals (`source.principals: ["*"]`) outside the ingress gateway
- JWT validation via `RequestAuthentication` + `AuthorizationPolicy` with `requestPrincipals` for end-user auth

**Traffic policy:**
- `DestinationRule` sets per-destination connection pools, outlier detection, and TLS mode (`ISTIO_MUTUAL` for in-mesh)
- `VirtualService` retries are bounded and only on idempotent methods; `retryOn` is explicit (e.g. `5xx,gateway-error,reset`)
- Timeouts set explicitly on `VirtualService` routes; default-no-timeout is rarely correct

**Gateways:**
- `Gateway` resources reference real cert sources (`credentialName` for SDS); no inline cert material
- TLS mode is `SIMPLE` or `MUTUAL`; `PASSTHROUGH` only when intentional and documented
- `Gateway` host lists are explicit, not `*`, outside test environments

### Cross-mesh hygiene

- mTLS is on for all east-west traffic; no plaintext fallback by default
- Default-deny authorization at the mesh layer for prod namespaces
- Mesh control plane (linkerd-controller, istiod, etc.) has its own NetworkPolicy and resource limits
- Mesh CRD versions are pinned to a chart release, not pulled from `main`
- Sidecar resource limits sum across workloads fit within node capacity (often missed in capacity planning)
- Mesh upgrade plan documented; rollback path tested
