---
name: review-authoring
description: Use when the user asks to review skills, agent definitions, rules, slash commands, hooks, MCP server config, or plugin manifests, asks whether a hook or skill is safe, asks about over-broad tool grants or prompt injection in agent instructions, or when another skill dispatches an authoring review.
---

# Agent Authoring Review

Safety review of files that configure or instruct a coding agent: skills, subagents, rules, commands, hooks, settings, MCP config, plugin manifests, and agent instruction files. These files execute code or steer a model with the user's privileges, so a defect here is a code-execution or excessive-agency defect, not a style nit.

**Out of scope** (defer to siblings):
- Application source code → `review-code` / `review-security`
- CI workflows → `review-ci`
- Prose clarity of instructions → `simplify-prose`
- Style conventions → the target repo's own `.claude/rules/skill-authoring.md` / `rule-authoring.md` when present. Cite the rule by path; do not restate it.

## In-scope files

```
**/SKILL.md                     **/.claude/settings*.json
**/.claude/agents/**            **/hooks.json   **/hooks/hooks.json
**/agents/*.md                  **/.mcp.json
**/.claude/rules/**             **/.claude-plugin/plugin.json
**/rules/*.md                   **/.claude-plugin/marketplace.json
**/.claude/commands/**          **/AGENTS.md
**/commands/*.md                **/CLAUDE.md
```

Also in scope: any script a hook, skill, or command invokes (follow the path from the config), since the config's safety depends on it.

## Workflow

### 1. Resolve scope

- **Changed files (PR or branch):** `git diff --name-only --diff-filter=d <base>...HEAD` (default `<base>` is `main`), or `gh pr diff <number> --name-only`. Filter to the globs above.
- **Explicit paths:** expand directories, then filter to the globs above.
- **Full repo:** walk for the globs above (default).
- **If invoked from review-all:** receive `file_list`, `has_changes`, `base_ref`, `REVIEW_DIR`, and `pr_url`. Skip scope confirmation.

The resolved list is the scope. Every in-scope file gets reviewed and a `COVERAGE` row, including files the user did not name.

### 2. Inventory

Classify each file by type (hook config, subagent, command, skill, rule, settings, MCP, plugin manifest, instruction file). Note the trust context: project-shared (committed, runs for every contributor) vs. user-local (`settings.local.json`, `~/.claude/`). Project-shared defects are one severity higher.

### 3. Review

With more than ~10 in-scope files, launch one investigation subagent (`subagent_type="generalPurpose"`, `model: sonnet` per `subagent-model-routing`) with the file list, inventory, and [reference.md](reference.md). Otherwise review inline.

For each file:
- Apply **every** check for its type in [reference.md](reference.md), plus the **All files** checks. The per-type checks are mandatory, not a menu.
- Follow referenced scripts and paths. A hook entry that runs `./scripts/guard.sh` is reviewed together with `guard.sh`.
- Read each cited line before raising a finding; drop what you cannot verify.

Run validators when available; record each one's result under **Tool availability**:

```sh
jq empty <file.json>                                  # every JSON config parses
command -v shellcheck >/dev/null && shellcheck <hook-scripts>
command -v gitleaks  >/dev/null && gitleaks detect --no-git --source <dir> --report-format json --report-path -
command -v claude    >/dev/null && claude plugin validate <plugin-dir>   # plugin dirs only
```

If `gitleaks` is unavailable, grep in-scope files for token shapes (`AKIA`, `ghp_`, `gho_`, `xox[bp]-`, `sk-`, `-----BEGIN`, `Bearer `, `password\s*[:=]`) and note the fallback.

### 4. Present results

Resolve the output directory (skip if `REVIEW_DIR` was provided):

```sh
REVIEW_DATE=$(date +%Y-%m-%d)
REVIEW_DIR=".reviews/${REVIEW_DATE}"
if [ -d "$REVIEW_DIR" ]; then REVIEW_DIR=".reviews/${REVIEW_DATE}-$(date +%H%M)"; fi
~/.claude/scripts/ensure-gitignore.sh '.reviews/'
mkdir -p "$REVIEW_DIR"
```

Write `${REVIEW_DIR}/AUTHORING-REVIEW.md`:
1. Run metadata header (same block as `review-ci`: run time, branch @ commit, subject, base, scope)
2. Inventory (from step 2)
3. Findings, ordered by severity
4. Coverage rows
5. Not checked
6. Tool availability

