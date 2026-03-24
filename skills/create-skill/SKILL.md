---
name: create-skill
description: Use when creating, writing, or authoring a new Cursor agent skill, or when asking about skill structure, SKILL.md format, or skill best practices.
---

# Create Skill

## Skill Types

Categorize before writing -- this determines structure, degrees of freedom, and testing approach:

- **Technique**: concrete method with steps (e.g. condition-based-waiting)
- **Pattern**: mental model / way of thinking (e.g. flatten-with-flags)
- **Reference**: API docs, syntax guides, tool documentation
- **Workflow**: multi-step process with decision points (e.g. ship-it)

## Requirements Gathering

Infer from conversation context when possible. If clarification is needed, use AskQuestion (or ask conversationally if unavailable). Capture:

1. **Purpose and scope**: what specific task or workflow
2. **Storage location**: personal (`~/.cursor/skills/`) or project (`.cursor/skills/`)
3. **Trigger scenarios**: when should the agent apply this skill
4. **Domain knowledge**: what the agent wouldn't already know
5. **Output format**: templates, styles, or conventions required
6. **Existing patterns**: examples or conventions to follow

## Design

### Name

- Lowercase letters, numbers, hyphens only. Max 64 chars
- Prefer verb-first or gerund form: `create-skill` > `skill-creation`, `analyze-sessions` > `session-analysis`
- Name by what you DO or core insight, not generic labels
- Avoid: `helper`, `utils`, `tools`, `misc`

### Description (CSO-Critical)

The description determines whether the agent loads this skill. Max 1024 chars, third person.

**Start with "Use when..."** -- describe ONLY triggering conditions (symptoms, situations, contexts).

**NEVER summarize the skill's workflow or process.** Testing shows agents follow descriptions as shortcuts, skipping the full skill body. A description saying "does X then Y" causes agents to do exactly X then Y without reading the actual detailed instructions.

Include concrete triggers: error messages, symptoms, tool names, synonyms.

```yaml
# BAD: workflow summary -- agent will shortcut to this
description: Analyzes code diffs, generates commit messages, and pushes to remote.

# BAD: too vague
description: Helps with documents.

# GOOD: triggering conditions only
description: Use when reviewing pull requests, examining code changes, or when asked for a code review.

# GOOD: specific triggers with keywords
description: Use when tests have race conditions, timing dependencies, or pass/fail inconsistently.
```

### Directory Layout

```
skill-name/
├── SKILL.md              # Required -- main instructions
├── reference.md          # Optional -- detailed docs (progressive disclosure)
└── scripts/              # Optional -- utility scripts
    └── validate.py
```

## Authoring Principles

### Conciseness

The context window is shared. Only add what the agent doesn't already know. Challenge each paragraph: "Does this justify its token cost?"

```markdown
# GOOD (~50 tokens): assumes agent knows what PDFs are
## Extract PDF text
Use pdfplumber:
  import pdfplumber
  with pdfplumber.open("file.pdf") as pdf:
      text = pdf.pages[0].extract_text()

# BAD (~150 tokens): explains what a PDF is
PDF (Portable Document Format) files are a common file format...
```

### Progressive Disclosure

Keep SKILL.md under 500 lines. Put detailed reference material in separate files the agent reads only when needed. Keep references **one level deep** from SKILL.md -- deeply nested references may be partially read.

```markdown
## Advanced features
**Form filling**: See [FORMS.md](FORMS.md) for complete guide
**API reference**: See [REFERENCE.md](REFERENCE.md) for all methods
```

For reference files over 100 lines, include a table of contents at the top.

### Degrees of Freedom

Match specificity to task fragility:

- **High freedom** (text instructions): multiple valid approaches, context-dependent. Example: code review guidelines
- **Medium freedom** (pseudocode/templates): preferred pattern with acceptable variation. Example: report generation
- **Low freedom** (exact scripts): fragile operations, consistency critical. Example: database migrations -- "Run exactly this. Do not modify."

### Token Efficiency

- Move details to `--help` flags or reference files
- Cross-reference other skills instead of repeating content
- One excellent example beats many mediocre ones
- Compress examples: show minimal input/output, not verbose narratives

## Common Patterns

Brief summary below. See [best-practices.md](best-practices.md) for detailed examples with good/bad comparisons.

