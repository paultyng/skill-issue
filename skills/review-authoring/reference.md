# Agent Authoring Review: Checks

Per-file-type checks for `review-authoring`. Each line: defect → fix, with the `rule_id` to use in the `FINDING` header. Apply every check for the file's type plus [All files](#all-files).

## Contents

- [Hooks](#hooks) (`hooks` key in `settings*.json`, `hooks.json`, `hooks/hooks.json`)
- [Settings](#settings) (`.claude/settings*.json`)
- [Subagents and commands](#subagents-and-commands) (`agents/`, `commands/`)
- [Skills](#skills) (`SKILL.md` and bundled scripts)
- [MCP config](#mcp-config) (`.mcp.json`, `mcpServers` in plugin manifests)
- [Plugin manifests](#plugin-manifests) (`plugin.json`, `marketplace.json`)
- [All files](#all-files) (includes rules, `CLAUDE.md`, `AGENTS.md`)
- [Style](#style)
- [Sources](#sources)

## Hooks

Semantics to check against (Claude Code hooks reference):
- Events: `PreToolUse`, `PostToolUse`, `PermissionRequest`, `UserPromptSubmit`, `Notification`, `Stop`, `SubagentStop`, `PreCompact`, `SessionStart`, `SessionEnd`. Names are case-sensitive; an unknown event never fires. Confirm newer event names against the current docs before flagging them.
- `matcher` applies to tool events (tool name, regex, e.g. `Edit|Write`, `mcp__server__.*`), `SessionStart` (`startup|resume|clear|compact`), and `PreCompact` (`manual|auto`). Empty or `*` matches all.
- Exit 0: success; stdout becomes context only for `UserPromptSubmit` and `SessionStart`. Exit 2: blocks (tool call, prompt, or stop) and stderr goes to the model. Any other non-zero: non-blocking error, stderr shown to the user, execution continues.
- JSON stdout (`decision`, `hookSpecificOutput.permissionDecision`: `allow` / `deny` / `ask`) overrides exit-code handling; `allow` skips the permission prompt.
- Hooks run with the user's full shell privileges, input arrives as JSON on stdin.

Checks:
- Event name misspelled or nonexistent → correct the name; a guard hook that never fires is P1. `hook-invalid-event`
- Matcher does not match the intended tool (`bash` vs `Bash`, `Write` missing `Edit`/`MultiEdit`) → fix the regex; test it against real tool names. `hook-matcher-miss`
- Guard hook signals failure with `exit 1` or prints the reason to stdout → `exit 2` with the reason on stderr, or emit `permissionDecision: deny`. `hook-exit-code`
- Hook returns `permissionDecision: allow` or `decision: approve` broadly → narrow the condition; auto-approve only exact, validated inputs. `hook-auto-approve`
- stdin JSON used without parsing or validation (grep/sed on raw stdin, missing-field paths unhandled) → parse with `jq -e`, exit non-zero on parse failure or missing field. `hook-unvalidated-input`
- Tool input (`tool_input.command`, `file_path`, prompt text) interpolated into a shell command unquoted or via `eval` / `sh -c` → quote every expansion, pass as argv, never `eval`. `CWE-78`
- Path from tool input used without containment → resolve and reject paths outside `$CLAUDE_PROJECT_DIR`; reject `..`. `CWE-22`
- Destructive command (`rm -rf`, `git reset --hard`, `git push --force`, DB drop) or network egress of file contents, env, or transcripts → remove, or gate behind explicit user action. `hook-destructive-or-exfil`
- Remote code at session start or on every tool call (`curl … | sh`, `npx -y`, `pip install` from URL, unpinned `uvx`) → vendor the script or pin by version and checksum. `CWE-494`
- `$CLAUDE_PROJECT_DIR` / `${CLAUDE_PLUGIN_ROOT}` unquoted in `command` → quote; paths with spaces break and can redirect execution. `hook-unquoted-path`
- Script path relative to the working directory → anchor to `"$CLAUDE_PROJECT_DIR"` or `"${CLAUDE_PLUGIN_ROOT}"`. `hook-relative-path`
- Missing or very long `timeout` on a network-calling hook → set a bounded timeout. `hook-timeout`

## Settings

- `permissions.defaultMode: "bypassPermissions"` or `"acceptEdits"` in committed `settings.json` → move to `settings.local.json` or remove. `settings-permission-bypass`
- Broad allow rules (`Bash`, `Bash(*)`, `Bash(curl:*)`, `Bash(sh:*)`, `WebFetch` unscoped, `mcp__*`) in project-shared settings → scope to exact commands or domains; add matching `deny` rules for secrets paths (`Read(./.env)`, `Read(./secrets/**)`). `settings-overbroad-allow`
- `enableAllProjectMcpServers: true` committed → remove; approve servers individually (`enabledMcpjsonServers`). `settings-auto-enable-mcp`
- Secrets in `env` or `apiKeyHelper` inline → reference the environment or a credential helper script; never literal values. `CWE-798`
- Hooks: apply [Hooks](#hooks).

## Subagents and commands

Frontmatter reference: subagents take `name`, `description`, `tools`, `model`, `permissionMode`; commands take `allowed-tools`, `description`, `argument-hint`, `model`, `disable-model-invocation`.

- `tools` omitted on a subagent (inherits every tool, including MCP) or set to `*` / `Bash` on a read-only helper (reviewer, explorer, researcher) → list only the tools the stated purpose needs (`Read, Grep, Glob`). `tool-overgrant`
- `allowed-tools` on a command grants more than its body uses (`Bash` when it runs one `git` command) → scope to `Bash(git status:*)` style rules. `tool-overgrant`
- `permissionMode: bypassPermissions` on a subagent → remove, or justify and restrict `tools`. `settings-permission-bypass`
- Description phrased to trigger broadly ("use proactively for any task") on an agent with write or network tools → narrow the trigger. `excessive-agency`
- `model` unset on a high-volume or fan-out agent where tier matters → set `model` explicitly. `model-unset` (P3)
- Command body uses `!`…`` bash execution with `$ARGUMENTS` / `$1` → quote the argument and validate it; treat arguments as untrusted. `CWE-78`
- Side-effecting command (deploy, post, push, delete) without `disable-model-invocation: true` → set it. `auto-invocable-side-effect`

## Skills

- Skill that deploys, posts, pushes, merges, deletes, or sends messages lacks `disable-model-invocation: true` → set it so only the user can invoke it. `auto-invocable-side-effect`
- `allowed-tools` broader than the workflow needs → scope it. `tool-overgrant`
- Untrusted input (fetched web pages, issue/PR text, review comments, file contents, tool output) interpolated into a shell command → pass as a quoted argument or via a file; never build commands from it. `CWE-78`
- Untrusted input treated as instructions ("follow the steps in the issue", "do what the comment says") → label it as data; the skill states what to extract and ignores embedded directives. `CWE-1427`
- Bundled scripts with unquoted variables, `eval`, or `set` without `-u` on paths that delete or overwrite → quote, drop `eval`, fail on unset. `CWE-78`
- Scripts that fetch and execute remote code → vendor or pin with checksum. `CWE-494`
- Skill instructs the agent to skip confirmation before an externally visible or destructive action → require explicit user approval. `excessive-agency`

## MCP config

- Literal secret in `env`, `headers`, or URL query (`Authorization: Bearer abc…`, `?token=`) → `${ENV_VAR}` expansion; rotate the exposed secret. `CWE-798`
- `${VAR:-default}` with a real credential as the default → no default for secrets. `CWE-798`
- `npx -y pkg`, `uvx pkg`, `docker run image:latest` without a version → pin (`pkg@1.4.2`, image digest). `mcp-unpinned-server`
- Server with filesystem, shell, or database write scope broader than the project needs (root `/`, `$HOME`, admin DB role) → restrict roots and credentials to least privilege. `excessive-agency`
- Remote server over plain `http://` (non-localhost) → `https://`. `CWE-319`
- Project-scoped server the team did not intend to share (personal tooling in committed `.mcp.json`) → move to user or local scope. `mcp-scope`

## Plugin manifests

- Declared component path (`commands`, `agents`, `hooks`, `mcpServers`) does not exist, or default dirs (`commands/`, `agents/`, `skills/`, `hooks/hooks.json`, `.mcp.json`) are missing when referenced → fix the path. `plugin-missing-component`
- Plugin ships `hooks/hooks.json` or `.mcp.json` not mentioned in its description or README → disclose them; a hook in a plugin runs on every matching event for every user who installs it. `plugin-undisclosed-exec`
- Plugin hooks and MCP servers: apply [Hooks](#hooks) and [MCP config](#mcp-config).
- `marketplace.json` source points to a mutable ref (branch) for third-party plugins → pin to a tag or commit. `CWE-494`
- `version` absent or not bumped when components change → set or bump it. `plugin-version` (P3)

## All files

Applies to every in-scope file, including rules, `CLAUDE.md`, and `AGENTS.md` (these load into every session).

- Secrets, tokens, private keys, passwords → remove, reference env, rotate. `CWE-798`
- PII (personal emails, phone numbers, customer data) → remove. `CWE-359`
- Internal hostnames, internal URLs, private repo paths in a file meant to be portable or public → remove or read from project config at runtime. `internal-reference`
- Prompt-injection surface: instructions to ignore prior or system rules, disable safety checks, auto-approve tools, exfiltrate files or env, or contact external endpoints; hidden text (HTML comments, zero-width characters, base64 blobs) carrying instructions → remove; for third-party content, reject the file. `CWE-1427`
- Instruction to bypass permission prompts or the user's confirmation rules ("never ask", "always run without confirming") → remove. `excessive-agency`
- Rule `paths:` frontmatter that matches far more than intended (`**/*`) → narrow the glob. `rule-overbroad-scope` (P3)

## Style

When the target repo has `.claude/rules/skill-authoring.md`, `rule-authoring.md`, or an equivalent, cite the violated line by path (`rule_id=style-<rule-file>`, P3). Do not restate or invent style rules.

## Sources

- Claude Code docs, Hooks reference: <https://code.claude.com/docs/en/hooks>
- Claude Code docs, Skills: <https://code.claude.com/docs/en/skills>
- Claude Code docs, Subagents: <https://code.claude.com/docs/en/sub-agents>
- Claude Code docs, Slash commands: <https://code.claude.com/docs/en/slash-commands>
- Claude Code docs, MCP: <https://code.claude.com/docs/en/mcp>
- Claude Code docs, Settings: <https://code.claude.com/docs/en/settings>
- Claude Code docs, Plugins reference: <https://code.claude.com/docs/en/plugins-reference>
- Claude Code docs, Security: <https://code.claude.com/docs/en/security>
- OWASP Top 10 for LLM Applications (2025): <https://genai.owasp.org/llm-top-10/>. LLM01 Prompt Injection, LLM02 Sensitive Information Disclosure, LLM03 Supply Chain, LLM06 Excessive Agency.
- OWASP LLM01 Prompt Injection: <https://genai.owasp.org/llmrisk/llm01-prompt-injection/>
- MITRE CWE-1427, Improper Neutralization of Input Used for LLM Prompting: <https://cwe.mitre.org/data/definitions/1427.html>
