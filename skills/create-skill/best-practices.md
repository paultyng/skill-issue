# Skill Authoring Best Practices -- Detailed Reference

## Contents

- Pattern examples with good/bad comparisons
- Degrees of freedom examples
- Claude Search Optimization (CSO) deep dive
- Evaluation-driven development
- Iterative Claude A/B development
- Bulletproofing discipline skills
- Testing methodology
- Anti-patterns expanded
- File organization patterns

---

## Pattern Examples

### Template Pattern

Provide output format templates. Match strictness to requirements.

**Strict** (for APIs, data formats):

```markdown
## Report structure

ALWAYS use this exact template:

# [Analysis Title]

## Executive summary
[One-paragraph overview of key findings]

## Key findings
- Finding 1 with supporting data
- Finding 2 with supporting data

## Recommendations
1. Specific actionable recommendation
2. Specific actionable recommendation
```

**Flexible** (when adaptation is useful):

```markdown
## Report structure

Sensible default format -- use judgment based on the analysis:

# [Analysis Title]

## Executive summary
[Overview]

## Key findings
[Adapt sections based on what you discover]

Adjust sections as needed for the specific analysis type.
```

### Examples Pattern

Input/output pairs showing desired style and detail:

```markdown
## Commit message format

**Example 1:**
Input: Added user authentication with JWT tokens
Output:
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware

**Example 2:**
Input: Fixed bug where dates displayed incorrectly in reports
Output:
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
```

One excellent example beats many mediocre ones. Choose the most relevant language.

### Workflow/Checklist Pattern

Sequential steps with a copy-paste progress tracker:

```markdown
## Form filling workflow

Copy this checklist and track progress:

Task Progress:
- [ ] Step 1: Analyze the form
- [ ] Step 2: Create field mapping
- [ ] Step 3: Validate mapping
- [ ] Step 4: Fill the form
- [ ] Step 5: Verify output

**Step 1: Analyze the form**
Run: `python scripts/analyze_form.py input.pdf`
This extracts form fields and saves to `fields.json`.

**Step 2: Create field mapping**
Edit `fields.json` to add values for each field.
...
```

### Conditional Workflow Pattern

Guide through decision points:

```markdown
## Document modification

1. Determine the modification type:

   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow:
   - Use docx-js library
   - Build document from scratch
   - Export to .docx format

3. Editing workflow:
   - Unpack existing document
   - Modify XML directly
   - Validate after each change
   - Repack when complete
```

### Feedback Loop Pattern

Validate → fix → re-validate for quality-critical tasks:

```markdown
## Document editing process

1. Make your edits to `word/document.xml`
2. **Validate immediately**: `python scripts/validate.py unpacked_dir/`
3. If validation fails:
   - Review the error message carefully
   - Fix the issues
   - Run validation again
4. **Only proceed when validation passes**
5. Rebuild: `python scripts/pack.py unpacked_dir/ output.docx`
```

---

## Degrees of Freedom Examples

### High Freedom (text-based instructions)

Use when multiple approaches are valid and decisions depend on context:

```markdown
## Code review process

1. Analyze the code structure and organization
2. Check for potential bugs or edge cases
3. Suggest improvements for readability and maintainability
4. Verify adherence to project conventions
```

### Medium Freedom (pseudocode with parameters)

Use when a preferred pattern exists but some variation is acceptable:

```python
def generate_report(data, format="markdown", include_charts=True):
    # Process data
    # Generate output in specified format
    # Optionally include visualizations
```

### Low Freedom (exact scripts)

Use when operations are fragile and consistency is critical:

```markdown
## Database migration

Run exactly this script:

python scripts/migrate.py --verify --backup

Do not modify the command or add additional flags.
```

---

## Claude Search Optimization (CSO) Deep Dive

### Keyword Strategy

Include words the agent would search for:

- **Error messages**: "Hook timed out", "ENOTEMPTY", "race condition"
- **Symptoms**: "flaky", "hanging", "zombie", "pollution"
- **Synonyms**: "timeout/hang/freeze", "cleanup/teardown/afterEach"
- **Tools**: actual commands, library names, file types

### Description Anti-Pattern: Workflow Summary

Testing revealed that when a description summarizes a skill's workflow, agents follow the description instead of reading the full skill body.

```yaml
# BAD: summarizes workflow -- agent may follow this, skip the skill body
description: Code review between tasks with dispatch of subagents

# This caused an agent to do ONE review, even though the skill's body
# clearly showed TWO reviews (spec compliance then code quality).

# GOOD: triggering conditions only
description: Use when executing implementation plans with independent tasks
# Agent correctly read the full body and followed the two-stage review.
```

The trap: descriptions that summarize workflow create a shortcut agents will take. The skill body becomes documentation they skip.

### Token Efficiency

**Move details to tool help:**
```markdown
# BAD: document all flags in SKILL.md
search-conversations supports --text, --both, --after DATE, --before DATE, --limit N

# GOOD: reference --help
search-conversations supports multiple modes and filters. Run --help for details.
```

**Use cross-references:**
```markdown
# BAD: repeat workflow details
When searching, dispatch subagent with template...
[20 lines of repeated instructions]

# GOOD: reference other skill
Always use subagents. REQUIRED: Use create-skill for authoring workflow.
```

**Compress examples:**
```markdown
# BAD: verbose (42 words)
your human partner: "How did we handle authentication errors in React Router before?"
You: I'll search past conversations for React Router authentication patterns.
[Dispatch subagent with search query: "React Router authentication error handling 401"]

# GOOD: minimal (20 words)
Partner: "How did we handle auth errors in React Router?"
You: Searching... [Dispatch subagent → synthesis]
```

---

## Evaluation-Driven Development