- **Template**: provide output format templates (strict for APIs, flexible for analysis)
- **Examples**: input/output pairs showing desired style and detail level
- **Workflow/Checklist**: sequential steps with copy-paste progress checklist
- **Conditional workflow**: decision points guiding to different paths
- **Feedback loop**: validate → fix → re-validate cycle for quality-critical tasks

## Script Guidelines

When including utility scripts:

- **Solve, don't punt**: handle errors explicitly instead of failing and letting the agent figure it out
- **Self-documenting constants**: no magic numbers -- comment why each value was chosen
- **Clear intent**: state whether the agent should **execute** the script ("Run `analyze.py`") or **read** it as reference ("See `analyze.py` for the algorithm")
- Pre-made scripts are more reliable than generated code, save tokens, and ensure consistency

## MCP Tool References

Always use fully qualified names: `ServerName:tool_name`

```markdown
Use the GitHub:create_issue tool to create issues.
Use the Atlassian:getJiraIssueTypeMetaWithFields tool to discover custom fields.
```

## External Content and Licensing

When incorporating content from web sources or OSS into a skill:

- **Inline the content** -- skills should be self-contained with no runtime web lookups
- **Always cite the source URL** even when content is fully inlined
- **Comply with licensing terms**: MIT/Apache/etc. require copyright notice preserved
- Include a **Sources** section in the skill with attribution and license type
- For OSS: link to the repo/file, note the license, credit the author(s)
- For web content (docs, blog posts): link to the source URL for reference

## Testing and Validation

Skills are TDD applied to process documentation. If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.

### RED -- Baseline

Run a representative scenario WITHOUT the skill. Document:
- What choices did the agent make?
- What rationalizations did it use (verbatim)?
- Which pressures triggered violations?

### GREEN -- Write Minimal Skill

Write the skill addressing those specific failures. Run the same scenario WITH the skill. The agent should now comply.

### REFACTOR -- Close Loopholes

Agent found a new rationalization? Add an explicit counter. Re-test until the skill is robust.

### Testing by Skill Type

- **Discipline-enforcing** (rules/requirements): pressure scenarios combining time + sunk cost + exhaustion
- **Technique** (how-to guides): application scenarios + edge cases + missing-information tests
- **Pattern** (mental models): recognition scenarios + counter-examples (when NOT to apply)
- **Reference** (documentation): retrieval scenarios + application scenarios + gap testing

### Bulletproofing Discipline Skills

For skills that enforce rules, agents will rationalize under pressure:

- Don't just state the rule -- forbid specific workarounds
- Build a rationalization table: `| Excuse | Reality |`
- Create a red flags list for self-checking
- Address "spirit vs letter" arguments: "Violating the letter of the rules IS violating the spirit"

## Verification Checklist

Before finalizing:

- [ ] Description starts with "Use when..." -- triggering conditions only, no workflow summary
- [ ] SKILL.md body is under 500 lines
- [ ] Consistent terminology throughout (pick one term, use it everywhere)
- [ ] File references are one level deep from SKILL.md
- [ ] No time-sensitive information (use "old patterns" section if needed)
- [ ] Examples are concrete, not abstract
- [ ] Tested with a representative scenario (baseline → with skill)
- [ ] External content is inlined with source attribution

## Anti-Patterns

- **Narrative storytelling**: "In session 2025-10-03, we found..." -- too specific, not reusable
- **Multi-language dilution**: one excellent example in the most relevant language beats mediocre examples in five languages
- **Workflow summary in description**: causes agents to shortcut past the actual skill body
- **Generic labels**: helper1, step3, pattern4 -- labels should have semantic meaning
- **Windows-style paths**: always use forward slashes (`scripts/helper.py`)
- **Too many options**: provide a default with an escape hatch, not a menu of five libraries
- **Vague names**: `helper`, `utils`, `tools` -- name by what the skill does
- **Inconsistent terminology**: pick one term (e.g. always "API endpoint", not mixing "URL", "route", "path")

---

## Sources

Content in this skill and [best-practices.md](best-practices.md) incorporates material from:

- [Anthropic: Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [obra/superpowers: writing-skills](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md) -- used under [MIT License](https://github.com/obra/superpowers/blob/main/LICENSE), copyright Jesse Vincent
