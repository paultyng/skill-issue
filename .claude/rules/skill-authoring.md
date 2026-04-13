---
paths:
  - "skills/**/*.md"
---

# skill-authoring

Rules for editing skills in this repository.

## Structure

- **SKILL.md under 500 lines.** Move details to reference files.
- **Reference files one level deep** from SKILL.md (e.g., `reference.md`, not `refs/sub/detail.md`).
- **Reference files over 100 lines** must have a table of contents at the top.
- Use `/create-skill` when creating new skills — do not write SKILL.md from scratch.

## Naming

- Skill directories: lowercase letters, numbers, hyphens. Max 64 chars.
- **Verb-first or gerund**: `discover-patterns` not `pattern-discovery`, `review-code` not `code-review`.
- No generic names: `helper`, `utils`, `tools`, `misc`.

## Description (CSO-Critical)

- **MUST start with "Use when..."** — triggering conditions only.
- **NEVER summarize the workflow.** Agents shortcut to the description, skipping the body.
- Max 1024 chars, third person.

## Conciseness

- The context window is shared. Challenge each paragraph: "Does this justify its token cost?"
- Only include what the agent doesn't already know. Assume domain competence.
- One excellent example beats many mediocre ones.
- Compress examples: minimal input/output, not verbose narratives.
- No narrative storytelling ("In session 2025-10-03, we found...").

## Content Restrictions

- **No company-specific documentation, tooling, or internal references.** Skills must be portable across any codebase. Reference generic patterns (e.g., "CI pipeline" not "our Jenkins setup").
- **No proprietary tool names, internal URLs, or org-specific workflows.** If a skill needs org-specific context, it should read it from REVIEW.md, CLAUDE.md, or `.claude/rules/` at runtime.
- **No third-party dependencies** in scripts — keep skills self-contained.

## MCP Tool References

Always use fully qualified names: `ServerName:tool_name`.
