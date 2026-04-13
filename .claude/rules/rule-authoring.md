---
paths:
  - "rules/**/*.md"
---

# rule-authoring

Rules for editing rules in this repository.

- Use `/create-rule` when creating new rules — do not write rule files from scratch.
- **One topic per file** with a descriptive filename (`testing.md`, `api-design.md`).
- **Under 200 lines** — longer files reduce adherence; split if growing large.
- **Specific and verifiable**: "Use 2-space indentation" not "format code nicely".
- Use `IMPORTANT` / `YOU MUST` emphasis for rules that are frequently violated.
- Check existing rules for contradictions before adding new ones.
- Path-scope rules to relevant file types — don't always-load a language-specific rule.
- **No company-specific references.** Rules must be portable. Org-specific context belongs in project-level CLAUDE.md or REVIEW.md, not in shared rules.