Build evaluations BEFORE writing extensive documentation. This ensures the skill solves real problems.

1. **Identify gaps**: run the agent on representative tasks without a skill. Document specific failures or missing context
2. **Create evaluations**: build 3+ scenarios that test those gaps
3. **Establish baseline**: measure performance without the skill
4. **Write minimal instructions**: just enough to address the gaps and pass evaluations
5. **Iterate**: execute evaluations, compare against baseline, refine

This prevents documenting imagined requirements that never materialize.

---

## Iterative Claude A/B Development

Work with one instance ("Claude A") to create a skill used by others ("Claude B"):

**Creating a new skill:**

1. Complete a task with Claude A using normal prompting. Notice what context you repeatedly provide
2. Identify the reusable pattern -- what would help for similar future tasks
3. Ask Claude A to create a skill capturing those patterns
4. Review for conciseness -- remove explanations the agent doesn't need
5. Test with Claude B (fresh instance with the skill) on related tasks
6. Iterate: if Claude B struggles, return to Claude A with specifics

**Iterating on existing skills:**

1. Use the skill with Claude B on real tasks (not test scenarios)
2. Observe behavior -- where does it struggle, succeed, or make unexpected choices
3. Return to Claude A with observations: "Claude B forgot to filter test accounts when I asked for a regional report"
4. Apply refinements and re-test

**What to watch for:**

- Unexpected file reading order -- structure might not be intuitive
- Missed references -- links might need to be more prominent
- Overreliance on certain sections -- consider promoting to main SKILL.md
- Ignored files -- might be unnecessary or poorly signaled

---

## Bulletproofing Discipline Skills

Skills that enforce rules (like TDD) need to resist rationalization. Agents find loopholes under pressure.

### Close Every Loophole Explicitly

Don't just state the rule -- forbid specific workarounds:

```markdown
# BAD: just the rule
Write code before test? Delete it.

# GOOD: close loopholes
Write code before test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete
```

### Rationalization Table Template

Capture rationalizations from baseline testing:

```markdown
| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "It's about spirit not ritual" | Violating the letter IS violating the spirit. |
| "This is different because..." | It's not. Follow the process. |
```

### Red Flags List Template

```markdown
## Red Flags -- STOP and Start Over

- Code before test
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "This is different because..."

**All of these mean: delete and start over.**
```

### Spirit vs. Letter

Add this foundational principle early in discipline skills:

> **Violating the letter of the rules is violating the spirit of the rules.**

This cuts off an entire class of rationalization.

---

## Testing Methodology

### Pressure Scenario Construction

For discipline-enforcing skills, combine multiple pressures:

- **Time pressure**: "We need this shipped today"
- **Sunk cost**: agent has already written code before seeing the skill
- **Authority**: "The tech lead said to skip tests this time"
- **Exhaustion**: many tasks completed, discipline slipping on later ones

### Per-Type Testing Approaches

**Discipline-enforcing** (TDD, verification-before-completion):
- Academic questions: do they understand the rules?
- Pressure scenarios: do they comply under stress?
- Multiple pressures combined
- Success: agent follows rule under maximum pressure

**Technique** (condition-based-waiting, root-cause-tracing):
- Application scenarios: can they apply correctly?
- Variation scenarios: do they handle edge cases?
- Missing information: do instructions have gaps?
- Success: agent applies technique to new scenario

**Pattern** (reducing-complexity, information-hiding):
- Recognition: do they recognize when the pattern applies?
- Application: can they use the mental model?
- Counter-examples: do they know when NOT to apply?
- Success: correctly identifies when/how to apply

**Reference** (API docs, command references):
- Retrieval: can they find the right information?
- Application: can they use what they found?
- Gap testing: are common use cases covered?
- Success: finds and correctly applies reference info

---

## Anti-Patterns Expanded

### Narrative Storytelling
"In session 2025-10-03, we found that empty projectDir caused..." -- too specific to one incident, not reusable as a pattern. Extract the technique, discard the narrative.

### Multi-Language Dilution
Creating example-js.js, example-py.py, example-go.go -- mediocre quality in each, maintenance burden. Pick the most relevant language, write one excellent example. Agents are good at porting.

### Code in Flowcharts
```
step1 [label="import fs"];
step2 [label="read file"];
```
Can't copy-paste, hard to read. Use code blocks for code, flowcharts only for non-obvious decisions.

### Generic Labels
helper1, helper2, step3, pattern4 -- labels should have semantic meaning. Name by what the thing does.

### Too Many Options
"You can use pypdf, or pdfplumber, or PyMuPDF, or pdf2image..." -- provide a default with an escape hatch:
"Use pdfplumber for text extraction. For scanned PDFs requiring OCR, use pdf2image with pytesseract instead."

### Time-Sensitive Information
"If before August 2025, use old API" -- will become outdated. Use an "old patterns" section with `<details>` collapse instead.

---

## File Organization Patterns

### Self-Contained Skill
```
defense-in-depth/
  SKILL.md    # Everything inline
```
When: all content fits, no heavy reference needed.

### Skill with Reusable Tool
```
condition-based-waiting/
  SKILL.md    # Overview + patterns
  example.ts  # Working helpers to adapt
```
When: tool is reusable code, not just narrative.

### Skill with Heavy Reference
```
pptx/
  SKILL.md       # Overview + workflows
  pptxgenjs.md   # API reference
  ooxml.md       # XML structure docs
  scripts/       # Executable tools
```
When: reference material too large for inline. Keep SKILL.md as the entry point with links.

---

## Sources

Content in this file incorporates material from:

- [Anthropic: Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [obra/superpowers: writing-skills](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md) -- used under [MIT License](https://github.com/obra/superpowers/blob/main/LICENSE), copyright Jesse Vincent
