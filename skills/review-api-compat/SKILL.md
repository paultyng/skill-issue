---
name: review-api-compat
description: Use when the user asks for an API compatibility review, breaking change review, proto breaking change review, buf breaking review, OpenAPI compatibility check, gRPC backwards compatibility audit, "are these API changes breaking", "did we break the wire", contract evolution review, or backwards-compatibility audit on an API surface.
---

# API Compatibility Review

Structured review of API contract evolution. Detects breaking changes in protobuf services, OpenAPI specs, and (where applicable) GraphQL schemas; classifies them as wire-breaking, behavior-breaking, or policy-breaking; recommends remediation (deprecate-then-remove, version bump, new field).

**Out of scope** (defer to siblings):
- Internal Go API surface (function signatures, struct fields) — `review-code` covers this through SOLID/coupling lens
- New field validation correctness — `review-code` / `review-security`
- Protobuf style / lint pass-fail (naming, comments, package layout) — `review-code` runs `buf lint`

`review-api-compat` is the **diff-aware** counterpart: same proto/OpenAPI files, but compared against a base ref to catch what *changed*.

## Workflow

### 1. Scope and explore

- Confirm scope with the user: changed files (PR or branch diff — the default), explicit paths to a previous version (e.g. a tag), or full codebase against `main`.
- **Resolve scope.** This skill is fundamentally diff-based:
  - **Default**: `base_ref` is `main` (or the PR base). Compute changed files via `git diff --name-only --diff-filter=d <base>...HEAD`. Filter to API spec files (see below).
  - **PR**: use `gh pr view <num> --json baseRefName -q .baseRefName` for the base, `gh pr diff <num> --name-only` for changed files.
  - **Tag-vs-tag**: user supplies `<from-tag>...<to-tag>`; same diff machinery.
- **If invoked from review-all**: receive `file_list`, `has_changes`, `base_ref`, `REVIEW_DIR`, and `pr_url`. If `has_changes` is false, exit early with status "no API spec changes in scope" — there is nothing to compare.

**File classification:**
- **Protobuf**: `*.proto` files; presence of `buf.yaml` / `buf.gen.yaml` / `buf.lock` confirms a buf workspace.
- **OpenAPI**: `openapi.yml`, `openapi.yaml`, `openapi.json`, `swagger.yml`, `swagger.yaml`, `swagger.json`, files with top-level `openapi:` or `swagger:` keys.
- **GraphQL** (lighter coverage): `*.graphql`, `*.gql`, files with `schema { ... }` or `type Query { ... }`.

### 2. Determine compatibility policy

Detect the project's stance from configuration; ask the user if unclear:
- **Protobuf**: `buf.yaml` `breaking:` block (rule set: `FILE`, `PACKAGE`, `WIRE`, `WIRE_JSON`); `breaking.except:` exclusions; `buf.yaml` modules with versioning (`v1`, `v1beta1`, `v2`).
- **OpenAPI**: SemVer in `info.version`; declared compatibility policy in repo docs (e.g. `API.md`); existing release notes for prior breaks.
- **GraphQL**: deprecation policy; usage of `@deprecated` directive.

