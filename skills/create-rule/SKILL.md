---
name: create-rule
description: Use when creating, writing, or updating a Claude Code rule file (.claude/rules/*.md or ~/.claude/rules/*.md), or when asking about rule format, path scoping, or rule best practices.
---

# Create Rule

## Rules vs CLAUDE.md vs Skills

Choose the right mechanism before writing anything:

| Mechanism | When to use | Loads |
|---|---|---|
| **Rule** | Behavioral instructions scoped to a topic or file type | Every session (or on path match) |
| **CLAUDE.md** | Broad project context: build commands, architecture, workflows | Every session |
| **Skill** | Repeatable on-demand workflows | Only when invoked |

If the instruction only makes sense for certain file types (e.g. Go, test files), use a path-scoped rule. If it's a repeatable task workflow, use a skill instead.

## Storage Locations

| Scope | Path |
|---|---|
| Personal, all projects on this machine | `~/.claude/rules/<topic>.md` |
| Project, shared with team via git | `.claude/rules/<topic>.md` |

Rules in subdirectories are discovered recursively (e.g. `.claude/rules/frontend/react.md` works).

## Rule File Format

```markdown
---
paths:            # optional; omit for always-load
  - "**/*.go"
  - "**/*_test.go"
---

# rule-name

Instructions...
```

No `paths` frontmatter → rule loads every session.
`paths` present → rule loads only when Claude opens a matching file.

## Path Scoping Decision

Use **always-load** (no frontmatter) for:
- Universal behaviors: commit style, escalation policy, output verbosity
- Toolchain choices: task runner, package manager, CI tooling

Use **path-scoped** for:
- Language conventions: `**/*.go`, `**/*.ts`, `**/*.py`
- Test files: `**/*_test.go`, `**/*.test.ts`, `**/*.spec.ts`
- Domain directories: `src/api/**/*`, `e2e/**/*.go`, `migrations/**/*.sql`

See [references/rule-patterns.md](references/rule-patterns.md) for glob pattern examples.

## Writing Effective Rules

- **Specific and verifiable**: "Use 2-space indentation" not "format code nicely"
- **One topic per file** with a descriptive filename (`testing.md`, `api-design.md`)
- **Under 200 lines**. Longer files reduce adherence; split if growing large
- **Markdown structure**: use headers and bullets, not dense paragraphs
- **No contradictions** across rule files; audit when adding new ones
- **IMPORTANT** / **YOU MUST** emphasis for rules that are frequently violated

## Workflow

1. **New or update?** Check existing rules in the target directory for overlap
2. **Scope**: personal (`~/.claude/rules/`) or project (`.claude/rules/`)?
3. **Path scope**: universal (no frontmatter) or file-type specific?
4. **Check for conflicts**: scan existing rules for contradictions or duplication
5. **Write the file**: concrete, verifiable instructions; one topic
6. **Verify**: confirm file is under 200 lines and uses specific language

## Authoring Checklist

- [ ] Description starts with "Use when..." if this is actually a skill (wrong tool if so)
- [ ] Topic is focused: one concern per file
- [ ] Path scope matches actual applicability (don't always-load a Go-only rule)
- [ ] Instructions are concrete and verifiable, not vague
- [ ] No contradictions with existing rules in the same directory
- [ ] File is under 200 lines

## Anti-Patterns

- **Vague rules**: "write clean code", "be consistent". Not actionable
- **Duplicating defaults**: don't document what Claude already does correctly
- **Over-specifying**: bloated rule files cause Claude to ignore them
- **Wrong scope**: file-type-specific rules (Go, SQL) in always-load waste context
- **Contradictions**: two rules giving conflicting guidance on the same behavior
- **Workflow steps in rules**: if it's a multi-step process, use a skill instead

## Additional Resources

- Full glob pattern examples and good/bad rule samples: [references/rule-patterns.md](references/rule-patterns.md)
- Official docs: https://code.claude.com/docs/en/memory#organize-rules-with-clauderules