Present the report to the user.

## Output format

Each finding starts with its header line, then one line of defect + fix:

```
FINDING | rule_id=CWE-78 | sev=P0 | blocking=y | conf=high | dkey=.claude/settings.json:14:CWE-78
[.claude/settings.json:14] — PreToolUse hook interpolates `tool_input.command` unquoted into `sh -c`. Read stdin with `jq -r`, quote the variable, reject on parse failure.
```

After all findings, one row per in-scope file:

```
COVERAGE | file=.claude/settings.json | status=read-fully
COVERAGE | file=skills/deploy/SKILL.md | status=read-fully
```

Header fields, `rule_id` conventions, and blocking defaults follow [review-all reference-tracking.md § Finding header](../review-all/reference-tracking.md#finding-header). Use the `rule_id` given per check in [reference.md](reference.md). A missing header or coverage row is a reviewer defect: list the file under **Not checked**, never as clean.

In PR mode (`pr_url` set), wrap each `path:line` with `~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>`. Findings follow `terse-comments`.

### Severity

| Sev | Meaning | Examples |
|---|---|---|
| P0 | Code execution, secret exposure, or permission bypass reachable without further mistakes | Literal token in `.mcp.json`; `curl … \| sh` in a SessionStart hook; unquoted tool input in a hook command; `defaultMode: bypassPermissions` in committed settings |
| P1 | Excessive agency or a guard that silently does not guard | Side-effecting skill without `disable-model-invocation: true`; subagent with omitted `tools` (inherits all); blocking hook that exits 1 instead of 2; untrusted content treated as instructions; unpinned `npx -y` MCP server |
| P2 | Missing validation or hygiene that raises risk | Hook that does not validate stdin JSON; invalid matcher that never fires on a non-guard hook; plugin component path that does not exist |
| P3 | Cost or clarity | Model unset where cost matters; style violation of the target repo's authoring rule |

## Rationalization table

| Excuse | Reality |
|---|---|
| "The other files are outside the files the user asked about." | Scope is every in-scope glob in the resolved file list. Named files set the focus, not the boundary. Unreviewed files get `not-read` coverage rows and a **Not checked** entry. |
| "I caught the obvious defects, so the review is done." | The per-type checks in reference.md are mandatory. Hook exit-code semantics, `disable-model-invocation`, and the secrets sweep are the ones most often skipped. |
| "CLAUDE.md and AGENTS.md are prose, not config." | They load into every session. Secrets, internal URLs, and injected instructions there reach the model on every run. Sweep them. |
| "The hook exits non-zero on failure, so it blocks." | Only exit code 2 blocks, and only its stderr reaches the model. Exit 1 is a non-blocking error; the tool call proceeds. |
| "`tools` is not set, so the agent gets defaults." | Omitted `tools` inherits every tool, including MCP tools. That is the broadest grant, not a safe default. |
| "The skill only runs when the user asks." | Without `disable-model-invocation: true` the model can invoke it on its own when the description matches. |
| "It's a well-known MCP package." | `npx -y pkg` fetches whatever is latest at session start. Known name, unknown code. |

## Red flags

Stop and re-check coverage if you are about to:
- Write "Not flagged … outside the requested files."
- Finish with fewer `COVERAGE` rows than in-scope files.
- Pass a hook config without reading the script it runs.
- Pass a skill or command that deploys, posts, pushes, or deletes without checking its frontmatter.
- Skip CLAUDE.md / AGENTS.md because they "look like docs."
- Restate the target repo's style rules instead of citing them.

## Guidelines

- **REVIEW.md integration:** if a `REVIEW.md` context section was provided by review-all (or exists at the repo root when standalone), treat its rules as additional criteria. "Always check" items are P1; domain items are P2. "Skip" patterns exclude matching files.
- For follow-up reviews, find the latest `.reviews/*/AUTHORING-REVIEW.md`, re-evaluate prior findings, and append a FIXED / Still applicable table.
- Findings must cite probed evidence (`path:line`, command output). Per `~/.claude/rules/probe-not-assume.md`.

## Tool availability

Report each validator as `ran`, `skipped (not installed)`, or `failed (<reason>)`. A skipped secrets scanner means the grep fallback ran; say so.

## Sources

See [reference.md § Sources](reference.md#sources).
