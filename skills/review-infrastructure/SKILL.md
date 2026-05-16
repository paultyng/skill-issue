---
name: review-infrastructure
description: Use when the user asks for an infrastructure review, IaC review, Terraform review, Kubernetes manifest review, Dockerfile review, Helm chart review, container review, gateway review (Envoy / Ingress / Gateway API), service mesh review (Linkerd / Istio), east-west traffic review, north-south traffic review, mesh authorization review, or "review the infra / IaC / manifests / Dockerfile / helm chart / gateway / mesh config".
---

# Infrastructure Review

Structured infrastructure-as-code review producing actionable, prioritized findings with code-level references. Covers Terraform / OpenTofu, Kubernetes manifests, Dockerfiles, Helm charts, **north-south gateway exposure** (Envoy as edge gateway, Ingress controllers, Gateway API), and **east-west service mesh** (Linkerd, Istio).

**Out of scope** (defer to siblings):
- Pod shutdown / SIGTERM / `preStop` / `terminationGracePeriodSeconds` → `review-reliability`
- IAM policies, secret material, KMS key usage → `review-security` (but flag inline plaintext secrets in TF / k8s here)
- Application source code (`.go`, `.proto`, etc.) → `review-code`

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full codebase, specific paths/modules, changed files only (PR or branch diff), or specific concern.
- **Resolve scope to a file list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD` to get changed files (default `<base>` is `main`). If the user references a PR number, use `gh pr diff <number> --name-only` instead. Filter to infrastructure file types (see classification below).
  - **Explicit paths/modules:** The user may specify directories (e.g. `terraform/`, `deploy/k8s/`) or individual files. Include all infra files under it.
  - **Full codebase:** No filtering. Walk the repo for infra files (default).
- **If invoked from review-all**: receive `file_list`, `has_changes`, `base_ref`, `REVIEW_DIR`, and `pr_url` from the orchestrator. Skip your own scope confirmation and use the provided values directly.
- **Pass the resolved scope** (file list) to all exploration and investigation subagents so they only read and analyze scoped files.

**File classification.** Detect by extension and content sniff:
- **Terraform / OpenTofu**: `*.tf`, `*.tofu`, `*.tfvars`. Inspect `provider`, `backend`, `terraform { required_*_version }` blocks.
- **Kubernetes manifests**: YAML with `apiVersion:` + `kind:` keys. Includes raw manifests, Kustomize bases/overlays, ArgoCD `Application` specs, FluxCD `Kustomization`.
- **Dockerfile**: filename `Dockerfile`, `Containerfile`, or `*.Dockerfile`.
- **Helm**: directories containing `Chart.yaml`. Template files live under `templates/`; values in `values.yaml` and `values-*.yaml`.
- **Gateway (north-south)**: Envoy bootstrap / config (`envoy.yaml`, files referencing `node:`, `static_resources:`, `dynamic_resources:`, `listeners:` + `filter_chains:`). YAML manifests whose `apiVersion` matches `gateway.networking.k8s.io/*` (Gateway API), `getambassador.io/*` (Emissary/Ambassador), or `projectcontour.io/*` (Contour). Standard k8s `Ingress` resources.
- **Service mesh (east-west)**: YAML manifests whose `apiVersion` matches `networking.istio.io/*`, `security.istio.io/*`, `policy.linkerd.io/*`, or `linkerd.io/*`. Namespaces/workloads with `linkerd.io/inject` or `istio-injection` annotations/labels.

### 2. System overview

Produce a brief topology summary covering:
- Cloud / hosting model (if discernible from TF providers or k8s annotations)
- Cluster shape: namespaces, ingress/egress points, service mesh in use (Linkerd / Istio / Envoy / none)
- North-south entry points: gateway in use (Envoy, Ingress controller, Gateway API) and what it terminates (TLS, mTLS, JWT)
- East-west traffic posture: mesh in use (Linkerd / Istio / none); mTLS default-on or default-off; authorization mode (allow-all, allow-list, default-deny)
- Workload classes: stateful sets vs. deployments, daemonsets, jobs/cronjobs
- Container image sources and registries

This anchors findings to the actual deployment topology.

### 3. Launch investigation subagents in parallel

Launch investigation subagents concurrently using the Task tool (`model: sonnet` per `subagent-model-routing` — infra analysis needs to interpret resource relationships, not just pattern-match). Each receives the system overview and the relevant subset of in-scope files. Only launch subagents whose preconditions are met.

| Subagent | Precondition | Categories |
|---|---|---|
| Terraform / OpenTofu | any `*.tf`, `*.tofu`, `*.tfvars` | Terraform checklist in [reference.md](reference.md) |
| Kubernetes | any k8s YAML | Kubernetes checklist in [reference.md](reference.md) |
| Dockerfile | any Dockerfile | Dockerfile checklist in [reference.md](reference.md) |
| Helm | any `Chart.yaml` | Helm checklist in [reference.md](reference.md) |
| Gateway (north-south) | Envoy bootstrap, Gateway API CRDs, Ingress | Gateway checklist in [reference.md](reference.md) |
| Service mesh (east-west) | Linkerd/Istio CRDs or injection annotations | Service mesh checklist in [reference.md](reference.md) |

Each subagent must:
- Read **only** the in-scope files supplied.
- Apply the matching checklist in [reference.md](reference.md).
- Run the static analyzers below when the binary is on `PATH`. If a binary is missing, record it in the report as "tool not available" — do not install or fetch it.
- For each finding, search nearby files (`README.md`, in-repo runbooks, `TODO`/`FIXME`/`HACK`/`XXX` comments) for existing tracking.
- Return findings using the **infrastructure findings** template.

### 4. Run static analyzers

Invoke each tool if available and capture its output for the investigation subagent to triage:

```sh
# Terraform — syntax, idiom, deprecations
command -v tflint    >/dev/null && tflint --format=compact <scope>
command -v tfsec     >/dev/null && tfsec --no-color --format default <scope>
command -v checkov   >/dev/null && checkov -d <scope> --quiet --compact

# Kubernetes — schema + best-practice lint
command -v kubeconform >/dev/null && kubeconform -strict -summary <files>
command -v kube-linter >/dev/null && kube-linter lint <files>

# Dockerfile
command -v hadolint  >/dev/null && hadolint <Dockerfile>

# Helm — render then re-lint the rendered manifests
command -v helm      >/dev/null && helm lint <chart-dir> \
  && helm template <chart-dir> | kubeconform -strict -summary - 2>/dev/null \
  && helm template <chart-dir> | kube-linter lint - 2>/dev/null
```

Tool output is **input** to the review, not the review itself. The subagent must interpret findings in context (e.g. a `kube-linter` "no-readiness-probe" warning on a Job is expected; on a Deployment it is not).

### 5. Present results

Resolve the review output directory:

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR="reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR="reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header) below) and prepend the rendered block to `${REVIEW_DIR}/INFRASTRUCTURE-REVIEW.md`.

Write the output structured as:
1. Run metadata header
2. Topology overview (from step 2)
3. Findings table (one section per subagent / surface)
4. Tool availability notes (which analyzers were run vs. skipped)
5. Recommended fix order

Present the report to the user.

---

## Run metadata header

Capture once near `REVIEW_DIR` resolution and prepend the rendered block to the output document:

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
GIT_SUBJECT=$(git log -1 --pretty=%s)
# When scope is diff-based, also: BASE_REF=<base>; BASE_COMMIT=$(git rev-parse --short "$BASE_REF")
```

Header template (placed at the top of the output `.md`, before the H1 title):

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Base:** {BASE_REF} @ {BASE_COMMIT}   <!-- omit when scope is not diff-based -->
> **Scope:** {scope description}
```

---

## Finding link wrapping (PR mode)

When the review is scoped to a GitHub PR (`pr_url` is provided by the caller, or, when run standalone, `gh pr view --json url -q .url 2>/dev/null` returns one), wrap every `path:line` reference inside the finding tables below as a Markdown link:

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>
# pr_url set   → [path:line](https://github.com/.../pull/N/files#diff-<hash>R<line>)
# pr_url empty → path:line   (plain text, unchanged)
```

The display text stays `path:line` so plain and linked tables look identical; only the URL goes in the link target. Pass `L` as the fourth argument for findings about removed code (default is `R`). Omit `<line>` for file-level findings to get a file-anchor link. Apply the same wrapping to `path:line` references inside the Tracked column. Findings follow `terse-comments`: concrete fix, optional `bug:`/`risk:`/`nit:`/`unsure:` prefix, no praise or restating the diff.

---

## Output Templates

### Infrastructure findings

```markdown
| Priority | Surface | Finding | Impact | Effort | Tracked |
|----------|---------|---------|--------|--------|---------|
| P0 | k8s | Description with code references | Impact on availability / security / cost | trivial / small / moderate / large | — |
| P1 | terraform | Description with code references | Impact description | Effort estimate | FIXME in file:line |
```

**Surface column values:** `terraform`, `k8s`, `dockerfile`, `helm`, `gateway`, `mesh`.

**Tracked column values:** Use `—` for new findings. For already-captured findings: `TODO in file:line`, `FIXME in file:line`, `README`, `#123` (issue reference), etc.

### Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Brief explanation of the fix |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- Search the organization's codebase (Sourcegraph, GitHub) for existing module / chart / manifest patterns before recommending new ones.
- Include effort estimates to help prioritize implementation.
- When the user asks for a follow-up review, find the most recent review directory (`ls -d reviews/*/ 2>/dev/null | sort | tail -1`) containing `INFRASTRUCTURE-REVIEW.md`, re-evaluate all prior findings, and append the re-evaluation table.
- For detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (Infrastructure section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
