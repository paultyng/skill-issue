# CI / Workflow Review: Framework Reference

Detailed checklists for CI / pipeline review. SKILL.md references this file.

Reference sources:
- [GitHub Actions: Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GitHub Actions: Security hardening for self-hosted runners](https://docs.github.com/en/actions/security-guides/security-hardening-for-self-hosted-runners)
- [OpenSSF Scorecard: Pinned-Dependencies / Token-Permissions](https://github.com/ossf/scorecard/blob/main/docs/checks.md)
- [SLSA: Supply-chain Levels for Software Artifacts](https://slsa.dev/)
- [zizmor: GitHub Actions static analysis](https://woodruffw.github.io/zizmor/)
- [actionlint: GitHub Actions linter](https://github.com/rhysd/actionlint)

## Table of contents

- [GitHub Actions: triggers](#github-actions-triggers)
- [GitHub Actions: permissions and tokens](#github-actions-permissions-and-tokens)
- [GitHub Actions: action pinning and supply chain](#github-actions-action-pinning-and-supply-chain)
- [GitHub Actions: secrets and credentials](#github-actions-secrets-and-credentials)
- [GitHub Actions: runners](#github-actions-runners)
- [GitHub Actions: caching](#github-actions-caching)
- [GitHub Actions: matrices, concurrency, and idempotency](#github-actions-matrices-concurrency-and-idempotency)
- [GitHub Actions: composite and reusable workflows](#github-actions-composite-and-reusable-workflows)
- [GitHub Actions: shell hygiene inside `run:` blocks](#github-actions-shell-hygiene-inside-run-blocks)
- [Dependabot / Renovate](#dependabot--renovate)
- [Cross-platform (CircleCI, Buildkite, GitLab, Jenkins)](#cross-platform-circleci-buildkite-gitlab-jenkins)

## GitHub Actions: triggers

**Trigger choice is a security control.** The most dangerous default in GitHub Actions is `pull_request_target` because the workflow runs with **write** access to repo secrets and contents on a `pull_request` event — including from forks.

- `pull_request` is the default for PR validation. Runs in the fork's read-only context. Use this unless you specifically need write access.
- `pull_request_target` should be reserved for workflows that genuinely need write access (labelling, comment posting). When used:
  - **Do not** check out the PR's code (`actions/checkout` with the PR ref) and then run it. That is the canonical script-injection vulnerability ("pwn request").
  - If the workflow must run code from the PR for analysis, isolate the checkout step from any secret-using step (use a separate job with no secrets, or run the analysis in a sandbox).
  - Gate execution on `github.event.pull_request.head.repo.full_name == github.repository` if you only want to allow PRs from the same repo.
- `workflow_run` workflows inherit similar risks; the workflow runs with write access in the context of the parent repo. Validate inputs.
- `schedule` triggers run on the default branch only — code changes to a workflow on a feature branch will not be exercised by the schedule until merged.
- `workflow_dispatch` should validate inputs explicitly; user-supplied inputs are not sanitized.

## GitHub Actions: permissions and tokens

**Token permissions:**
- Workflow-level `permissions:` block is set explicitly. Default to `permissions: read-all` (or `contents: read`) and grant write scopes per-job only where needed.
- Repo-level default is `permissions: read-all` or `restricted` (this is a repo/org setting, but call it out if workflows assume `write-all`).
- `GITHUB_TOKEN` should not be used for cross-repo writes — use a fine-scoped GitHub App or PAT for that, with the credential stored as a secret.

**OIDC over long-lived secrets:**
- Cloud auth (AWS, GCP, Azure) uses OIDC federation (`permissions: id-token: write`) — not long-lived access keys stored as secrets.
- The OIDC trust policy on the cloud side restricts by repo, branch/tag, and environment. Wildcards in trust conditions are a finding.

**Environments:**
- Production deploys gated by an `environment:` with required reviewers and protection rules.
- Environment secrets are scoped to the environment, not the repo. Don't duplicate secrets at repo level when an environment exists.

## GitHub Actions: action pinning and supply chain

**Pinning:**
- Every third-party action reference is pinned by full 40-char commit SHA, with the version recorded as a comment: `uses: foo/bar@<sha>  # v1.2.3`. Tag-only pins (`@v1`, `@main`) are a finding — tags are mutable.
- First-party / vendor actions (`actions/*`, `github/*`) may be pinned by tag if your org explicitly trusts the publisher; record the policy in `CODEOWNERS` or `REVIEW.md`. Default position: pin everything by SHA.
- Renovate / Dependabot updates the SHA-pinned actions with new SHAs; the comment makes review tractable.

**Supply-chain exposure:**
- Self-hosted action references (`uses: ./.github/actions/foo`) read code from the same repo as the workflow — usually safe, but flag when a workflow with high privileges runs an action whose code is editable by ordinary contributors.
- `with:` inputs to external actions should not pass secrets unnecessarily. If only one step needs `${{ secrets.X }}`, scope it there.
- Docker-container actions (`uses: docker://...`) pull mutable images unless the image is digest-pinned (`docker://image@sha256:...`).

## GitHub Actions: secrets and credentials

**Surface area:**
- Secrets used in `if:` conditions or `env:` at workflow level leak into every step's environment. Scope to the step that needs it.
- Secrets passed to third-party actions via `with:` are visible to that action's code. Confirm necessity.
- Secrets are not logged: avoid `echo $TOKEN`, `set -x` in shell steps that consume secrets. GitHub does mask known secrets in logs, but transformations (base64, jq) bypass masking.

**Bootstrapping:**
- Do not store cloud long-lived keys; use OIDC (see above).
- For GHCR / image registry pushes, use `GITHUB_TOKEN` with `packages: write`, not a stored PAT.
- npm publish / PyPI publish: use trusted publishers (OIDC) when supported.

## GitHub Actions: runners

**GitHub-hosted vs self-hosted:**
- Public repos with self-hosted runners are dangerous: anyone can open a PR that runs arbitrary code on your runner. Require runner groups + approval for first-time contributors, or restrict self-hosted runners to private repos only.
- Self-hosted runners are ephemeral (one-shot, per-job) — not long-lived VMs that carry state across runs. Long-lived runners accumulate poisoned state and cached secrets.
- Self-hosted runners are network-isolated from production by default; cross-network access is an explicit decision.

**Runner OS pinning:**
- `runs-on:` uses pinned versions (`ubuntu-22.04`, not `ubuntu-latest`). `latest` rolls forward and can change tool versions unpredictably.

## GitHub Actions: caching

- `actions/cache` `key:` includes enough inputs to invalidate when those inputs change (e.g. `${{ hashFiles('go.sum') }}`). Stale-key restores produce subtly wrong builds.
- Cache scopes are restricted to relevant branches (the default scope behavior was widened in GHA over time; verify against the workflow's intent).
- Do not cache secrets or `~/.npmrc`-style credential files.
- `restore-keys:` fallbacks are explicit and ordered most-specific first.
- Caching tool installs (`actions/setup-go` with cache enabled) is preferred over hand-rolled `actions/cache` for that purpose.

## GitHub Actions: matrices, concurrency, and idempotency

- `fail-fast: false` on matrices that should report all failures (test matrices); `fail-fast: true` (default) on matrices where one failure invalidates the rest.
- `concurrency:` group scoped per workflow + ref to avoid two simultaneous runs of the same PR colliding. `cancel-in-progress: true` for CI; `false` (or unset) for deploys.
- Deploy steps are idempotent — re-running the job should not double-deploy.
- Workflow steps don't depend on prior-run state (no "if this file exists from a previous run...").

## GitHub Actions: composite and reusable workflows

- Reusable workflows (`workflow_call`) pin their callee by SHA when the callee is in a different repo.
- Composite actions (`action.yml` with `runs: using: composite`) live in `.github/actions/<name>/`. Each composite action has a `README.md` documenting inputs and outputs.
- `inputs:` are typed (`type: string|boolean|number`) with `required` and `default` set explicitly.
- Outputs are documented and used by the caller — orphan outputs are dead code.

## GitHub Actions: shell hygiene inside `run:` blocks

- `shell: bash` is set explicitly when the workflow may run on multiple OS images (avoids picking up `sh` on Windows / inconsistent defaults).
- `set -euo pipefail` at the top of multi-line bash blocks. `actionlint` flags missing `set -e`.
- User-controlled context (`${{ github.event.pull_request.title }}`, `${{ github.head_ref }}`) is **never** interpolated directly into shell — that is the GHA injection class. Pass via `env:` and reference `$VAR` inside the script.
- `if: contains(...)` and `if: startsWith(...)` over raw regex on user-controlled context.
- Heredocs and quoting reviewed for shell-injection inside the script body.

## Dependabot / Renovate

- A bot is configured. Manual dependency review at human scale doesn't catch transitive supply-chain attacks.
- For Dependabot: `.github/dependabot.yml` covers all ecosystems in use (`gomod`, `npm`, `pip`, `github-actions`, `docker`, `terraform`).
- For Renovate: `renovate.json` enables `github-actions` and pins to commit SHAs (`extends: ["config:recommended", "helpers:pinGitHubActionDigests"]`).
- Auto-merge of patch versions is acceptable if CI is trustworthy; auto-merge of major versions is not.

## Cross-platform (CircleCI, Buildkite, GitLab, Jenkins)

Most of the GitHub Actions concerns translate; the shape is different. Look for:

**Trigger semantics:**
- Whether the platform exposes a "fork PR" mode that runs with secrets (CircleCI: `Pass secrets to builds from forked pull requests` — should be off for OSS).
- Whether scheduled pipelines run on `main` only.

**Secrets surface:**
- Where secrets are stored (project-scoped, org-scoped, environment-scoped). Project-scoped + many contributors = blast radius.
- Whether secrets are masked in logs.

**Pinning and supply chain:**
- Orbs (CircleCI) pinned by version or SHA, not `volatile` tags.
- `image:` references for Docker executors pinned by digest.
- Plugins (Buildkite, Jenkins) version-pinned.

**Runner hygiene:**
- Self-hosted runners ephemeral; isolated from production unless intentional.
- Build agents tool versions pinned.

**Caching:**
- Cache keys reflect inputs; no credential files cached.

Cross-platform reviews can be lighter than GHA since the supply-chain landscape (action pinning, `pull_request_target`) is GHA-specific. The shell-injection and secret-scope concerns are universal.