Record the resolved policy. Findings are graded against it (a `WIRE` policy allows JSON-but-not-wire breaks; a `WIRE_JSON` policy doesn't).

### 3. Run the breaking-change tools

```sh
# Protobuf — against the base ref (preferred, integrates with buf.yaml policy)
command -v buf >/dev/null && buf breaking --against "$(git rev-parse $base_ref).git#format=git"

# Protobuf — alternative when buf is not configured
command -v protolock >/dev/null && protolock status --lockdir . --uptodate

# OpenAPI — multiple options; pick whichever is on PATH
command -v oasdiff >/dev/null && oasdiff breaking <base-spec> <head-spec>
command -v openapi-diff >/dev/null && openapi-diff <base-spec> <head-spec>

# GraphQL
command -v graphql-inspector >/dev/null && graphql-inspector diff <base-schema> <head-schema>
```

To get the base version of a spec file: `git show $base_ref:<path>` into a temp file, then diff.

Tool output is **input** to the review; the subagent triages and contextualizes.

### 4. Launch investigation subagent

Launch a single investigation subagent (`subagent_type="generalPurpose"`, `model: sonnet` per `subagent-model-routing`) with: resolved policy, tool outputs, and the changed-spec file list.

Prompt it to:
- For each detected change, classify as: **wire-breaking** / **behavior-breaking** / **policy-breaking** / **non-breaking**. See [reference.md](reference.md) for the matrix.
- For each breaking change, recommend remediation: deprecate-then-remove, version bump, new alternative field/method, additive change instead.
- For each non-breaking change, sanity-check that it's truly additive (no enum value reuse, no field number reuse, no required→optional flip in a strict consumer).
- Cite the wire/behavior rule violated.
- Search the repo for any documented intent (`CHANGELOG.md`, `MIGRATION.md`, doc comments) that legitimizes a deliberate break.

### 5. Present results

Resolve the review output directory (same pattern as siblings):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR="reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR="reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
mkdir -p "$REVIEW_DIR"
```

Capture run metadata (see [Run metadata header](#run-metadata-header)) and prepend to `${REVIEW_DIR}/API-COMPAT-REVIEW.md`.

Output structure:
1. Run metadata header
2. Resolved policy (which rule set + exclusions)
3. Findings table (grouped by surface: proto / openapi / graphql)
4. Tool availability notes
5. Recommended remediation order

Present the report to the user.

---

## Run metadata header

```sh
RUN_DATETIME=$(date -u +"%Y-%m-%d %H:%M UTC")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
GIT_SUBJECT=$(git log -1 --pretty=%s)
BASE_REF=<base>; BASE_COMMIT=$(git rev-parse --short "$BASE_REF")
```

```markdown
> **Run:** {RUN_DATETIME}
> **Branch:** {GIT_BRANCH} @ {GIT_COMMIT} (`{GIT_COMMIT_FULL}`)
> **Subject:** {GIT_SUBJECT}
> **Base:** {BASE_REF} @ {BASE_COMMIT}
> **Scope:** {scope description}
> **Policy:** {resolved policy, e.g. buf FILE + WIRE}
```

---

## Finding link wrapping (PR mode)

When `pr_url` is provided (or `gh pr view --json url -q .url 2>/dev/null` returns one for standalone runs), wrap every `path:line` reference inside the finding tables as a Markdown link:

```sh
~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>
```

The display text stays `path:line`. Pass `L` for findings about removed code. Findings follow `terse-comments`: concrete fix, optional `bug:`/`risk:`/`nit:`/`unsure:` prefix.

---

## Output Templates

### API compatibility findings

```markdown
| Priority | Surface | Change | Class | Recommendation | Tracked |
|----------|---------|--------|-------|----------------|---------|
| P0 | proto | `pkg.Service.Method` removed at file:line | wire-breaking | Deprecate first; remove in next major version | — |
| P1 | openapi | `GET /users` response field `name` type changed | behavior-breaking | Add new field, keep old; remove in next major | #123 |
| P2 | proto | New field `created_at` added | non-breaking | OK; document in changelog | — |
```

**Class column values:** `wire-breaking`, `behavior-breaking`, `policy-breaking`, `non-breaking`.

### Re-evaluation table (for follow-up reviews)

```markdown
| Finding | Status | What Changed |
|---------|--------|--------------|
| ~~1. Description~~ | RESOLVED | Reverted; field re-added |
| 2. Description | Still applicable | No changes |
```

---

## Guidelines

- The default position on a wire-breaking change is **block** unless an explicit version bump or migration plan is in the PR.
- A `non-breaking` classification still warrants a changelog entry if the change is user-visible.
- Search the organization's codebase (Sourcegraph, GitHub) for consumers of the changed surface before scoring a break as low-impact. A removed proto field that nobody reads is annoying; one that 200 services read is a P0.
- When the user asks for a follow-up review, find the most recent review directory and append the re-evaluation table.
- For detailed framework categories, see [reference.md](reference.md).
- **REVIEW.md integration**: If a `REVIEW.md` context section was provided by the review-all orchestrator (or exists at the repository root when running standalone), treat its rules as additional review criteria. "Always check" items are HIGH severity; domain-specific items (API compatibility section) are MEDIUM severity. "Skip" patterns exclude matching files from review scope.
