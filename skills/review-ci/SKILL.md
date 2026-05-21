---
name: review-ci
description: Use when the user asks for a CI review, CI/CD review, GitHub Actions review, workflow review, pipeline review, build pipeline audit, "review the workflows", "review the actions", action pinning audit, workflow permissions audit, or supply-chain review of CI configuration.
---

# CI / Workflow Review

Structured review of CI/CD pipeline configuration. Focus is on **GitHub Actions** (the dominant case); CircleCI / Buildkite / GitLab / Jenkins are noted where they share concerns but receive lighter coverage.

**Out of scope** (defer to siblings):
- Application source code → `review-code`
- Container images and Dockerfiles → `review-infrastructure`
- Application-level secrets and IAM → `review-security`

## Workflow

### 1. Scope and explore

- Confirm scope with the user: full repo CI config, specific workflow(s), or changed files only (PR or branch diff).
- **Resolve scope to a file list.** Based on what the user requested:
  - **Changed files (PR or branch):** Run `git diff --name-only --diff-filter=d <base>...HEAD`. If the user references a PR number, use `gh pr diff <number> --name-only` instead. Filter to CI file types (see classification below).
  - **Explicit paths:** Include all CI files under given directories.
  - **Full repo:** Walk for CI files (default).
- **If invoked from review-all**: receive `file_list`, `has_changes`, `base_ref`, `REVIEW_DIR`, and `pr_url` from the orchestrator. Skip your own scope confirmation.

**File classification.** Detect by path and content:
- **GitHub Actions workflows**: `.github/workflows/*.yml`, `.github/workflows/*.yaml`
- **Composite / reusable actions**: `action.yml` or `action.yaml` files (any location, but typically `.github/actions/*/action.yml`)
- **Dependabot / Renovate config**: `.github/dependabot.yml`, `renovate.json`, `.renovaterc*`
- **CircleCI**: `.circleci/config.yml`
- **Buildkite**: `.buildkite/pipeline.yml`, `.buildkite/*.yml`
- **GitLab CI**: `.gitlab-ci.yml`
- **Jenkins**: `Jenkinsfile`
- **Other**: `azure-pipelines.yml`, `cloudbuild.yaml`, `bitbucket-pipelines.yml`, `wercker.yml`

### 2. System overview

Produce a brief pipeline summary covering:
- Triggers in use: `push`, `pull_request`, `pull_request_target`, `workflow_dispatch`, `schedule`, `workflow_call`, `release`
- Branches / paths gated
- Reusable workflows or composite actions referenced
- Self-hosted vs. GitHub-hosted runners
- Secrets / OIDC providers in use (named, not values)
- Deploy targets (if discernible)

### 3. Launch investigation subagent

Launch a single investigation subagent (`subagent_type="generalPurpose"`, `model: sonnet` per `subagent-model-routing`) with the system overview and in-scope file list.

Prompt it to:
- Read only the in-scope files.
- Apply the GitHub Actions checklist in [reference.md](reference.md); for non-GHA platforms, apply the **cross-platform** subset.
- Run the static analyzers below when available.
- For each finding, search nearby files (workflow comments, `README.md`, in-repo runbooks) for existing tracking.
- Return findings using the **CI findings** template.

### 4. Run static analyzers

```sh
# GitHub Actions — syntax + best-practice lint
command -v actionlint >/dev/null && actionlint <files>

# GitHub Actions — supply-chain / security focused
command -v zizmor    >/dev/null && zizmor --format plain <files>

# Generic YAML hygiene (any platform)
command -v yamllint  >/dev/null && yamllint -f parsable <files>
```

Tool output is **input** to the review. The subagent must triage: `actionlint` `shellcheck` warnings inside `run:` blocks are real; some structural warnings are noisy and need filtering.

### 5. Present results

Resolve the review output directory (same pattern as siblings):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header)) and prepend the rendered block to `${REVIEW_DIR}/CI-REVIEW.md`.

Output structure:
1. Run metadata header
2. Pipeline overview (from step 2)
3. Findings table
4. Tool availability notes
5. Recommended fix order

Present the report to the user.

---

## Run metadata header

Capture once near `REVIEW_DIR` resolution and prepend to the output document:

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
GIT_SUBJECT=$(git log -1 --pretty=%s)
# When scope is diff-based, also: BASE_REF=<base>; BASE_COMMIT=$(git rev-parse --short "$BASE_REF")
```

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Base:** {BASE_REF} @ {BASE_COMMIT}   <!-- omit when scope is not diff-based -->
> **Scope:** {scope description}
```

---

## Finding link wrapping (PR mode)

When `pr_url` is set (or `gh pr view --json url -q .url 2>/dev/null` returns one for standalone runs), wrap every `path:line` reference inside the finding tables as a Markdown link:

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>
```

The display text stays `path:line`. Pass `L` as the fourth argument for findings about removed code (default `R`). Findings follow `terse-comments`: concrete fix, optional `bug:`/`risk:`/`nit:`/`unsure:` prefix.

---

## Output Templates

### CI findings

```markdown
| Priority | Workflow | Finding | Impact | Effort | Tracked |
|----------|----------|---------|--------|--------|---------|
| P0 | release.yml | Description with code references | Impact (supply chain / security / reliability) | trivial / small / moderate / large | — |
| P1 | ci.yml | Description with code references | Impact description | Effort estimate | #123 |
```

**Workflow column values:** filename relative to `.github/workflows/`, or `action.yml`, `dependabot.yml`, etc.

### Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | FIXED | Brief explanation of the fix |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- Search the organization's codebase (Sourcegraph, GitHub) for existing reusable workflows and centralized composite actions before recommending custom ones.
- Treat any third-party action that is not pinned by full commit SHA as a P0 supply-chain risk unless the action is from a vendored trust list (e.g. `actions/*`, `github/*`).
- Include effort estimates.
- When the user asks for a follow-up review, find the most recent review directory and append the re-evaluation table.
- For detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (CI section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`.
